packages <- c(
  "tidyverse", "yaml",
  "tidymodels", "ranger", "xgboost", "glmnet",
  "testthat", "shiny", "bslib", "DT", "zip"
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