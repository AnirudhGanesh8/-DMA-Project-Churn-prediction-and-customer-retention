packages <- c(
  "tidyverse", "lubridate", "yaml",
  "tidymodels", "ranger", "xgboost", "vip",
  "yardstick", "pROC", "ROCR", "ggthemes",
  "DALEX", "iml", "cowplot", "scales", "testthat"
)

install_if_missing <- function(pkgs) {
  installed <- rownames(installed.packages())
  for (p in pkgs) {
    if (!p %in% installed) {
      install.packages(p, repos = "https://cloud.r-project.org")
    }
  }
}

install_if_missing(packages)