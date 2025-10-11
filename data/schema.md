# Expected schema: data/customers.csv

Required columns:
- customer_id: string, unique customer identifier
- churn: categorical/binary (0/1, yes/no, true/false)
- tenure_months: integer >= 0
- monthly_charges: numeric
- total_charges: numeric
- contract_type: categorical (e.g., month_to_month, one_year, two_year)
- payment_method: categorical (e.g., credit_card, debit_card, bank_transfer, cash)
- has_internet: categorical yes/no
- has_phone: categorical yes/no
- num_services: integer count of services
- support_calls_90d: integer count (last 90 days)
- last_login_days: integer days since last login
- auto_pay: categorical yes/no

Notes:
- Additional columns are allowed; unused columns will be ignored or one-hot encoded.
- If `data/customers.csv` is missing, a synthetic dataset matching this schema is generated automatically.