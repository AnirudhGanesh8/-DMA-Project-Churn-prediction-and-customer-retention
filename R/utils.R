library(yaml)
library(tidyverse)

load_cfg <- function(path = "config.yml") {
  yaml::read_yaml(path)
}

ensure_dir <- function(path) {
  if (!dir.exists(path)) dir.create(path, recursive = TRUE, showWarnings = FALSE)
}

as_churn_factor <- function(x) {
  if (is.factor(x)) {
    # ensure levels "no","yes" order
    lev <- levels(x)
    if (all(c("no","yes") %in% lev)) return(factor(x, levels = c("no","yes")))
    if (all(c("Yes","No") %in% lev)) return(factor(ifelse(x=="Yes","yes","no"), levels=c("no","yes")))
    return(x)
  }
  if (is.logical(x)) return(factor(ifelse(x, "yes", "no"), levels = c("no","yes")))
  if (is.numeric(x)) return(factor(ifelse(x > 0.5, "yes", "no"), levels = c("no","yes")))
  if (is.character(x)) {
    x2 <- tolower(x)
    x2 <- ifelse(x2 %in% c("1","true","yes","y"), "yes",
          ifelse(x2 %in% c("0","false","no","n"), "no", x2))
    return(factor(x2, levels = c("no","yes")))
  }
  stop("Unsupported churn column type")
}

save_png <- function(plot, path, width = 8, height = 5, dpi = 150) {
  ggplot2::ggsave(filename = path, plot = plot, width = width, height = height, dpi = dpi)
}