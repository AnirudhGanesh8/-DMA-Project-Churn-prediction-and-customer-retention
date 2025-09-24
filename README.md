# Churn Prediction and Customer Retention (R, tidymodels)

[![CI](https://github.com/AnirudhGanesh8/-DMA-Project-Churn-prediction-and-customer-retention/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/AnirudhGanesh8/-DMA-Project-Churn-prediction-and-customer-retention/actions/workflows/ci.yml)

End-to-end pipeline to:
- Ingest customer data (or generate a realistic synthetic dataset if missing)
- Engineer features and train multiple churn models (Logistic Regression, Random Forest, XGBoost)
- Evaluate and select the best model by cross-validation metric (default: ROC AUC)
- Produce test-set predictions, curves (ROC, PR, gains), and an optimal decision threshold
- Simulate a cost-aware retention strategy to maximize expected profit
- Explain model behavior via variable importance and partial dependence

The pipeline is implemented in R with tidymodels and runs locally or in CI via GitHub Actions.

---

## Quick Start

Prereqs:
- R (≥ 4.2 recommended)
- Internet access to install CRAN packages

Clone and run:
```bash
git clone https://github.com/AnirudhGanesh8/-DMA-Project-Churn-prediction-and-customer-retention.git
cd -DMA-Project-Churn-prediction-and-customer-retention

# Install dependencies and run the full pipeline
make run
# or:
Rscript scripts/run_all.R
```

If `data/customers.csv` is missing, a synthetic dataset is generated automatically.

Outputs (artifacts and plots) are written to:
- artifacts/: RDS, CSV, threshold files, etc.
- reports/: PNG plots (ROC, PR, confusion matrix, lift/gains, VIP, PDPs)

---

## Project Structure

```
.
├─ config.yml                  # Central configuration (paths, features, models, costs)
├─ R/
│  ├─ install_packages.R       # Installs required CRAN packages
│  ├─ utils.R                  # Helpers (config, I/O, factor handling)
│  ├─ 01_load_data.R           # Load/generate data, persist raw.rds
│  ├─ 02_feature_engineering.R # Feature engineering, persist processed.rds
│  ├─ 03_train_models.R        # CV, tuning, pick best, predictions & metrics
│  ├─ 04_evaluate.R            # Curves and confusion matrix plots
│  ├─ 05_retention_strategy.R  # Profit simulation across target fractions
│  └─ 06_explain_model.R       # Variable importance and partial dependence
├─ scripts/run_all.R           # Orchestrates all steps
├─ data/
│  ├─ schema.md                # Expected input schema
│  └─ customers.csv            # (Ignored by Git) optional local data
├─ artifacts/.gitkeep
├─ reports/.gitkeep
├─ tests/
│  └─ test_features.R          # Sanity checks for engineered features & target
├─ .github/workflows/ci.yml    # CI: run pipeline + tests, upload artifacts
├─ .gitignore
└─ Makefile
```

---

## Data

- Expected columns: see [data/schema.md](data/schema.md)
- Place your file at `data/customers.csv` (not committed by default)
- If absent, `R/01_load_data.R` generates a realistic synthetic dataset of size configured in `config.yml`

Target column handling:
- The target must be convertible to factor with levels `no, yes`. The helper `as_churn_factor()` converts from {0/1, true/false, y/n, Yes/No, etc.}

---

## Configuration

Edit [config.yml](config.yml):

- data:
  - path: where the CSV lives (default: data/customers.csv)
  - id_col: primary key column name
  - target_col: churn column name
  - synthetic_rows: used if data file is missing
  - test_size, seed
- features:
  - drop_cols, imputations, normalization flags
- models:
  - Enable/disable algorithms, RF/XGBoost hyperparams and tuning
- training:
  - CV folds, metrics, optimize_metric (default: roc_auc)
- retention:
  - Business values: contact cost, offer cost, save rate, LTV uplift
- paths:
  - Output folders (artifacts, reports)

---

## Running the Pipeline

- Full run:
```bash
make run
# or
Rscript scripts/run_all.R
```

- Individual steps (for debugging/development):
```bash
Rscript R/01_load_data.R
Rscript R/02_feature_engineering.R
Rscript R/03_train_models.R
Rscript R/04_evaluate.R
Rscript R/05_retention_strategy.R
Rscript R/06_explain_model.R
```

- Tests:
```bash
make test
# or
Rscript -e "testthat::test_dir('tests')"
```

---

## Outputs Overview

Artifacts (artifacts/):
- raw.rds, processed.rds
- best_workflow.rds (fitted best model)
- cv_scores.csv (per-model CV summary)
- predictions_test.csv (.pred_yes and labels)
- metrics_test.csv (ROC AUC, PR AUC, Accuracy, Kappa, F1)
- threshold_optimal.txt (F1-optimized threshold)
- profit_curve.csv (retention simulation results)
- retention_best_policy.csv (argmax profit row)

Reports (reports/):
- roc_curve.png, pr_curve.png
- confusion_matrix.png
- lift_curve.png
- variable_importance.png
- partial_dependence_<feature>.png (top-3 features when supported)

---

## CI/CD

This repo includes a GitHub Actions workflow:
- Installs R and dependencies
- Runs the pipeline and tests on push and PR
- Uploads artifacts and reports as build artifacts

File: [.github/workflows/ci.yml](.github/workflows/ci.yml)

To view CI outputs:
- Go to Actions > latest run > Artifacts > download artifacts-and-reports

To schedule periodic runs (e.g., nightly), add a cron trigger:
```yaml
on:
  schedule:
    - cron: "0 2 * * *"  # 02:00 UTC daily
  workflow_dispatch:
  push:
  pull_request:
```

---

## Deployment and Hosting Options

This project produces batch predictions and static plots. You have several deployment paths depending on your needs.

1) Host static reports on GitHub Pages
- Goal: Make the plots and a summary report publicly viewable
- Approach A (simple): Publish the reports/ folder via Pages
  - Create a docs/ folder and have CI copy rendered images there:
    ```yaml
    - name: Copy reports to docs
      run: |
        rm -rf docs
        mkdir -p docs
        cp -r reports/* docs/
        cp artifacts/metrics_test.csv docs/ || true
        cp artifacts/retention_best_policy.csv docs/ || true
    ```
  - Enable GitHub Pages: Settings > Pages > Deploy from branch > main > /docs
- Approach B (nicer): Add an R Markdown summary (HTML) and publish it
  - Create e.g., `reports/summary.Rmd` that reads artifacts and plots
  - Render in CI:
    ```yaml
    - name: Render R Markdown
      run: Rscript -e 'rmarkdown::render("reports/summary.Rmd", output_dir = "docs")'
    ```
  - Enable Pages on /docs as above

2) Expose a real-time prediction API (plumber)
- Goal: Serve churn scores programmatically
- Steps:
  - Save `best_workflow.rds` from artifacts into the container or load from disk
  - Minimal `plumber.R`:
    ```r
    library(plumber); library(tidymodels)
    wf <- readRDS("artifacts/best_workflow.rds")

    #' Score a single customer record
    #' @param json JSON body with customer features (same schema as training minus target)
    #' @post /predict
    function(req, res){
      payload <- jsonlite::fromJSON(req$postBody, simplifyDataFrame = TRUE)
      new_df <- tibble::as_tibble(payload)
      prob <- predict(wf, new_df, type = "prob")$.pred_yes
      list(prob_yes = prob)
    }
    ```
  - Run locally:
    ```bash
    R -e "pr <- plumber::plumb('plumber.R'); pr$run(host='0.0.0.0', port=8000)"
    ```
  - Host options:
    - Docker + a cloud VM (AWS Lightsail/EC2, GCP, Azure)
    - Render.com, Fly.io, or Heroku (via Docker)
    - Posit Connect/Server (if available)

  - Optional Dockerfile:
    ```dockerfile
    FROM rocker/r-ver:4.3.2
    RUN apt-get update && apt-get install -y libcurl4-openssl-dev libssl-dev libxml2-dev
    COPY . /app
    WORKDIR /app
    RUN R -e "install.packages(c('plumber','tidymodels','yaml','vip','iml','ranger','xgboost','jsonlite','tidyverse'), repos='https://cloud.r-project.org')"
    EXPOSE 8000
    CMD ["R", "-e", "pr <- plumber::plumb('plumber.R'); pr$run(host='0.0.0.0', port=8000)"]
    ```

