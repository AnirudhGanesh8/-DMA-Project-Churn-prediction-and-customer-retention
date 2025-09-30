targets <- list(
  artifacts = "artifacts",
  reports = "reports"
)

for (d in targets) {
  if (dir.exists(d)) {
    files <- list.files(d, full.names = TRUE, recursive = FALSE)
    files <- files[basename(files) != ".gitkeep"]
    if (length(files) > 0) {
      try(unlink(files, recursive = TRUE, force = TRUE), silent = TRUE)
    }
  }
}

message("Cleaned artifacts/ and reports/ (kept .gitkeep)")
