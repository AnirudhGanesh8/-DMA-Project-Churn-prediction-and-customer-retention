library(tidyverse)
library(tidymodels)
source("R/utils.R")

cfg <- load_cfg()
artifacts <- cfg$paths$artifacts_dir
reports <- cfg$paths$reports_dir
ensure_dir(reports)

preds <- read_csv(file.path(artifacts, "predictions_test.csv"), show_col_types = FALSE)
target_col <- cfg$data$target_col

params <- cfg$retention
c_contact <- params$contact_cost_per_customer
c_offer   <- params$offer_cost_per_converted
save_rate <- params$expected_save_rate_given_contact
uplift    <- params$expected_ltv_uplift

# Rank customers by churn probability
ranked <- preds %>% arrange(desc(.pred_yes)) %>% mutate(rank = row_number())

simulate_profit <- function(k_frac) {
  n <- nrow(ranked)
  k <- ceiling(k_frac * n)
  contacted <- ranked[1:k, ]
  # Expected number of true churners contacted and saved
  true_churn <- mean(contacted[[target_col]] == "yes") * k
  saved <- save_rate * true_churn
  revenue <- saved * uplift
  cost <- k * c_contact + saved * c_offer
  profit <- revenue - cost
  tibble(frac_targeted = k_frac, profit = profit, revenue = revenue, cost = cost)
}

grid <- seq(0.05, 1.0, by = 0.05)
profit_curve <- map_dfr(grid, simulate_profit)

write_csv(profit_curve, file.path(artifacts, "profit_curve.csv"))

p_prof <- ggplot(profit_curve, aes(x = frac_targeted, y = profit)) +
  geom_line(color = "#2ca02c", linewidth = 1) +
  geom_point(size = 1.25) +
  scale_x_continuous(labels = scales::percent) +
  theme_minimal() + labs(title = "Retention Profit Curve", x = "Percent of customers targeted", y = "Expected profit")
save_png(p_prof, file.path(reports, "profit_curve.png"))

best_row <- profit_curve %>% slice_max(profit, n = 1)
write_csv(best_row, file.path(artifacts, "retention_best_policy.csv"))