/*
Step 1: Database Setup
Description: Creates a new database for the retail analytics project.
*/

USE master;
GO

-- Check if database exists and drop it to start fresh (useful for reproducibility)
IF EXISTS (SELECT * FROM sys.databases WHERE name = 'PortfolioProject_Retail')
BEGIN
    ALTER DATABASE PortfolioProject_Retail SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE PortfolioProject_Retail;
END
GO

-- Create the new database
CREATE DATABASE PortfolioProject_Retail;
GO