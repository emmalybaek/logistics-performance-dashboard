-- 02. Staging

/* This script will rename, standardize, cast datatypes and clean data. The staging layer retains the grain of the 
source dataset, for example, one row per order item with attributes from multiply business entities repeated 
across rows. In this layer, we also transform the data, so columns and values are standardized and datatypes are 
correct. Since we don't need a physical table with this data, but rather just store the data, the layer is created as 
a view. In a real scenarie, where raw_data is updated regular (each day most likely), the view will automatically 
reflect the lastest source data. The staging layer is done with CTE's so it is easy to follow along as well as adding 
new rules for team-members.*/

-- Create a staging view
CREATE OR replace VIEW stg_supply_chain AS 

WITH 

/*Change the column names to lower case and underscore*/

rename_columns AS (

SELECT
-- Location
"Order City" AS order_city,
"Order Region" AS order_region,
"Order State" AS order_state,
"Order Zipcode" AS order_zipcode,
"Order Country" AS order_country,
"Market" AS market,

-- Order
"Order Id" AS order_id,
"Order Status" AS order_status,
"order date (DateOrders)" AS order_date,

-- Order Item
"Order Item Id" AS item_id,
"Order Item Product Price" AS item_price,
"Order Item Quantity" AS item_quantity,
"Order Item Total" AS item_total,
"Order Item Profit Ratio" AS item_profit_ratio,
"Order Item Discount" AS item_discount, 
"Order Item Discount Rate" AS item_discount_rate,
"Benefit per order" AS benefit_per_order,
"Sales" AS sales,
"Order Profit Per Order" AS order_profit,

-- Product
"Product Card Id" AS product_id,
"Product Name" AS product_name,
"Product Price" AS product_price, 
"Product Image" AS product_image,

-- Category
"Category Id" AS category_id,
"Category Name" AS category_name,

-- Department
"Department Id" AS department_id,
"Department Name" AS department_name,

-- Shipping
"Shipping Mode" AS shipping_mode,
"Days for shipping (real)" AS actual_shipping_days,
"Days for shipment (scheduled)" AS scheduled_shipping_days,
"Delivery Status" AS delivery_status,
"Late_delivery_risk" AS late_delivery_risk,
"shipping date (DateOrders)" AS shipping_date

FROM raw_data
),

/*Standardize text values. Take all columns from rename_columns except the text column i want 
to tansform further*/

standardize_text AS (
SELECT * EXCLUDE ( 
order_city,
order_region, 
order_state,
order_country,
market, 
product_name, 
product_image,
category_name,
department_name, 
order_status,
shipping_mode,
delivery_status
),

-- Remove spaces before and after with TRIM and keep the column names 
TRIM(order_city) AS order_city,
TRIM(order_region) AS order_region,
TRIM(order_state) AS order_state,
TRIM(order_country) AS order_country,
TRIM(market) AS market,

TRIM(product_name) AS product_name, 
TRIM(product_image) AS product_image,

TRIM(category_name) AS category_name,
TRIM(department_name) AS department_name,

-- Change the text to lowercase and keep the column names
LOWER(TRIM(order_status)) AS order_status,
LOWER(TRIM(shipping_mode)) AS shipping_mode, 
LOWER(TRIM(delivery_status)) AS delivery_status 

FROM rename_columns
), 

/*Correct data types. Take all columns from standardize_text except the columns i want 
to tansform further. Change the date format with TRY_STRPTIME to ensure correct timestamp format. 
Let float types have max 18 number of digits in total and 2 decimal points except ratios/rates columns. */

cast_types AS (
SELECT * EXCLUDE ( 
order_date,
shipping_date, 
item_price,
item_discount,
item_discount_rate,
item_profit_ratio,
item_total,
product_price,
benefit_per_order,
sales,
order_profit,
order_zipcode
),

-- Change columns to date type
TRY_STRPTIME(order_date, '%m/%d/%Y %H:%M') AS order_date,
TRY_STRPTIME(shipping_date, '%m/%d/%Y %H:%M') AS shipping_date,

-- Accept up to 18 digits in total and 2 decimalpoints for monetary values
CAST(item_price AS Decimal(18,2)) AS item_price,
CAST(item_discount AS Decimal(18,2)) AS item_discount,
CAST(item_total AS Decimal(18,2)) AS item_total,
CAST(product_price AS Decimal(18,2)) AS product_price,
CAST(benefit_per_order AS Decimal(18,2)) AS benefit_per_order,
CAST(sales AS Decimal(18,2)) AS sales,
CAST(order_profit AS decimal(18,2)) AS order_profit, 

-- Accept up to 10 digits in total and 4 decimalpoints for ratios and rates
CAST(item_discount_rate AS Decimal(10,4)) AS item_discount_rate,
CAST(item_profit_ratio AS Decimal(10,4)) AS item_profit_ratio,

-- Convert zipcode to text
CAST(order_zipcode AS VARCHAR) AS order_zipcode,

FROM standardize_text
)

/* Create the staging view */

SELECT * 
FROM cast_types;

-- Validate staging view
SELECT * 
FROM stg_supply_chain
LIMIT 50;

DESCRIBE stg_supply_chain;