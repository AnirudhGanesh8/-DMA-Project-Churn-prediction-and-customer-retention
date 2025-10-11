library(tidyverse)
source("R/utils.R")

cfg <- load_cfg()
set.seed(cfg$data$seed)

ensure_dir("data")
ensure_dir(cfg$paths$artifacts_dir)

data_path <- cfg$data$path
override_path <- getOption("dma.data_path", default = NULL)

generate_synthetic <- function(n = 10000) {
  contract_type <- sample(c("month_to_month", "one_year", "two_year"), n, replace = TRUE, prob = c(0.6, 0.25, 0.15))
  has_internet <- rbinom(n, 1, 0.8)
  has_phone <- rbinom(n, 1, 0.9)
  num_services <- pmax(1, has_internet + has_phone + rpois(n, lambda = 1))
  tenure_months <- pmax(1, rpois(n, lambda = 18) + ifelse(contract_type=="two_year", 12, 0))
  monthly_charges <- round(runif(n, 15, 120) + 5 * num_services + ifelse(has_internet==1, 10, 0), 2)
  total_charges <- monthly_charges * tenure_months + rnorm(n, 0, 50)
  payment_method <- sample(c("credit_card", "debit_card", "bank_transfer", "cash"), n, replace = TRUE, prob = c(0.35, 0.25, 0.3, 0.1))
  support_calls_90d <- rpois(n, lambda = 0.8 + 0.6 * (monthly_charges > 80))
  last_login_days <- pmax(0, round(rnorm(n, mean = 7, sd = 5)))
  auto_pay <- rbinom(n, 1, ifelse(payment_method %in% c("credit_card", "bank_transfer"), 0.7, 0.4))

  lp <- -2.2 +
    0.02 * (monthly_charges - 50) -
    0.035 * tenure_months +
    0.6 * (contract_type == "month_to_month") +
    0.35 * (support_calls_90d >= 2) +
    0.25 * (last_login_days > 14) -
    0.4 * (auto_pay == 1)
  p <- 1 / (1 + exp(-lp))
  churn <- rbinom(n, 1, p)

  tibble(
    customer_id = sprintf("C%06d", seq_len(n)),
    tenure_months,
    monthly_charges,
    total_charges = round(total_charges, 2),
    contract_type,
    payment_method,
    has_internet = factor(ifelse(has_internet==1, "yes", "no")),
    has_phone = factor(ifelse(has_phone==1, "yes", "no")),
    num_services,
    support_calls_90d,
    last_login_days,
    auto_pay = factor(ifelse(auto_pay==1, "yes", "no")),
    churn = factor(ifelse(churn==1, "yes", "no"), levels = c("no","yes"))
  )
}

if (!is.null(override_path) && file.exists(override_path)) {
  message("Using uploaded dataset: ", override_path)
  df <- read_csv(override_path, show_col_types = FALSE)
  if (!cfg$data$target_col %in% names(df)) {
    stop("Target column not found in uploaded dataset: ", cfg$data$target_col)
  }
  df[[cfg$data$target_col]] <- as_churn_factor(df[[cfg$data$target_col]])
} else if (!file.exists(data_path)) {
  message("No data found at ", data_path, " — generating synthetic dataset.")
  df <- generate_synthetic(cfg$data$synthetic_rows)
  write_csv(df, data_path)
} else {
  df <- read_csv(data_path, show_col_types = FALSE)
  if (!cfg$data$target_col %in% names(df)) {
    stop("Target column not found: ", cfg$data$target_col)
  }
  df[[cfg$data$target_col]] <- as_churn_factor(df[[cfg$data$target_col]])
}

saveRDS(df, file.path(cfg$paths$artifacts_dir, "raw.rds"))
write_csv(df, file.path(cfg$paths$artifacts_dir, "raw.csv"))
message("Loaded rows: ", nrow(df))