/*
Step 4: Cohort Analysis (Retention Rate)
Description: Tracks how user cohorts behave over time (Monthly Retention).
Techniques: Self-Joins, Date Manipulation, Aggregation.
*/

USE PortfolioProject_Retail;
GO

-- 1. Identify the first purchase month for each customer (Cohort Month)
WITH FirstPurchase AS (
    SELECT 
        CustomerID, 
        MIN(DATEFROMPARTS(YEAR(InvoiceDate), MONTH(InvoiceDate), 1)) AS CohortMonth
    FROM Fact_Sales
    GROUP BY CustomerID
),
-- 2. Identify all months where customers were active
UserActivity AS (
    SELECT DISTINCT 
        CustomerID, 
        DATEFROMPARTS(YEAR(InvoiceDate), MONTH(InvoiceDate), 1) AS ActivityMonth
    FROM Fact_Sales
),
-- 3. Calculate retention lags
CohortSize AS (
    SELECT 
        fp.CohortMonth,
        DATEDIFF(month, fp.CohortMonth, ua.ActivityMonth) AS MonthIndex,
        COUNT(DISTINCT fp.CustomerID) AS UserCount
    FROM FirstPurchase fp
    JOIN UserActivity ua ON fp.CustomerID = ua.CustomerID
    GROUP BY fp.CohortMonth, ua.ActivityMonth
)
-- 4. Calculate Retention Rate (%)
SELECT 
    CohortMonth,
    MonthIndex,
    UserCount,
    -- Formula: Users Active in Month X / Users in Month 0
    CAST(UserCount * 100.0 / FIRST_VALUE(UserCount) OVER (PARTITION BY CohortMonth ORDER BY MonthIndex) AS DECIMAL(5,2)) AS RetentionRate_Percent
FROM CohortSize
WHERE CohortMonth > '2010-12-01' -- Filter partial data from first month if needed
ORDER BY CohortMonth, MonthIndex;