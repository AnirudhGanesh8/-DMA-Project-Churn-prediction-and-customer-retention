library(tidyverse)
library(tidymodels)
source("R/utils.R")

cfg <- load_cfg()
set.seed(cfg$data$seed)

artifacts <- cfg$paths$artifacts_dir
reports <- cfg$paths$reports_dir
ensure_dir(artifacts); ensure_dir(reports)

quick <- isTRUE(getOption("dma.quick", cfg$training$quick))  # allow override via options

df <- readRDS(file.path(artifacts, "processed.rds"))
id_col <- cfg$data$id_col
target_col <- cfg$data$target_col

# Split
spl <- initial_split(df, prop = 1 - cfg$data$test_size, strata = !!sym(target_col))
train <- training(spl)
test  <- testing(spl)

# Aggressive downsample for speed in quick mode
if (quick && nrow(train) > 500) {
  message("[quick] Downsampling training set for speed (n=500)...")
  train <- train %>% slice_sample(n = 500)
}

# Recipe
rec <- recipe(as.formula(paste(target_col, "~ .")), data = train) %>%
  update_role(!!sym(id_col), new_role = "id") %>%
  step_rm(matches("^X[.]")) %>%
  step_rm(any_of(c())) %>%
  # Convert logicals to factors so they can be dummy-encoded
  step_mutate(dplyr::across(where(is.logical), ~ factor(.x, levels = c(FALSE, TRUE), labels = c("no", "yes")))) %>%
  step_zv(all_predictors()) %>%
  step_impute_median(all_numeric_predictors(), skip = FALSE) %>%
  step_impute_mode(all_nominal_predictors(), -all_outcomes(), skip = FALSE) %>%
  # Collapse very rare categories to reduce dimensionality/collinearity
  step_other(all_nominal_predictors(), -all_outcomes(), threshold = 0.01, other = "other") %>%
  # Handle unseen levels during resampling
  step_novel(all_nominal_predictors(), -all_outcomes()) %>%
  step_dummy(all_nominal_predictors(), -all_outcomes()) %>%
  # Remove any zero-variance columns created by dummying/novel
  step_zv(all_predictors()) %>%
  # Remove linear combinations and highly correlated numeric features to stabilize GLM
  step_lincomb(all_predictors()) %>%
  step_corr(all_numeric_predictors(), threshold = 0.99) %>%
  step_normalize(all_numeric_predictors(), -has_role("id"))

# Models
models <- list()

if (isTRUE(cfg$models$logistic_reg)) {
  # Use glmnet with a small L1 penalty to avoid rank-deficiency
  spec_log <- logistic_reg(penalty = 0.001, mixture = 1) %>% set_engine("glmnet")
  wf_log <- workflow() %>% add_model(spec_log) %>% add_recipe(rec)
  models$logistic <- list(type = "logistic", wf = wf_log, tune = FALSE)
}

if (isTRUE(cfg$models$random_forest)) {
  if (quick) {
    spec_rf <- rand_forest(
      trees = 100, mtry = NULL, min_n = 5
    ) %>%
      set_engine("ranger", importance = "impurity") %>%
      set_mode("classification")
    wf_rf <- workflow() %>% add_model(spec_rf) %>% add_recipe(rec)
    models$rf <- list(type = "rf", wf = wf_rf, tune = FALSE)
  } else {
    spec_rf <- rand_forest(
      mtry = tune(), min_n = tune(), trees = cfg$models$rf$trees
    ) %>%
      set_engine("ranger", importance = "impurity") %>%
      set_mode("classification")
    wf_rf <- workflow() %>% add_model(spec_rf) %>% add_recipe(rec)
    models$rf <- list(type = "rf", wf = wf_rf, tune = TRUE)
  }
}

if (isTRUE(cfg$models$xgboost)) {
  if (quick) {
    spec_xgb <- boost_tree(
      trees = 150, learn_rate = 0.1, mtry = NULL,
      tree_depth = 4, min_n = 5, loss_reduction = 0
    ) %>%
      set_engine("xgboost") %>%
      set_mode("classification")
    wf_xgb <- workflow() %>% add_model(spec_xgb) %>% add_recipe(rec)
    models$xgb <- list(type = "xgb", wf = wf_xgb, tune = FALSE)
  } else {
    spec_xgb <- boost_tree(
      trees = cfg$models$xgb$trees, learn_rate = tune(), mtry = tune(),
      tree_depth = tune(), min_n = tune(), loss_reduction = tune()
    ) %>%
      set_engine("xgboost") %>%
      set_mode("classification")
    wf_xgb <- workflow() %>% add_model(spec_xgb) %>% add_recipe(rec)
    models$xgb <- list(type = "xgb", wf = wf_xgb, tune = TRUE)
  }
}

