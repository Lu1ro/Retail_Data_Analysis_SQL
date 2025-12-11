/*
Step 3: RFM Segmentation & Analysis
Description: 
1. Calculates Recency, Frequency, Monetary metrics for each customer.
2. Segments customers using NTILE (statistical grouping).
3. Provides summary statistics for each segment (Actionable Insights).
*/

USE PortfolioProject_Retail;
GO

-- =============================================
-- PART 1: DETAILED RFM CALCULATION
-- =============================================
WITH RFM_Base AS (
    SELECT 
        CustomerID,
        -- Recency: Days since last purchase
        DATEDIFF(day, MAX(InvoiceDate), (SELECT MAX(InvoiceDate) FROM Fact_Sales)) AS RecencyDays,
        -- Frequency: Count of unique invoices
        COUNT(DISTINCT InvoiceNo) AS Frequency,
        -- Monetary: Total spend
        SUM(TotalAmount) AS Monetary
    FROM Fact_Sales
    GROUP BY CustomerID
),
RFM_Scored AS (
    SELECT 
        *,
        -- Score customers from 1 (bad) to 5 (good) using Window Functions
        NTILE(5) OVER (ORDER BY RecencyDays DESC) AS R_Score,
        NTILE(5) OVER (ORDER BY Frequency ASC) AS F_Score,
        NTILE(5) OVER (ORDER BY Monetary ASC) AS M_Score
    FROM RFM_Base
),
RFM_Final AS (
    SELECT 
        CustomerID,
        RecencyDays, Frequency, Monetary,
        CONCAT(R_Score, F_Score, M_Score) AS RFM_Code,
        -- Customer Segmentation Logic
        CASE 
            WHEN R_Score = 5 AND F_Score = 5 AND M_Score = 5 THEN 'Champions'
            WHEN F_Score >= 4 AND M_Score >= 4 THEN 'Loyal Customers'
            WHEN R_Score >= 4 AND F_Score <= 2 THEN 'New Customers'
            WHEN R_Score <= 2 AND F_Score >= 4 THEN 'At Risk'
            WHEN R_Score <= 2 AND M_Score <= 2 THEN 'Lost Customers'
            ELSE 'Potential Loyalist'
        END AS Segment
    FROM RFM_Scored
)
-- 1. View detailed data (Top 100 for review)
SELECT TOP 100 * FROM RFM_Final ORDER BY Monetary DESC;

-- =============================================
-- PART 2: SEGMENT ANALYSIS (INSIGHTS)
-- Use this query to generate charts or reports
-- =============================================
WITH RFM_Base AS (
    -- (Repeat CTE for the summary query context)
    SELECT 
        CustomerID,
        DATEDIFF(day, MAX(InvoiceDate), (SELECT MAX(InvoiceDate) FROM Fact_Sales)) AS RecencyDays,
        COUNT(DISTINCT InvoiceNo) AS Frequency,
        SUM(TotalAmount) AS Monetary
    FROM Fact_Sales
    GROUP BY CustomerID
),
RFM_Scored AS (
    SELECT *,
    NTILE(5) OVER (ORDER BY RecencyDays DESC) AS R_Score,
    NTILE(5) OVER (ORDER BY Frequency ASC) AS F_Score,
    NTILE(5) OVER (ORDER BY Monetary ASC) AS M_Score
    FROM RFM_Base
),
RFM_Segments AS (
     SELECT CustomerID, Monetary,
        CASE 
            WHEN R_Score = 5 AND F_Score = 5 AND M_Score = 5 THEN 'Champions'
            WHEN F_Score >= 4 AND M_Score >= 4 THEN 'Loyal Customers'
            WHEN R_Score >= 4 AND F_Score <= 2 THEN 'New Customers'
            WHEN R_Score <= 2 AND F_Score >= 4 THEN 'At Risk'
            WHEN R_Score <= 2 AND M_Score <= 2 THEN 'Lost Customers'
            ELSE 'Potential Loyalist'
        END AS Segment
    FROM RFM_Scored
)
SELECT 
    Segment,
    COUNT(*) AS CustomerCount,
    CAST(AVG(Monetary) AS DECIMAL(18,2)) AS AvgSpend,
    CAST(SUM(Monetary) AS DECIMAL(18,2)) AS TotalRevenue
FROM RFM_Segments
GROUP BY Segment
ORDER BY TotalRevenue DESC;