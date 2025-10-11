# DMA Project · Churn Prediction & Customer Retention

[![CI](https://github.com/AnirudhGanesh8/-DMA-Project-Churn-prediction-and-customer-retention/actions/workflows/ci.yml/badge.svg)](https://github.com/AnirudhGanesh8/-DMA-Project-Churn-prediction-and-customer-retention/actions/workflows/ci.yml)
![R](https://img.shields.io/badge/R-4.5%2B-276DC3?logo=r&logoColor=white)
![Shiny](https://img.shields.io/badge/Shiny-Dashboard-0099F9?logo=r&logoColor=white)
![Tidymodels](https://img.shields.io/badge/Made%20with-tidymodels-FF6F00)

Predict customer churn, select the best model, and optimize who to contact for maximum retention profit—all in a fast, configurable R pipeline with a modern Shiny dashboard.

- End‑to‑end ML workflow (data → features → models → evaluation → business strategy)
- Models: Logistic (glmnet), Random Forest (ranger), XGBoost
- Quick mode for instant runs; full mode for higher accuracy
- Clean visuals: ROC, PR, Confusion, Gains, and Profit curves
- Production‑style artifacts and CSVs for analysis and reporting

---

## Table of Contents

- Overview
- Project Structure
- Features
- Getting Started
- How to Run
- Configuration
- Shiny Dashboard
- Outputs and Artifacts
- Models and Training
- Performance Controls
- Testing
- Troubleshooting
- License

---

## Overview

This project predicts which customers are likely to churn and translates predictions into an optimal retention policy. It balances:

- Who to contact (targeting), and
- How many to contact (budget/ROI)

Business benefit: focus your retention budget on customers who are both likely to churn and likely to respond to intervention.

---

## Project Structure

```
.
├─ app/                      # Shiny dashboard
│  └─ app.R
├─ R/                        # R scripts (pipeline steps and utilities)
│  ├─ 01_load_data.R
│  ├─ 02_feature_engineering.R
│  ├─ 03_train_models.R
│  ├─ 04_evaluate.R
│  ├─ 05_retention_strategy.R
│  ├─ 06_explain_model.R     # optional (disabled by default)
│  ├─ install_packages.R
│  └─ utils.R
├─ data/
│  ├─ customers.csv          # provide your dataset here (optional)
│  └─ schema.md
├─ artifacts/                # generated: models, metrics, predictions, etc.
├─ reports/                  # generated: plots (PNG)
├─ scripts/
│  └─ run_all.R              # orchestrates the pipeline
├─ tests/
│  └─ test_features.R
├─ config.yml                # main configuration
├─ README.md
├─ Makefile
└─ .github/workflows/ci.yml  # CI placeholder
```

---

## Features

- Data loading
	- Uses `data/customers.csv` if present; otherwise synthesizes realistic data.
- Feature engineering
	- Tenure bins, high‑value flags, service combinations, engagement metrics, normalized spend.
- Modeling (tidymodels)
	- Logistic Regression (glmnet), Random Forest (ranger), XGBoost.
	- Best model selected by ROC AUC.
- Evaluation & Business visuals
	- ROC Curve, PR Curve, Confusion Matrix, Gains Curve, Profit Curve.
- Retention strategy
	- Finds profit‑maximizing targeting % using configurable costs and uplift.
- Shiny dashboard
	- Run/Refresh with Quick mode toggle
	- KPIs, 5 core plots, artifacts preview
	- Download data and plots ZIP

---

## Getting Started

### Prerequisites

- R 4.5+ (Windows: also have RTools if building packages)
- Internet access to install CRAN packages on first run

Packages are auto‑installed via `R/install_packages.R`:

tidyverse, tidymodels, ranger, xgboost, glmnet, shiny, bslib, DT, zip, testthat, yaml

---

## How to Run

You can run the pipeline (to generate artifacts/plots) and/or launch the Shiny dashboard.

### 1) Run the end‑to‑end pipeline (fast quick mode by default)

This generates artifacts in `artifacts/` and plots in `reports/`.

```powershell
# From the project root
"C:\Program Files\R\R-4.5.1\bin\R.exe" -f scripts/run_all.R
```

Or, if Rscript is on PATH:

```powershell
Rscript scripts/run_all.R
```

### 2) Start the Shiny dashboard

Click “Run / Refresh” inside the app to execute the pipeline and render all visuals.

```powershell
"C:\Program Files\R\R-4.5.1\bin\R.exe" -e "shiny::runApp('app', launch.browser=TRUE)"
```

Tip (Windows): If your system doesn’t find Rscript on PATH, use the full path to R as shown above.

---

## Configuration

All knobs live in `config.yml`.

Key sections:

- data
	- path: `data/customers.csv`
	- synthetic_rows: 2000 (used if no CSV found)
	- test_size: 0.2
- features
	- normalize, impute, interactions, drop_cols
- models
	- logistic_reg: true
	- random_forest: true
	- xgboost: true
	- rf/xgb: default trees; tune=true (full mode)
- training
	- quick: true (fast demo mode)
	- cv_folds: 5 (used in full mode)
	- optimize_metric: roc_auc
- retention (business economics)
	- contact_cost_per_customer
	- offer_cost_per_converted
	- expected_save_rate_given_contact
	- expected_ltv_uplift
- paths
	- artifacts_dir, reports_dir
- reports
	- explain: false (enable to generate model explainability)

---

## Shiny Dashboard

Sidebar

- Quick Mode
	- Fast run (500 training rows, 2‑fold CV, no tuning for RF/XGB).
- Run / Refresh
	- Executes pipeline; updates KPIs, plots, and tables.
- Downloads
	- Current data (artifacts/raw.csv)
	- All plots (ZIP from `reports/`)

Main Area

- KPIs (after run):
	- ROC AUC, PR AUC, Accuracy, F1
- Plots (5):
	- ROC Curve: ranking quality (TPR vs FPR)
	- PR Curve: precision vs recall (great for class imbalance)
	- Confusion Matrix: at F1‑optimized threshold
	- Profit Curve: expected profit vs % targeted with peak marker
	- Gains Curve: cumulative % of churners captured vs % targeted
- Artifacts Tabs:
	- CV scores table
	- Predictions preview (test set)

---

## Outputs and Artifacts

Generated after a pipeline run:

- Models and metrics
	- `artifacts/best_workflow.rds`
	- `artifacts/cv_scores.csv`
	- `artifacts/metrics_test.csv`
	- `artifacts/predictions_test.csv`
	- `artifacts/threshold_optimal.txt`
- Data snapshots
	- `artifacts/raw.rds`, `artifacts/raw.csv`
	- `artifacts/processed.rds`
- Business strategy
	- `artifacts/profit_curve.csv`
	- `artifacts/retention_best_policy.csv`
- Plots (PNG, for reports/presentations)
	- `reports/roc_curve.png`
	- `reports/pr_curve.png`
	- `reports/confusion_matrix.png`
	- `reports/profit_curve.png`
	- `reports/gains_curve.png`

---

## Models and Training

- Logistic Regression (glmnet)
	- Uses small L1 penalty to eliminate rank-deficiency; interpretable baseline.
- Random Forest (ranger)
	- Handles nonlinearity and interactions; robust out‑of‑the‑box.
- XGBoost
	- Often highest accuracy; efficient gradient boosting.

Model selection is based on `training.optimize_metric` (default: ROC AUC). In quick mode, RF/XGB use fixed reasonable hyperparameters for speed; in full mode, tuning is enabled.

---

## Performance Controls

- Fastest runs (demo/iterating):
	- Keep “Quick mode” ON in the app (or `training.quick: true` in `config.yml`)
	- Optional: reduce `data.synthetic_rows` or use a smaller `customers.csv`
- Higher accuracy (final results):
	- Turn “Quick mode” OFF
	- Increase `training.cv_folds`
	- Keep RF/XGB tuning enabled

---

## Testing

- Minimal tests live in `tests/`.
- Run tests from R:

```r
testthat::test_dir("tests")
```

---

## Troubleshooting

- Rscript not found on Windows
	- Use the full path to R: `"C:\\Program Files\\R\\R-4.5.1\\bin\\R.exe"`
- Package install errors
	- Ensure internet connectivity; on Windows, install RTools if compilation is needed.
- xgboost build issues (Windows)
	- Install via CRAN; if needed, install the prebuilt binary or update RTools.
- Shiny app shows old plots
	- Click “Run / Refresh” to regenerate artifacts and plots for the current session.
- Metrics show NA in PR AUC
	- In very small samples or extreme thresholds, precision can be undefined; switch off Quick mode for stability.

---

## License

Add your preferred license (e.g., MIT) in a `LICENSE` file. Update this section accordingly.

---

## Acknowledgements

Built with:

- tidymodels (parsnip, recipes, workflows, tune, yardstick, rsample)
- tidyverse (dplyr, ggplot2, readr, tidyr, purrr)
- shiny + bslib + DT
- ranger, xgboost, glmnet

If you want, we can also add a docs/ folder with screenshots and wire up GitHub Pages for a lightweight project site.

# DMA Project (Simplified)

This repo builds a churn model and generates 4 core plots:
- ROC curve: `reports/roc_curve.png`
- Precision–Recall curve: `reports/pr_curve.png`
- Confusion Matrix (at optimal F1 threshold): `reports/confusion_matrix.png`
- Retention Profit curve: `reports/profit_curve.png`

## Quick start (Windows PowerShell)

1. Ensure R is installed (Rscript in PATH). If not, run R from the Start menu and install packages.
2. From the project folder:

```powershell
Rscript scripts/run_all.R
```

Run tests:

```powershell
Rscript -e "testthat::test_dir('tests')"
```

If Rscript isn’t in PATH, use the full path, e.g.:

```powershell
& "C:\\Program Files\\R\\R-4.x.x\\bin\\Rscript.exe" scripts\\run_all.R
```

## Config knobs
- `training.quick: true` speeds up runs by reducing tuning and sampling.
- Toggle models in `config.yml` under `models`.
- Set `reports.explain: true` to generate extra explainability plots (off by default to keep outputs minimal).

Artifacts are written to `artifacts/`. Plots are written to `reports/`.

## Shiny dashboard

Launch the app to run the pipeline and view the 4 main plots and KPIs:

```powershell
R -e "shiny::runApp('app', launch.browser=TRUE)"
```

Use the Quick mode toggle in the app for fast runs.
