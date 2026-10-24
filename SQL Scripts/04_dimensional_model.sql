-- 04. Dimensional Model

/* This script will create the dimensional model. The purpose of dimensional modeling is to enable BI reporting. 

Facts are used to measure a business activity for example sales, orders or product items. They are generally numeric, 
and they consist of two types of columns: keys and measures.  

Dimensions defines the context of the facts and are generally descriptive. Only one column can be the primary key
in dimension tables. It is best practice to use surrogate keys instead of primary keys however. Both should be included. 

The model follows a dimensional star schema because it is easy to query, easy to use and has good performance. 

The script follows this process for dimensional designs:

1. Select the business processes 
    ↓
2. Identify facts and declare the grains 
    ↓
3. Identify the dimensions 
    ↓
4. Build facts and dimensions 
    ↓
5. Validate dimensional model
*/

-- ============================================================
-- 1. Select the business processes
-- ============================================================
/*

The activities that generate information for our dashboard-purpose is shipments and item sales. These are the core processes, 
we want to analyze further in the dashboard. They allow us to analyze KPI's sush as Number of Complets, Average Actual Shipping Days,
Average Order Value and Average Items per Order etc. They have different grains, which mean we need more than one fact table. 

-- ============================================================
-- 2. Identify facts and declare the grains
-- ============================================================

Having each item or order on every line in the fact tables gives us the opportunity to aggregate data (sum, average etc.) to find 
Total Orders, Total Sales, Total Profit etc. 

fact_orders: 
- Grain: One row per order
- Business process: Order processing and delivery performance 

fact_item:
- Grain: One row per item
- Business process: Item sales and profit
*/

-- ============================================================
-- 3. Identify dimensions
-- ============================================================
/* Dimensions provide the descriptive context used to filter, group and analyze the fact tables. For instance, 
can we group by shipping_mode to count all orders for each category. The flexible thing about dimensional modeling, 
is that we can group all entities that are related to the same hierarchi, so we can put product, department and category
information in the same dimension. Then we need location information and shipping information in two seperate dimension tables.
Lastly a date dimension will describe the context of time. 

dim_product: Describes the product hierarchi. 
dim_date: Describes the time context of an order.
dim_location: Describes the geograhically context of an order. 
dim_shipping: Describes delivery context.*/

-- ============================================================
-- 4. Build facts and dimensions
-- ============================================================

/*
fact_orders: 
order_id <- natural/source key 
locationKey <- FK coming from dim_location
shippingKey <- FK coming from dim_shipping
orderDateKey <- FK coming from dim_date - remember dim_date both tells us about order date and shipping date, which is why we make clear date keys here.
shippingDateKey <- FK coming from dim_date - see above.
actual_shipping_days
scheduled_shipping_days
late_delivery_risk

fact_item: 
item_id <- natural/source key
order_id <- natural/source key
productKey <- FK coming from dim_product
orderDateKey <- FK coming from dim_date
item_price
item_quantity
item_total
item_profit_ratio
item_discount
item_discount_rate
sales
order_profit  

dim_product:
productKey <- PK/surrogate key
product_id <- natural/source key
category_id 
category_name 
department_id 
department_name
product_name
product_price

dim_location:
locationKey <- PK/surrogate key
order_city
order_region
order_state
order_country 
market 

dim_shipping:
shippingKey <- PK/surrogate key
shipping_mode
delivery_status

dim_date:
dateKey <- PK/surrogate key
date
day
day_name
week
month
month_name
quarter
year
*/

-- Validate whether benefit_per_order and order_profit contain identical values
SELECT
COUNT(*) AS total_rows,
COUNT(*) FILTER (WHERE benefit_per_order IS DISTINCT FROM order_profit) AS different_values
FROM item;
-- Result: 0 different values.
-- Keep only order_profit in the dimensional model and rename it to item_profit,
-- since the value is stored at item grain.

-- Drop existing tables (drops child tables before parent tables)
DROP TABLE IF EXISTS fact_orders;
DROP TABLE IF EXISTS fact_item;
DROP TABLE IF exists dim_shipping;
DROP TABLE IF exists dim_item;
DROP TABLE IF exists dim_orders;
DROP TABLE IF exists dim_product;
DROP TABLE IF exists dim_location;
DROP TABLE IF EXISTS dim_date;

-- Create dimensional product table 
CREATE TABLE dim_product (
productKey bigint PRIMARY KEY, 
product_id integer, 
category_id integer, 
category_name varchar, 
department_id integer, 
department_name varchar, 
product_name varchar, 
product_price decimal(18,2)); 

