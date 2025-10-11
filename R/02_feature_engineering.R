library(tidyverse)
library(lubridate)
source("R/utils.R")

cfg <- load_cfg()
artifacts <- cfg$paths$artifacts_dir
ensure_dir(artifacts)

raw <- readRDS(file.path(artifacts, "raw.rds"))
id_col <- cfg$data$id_col
target_col <- cfg$data$target_col

# Drop columns if configured
if (length(cfg$features$drop_cols) > 0) {
  raw <- raw %>% select(-any_of(cfg$features$drop_cols))
}

engineer <- function(d) {
  d %>%
    mutate(
      churn = as_churn_factor(.data[[target_col]]),
      tenure_bins = cut(tenure_months, breaks = c(-Inf, 3, 6, 12, 24, Inf),
                        labels = c("<=3", "4-6", "7-12", "13-24", "25+")),
      high_value = monthly_charges > quantile(monthly_charges, 0.75, na.rm = TRUE),
      service_combo = paste0(has_internet, "_", has_phone, "_", pmin(num_services, 4)),
      # Basic RFM-like signals
      recency_30d = pmin(last_login_days, 30),
      freq_support = pmin(support_calls_90d, 6),
      monetized = total_charges / pmax(tenure_months, 1)
    )
}

processed <- engineer(raw)

saveRDS(processed, file.path(artifacts, "processed.rds"))
message("Processed rows: ", nrow(processed), " | Columns: ", ncol(processed))