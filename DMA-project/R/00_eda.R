library(tidyverse)
library(ggthemes)
source("R/utils.R")

cfg <- load_cfg()
artifacts <- cfg$paths$artifacts_dir
reports <- cfg$paths$reports_dir
ensure_dir(reports)

raw <- readRDS(file.path(artifacts, "raw.rds"))
processed <- readRDS(file.path(artifacts, "processed.rds"))

id_col <- cfg$data$id_col
target_col <- cfg$data$target_col

# 1) Overall churn rate
overall_churn <- raw %>%
  mutate(churn = as_churn_factor(.data[[target_col]])) %>%
  count(churn) %>%
  mutate(pct = n / sum(n))

p_churn <- ggplot(overall_churn, aes(x = churn, y = pct, fill = churn)) +
  geom_col(width = 0.6) +
  scale_y_continuous(labels = scales::percent) +
  scale_fill_brewer(palette = "Set2", guide = "none") +
  theme_minimal() + labs(title = "Overall Churn Rate", x = NULL, y = "Percent")
save_png(p_churn, file.path(reports, "eda_overall_churn.png"))

# 2) Missingness (top 25 columns by missing percent) on raw
miss_tbl <- tibble(
  column = names(raw),
  missing = map_dbl(raw, ~sum(is.na(.x))),
  total = nrow(raw)
) %>% mutate(miss_pct = missing / total) %>% arrange(desc(miss_pct)) %>% slice_head(n = 25)

p_miss <- ggplot(miss_tbl, aes(x = reorder(column, miss_pct), y = miss_pct)) +
  geom_col(fill = "#9ecae1") + coord_flip() +
  scale_y_continuous(labels = scales::percent) +
  theme_minimal() + labs(title = "Missingness by Column (Top 25)", x = NULL, y = "% Missing")
save_png(p_miss, file.path(reports, "eda_missingness.png"))

# 3) Distributions by churn (key numeric features)
num_feats <- c("monthly_charges", "tenure_months")
for (f in intersect(num_feats, names(raw))) {
  p <- raw %>%
    mutate(churn = as_churn_factor(.data[[target_col]])) %>%
    ggplot(aes(x = .data[[f]], fill = churn)) +
    geom_histogram(alpha = 0.6, position = "identity", bins = 30) +
    theme_minimal() +
    scale_fill_brewer(palette = "Set2") +
    labs(title = paste("Distribution of", f, "by Churn"), x = f, y = "Count")
  save_png(p, file.path(reports, paste0("eda_dist_", f, ".png")))
}

# 4) Churn rate by key categorical features
cat_feats <- c("contract_type", "payment_method", "auto_pay")
for (f in intersect(cat_feats, names(raw))) {
  agg <- raw %>%
    mutate(churn = as_churn_factor(.data[[target_col]])) %>%
    group_by(.data[[f]]) %>%
    summarise(churn_rate = mean(churn == "yes", na.rm = TRUE), .groups = "drop")
  p <- ggplot(agg, aes(x = reorder(.data[[f]], churn_rate), y = churn_rate)) +
    geom_col(fill = "#a1d99b") + coord_flip() +
    scale_y_continuous(labels = scales::percent) +
    theme_minimal() + labs(title = paste("Churn Rate by", f), x = f, y = "Churn Rate")
  save_png(p, file.path(reports, paste0("eda_churn_by_", f, ".png")))
}

# 5) Correlation heatmap (processed numeric)
num_cols <- processed %>% select(where(is.numeric)) %>% select(-any_of(id_col))
if (ncol(num_cols) >= 2) {
  cm <- suppressWarnings(cor(num_cols, use = "pairwise.complete.obs"))
  cm_long <- as.data.frame(as.table(cm))
  names(cm_long) <- c("Var1", "Var2", "value")
  p_corr <- ggplot(cm_long, aes(x = Var1, y = Var2, fill = value)) +
    geom_tile() +
    scale_fill_gradient2(low = "#d7191c", mid = "#f7f7f7", high = "#2c7bb6", midpoint = 0, limits = c(-1,1)) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
    labs(title = "Correlation Heatmap (Processed Numeric)", x = NULL, y = NULL, fill = "corr")
  save_png(p_corr, file.path(reports, "eda_corr_heatmap.png"), width = 9, height = 7)
}

# 6) Quick EDA summary CSVs
eda_dir <- artifacts

# churn by contract
if ("contract_type" %in% names(raw)) {
  churn_by_contract <- raw %>%
    mutate(churn = as_churn_factor(.data[[target_col]])) %>%
    count(contract_type, churn) %>% group_by(contract_type) %>%
    mutate(pct = n/sum(n)) %>% ungroup()
  readr::write_csv(churn_by_contract, file.path(eda_dir, "eda_churn_by_contract.csv"))
}

# numeric summaries
num_summary <- raw %>%
  mutate(churn = as_churn_factor(.data[[target_col]])) %>%
  select(where(is.numeric), churn) %>%
  pivot_longer(cols = -churn, names_to = "feature", values_to = "value") %>%
  group_by(feature, churn) %>%
  summarise(n = sum(!is.na(value)), mean = mean(value, na.rm = TRUE), sd = sd(value, na.rm = TRUE),
            p25 = quantile(value, 0.25, na.rm = TRUE), median = median(value, na.rm = TRUE), p75 = quantile(value, 0.75, na.rm = TRUE),
            .groups = "drop")
readr::write_csv(num_summary, file.path(eda_dir, "eda_numeric_by_churn.csv"))

message("EDA artifacts saved to ", reports, " and ", artifacts)