-- Insert data in dim_product table
INSERT INTO dim_product
SELECT 
ROW_NUMBER() OVER (ORDER BY p.product_id) AS productKey,
p.product_id, 
c.category_id, 
c.category_name, 
d.department_id, 
d.department_name, 
p.product_name, 
p.product_price
FROM product p
LEFT JOIN category c ON p.category_id = c.category_id 
LEFT JOIN department d ON c.department_id = d.department_id 

-- Create dimensional location table
CREATE TABLE dim_location(
locationKey bigint PRIMARY KEY, 
order_city varchar, 
order_region varchar, 
order_state varchar, 
order_country varchar, 
market varchar);

-- Insert data in dim_location table 
INSERT INTO dim_location
SELECT 
ROW_NUMBER() OVER (ORDER BY 
order_city, 
order_region, 
order_state, 
order_country, 
market) AS locationKey,

order_city, 
order_region, 
order_state, 
order_country, 
market
FROM (
SELECT DISTINCT 
order_city, order_region, order_state, order_country, market FROM location); 

-- Create dimensional shipping table 
CREATE TABLE dim_shipping(
ShippingKey bigint PRIMARY KEY, 
shipping_mode varchar, 
delivery_status varchar);

-- Insert data in dim_shipping table
INSERT INTO dim_shipping
SELECT 
ROW_NUMBER() OVER (ORDER BY 
shipping_mode,
delivery_status) AS shippingKey,

shipping_mode, 
delivery_status
FROM (
SELECT DISTINCT shipping_mode, delivery_status
FROM shipping
);

-- Create dimensional date table 
CREATE TABLE dim_date(
dateKey integer PRIMARY KEY,
date date NOT NULL, 
DAY integer, 
day_name varchar, 
week integer, 
MONTH integer, 
month_name varchar, 
quarter integer, 
YEAR integer
);

-- Insert data in dim_date table
INSERT INTO dim_date
SELECT
cast(strftime(date, '%Y%m%d') AS integer) AS dateKey,
date, 
day(date) AS day, 
dayname(date) AS day_name,
week(date) AS week, 
month(date) AS month, 
monthname(date) AS month_name, 
quarter(date) AS quarter, 
year(date) AS year 
FROM (
SELECT DISTINCT CAST(order_date AS date) AS date 
FROM orders 
UNION 
SELECT DISTINCT CAST(shipping_date AS date) AS date
FROM shipping
)
ORDER BY date;

-- Create fact orders table 
CREATE TABLE fact_orders(
order_id integer PRIMARY key, 
locationKey bigint NOT null, 
shippingKey bigint NOT null, 
orderDateKey integer NOT null, 
shippingDateKey integer NOT NULL,
actual_shipping_days integer, 
scheduled_shipping_days integer, 
late_delivery_risk integer,

FOREIGN KEY (locationKey) REFERENCES dim_location(locationKey),
FOREIGN KEY (shippingKey) REFERENCES dim_shipping(shippingKey),
FOREIGN KEY (orderDateKey) REFERENCES dim_date(DateKey),
FOREIGN KEY (shippingDateKey) REFERENCES dim_date(DateKey)
);

-- Insert data in fact_orders table
INSERT INTO fact_orders
SELECT 
o.order_id, 
dl.locationKey, 
ds.shippingKey, 
od.DateKey AS orderDateKey, 
sd.DateKey AS shippingDateKey, 
s.actual_shipping_days, 
s.scheduled_shipping_days, 
s.late_delivery_risk
FROM orders o 
LEFT JOIN shipping s ON o.order_id = s.order_id
LEFT JOIN dim_shipping ds ON s.shipping_mode = ds.shipping_mode AND s.delivery_status = ds.delivery_status
LEFT JOIN location l ON o.location_id = l.location_id
LEFT JOIN dim_location dl ON l.order_city IS NOT DISTINCT FROM dl.order_city
AND l.order_region IS NOT DISTINCT FROM dl.order_region
AND l.order_state IS NOT DISTINCT FROM dl.order_state
AND l.order_country IS NOT DISTINCT FROM dl.order_country
AND l.market IS NOT DISTINCT FROM dl.market
LEFT JOIN dim_date od ON CAST(o.order_date AS date) = od.date
LEFT JOIN dim_date sd ON CAST(s.shipping_date AS date) = sd.date;

