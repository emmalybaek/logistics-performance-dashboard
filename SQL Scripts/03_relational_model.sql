-- 03. Relational Model

/* This script will create the intermediate layer of the data transformation. It will transform the staging data into 
entity level datasets and build the normalized relationel model used as the foundation for the dimensional model. 

Flow:
stg_supply_chain
    ↓
Intermediate entity views
    ↓
Validate grains and relationships
    ↓
Physical normalized relational model (3NF)
*/

-- ============================================================
-- 1. Intermediate entity views
-- ============================================================

/*
Each view has a clearly defined grain and prepares keys and relationsships for the physical model. 

For example is the grain in the Location entity: One row per location. Since there is no Location Id already, we will 
create it by unique combination of City, Region, State, Zipcode and Market.*/

CREATE OR replace VIEW int_location AS 

SELECT 
ROW_NUMBER() OVER ( 
ORDER BY 
order_country, 
order_region, 
order_state,
order_city,
order_zipcode, 
market
) AS 
location_id, 
order_city,
order_region, 
order_state,
order_zipcode, 
order_country, 
market
FROM (
SELECT DISTINCT 
order_city, 
order_region, 
order_state, 
order_zipcode, 
order_country,
market
FROM stg_supply_chain
);
-- ROW_NUMBER gives each unique location a artificial id number, which is the surrogate key.  
-- SELECT DISTINCT says give me one ROW per UNIQUE location combination. 

/* For the Order entity, the grain is: One row per Order Id. To get Location Id we will need to join 
the information from int_location with the information from the staging view.*/

CREATE OR replace VIEW int_order AS 

SELECT DISTINCT 
s.order_id, 
l.location_id, 
s.order_status, 
s.order_date
FROM stg_supply_chain s 
LEFT JOIN int_location l 
ON s.order_city IS NOT DISTINCT FROM l.order_city
AND s.order_region IS NOT DISTINCT FROM l.order_region
AND s.order_state IS NOT DISTINCT FROM l.order_state
AND s.order_zipcode IS NOT DISTINCT FROM l.order_zipcode
AND s.order_country IS NOT DISTINCT FROM l.order_country
AND s.market IS NOT DISTINCT FROM l.market;
-- From the staging data, we collect order information. we then find the same rows from the int_location and join 
-- matching columns in this order view. We use "Is not distinct from", because zipcode often is null. 

/* For the Item view, the grain is: One row per Item Id. Since all the columns can be found in the staging view, 
it is not nessesary to join data in this case.*/ 

CREATE OR replace VIEW int_item AS 

SELECT DISTINCT 
item_id, 
order_id, 
product_id, 
item_price, 
item_quantity, 
item_total, 
item_profit_ratio, 
item_discount, 
item_discount_rate, 
benefit_per_order, 
sales, 
order_profit
FROM stg_supply_chain;

/* For the Product view, the grain is: One row per Product Id.*/ 

CREATE OR replace VIEW int_product AS 

SELECT DISTINCT 
product_id, 
category_id, 
product_name, 
product_price, 
product_image
FROM stg_supply_chain;

/* For the Category view, the grain is: One row per Category Id.*/ 

CREATE OR replace VIEW int_category AS 

SELECT DISTINCT 
category_id, 
department_id, 
category_name
FROM stg_supply_chain;

/* For the Department view, the grain is: One row per Department Id.*/ 

CREATE OR replace VIEW int_department AS 

SELECT DISTINCT 
department_id, 
department_name
FROM stg_supply_chain;

/* For the Shipping view, the grain is: One row per Order Id.*/ 

CREATE OR replace VIEW int_shipping AS 

SELECT DISTINCT 
order_id, 
shipping_mode, 
actual_shipping_days, 
scheduled_shipping_days, 
delivery_status, 
late_delivery_risk, 
shipping_date
FROM stg_supply_chain;

-- ============================================================
-- 2. Validate grains and relationsships
-- ============================================================

-- Validate grain in int_location view
SELECT 
count(*) AS row_count,
count(DISTINCT location_id) AS unique_location_ids
FROM int_location;
-- Perfect, there is 3,800 rows in the int_location view, and there is 3,800 unique locations ids, meaning all 
-- rows are unique in this intermediate view, which is exactly what we want an entity to be.  

-- Validate grain in int_order view
SELECT
count(*) AS row_count, 
COUNT(DISTINCT order_id) AS unique_order_ids 
FROM int_order;
-- There is 65,752 rows in total and 65,752 unique order ids, so the grain is fully correct. 

-- Validate grain in int_item view 
SELECT 
count(*) AS row_count,
count(DISTINCT item_id) AS unique_item_ids
FROM int_item;
-- There is 180,519 rows in total and 180,519 unique item ids, so the grain is fully correct coded. 

-- Validate grain in int_product view 
SELECT 
count(*) AS row_counts,
count(DISTINCT product_id) AS unique_product_ids
FROM int_product;
-- There is 118 rows in total and 118 unique product ids, so grain is unique in this view. 

-- Validate grain in int_product view 
SELECT 
count(*) AS row_counts,
count(DISTINCT category_id) AS unique_category_ids
FROM int_category;
-- There is 51 rows in total and 51 unique category ids, so grain is unique in this view. 

