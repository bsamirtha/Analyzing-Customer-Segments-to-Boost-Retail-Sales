-- Step 1: Reset the database environment
-- Drop the existing database to start fresh and create a new one.
DROP DATABASE IF EXISTS sales_db;
CREATE DATABASE sales_db;
USE sales_db;

-- Verify initial data by displaying sample rows
SELECT * FROM sales_data_sample_project LIMIT 10;

-- Step 2: Calculate total sales in the dataset
-- Helps understand overall sales volume.
SELECT SUM(SALES) AS total_sales 
FROM sales_data_sample_project;
-- Expected output: total sales value (e.g., 10,032,628)

-- Step 3: Identify the top 5 customers by total sales
-- Useful for targeting key customers or VIP programs.
SELECT CUSTOMERNAME, SUM(SALES) AS total_sales
FROM sales_data_sample_project
GROUP BY CUSTOMERNAME
ORDER BY total_sales DESC
LIMIT 5;

-- Step 4: Analyze monthly sales trends
-- Helps identify seasonal patterns or peak months.
SELECT MONTH_ID, SUM(SALES) AS monthly_sales
FROM sales_data_sample_project
GROUP BY MONTH_ID
ORDER BY MONTH_ID;

-- Step 5: Sales by product line
-- Understand which product lines contribute most to revenue.
SELECT PRODUCTLINE, SUM(SALES) AS total_sales
FROM sales_data_sample_project
GROUP BY PRODUCTLINE
ORDER BY total_sales DESC;

-- Step 6: Inspect distinct values for key categorical columns
-- Useful for data quality check and understanding dataset categories.
SELECT DISTINCT STATUS FROM sales_data_sample_project;
SELECT DISTINCT YEAR_ID FROM sales_data_sample_project;
SELECT DISTINCT PRODUCTLINE FROM sales_data_sample_project;
SELECT DISTINCT COUNTRY FROM sales_data_sample_project;
SELECT DISTINCT DEALSIZE FROM sales_data_sample_project;
SELECT DISTINCT TERRITORY FROM sales_data_sample_project;

-- Step 7: Find distinct months available in a specific year (2005 example)
-- Verifies data coverage for given time periods.
SELECT DISTINCT MONTH_ID 
FROM sales_data_sample_project
WHERE YEAR_ID = 2005
ORDER BY 1;

-- Check months for year 2003 similarly
SELECT DISTINCT MONTH_ID 
FROM sales_data_sample_project
WHERE YEAR_ID = 2003
ORDER BY 1;

-- Step 8: Revenue by product line (detailed revenue analysis)
SELECT PRODUCTLINE, SUM(SALES) AS REVENUE 
FROM sales_data_sample_project
GROUP BY PRODUCTLINE
ORDER BY REVENUE DESC;

-- Step 9: Revenue by year
-- Understand revenue trends over years.
SELECT YEAR_ID, SUM(SALES) AS REVENUE 
FROM sales_data_sample_project
GROUP BY YEAR_ID
ORDER BY REVENUE DESC;

-- Step 10: Revenue by deal size
-- Helps analyze sales based on deal categories (Small, Medium, Large).
SELECT DEALSIZE, SUM(SALES) AS REVENUE 
FROM sales_data_sample_project
GROUP BY DEALSIZE
ORDER BY REVENUE DESC;

-- Step 11: Top countries by revenue
-- Identify geographical hotspots for sales.
SELECT COUNTRY, SUM(SALES) AS REVENUE
FROM sales_data_sample_project
GROUP BY COUNTRY
ORDER BY REVENUE DESC;

-- Step 12: Top cities in the USA by revenue
-- Drills down into important cities within a major market.
SELECT CITY, SUM(SALES) AS REVENUE
FROM sales_data_sample_project
WHERE COUNTRY = 'USA'
GROUP BY CITY
ORDER BY REVENUE DESC;

-- Step 13: Top products in the USA by year and product line
-- Product-level analysis in the USA market.
SELECT COUNTRY, YEAR_ID, PRODUCTLINE, SUM(SALES) AS REVENUE
FROM sales_data_sample_project
WHERE COUNTRY = 'USA'
GROUP BY COUNTRY, YEAR_ID, PRODUCTLINE
ORDER BY REVENUE DESC;

-- Step 14: Best month for sales in a selected year (2004 example)
-- Identify peak months for targeted marketing or inventory planning.
SELECT MONTH_ID, SUM(SALES) AS REVENUE, COUNT(ORDERNUMBER) AS FREQUENCY 
FROM sales_data_sample_project
WHERE YEAR_ID = 2004 -- Modify year as needed (e.g., 2003, 2005)
GROUP BY MONTH_ID
ORDER BY REVENUE DESC;

-- Step 15: Products sold in November of a given year (2003 example)
-- Analyze sales and orders during a specific month.
SELECT MONTH_ID, PRODUCTLINE, SUM(SALES) AS REVENUE, COUNT(ORDERNUMBER) AS No_Orders 
FROM sales_data_sample_project
WHERE MONTH_ID = 11 AND YEAR_ID = 2003 -- Modify year as needed
GROUP BY MONTH_ID, PRODUCTLINE
ORDER BY REVENUE DESC;

