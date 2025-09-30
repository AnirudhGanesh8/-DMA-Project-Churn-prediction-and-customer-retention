# Problem Statement: Customer Churn Prediction and Retention

Objective:
- Predict the probability that a customer will churn in the next period and identify which customers to target for retention to maximize expected profit.

Business Context:
- Subscription-based service with monthly billing. Churn directly impacts recurring revenue and customer lifetime value (LTV).
- Limited retention budget requires prioritization of customers most likely to churn and most valuable to save.

Scope:
- Supervised binary classification on historical customer data with features capturing tenure, usage, support interactions, products, and billing.
- Post-model decisioning layer computing the optimal fraction of customers to target given contact and offer costs, expected save rate, and LTV uplift.

Success Criteria:
- Modeling: High discrimination (ROC AUC and PR AUC) and robust calibration of churn probabilities.
- Economics: Positive net profit from the recommended targeting policy under provided cost/benefit assumptions.

Assumptions:
- Labeled churn outcome is reliable for training; future scoring conditions are comparable to training data.
- Provided costs and uplift are approximate; sensitivity analysis can be run by adjusting `retention` parameters in `config.yml`.

Deliverables:
- Artifacts: Best model, CV/test metrics, predictions, optimal threshold, retention profit curve and recommended targeting fraction.
- Reports: ROC, PR, Confusion Matrix, Gains/Lift, Variable Importance, Partial Dependence, EDA plots.
- Power BI export: `artifacts/powerbi_export.csv` for dashboards.

Next Steps (Presentation):
- Build a concise slide deck or Power BI report with: problem, data overview (EDA), model approach, key metrics, threshold policy, and business impact.
