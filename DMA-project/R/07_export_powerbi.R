library(tidyverse)
source("R/utils.R")

cfg <- load_cfg()
artifacts <- cfg$paths$artifacts_dir
ensure_dir(artifacts)

# Load data and predictions
processed <- readRDS(file.path(artifacts, "processed.rds"))
preds <- readr::read_csv(file.path(artifacts, "predictions_test.csv"), show_col_types = FALSE)

id_col <- cfg$data$id_col
target_col <- cfg$data$target_col

# Prepare a slim export suitable for BI tools
cols_keep <- c(
  id_col, target_col, "tenure_months", "monthly_charges", "total_charges",
  "contract_type", "payment_method", "has_internet", "has_phone", "num_services",
  "support_calls_90d", "last_login_days", "auto_pay"
)

# Perform a safe join by ID only; keep truth/labels from preds
export_df <- processed %>%
  select(any_of(cols_keep)) %>%
  inner_join(preds %>% select(all_of(c(id_col, target_col)), .pred_yes, pred_label), by = id_col)

# Rename columns for clarity in BI
export_df <- export_df %>%
  rename(
    churn_true = !!sym(target_col),
    churn_prob = .pred_yes,
    churn_pred = pred_label
  )

out_path <- file.path(artifacts, "powerbi_export.csv")
readr::write_csv(export_df, out_path)
message("Power BI export written to ", out_path)