# CV and metrics
v_folds <- if (quick) 2L else cfg$training$cv_folds
folds <- vfold_cv(train, v = v_folds, strata = !!sym(target_col))

# During resampling/tuning, compute only ROC AUC to avoid threshold/precision warnings and speed up
metric_set <- yardstick::metric_set(yardstick::roc_auc)

# Tuning helper
tune_model <- function(entry) {
  if (!isTRUE(entry$tune)) {
    message("Fitting non-tuned model: ", entry$type)
    res <- fit_resamples(entry$wf, folds, metrics = metric_set, control = control_resamples(save_pred = TRUE))
    list(result = res, best_params = NULL, wf_final = fit(entry$wf, train))
  } else {
    message("Tuning model: ", entry$type)
    # Extract tunable parameters from the workflow and create a space-filling grid
    param_set <- tune::extract_parameter_set_dials(entry$wf)
    # Finalize parameter ranges (e.g., `mtry`) using the training data
    param_set <- dials::finalize(param_set, train)
  grid_size <- if (quick) 3L else 20L
    grid <- dials::grid_space_filling(param_set, size = grid_size)
    ctrl <- control_grid(save_pred = TRUE, verbose = FALSE)
    res <- tune_grid(entry$wf, resamples = folds, grid = grid, metrics = metric_set, control = ctrl)
  best <- select_best(res, metric = cfg$training$optimize_metric)
    wf_final <- finalize_workflow(entry$wf, best) %>% fit(train)
    list(result = res, best_params = best, wf_final = wf_final)
  }
}

results <- lapply(models, tune_model)

# Pick best by optimize_metric
collect_scores <- function(res) {
  if (inherits(res$result, "tune_results")) {
    show_best(res$result, metric = cfg$training$optimize_metric, n = 1)
  } else {
    collect_metrics(res$result) %>% filter(.metric == cfg$training$optimize_metric) %>% arrange(desc(mean)) %>% slice(1)
  }
}
scores <- map_dfr(results, collect_scores, .id = "model")
best_name <- scores %>% arrange(desc(mean)) %>% slice(1) %>% pull(model)
best_entry <- results[[best_name]]

saveRDS(best_entry$wf_final, file.path(artifacts, "best_workflow.rds"))
write_csv(scores, file.path(artifacts, "cv_scores.csv"))

# Predict on test
best_fit <- best_entry$wf_final
prob_col <- paste0(".pred_", "yes")
pred_probs <- predict(best_fit, test, type = "prob")
pred_class_default <- predict(best_fit, test, type = "class")
pred_test <- pred_probs %>%
  bind_cols(pred_class_default) %>%
  bind_cols(test %>% select(!!sym(id_col), !!sym(target_col)))

# Find optimal threshold by maximizing F1 over a grid
ths <- seq(0.01, 0.99, by = 0.01)
score_th <- function(th) {
  lab <- factor(ifelse(pred_test$.pred_yes >= th, "yes", "no"), levels = c("no","yes"))
  yardstick::f_meas_vec(truth = pred_test[[target_col]], estimate = lab)
}
vals <- sapply(ths, score_th)
opt_th <- ths[which.max(vals)]
writeLines(as.character(opt_th), con = file.path(artifacts, "threshold_optimal.txt"))

# Apply threshold
pred_labeled <- pred_test %>%
  mutate(pred_label = factor(ifelse(.pred_yes >= opt_th, "yes", "no"), levels = c("no","yes")))

# Metrics on test
metrics_test <- yardstick::metric_set(roc_auc, pr_auc, accuracy, kap, f_meas)(
  data = pred_labeled, truth = !!sym(target_col), estimate = pred_label, .pred_yes
)
write_csv(pred_labeled %>% select(all_of(c(id_col, target_col)), .pred_yes, pred_label),
          file.path(artifacts, "predictions_test.csv"))
write_csv(metrics_test, file.path(artifacts, "metrics_test.csv"))