--------------------------------------------------------------------------------
-- RFM Analysis (Recency, Frequency, Monetary) - To identify best customers
--------------------------------------------------------------------------------

-- Step 16: Create a base RFM table with customer level metrics
-- Recency: Days since last purchase; Frequency: Number of orders; Monetary: Total sales
CREATE TEMPORARY TABLE rfm AS
SELECT
    CUSTOMERNAME,
    SUM(SALES) AS MonetaryValue,
    AVG(SALES) AS AvgMonetaryValue,
    COUNT(ORDERNUMBER) AS Frequency,
    MAX(STR_TO_DATE(ORDERDATE, '%Y-%m-%d')) AS LastOrderDate,
    (SELECT MAX(STR_TO_DATE(ORDERDATE, '%Y-%m-%d')) FROM sales_data_sample_project) AS MaxOrderDate,
    DATEDIFF(
        (SELECT MAX(STR_TO_DATE(ORDERDATE, '%Y-%m-%d')) FROM sales_data_sample_project),
        MAX(STR_TO_DATE(ORDERDATE, '%Y-%m-%d'))
    ) AS Recency
FROM sales_data_sample_project
GROUP BY CUSTOMERNAME;

-- Step 17: Drop the old RFM final table if exists and create new one with RFM scores (quartiles)
DROP TEMPORARY TABLE IF EXISTS rfm_final;

CREATE TEMPORARY TABLE rfm_final AS
WITH rfm AS (
    SELECT
        CUSTOMERNAME,
        SUM(SALES) AS MonetaryValue,
        AVG(SALES) AS AvgMonetaryValue,
        COUNT(ORDERNUMBER) AS Frequency,
        MAX(ORDERDATE) AS LastOrderDate,
        (SELECT MAX(ORDERDATE) FROM sales_data_sample_project) AS MaxOrderDate,
        DATEDIFF((SELECT MAX(ORDERDATE) FROM sales_data_sample_project), MAX(ORDERDATE)) AS Recency
    FROM sales_data_sample_project
    GROUP BY CUSTOMERNAME
),
rfm_calc AS (
    -- Assign quartiles to each metric: Recency (descending), Frequency (ascending), Monetary (ascending)
    SELECT *,
        NTILE(4) OVER (ORDER BY Recency DESC) AS rfm_recency,
        NTILE(4) OVER (ORDER BY Frequency) AS rfm_frequency,
        NTILE(4) OVER (ORDER BY MonetaryValue) AS rfm_monetary
    FROM rfm
)
SELECT *,
    -- Sum of quartile ranks to form a composite RFM score
    (rfm_recency + rfm_frequency + rfm_monetary) AS rfm_cell,
    -- Concatenate quartiles for detailed segment analysis
    CONCAT(rfm_recency, rfm_frequency, rfm_monetary) AS rfm_cell_string
FROM rfm_calc;

-- Step 18: Review the RFM scores and segmentation
SELECT * FROM rfm_final;

-- Step 19: Segment customers based on RFM scores using business logic
SELECT 
    CUSTOMERNAME, 
    rfm_recency, 
    rfm_frequency, 
    rfm_monetary,
    rfm_cell_string,
    CASE
        WHEN rfm_cell_string IN ('111','112','121','122','123','132','211','212','114','141','221') THEN 'Lost Customer'
        WHEN rfm_cell_string IN ('133','134','143','244','334','343','344','144') THEN 'Slipping Away'
        WHEN rfm_cell_string IN ('311','411','331','421','412') THEN 'New Customer'
        WHEN rfm_cell_string IN ('222','223','233','322','232','234') THEN 'Potential Churners'
        WHEN rfm_cell_string IN ('323','333','321','422','332','432','423') THEN 'Active'
        WHEN rfm_cell_string IN ('433','434','443','444') THEN 'Loyal'
        ELSE 'Unclassified'
    END AS CustomerSegment
FROM rfm_final;

--------------------------------------------------------------------------------
-- Step 20: Frequently Bought Together Products — Find products sold together in orders with exactly 3 items
--------------------------------------------------------------------------------

SELECT 
    ORDERNUMBER, 
    GROUP_CONCAT(PRODUCTCODE ORDER BY PRODUCTCODE SEPARATOR ', ') AS ProductCodes
FROM sales_data_sample_project
WHERE ORDERNUMBER IN (
    SELECT ORDERNUMBER
    FROM (
        SELECT ORDERNUMBER, COUNT(*) AS item_count
        FROM sales_data_sample_project
        WHERE STATUS = 'Shipped'
        GROUP BY ORDERNUMBER
        HAVING item_count = 3
    ) AS filtered_orders
)
GROUP BY ORDERNUMBER
ORDER BY ProductCodes DESC;
