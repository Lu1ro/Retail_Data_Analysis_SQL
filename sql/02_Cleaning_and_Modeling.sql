/*
Step 2: Data Cleaning and Modeling (ELT)
Description: 
1. Cleans raw data (handles NULLs, converts data types).
2. Deduplicates records.
3. Builds a Star Schema (Fact_Sales, Dim_Customer, Dim_Product).
*/

USE PortfolioProject_Retail;
GO

-- =============================================
-- 1. CLEANUP PREVIOUS ATTEMPTS
-- =============================================
IF OBJECT_ID('Fact_Sales', 'U') IS NOT NULL DROP TABLE Fact_Sales;
IF OBJECT_ID('Dim_Product', 'U') IS NOT NULL DROP TABLE Dim_Product;
IF OBJECT_ID('Dim_Customer', 'U') IS NOT NULL DROP TABLE Dim_Customer;
IF OBJECT_ID('tempdb..#TempRetail') IS NOT NULL DROP TABLE #TempRetail;

-- =============================================
-- 2. STAGING & CLEANING (CTE)
-- =============================================
WITH CleanData AS (
    SELECT 
        InvoiceNo,
        StockCode,
        ISNULL(Description, 'Unknown') AS Description,
        -- Convert data types safely
        TRY_CAST(Quantity AS INT) AS Quantity,
        TRY_CAST(InvoiceDate AS DATETIME) AS InvoiceDate,
        -- Handle comma/dot decimal separator issues
        TRY_CAST(REPLACE(UnitPrice, ',', '.') AS DECIMAL(18, 2)) AS UnitPrice,
        CustomerID,
        Country,
        -- Window function to identify duplicates
        ROW_NUMBER() OVER (
            PARTITION BY InvoiceNo, StockCode, CustomerID, Quantity, InvoiceDate 
            ORDER BY InvoiceDate
        ) as row_num
    FROM stg_OnlineRetail
    WHERE CustomerID IS NOT NULL -- Exclude anonymous transactions
)
SELECT *
INTO #TempRetail
FROM CleanData
WHERE row_num = 1 -- Keep only unique records
  AND Quantity > 0 -- Filter out returns (negative quantity)
  AND UnitPrice > 0;

-- =============================================
-- 3. CREATE DIMENSION TABLES
-- =============================================

-- 3.1 Customer Dimension
CREATE TABLE Dim_Customer (
    CustomerID INT PRIMARY KEY,
    Country NVARCHAR(100)
);

-- Insert unique customers. 
-- Conflict resolution: If a customer has multiple countries, take the MAX (alphabetical).
INSERT INTO Dim_Customer (CustomerID, Country)
SELECT 
    CAST(CustomerID AS INT), 
    MAX(Country) 
FROM #TempRetail
GROUP BY CAST(CustomerID AS INT);

-- 3.2 Product Dimension
CREATE TABLE Dim_Product (
    StockCode NVARCHAR(50) PRIMARY KEY,
    Description NVARCHAR(255)
);

-- Insert unique products with the longest description available
INSERT INTO Dim_Product (StockCode, Description)
SELECT StockCode, MAX(Description)
FROM #TempRetail
GROUP BY StockCode;

-- =============================================
-- 4. CREATE FACT TABLE
-- =============================================
CREATE TABLE Fact_Sales (
    SalesID INT IDENTITY(1,1) PRIMARY KEY,
    InvoiceNo NVARCHAR(50),
    StockCode NVARCHAR(50) FOREIGN KEY REFERENCES Dim_Product(StockCode),
    CustomerID INT FOREIGN KEY REFERENCES Dim_Customer(CustomerID),
    InvoiceDate DATETIME,
    Quantity INT,
    UnitPrice DECIMAL(18, 2),
    TotalAmount AS (Quantity * UnitPrice) PERSISTED -- Computed column for performance
);

INSERT INTO Fact_Sales (InvoiceNo, StockCode, CustomerID, InvoiceDate, Quantity, UnitPrice)
SELECT 
    InvoiceNo, 
    StockCode, 
    CAST(CustomerID AS INT), 
    InvoiceDate, 
    Quantity, 
    UnitPrice
FROM #TempRetail;

-- Clean up temporary table
DROP TABLE #TempRetail;

-- Verification
SELECT 'Data Load Successful' AS Status, COUNT(*) AS TotalRows FROM Fact_Sales;