-- Validate grain in int_product view 
SELECT 
count(*) AS row_counts,
count(DISTINCT department_id) AS unique_department_ids
FROM int_department;
-- There is 11 rows in total and 11 unique department ids, so grain is unique in this view. 

-- Validate grain in int_shipping view 
SELECT 
count(*) AS row_counts,
count(DISTINCT order_id) AS unique_order_ids
FROM int_shipping;
-- There is 65,752 rows in total and 65,752 unique order ids, so grain is unique in this view. 

/* Let's now validate the relationsships / foreign key candidates.*/ 

-- Order -> Location
SELECT COUNT(*) AS missing_locations
FROM int_order
WHERE location_id IS NULL;
-- 0. 

-- Item -> Order
SELECT COUNT(*) AS missing_orders
FROM int_item i
LEFT JOIN int_order o
ON i.order_id = o.order_id
WHERE o.order_id IS NULL;
-- 0. 

-- Item -> Product
SELECT COUNT(*) AS missing_products
FROM int_item i
LEFT JOIN int_product p
ON i.product_id = p.product_id
WHERE p.product_id IS NULL;
-- 0. 

-- Product -> Category 
SELECT COUNT(*) AS missing_categories 
FROM int_product p 
LEFT JOIN int_category c
ON p.category_id = c.category_id
WHERE c.category_id IS NULL;
-- 0. 

-- Category -> Department 
SELECT COUNT(*) AS missing_departments
FROM int_category c 
LEFT JOIN int_department d
ON c.department_id = d.department_id
WHERE d.department_id IS NULL;
-- 0. 

-- Shipping -> Order 
SELECT COUNT(*) AS missing_orders
FROM int_shipping s 
LEFT JOIN int_order o
ON s.order_id = o.order_id
WHERE o.order_id IS NULL;
-- 0. 

-- Now the int views have been created and validated. We now know that there is exactly one row per entity key, 
-- and that every FK value have a matching parent. 


-- ============================================================
-- 3. Build normalized relational model (3NF)
-- ============================================================

/* Now we build the psysical normalized model with real tables, primary keys, foreign keys and constraints. 
Referenced parent tables are created before tables that depend on them. Afterwards, the database structure can
be visualized as an ER diagram (ERD). By storing data using entity relation (ER) data models in operational systems we 
eliminate inconsistent data, require less maintenance and storage data in an efficient way.   
*/

-- Drop existing tables (drops child tables before parent tables)
DROP TABLE IF exists shipping;
DROP TABLE IF exists item;
DROP TABLE IF exists orders;
DROP TABLE IF exists product;
DROP TABLE IF exists category;
DROP TABLE IF exists department;
DROP TABLE IF exists location;

-- Create location table 
CREATE TABLE location (
location_id bigint PRIMARY KEY, 
order_city varchar, 
order_region varchar, 
order_state varchar, 
order_zipcode varchar, 
order_country varchar, 
market varchar);

-- Insert data in location table
INSERT INTO location
SELECT *
FROM int_location;

-- Create department table
CREATE TABLE department (
department_id integer PRIMARY KEY, 
department_name varchar
);

-- Insert data in department table
INSERT INTO department
SELECT * 
FROM int_department;

-- Create category table 
CREATE TABLE category (
category_id integer PRIMARY KEY, 
department_id integer NOT NULL, 
category_name varchar,

FOREIGN KEY (department_id) REFERENCES department(department_id)
);

-- Insert data in category table 
INSERT INTO category 
SELECT * 
FROM int_category;

-- Create product table 
CREATE TABLE product (
product_id integer PRIMARY KEY, 
category_id integer NOT NULL, 
product_name varchar, 
product_price decimal(18,2), 
product_image varchar,

FOREIGN KEY (category_id) REFERENCES category(category_id)
);
-- Category id are labeled as foreign key and because of the logical model, where one product should always 
-- have exactly one category it cannot be null. 

-- Insert data in product table 
INSERT INTO product
SELECT * 
FROM int_product;

-- Create order table
CREATE TABLE orders (
order_id integer PRIMARY KEY, 
location_id bigint NOT NULL,
order_status varchar, 
order_date timestamp, 

FOREIGN KEY (location_id) REFERENCES location(location_id)
);

-- Insert data in order table
INSERT INTO orders
SELECT * 
FROM int_order;

-- Create item table
CREATE TABLE item (
item_id integer PRIMARY KEY, 
order_id integer NOT NULL, 
product_id integer NOT NULL, 
item_price decimal(18,2), 
item_quantity integer, 
item_total decimal(18,2), 
item_profit_ratio decimal(10,4), 
item_discount decimal(18,2), 
item_discount_rate decimal(10,4), 
benefit_per_order decimal(18,2), 
sales decimal(18,2), 
order_profit decimal(18,2),

FOREIGN KEY (order_id) REFERENCES orders(order_id), 
FOREIGN KEY (product_id) REFERENCES product(product_id)
);

-- Insert data in item table 
INSERT INTO item 
SELECT *
FROM int_item;

-- Create shipping table 
CREATE TABLE shipping (
order_id integer PRIMARY KEY, 
shipping_mode varchar, 
actual_shipping_days integer, 
scheduled_shipping_days integer, 
delivery_status varchar, 
late_delivery_risk integer, 
shipping_date timestamp,

FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

-- Insert data in shipping table 
INSERT INTO shipping
SELECT *
FROM int_shipping;