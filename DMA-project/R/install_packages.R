packages <- c(
  "tidyverse", "lubridate", "yaml",
  "tidymodels", "ranger", "xgboost", "vip",
  "yardstick", "ggthemes", "iml", "scales", "testthat"
)

# Ensure a user-writable library is first on .libPaths()
ensure_user_lib <- function() {
  # Try R_LIBS_USER, else fall back to AppData Local path on Windows
  user_lib <- Sys.getenv("R_LIBS_USER", unset = NA)
  if (is.na(user_lib) || user_lib == "") {
    # Construct default for Windows: %USERPROFILE%/AppData/Local/R/win-library/<major.minor>
    ver <- paste0(R.version$major, ".", strsplit(R.version$minor, "[.]")[[1]][1])
    user_lib <- file.path(Sys.getenv("USERPROFILE"), "AppData", "Local", "R", "win-library", ver)
  }
  if (!dir.exists(user_lib)) dir.create(user_lib, recursive = TRUE, showWarnings = FALSE)
  .libPaths(c(user_lib, .libPaths()))
  invisible(user_lib)
}

install_if_missing <- function(pkgs) {
  user_lib <- ensure_user_lib()
  installed <- rownames(installed.packages())
  for (p in pkgs) {
    if (!p %in% installed) {
      tryCatch({
        install.packages(p, repos = "https://cloud.r-project.org", lib = user_lib, dependencies = TRUE)
      }, error = function(e) {
        message("Failed to install ", p, ": ", conditionMessage(e))
      })
    }
  }
}

install_if_missing(packages)