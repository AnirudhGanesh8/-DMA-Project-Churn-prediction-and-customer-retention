library(tidyverse)
library(tidymodels)
library(vip)
library(iml)
source("R/utils.R")

cfg <- load_cfg()
artifacts <- cfg$paths$artifacts_dir
reports <- cfg$paths$reports_dir
ensure_dir(reports)

wf <- readRDS(file.path(artifacts, "best_workflow.rds"))
df <- readRDS(file.path(artifacts, "processed.rds"))

# Identify underlying model
mdl <- workflows::extract_fit_parsnip(wf)$fit
is_rf <- inherits(mdl, "ranger")
is_xgb <- inherits(mdl, "xgb.Booster")

# Variable importance
if (is_rf || is_xgb) {
  p_vip <- vip::vip(mdl, num_features = 20)
  save_png(p_vip, file.path(reports, "variable_importance.png"))
} else {
  message("Variable importance not available for this model; skipping VIP plot.")
}

# Partial dependence for top features (if available)
if (is_rf || is_xgb) {
  top_feats <- tryCatch({
    vip::vi(mdl) %>% arrange(desc(Importance)) %>% slice_head(n = 3) %>% pull(Variable)
  }, error = function(e) character(0))

  if (length(top_feats) > 0) {
    # Use raw predictors; workflow will handle recipe steps
    x <- df %>% select(-all_of(cfg$data$target_col))
    y <- df[[cfg$data$target_col]]

    pred_fun <- function(newdata) {
      as.numeric(predict(wf, new_data = as_tibble(newdata), type = "prob")$.pred_yes)
    }

    for (f in top_feats) {
      pd <- tryCatch({
        iml::Predictor$new(model = pred_fun, data = as.data.frame(x), y = as.numeric(y == "yes")) %>%
          iml::FeatureEffect$new(feature = f, method = "pdp")
      }, error = function(e) NULL)

      if (!is.null(pd)) {
        p <- as_tibble(pd$results) %>%
          ggplot(aes(x = .data[[f]], y = .value)) + geom_line(color = "#1f78b4") +
          theme_minimal() + labs(title = paste("Partial Dependence:", f), y = "P(churn = yes)")
        save_png(p, file.path(reports, paste0("partial_dependence_", f, ".png")))
      }
    }
  }
}