3) Automate batch scoring (scheduled CI)
- Goal: Re-run the full pipeline on a schedule and publish outputs
- Add a cron schedule in CI (see earlier)
- Optionally commit summary CSVs/PNGs back to the repo or upload to cloud storage
  - Example commit step (use a repo PAT with write permissions):
    ```bash
    git config user.name "github-actions[bot]"
    git config user.email "github-actions[bot]@users.noreply.github.com"
    git add docs/ artifacts/ reports/
    git commit -m "Nightly update of artifacts and reports" || echo "No changes"
    git push
    ```

4) Shiny dashboard (optional)
- For interactive exploration (threshold sliders, gains, feature effects), build a small Shiny app and deploy to:
  - [shinyapps.io](https://www.shinyapps.io/)
  - Posit Connect/Server
- The app would read from artifacts/ to display current results

Choose the path that fits your stakeholders:
- Static sharing: GitHub Pages
- Programmatic integration: plumber API
- Automated refresh: Scheduled CI
- Interactive analysis: Shiny

---

## Customizing Models

- Toggle algorithms in config.yml:
  - models.logistic_reg, models.random_forest, models.xgboost
- Adjust tuning grids by editing `R/03_train_models.R` (grid size, parameters)
- Change the selection metric via `training.optimize_metric` (e.g., pr_auc)

---

## Reproducibility

- Seeding: `data.seed` ensures reproducible splits and synthetic data
- Data privacy: `data/customers.csv` is git-ignored by default

---

## Troubleshooting

- Package installation issues
  - Run `Rscript R/install_packages.R` manually
  - Check internet/firewall settings for CRAN
- Missing columns / schema mismatches
  - See [data/schema.md](data/schema.md)
  - Update `config.yml` target/id names to match your data
- CI failures
  - Open the Actions logs and verify package installs and step outputs
  - Large dependency downloads can be slow on first run

---

## License

Specify your license (e.g., MIT) and add a LICENSE file if needed.
