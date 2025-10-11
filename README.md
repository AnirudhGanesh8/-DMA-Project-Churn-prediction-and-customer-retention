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