library(tidyverse)
library(tidymodels)
library(ggthemes)
source("R/utils.R")

cfg <- load_cfg()
artifacts <- cfg$paths$artifacts_dir
reports <- cfg$paths$reports_dir
ensure_dir(reports)


test_preds <- read_csv(file.path(artifacts, "predictions_test.csv"), show_col_types = FALSE)
id_col <- cfg$data$id_col
target_col <- cfg$data$target_col

# ROC and PR curves
roc_df <- yardstick::roc_curve(test_preds, truth = !!sym(target_col), .pred_yes)
pr_df  <- yardstick::pr_curve(test_preds,  truth = !!sym(target_col), .pred_yes)

p_roc <- ggplot(roc_df, aes(x = 1 - specificity, y = sensitivity)) +
  geom_path(color = "#2c7fb8") + geom_abline(lty = 2, color = "gray70") +
  theme_minimal() + ggtitle("ROC Curve")
save_png(p_roc, file.path(reports, "roc_curve.png"))

p_pr <- ggplot(pr_df, aes(x = recall, y = precision)) +
  geom_path(color = "#41ab5d") + theme_minimal() + ggtitle("Precision-Recall Curve")
save_png(p_pr, file.path(reports, "pr_curve.png"))

# Confusion matrix at chosen threshold
th <- as.numeric(readLines(file.path(artifacts, "threshold_optimal.txt")))
cm <- test_preds %>%
  mutate(pred_label = factor(ifelse(.pred_yes >= th, "yes", "no"), levels = c("no","yes"))) %>%
  yardstick::conf_mat(truth = !!sym(target_col), estimate = pred_label)
p_cm <- autoplot(cm, type = "heatmap") + ggtitle("Confusion Matrix (Optimal Threshold)")
save_png(p_cm, file.path(reports, "confusion_matrix.png"))

# Gains curve
gain <- yardstick::gain_curve(test_preds, truth = !!sym(target_col), .pred_yes)
p_lift <- ggplot(gain, aes(x = .percent_tested, y = .gain)) +
  geom_line(color = "#ff7f0e") +
  geom_abline(slope = 1, intercept = 0, lty = 2, color = "gray60") +
  scale_x_continuous(labels = scales::percent) +
  scale_y_continuous(labels = scales::percent) +
  theme_minimal() + labs(title = "Gains Curve", x = "Population targeted", y = "Gain")
save_png(p_lift, file.path(reports, "lift_curve.png"))