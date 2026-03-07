-- Create Schemas
CREATE SCHEMA raw;
CREATE SCHEMA clean;
CREATE SCHEMA mart;

-- Create Table Columns
CREATE TABLE raw.telco_customers (
	customer_id TEXT,
    gender TEXT,
    senior_citizen INT,
    partner TEXT,
    dependents TEXT,
    tenure INT,
    phone_service TEXT,
    multiple_lines TEXT,
    internet_service TEXT,
    online_security TEXT,
    online_backup TEXT,
    device_protection TEXT,
    tech_support TEXT,
    streaming_tv TEXT,
    streaming_movies TEXT,
    contract TEXT,
    paperless_billing TEXT,
    payment_method TEXT,
    monthly_charges NUMERIC,
    total_charges TEXT,
    churn TEXT
);

-- Check Data Completeness
SELECT * FROM raw.telco_customers
LIMIT 10;

-- Total Monthly Revenue
SELECT SUM (monthly_charges) AS Total_monthly_revenue
FROM raw.telco_customers;

-- Customer segmentation
SELECT contract,
       COUNT(*) AS customers
FROM raw.telco_customers
GROUP BY contract
ORDER BY customers DESC;

-- Churn rate
SELECT churn,
		COUNT(*) AS customers
FROM raw.telco_customers
GROUP BY churn;


-- Revenue by segment
SELECT contract,
		COUNT(*) AS customers,
		SUM(monthly_charges) AS revenue,
		AVG(monthly_charges) AS avg_revenue_per_customer
FROM raw.telco_customers
GROUP BY contract
ORDER BY revenue DESC;

-- Revenue Drop
WITH kpi AS (
  SELECT
    contract,
    COUNT(*)::numeric AS customers,
    SUM(monthly_charges)::numeric AS revenue,
    AVG(monthly_charges)::numeric AS arpu
  FROM raw.telco_customers
  GROUP BY contract
),
a AS (
  SELECT * FROM kpi WHERE contract = 'Month-to-month'
),
b AS (
  SELECT * FROM kpi WHERE contract = 'Two year'
)
SELECT 
  a.contract AS contract_a,
  b.contract AS contract_b,
  a.revenue - b.revenue AS revenue_diff,
  (a.customers - b.customers) * ((a.arpu + b.arpu) / 2) AS diff_due_to_customers,
  (a.arpu - b.arpu) * ((a.customers + b.customers) / 2) AS diff_due_to_arpu,
  (
    (a.customers - b.customers) * ((a.arpu + b.arpu) / 2)
    + (a.arpu - b.arpu) * ((a.customers + b.customers) / 2)
  ) AS approx_total_diff
FROM a CROSS JOIN b;


-- View: Summary
CREATE OR REPLACE VIEW mart.executive_kpis AS
SELECT
    COUNT(*) AS total_customers,
    SUM(monthly_charges) AS total_mrr,
    AVG(monthly_charges) AS arpu,
    ROUND(
        SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END)::numeric / COUNT(*),
        4
    ) AS churn_rate,
    SUM(CASE WHEN churn = 'Yes' THEN monthly_charges ELSE 0 END) AS revenue_at_risk
FROM raw.telco_customers;

SELECT * FROM mart.executive_kpis;

-- View 1: Revenue by contract
CREATE OR REPLACE VIEW mart.revenue_by_contract AS
SELECT
    contract,
    COUNT(*) AS customers,
    SUM(monthly_charges) AS revenue,
    AVG(monthly_charges) AS arpu,
    ROUND(
        SUM(monthly_charges) / SUM(SUM(monthly_charges)) OVER (),
        4
    ) AS revenue_share
FROM raw.telco_customers
GROUP BY contract
ORDER BY revenue DESC;

SELECT * FROM mart.revenue_by_contract;

-- View 2: Churn by contract
CREATE OR REPLACE VIEW mart.churn_by_contract AS
SELECT
    contract,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) AS churned_customers,
    SUM(CASE WHEN churn = 'No' THEN 1 ELSE 0 END) AS retained_customers,
    ROUND(
        SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END)::numeric / COUNT(*),
        4
    ) AS churn_rate
FROM raw.telco_customers
GROUP BY contract
ORDER BY churn_rate DESC;

SELECT * FROM mart.churn_by_contract;

-- View: 3.Churn by tenue
CREATE OR REPLACE VIEW mart.churn_by_tenure AS
SELECT
    CASE
        WHEN tenure < 6 THEN '0-6 months'
        WHEN tenure < 12 THEN '6-12 months'
        WHEN tenure < 24 THEN '12-24 months'
        ELSE '24+ months'
    END AS tenure_group,
    COUNT(*) AS customers,
    SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) AS churned_customers,
    ROUND(
        SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END)::numeric / COUNT(*),
        4
    ) AS churn_rate
FROM raw.telco_customers
GROUP BY 1
ORDER BY 1;

SELECT * FROM mart.churn_by_tenure;

-- View: 4. Churn by payment method
CREATE OR REPLACE VIEW mart.churn_by_payment_method AS
SELECT
    payment_method,
    COUNT(*) AS customers,
    SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END) AS churned_customers,
    ROUND(
        SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END)::numeric / COUNT(*),
        4
    ) AS churn_rate
FROM raw.telco_customers
GROUP BY payment_method
ORDER BY churn_rate DESC;

SELECT * FROM mart.churn_by_payment_method;

-- View: 5. Revenue at risk
CREATE OR REPLACE VIEW mart.revenue_at_risk AS
SELECT
    SUM(monthly_charges) AS revenue_at_risk
FROM raw.telco_customers
WHERE churn = 'Yes';

SELECT * FROM mart.revenue_at_risk;

-- View 6: Revenue lost by contract
CREATE OR REPLACE VIEW mart.revenue_dropoff_by_contract AS
SELECT
    contract,
    SUM(monthly_charges) FILTER (WHERE churn = 'Yes') AS revenue_lost,
    SUM(monthly_charges) FILTER (WHERE churn = 'No') AS retained_revenue
FROM raw.telco_customers
GROUP BY contract
ORDER BY revenue_lost DESC;

SELECT * FROM mart.revenue_dropoff_by_contract;

-- View 7: Driver tree summary
CREATE OR REPLACE VIEW mart.driver_tree_summary AS
SELECT
    contract,
    COUNT(*) AS customers,
    AVG(monthly_charges) AS arpu,
    ROUND(
        1 - SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END)::numeric / COUNT(*),
        4
    ) AS retention_rate,
    SUM(monthly_charges) AS revenue
FROM raw.telco_customers
GROUP BY contract
ORDER BY revenue DESC;

SELECT * FROM mart.driver_tree_summary;