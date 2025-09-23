# Churn prediction and customer retention modeling (DMA)

An end-to-end Data Mining and Analytics project in R for predicting customer churn and designing actionable retention strategies.

Highlights:
- Synthetic data generator (if `data/customers.csv` is absent)
- Robust feature engineering (RFM-ish, tenure, service flags, interactions)
- Modeling with tidymodels (logistic regression, random forest, XGBoost)
- Evaluation: ROC/PR AUC, confusion matrix at optimal threshold, lift & gains charts
- Explainability: feature importance and partial dependence (when applicable)
- Retention strategy: profit curve and decile targeting
- CI workflow to run tests and the full pipeline

## Project structure

```
.
├── config.yml
├── R
│   ├── 01_load_data.R
│   ├── 02_feature_engineering.R
│   ├── 03_train_models.R
│   ├── 04_evaluate.R
│   ├── 05_retention_strategy.R
│   ├── 06_explain_model.R
│   ├── install_packages.R
│   └── utils.R
├── scripts
│   └── run_all.R
├── data
│   ├── .gitkeep
│   └── schema.md
├── artifacts
│   └── .gitkeep
├── reports
│   └── .gitkeep
├── tests
│   └── test_features.R
├── .github
│   └── workflows
│       └── ci.yml
├── .gitignore
└── Makefile
```

## Getting started

1) Install R packages
```bash
Rscript R/install_packages.R
```

2) Configure `config.yml` (paths, target column, retention costs, model params)

3) Run the pipeline
```bash
Rscript scripts/run_all.R
```

Artifacts:
- `artifacts/processed.rds`: engineered dataset
- `artifacts/best_workflow.rds`: best model workflow
- `artifacts/predictions_test.csv`: test set predictions
- `artifacts/metrics_test.csv`: test metrics
- `artifacts/threshold_optimal.txt`: chosen classification threshold

Reports:
- `reports/roc_curve.png`, `reports/pr_curve.png`
- `reports/lift_curve.png`, `reports/confusion_matrix.png`
- `reports/variable_importance.png`, `reports/partial_dependence_<feature>.png`
- `reports/profit_curve.png`

## Data expectations

- A CSV at `data/customers.csv` (optional; synthetic data auto-generated if missing)
- Required columns (if using your own data; see `data/schema.md` for details):
  - `customer_id` (unique), `tenure_months`, `monthly_charges`, `total_charges`,
    `contract_type`, `payment_method`, `has_internet`, `has_phone`,
    `num_services`, `support_calls_90d`, `last_login_days`, `auto_pay`,
    and `churn` (0/1 or no/yes)

## Notes

- You can swap models or add tuning grids easily in `R/03_train_models.R`.
- To use your dataset, place it at `data/customers.csv` and ensure columns match schema.
- For uplift modeling, you can extend `05_retention_strategy.R` with treatment/control data.

## License

MIT (adjust as needed).