-- Create fact item table 
CREATE TABLE fact_item(
item_id integer PRIMARY KEY, 
order_id integer, 
productKey bigint NOT NULL, 
orderDateKey integer NOT NULL, 
item_price decimal(18,2), 
item_quantity integer,
item_total decimal(18,2), 
item_profit_ratio decimal(10,4), 
item_discount decimal(18,2), 
item_discount_rate decimal(10,4), 
sales decimal(18,2), 
item_profit decimal(18,2),

FOREIGN KEY (productKey) REFERENCES dim_product(productKey),
FOREIGN KEY (orderDateKey) REFERENCES dim_date(dateKey)
);

-- Insert data in fact_item table
INSERT INTO fact_item
SELECT 
i.item_id, 
i.order_id, 
dp.productKey, 
od.DateKey AS orderDateKey, 
i.item_price, 
i.item_quantity, 
i.item_total, 
i.item_profit_ratio, 
i.item_discount, 
i.item_discount_rate, 
i.sales, 
i.order_profit AS item_profit
FROM item i 
LEFT JOIN orders o ON i.order_id = o.order_id
LEFT JOIN dim_product dp ON i.product_id = dp.product_id
LEFT JOIN dim_date od ON CAST(o.order_date AS date) = od.date;

-- ============================================================
-- 5. Validate dimensional model
-- ============================================================

-- Validate grain in dim_location, which should be one row per unique order location
SELECT 
count(*) AS row_counts, 
count(DISTINCT (order_city, order_region, order_state, order_country, market)) AS unique_locations
FROM dim_location;
-- 3772 rows and 3772 unique locations as it should be. 

-- Validate grain in dim_shipping, which should be one row per unique combination of shipping_mode and delivery status
SELECT 
count(*) AS row_counts, 
count(DISTINCT (shipping_mode, delivery_status)) AS unique_shipping_combinations
FROM dim_shipping;
-- 12 rows in total and 12 unique combinations, så grain is not violated. 

-- Validate grain in dim_product, which should be one row per unique product id
SELECT 
count(*) AS unique_rows, 
count(DISTINCT product_id) AS unique_product_ids
FROM dim_product;
-- 118 rows in total and 118 unique product ids, so grain is not violated, which is good. 

-- Validate grain in dim_date, which is one row per calender date 
SELECT 
count(*) AS row_counts,
count(DISTINCT date) AS unique_dates
FROM dim_date;
-- 1133 number of rows and 1133 number of unique dates. All good. 

-- Validate grain in fact_orders, which is one row per order
SELECT 
count(*) AS row_counts,
count(DISTINCT order_id) AS unique_orders
FROM fact_orders;
-- 65,752 unique orders and total rows. All good. 

-- Validate grain in fact_item, which is one row per item
SELECT 
count(*) AS row_counts,
count(DISTINCT item_id) AS unique_items
FROM fact_item;
-- 180,519 unique items and total rows. All good. 

/* Validate relationsships:*/

-- fact_item -> dim_product (productKey is FK)
SELECT count(*) AS missing_products
FROM fact_item f
LEFT JOIN dim_product dp ON f.productKey = dp.productKey
WHERE dp.productKey IS NULL;
-- 0.

-- fact_item -> dim_date (dateKey is FK)
SELECT count(*) AS missing_dates
FROM fact_item f
LEFT JOIN dim_date d ON f.orderDateKey = d.dateKey
WHERE d.dateKey IS NULL;
-- 0.

-- fact_orders -> dim_date (dateKey is FK - Order date)
SELECT count(*) AS missing_dates
FROM fact_orders f
LEFT JOIN dim_date d ON f.orderDateKey = d.dateKey
WHERE d.dateKey IS NULL;
-- 0.

-- fact_orders -> dim_date (dateKey is FK - Shipping date)
SELECT count(*) AS missing_dates
FROM fact_orders f
LEFT JOIN dim_date d ON f.shippingDateKey = d.dateKey
WHERE d.dateKey IS NULL;
-- 0.

-- fact_orders -> dim_location (locationKey is FK)
SELECT count(*) AS missing_locations
FROM fact_orders f
LEFT JOIN dim_location l ON f.locationKey = l.locationKey
WHERE l.locationKey IS NULL;
-- 0.

-- fact_orders -> dim_shipping (shippingKey is FK)
SELECT count(*) AS missing_shipments
FROM fact_orders f
LEFT JOIN dim_shipping s ON f.shippingKey = s.shippingKey
WHERE s.shippingKey IS NULL;
-- 0.