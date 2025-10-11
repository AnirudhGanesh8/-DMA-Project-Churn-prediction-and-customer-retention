source("R/install_packages.R")   # ensure packages
source("R/01_load_data.R")
source("R/02_feature_engineering.R")
source("R/03_train_models.R")
source("R/04_evaluate.R")
source("R/05_retention_strategy.R")

# Optionally include explainability step (default off to keep only 4 plots)
cfg <- yaml::read_yaml("config.yml")
if (isTRUE(cfg$reports$explain)) {
	source("R/06_explain_model.R")
}