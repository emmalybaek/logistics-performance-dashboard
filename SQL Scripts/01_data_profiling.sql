-- 1. Data Profiling

/* This script will investigate and validate dataset grains, dependencies, null values, relationsships and data quality before modeling.
Further, it will use the data discovery results to layout the logic and normalized model.*/

-- First, let's rename the loaded dataset to raw_data
ALTER TABLE DataCoSupplyChainDataset
RENAME TO raw_data;

/* Secondly, let's start out with data about orders:*/

-- Let's first preview the order information columns and the order item information columns to see if their is some redudant data rows 
select "Order Id", "Order City", "Order Region", "Order State", "Order Zipcode", "Benefit per order"
from raw_data
limit 20;

select "Order item id", "Order Item Product Price", "Order Item Quantity", "Order Item Total"
from raw_data
limit 20;

-- Let's confirm that there are multiple order item rows for each order id (1-to-many relationsship).  
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT "Order Id") AS unique_orders,
    COUNT(DISTINCT "Order Item Id") AS unique_order_items
FROM raw_data; 
-- There IS 180,519 rows in intal which are all order items rows, while there is only 65,752 unique orders
-- This also mean that Order Item ID should be primary key. 

-- Does Order Id or Order Item Id determine Benefit?
SELECT
    "Order Id",
    COUNT(DISTINCT "Benefit per order") AS different_values
FROM raw_data
GROUP BY "Order Id"
HAVING COUNT(DISTINCT "Benefit per order") > 1;
-- There is multiple benefits per order lines for each order id. 

SELECT
"Order Item Id",
COUNT(DISTINCT "Benefit per order") AS different_values
FROM raw_data
GROUP BY "Order Item Id"
HAVING COUNT(DISTINCT "Benefit per order") > 1;
-- It returns 0 rows, so now we know that Order Item Id determine Benefit per order. 

-- Does Order Id determine Region and City?
SELECT
"Order Id",
COUNT(DISTINCT "Order City") AS cities,
COUNT(DISTINCT "Order State") AS states,
COUNT(DISTINCT "Order Region") AS regions,
COUNT(DISTINCT "Order Zipcode") AS zipcodes,
COUNT(DISTINCT "Order Country") AS contries
FROM raw_data
GROUP BY "Order Id"
HAVING
COUNT(DISTINCT "Order City") > 1
OR COUNT(DISTINCT "Order State") > 1
OR COUNT(DISTINCT "Order Region") > 1
OR COUNT(DISTINCT "Order Zipcode") > 1
OR COUNT(DISTINCT "Order Country") > 1;
-- It returns 0 rows, so now we know that Order Id determmines Region, City, State, Zipcode and Country. 

-- Let's see how many times locations is mentioned across orders 
SELECT 
"Order City", 
"Order State", 
"Order Region", 
"Order Zipcode",
COUNT(DISTINCT "Order Id") AS number_of_orders
FROM raw_data
GROUP BY "Order City", "Order State", "Order Region", "Order Zipcode"
HAVING COUNT(DISTINCT "Order Id") > 1
ORDER BY number_of_orders DESC;
-- The same locations are used for many different orders, which is why it make sense to have a seperate location entity.
-- To do this, we need to create a new variable called Location Id. 

-- Let's see if city determines Region and State
SELECT
"Order City",
COUNT(DISTINCT "Order State") AS states,
COUNT(DISTINCT "Order Region") AS regions
FROM raw_data
GROUP BY "Order City"
HAVING
COUNT(DISTINCT "Order State") > 1 OR
COUNT(DISTINCT "Order Region") > 1;
-- Many order cities have different states and regions attached to it, so we need both city, state, region and zipcode in the same entity.

-- Let's see if Order Id determines Order Status and Order Country
SELECT
"Order Id",
COUNT(DISTINCT "Order Status") AS statuses,
COUNT(DISTINCT "Order Country") AS countries
FROM raw_data
GROUP BY "Order Id"
HAVING
COUNT(DISTINCT "Order Status") > 1 OR
COUNT(DISTINCT "Order Country") > 1;
-- 0 rows returned, which mean Status and Country can belong to Order Id entity, because they describe that primary key. 

-- Let's see the dependence between Order Item Id and the following columns Item product price, item profit ratio etc. 
SELECT 
"Order Item Id", 
count(DISTINCT "Order Item Product Price") AS item_prices,
count(DISTINCT "Order Item Quantity") AS item_quantities,
count(DISTINCT "Order Item Total") AS item_total,
count(DISTINCT "Benefit per order") AS benefit,
count(DISTINCT "Order Item Profit Ratio") AS item_profit_ratio,
count(DISTINCT "Order Item Discount") AS item_discount,
count(DISTINCT "Order Item Discount Rate") AS item_discount_rates,
count(DISTINCT "Order Item Cardprod Id") AS item_cardprod_ids
FROM raw_data 
GROUP BY "Order Item Id"
HAVING 
COUNT(DISTINCT "Order Item Product Price") > 1 OR 
count(DISTINCT "Order Item Quantity") > 1 OR 
count(DISTINCT "Order Item Total") > 1 OR 
count(DISTINCT "Benefit per order") > 1 OR 
count(DISTINCT "Order Item Profit Ratio") > 1 OR
count(DISTINCT "Order Item Discount") > 1 OR
count(DISTINCT "Order Item Discount Rate") > 1 OR
count(DISTINCT "Order Item Cardprod Id") > 1;
-- 0 rows returned, which mean that these columns can function as attributes that describe Order Item Id. 
-- Det means that every Order Item Id has exactly one value of each of these attributes in the dataset. 

/*Based on the profiling above, the order-related columns can now be divided into three entities:

Orders: Order Id (PK), Location Id (FK)
Location: Location Id (PK). 
Items: Order Item Id (PK), Order Id (FK). 

The remaining columns becomes attributes of the entity they functionally depend on. 
*/ 

/* Let's now check data about products, categories and department information:*/
   
-- Naturally, each product must belong to an order item, which belongs to an order. 
-- Lets count how many unique products, categories and products names there is in the dataset. 
SELECT 
count(DISTINCT "Product Card ID") AS unique_products,
count(DISTINCT "Product Category Id") AS UNIQUE_categories,
count(DISTINCT "Product Name") AS UNIQUE_product_names,
count(DISTINCT "Category Name") AS UNIQUE_category_names,
count(DISTINCT "Product Price") AS UNIQUE_product_prices,
count(DISTINCT "Department Id") AS UNIQUE_department_ids,
count(DISTINCT "Department Name") AS UNIQUE_department_names
FROM raw_data
-- There is 118 unique product card ids and product names, which could be related. 
-- There is 51 unique categories that these products are connectet to.
-- To normalize data, we should therefore have properly have a product entity and a category entity. 
-- Further we see 50 unique category names, which tell us that two product category ids
-- has the same name, which need to be confirmed and further cleaned if nessesary. 
-- There is 11 unique department ids and names. 

-- Let's doublecheck if each product card id has an unique product name or if coincidence
SELECT "Product Card Id", count(DISTINCT "Product Name") AS product_names
FROM raw_data 
GROUP BY "Product Card Id"
HAVING COUNT(DISTINCT "Product Name") > 1; 
-- Nothing returned, so now we can conclude that each product card id has an unique product name. 
-- Because product card id determines product name, they belong to the same entity.  

-- Let's doublecheck if each department name has an unique department id or if coincidence
SELECT "Department Id", count(DISTINCT "Department Name") AS department_names
FROM raw_data
GROUP BY "Department Id"
HAVING COUNT(DISTINCT "Department Name") > 1; 
-- Nothing returned, so now we can conclude that each department id has an unique department name. 
-- Because department id determines department name, they belong to the same entity. 

-- Let's see the dependence between product card id and price, category and status 
SELECT 
"Product Card Id", 
count(DISTINCT "Product Price") AS product_price,
count(DISTINCT "Product Category Id") AS product_categories,
count(DISTINCT "Product Status") AS product_status,
count(DISTINCT "Product Image") AS product_image,
count(DISTINCT "Product Description") AS product_description
FROM raw_data 
GROUP BY "Product Card Id"
HAVING 
COUNT(DISTINCT "Product Price") > 1 OR 
count(DISTINCT "Product Category Id") > 1 OR 
count(DISTINCT "Product Status") > 1 OR 
count(DISTINCT "Product Description") > 1 OR 
count(DISTINCT "Product Image") > 1;
-- Nothing returned, so now we can conclude that each product card id is associated with 
-- exactly one product price, category id, status, image and description in the dataset. 
-- In other words, these are attributes to product card id together with product name. 

-- Let's see which category names has multiply product category ids
SELECT
"Category Name",
COUNT(DISTINCT "Product Category Id") AS category_ids
FROM raw_data
GROUP BY "Category Name"
HAVING COUNT(DISTINCT "Product Category Id") > 1;
-- Electronics (Category Name) has two different category ids. 

SELECT DISTINCT "Product Category Id", "Category Name"
FROM raw_data
WHERE "Category Name" = 'Electronics';
-- The exact product category ids are 13 and 37 which are both Electronics. 

-- Check relationsship between order Id and department:
SELECT
"Order Id",
COUNT(DISTINCT "Department Id") AS departments
FROM raw_data
GROUP BY "Order Id"
HAVING COUNT(DISTINCT "Department Id") > 1;
-- One order can consist of products from multiply departments, which give a many-to-many relationsship.

-- Check cardinalities between items, products, categories and departments id's 
SELECT 
count(DISTINCT "Order Item Id") AS unique_items,
count(DISTINCT "Product Card Id") AS unique_products,
count(DISTINCT "Product Category Id") AS unique_categories,
count(DISTINCT "Department Id") AS unique_departments
FROM raw_data;
-- There is 180,519 unique items, 118 unique products, 51 unique categories and 11 unique departments.

-- Check if category id and product category id is the same
SELECT
    COUNT(*) AS mismatches
FROM raw_data
WHERE "Category Id" <> "Product Category Id";
-- 0 returned, which mean they are always the same in the dataset, so lets only keep category id.  

-- Check if Order Item Cardprod Id is the same as Product Card Id
SELECT COUNT(*) AS mismatches
FROM raw_data
WHERE "Order Item Cardprod Id" IS DISTINCT FROM "Product Card Id";
-- They are always identical, so lets just keep Product Card Id

/* Based on above, the columns can be divided into three entities: 

Department: Department Id (PK), Product Card Id (FK), Product Category Id (FK)
Category: Category Id (PK), Department Id (FK)
Product: Product Card Id (PK), Product Category Id (FK), Department Id (FK)
*/

/* Let's now check data about shipping:*/

-- Let's see how constant the shipping information is across order ids 
SELECT 
"Order Id",
count(DISTINCT "Shipping Mode") AS shipping_modes,
count(DISTINCT "Days for shipping (real)") AS shipping_days,
count(DISTINCT "Days for shipment (scheduled)") AS shipment_days,
count(DISTINCT "Market"),
count(DISTINCT "Delivery Status") AS statuses,
count(DISTINCT "Late_delivery_risk") AS late_risks
FROM raw_data
GROUP BY "Order Id"
HAVING
COUNT(DISTINCT "Shipping Mode") > 1
OR COUNT(DISTINCT "Days for shipping (real)") > 1
OR COUNT(DISTINCT "Days for shipment (scheduled)") > 1
OR COUNT(DISTINCT "Market") > 1
OR COUNT(DISTINCT "Delivery Status") > 1
OR COUNT(DISTINCT "Late_delivery_risk") > 1;
-- 0 rows returned, which mean one order ID has all of these attributes. This mean that each order have exactly one shipping. 
-- We can still decide to have a seperate 
-- shipping entity instead of connecting it to the order Id entity. As for dates, the order date describe when the 
-- order was created, while shipping date describes when the order was shipped. So let's just add these two to the 
-- order entity and shipping entity seperately. As all shipping details are attributes to each order id, we can 
-- use order id as primary key in the shipping details entity.

/* Based on above, the columns can be included in the same entity: 

Shipping: Shipping Id (PK)
*/

/* Let's now dive a little deeper into data quality and consistency
*/

-- Check date formats before converting later 
SELECT "shipping date (DateOrders)", "Order date (DateOrders)"
FROM raw_data
LIMIT 20;
-- format is 2/3/2018 22:56 for both columns. 

-- Check out all columns for null percentage 
SUMMARIZE raw_data;
-- 86.24% Null values in zipcodes, which we will keep null, when we transform data. 
-- Product description seems to have the same values. This should be inspected. The same goes for 
-- product Status, which seems to all contain 0. 

-- Inspect Product Status
SELECT
    "Product Status",
    COUNT(*) AS row_count
FROM raw_data
GROUP BY "Product Status"
ORDER BY row_count DESC;
-- Product Status is 0 for all rows. 

-- Inspect Product Description
SELECT
    "Product Description",
    COUNT(*) AS row_count
FROM raw_data
GROUP BY "Product Description"
ORDER BY row_count DESC;
-- Product Description is empty for all rows.
-- Both of these columns are excluded from the analysis because they contain no analytical information. 

-- Check if any strings are empty and need to be handled
SELECT
COUNT(*) FILTER (WHERE "Product Name" = '') AS empty_product_names,
COUNT(*) FILTER (WHERE "Product Image" = '') AS empty_product_images,
COUNT(*) FILTER (WHERE "Category Name" = '') AS empty_category_names,
COUNT(*) FILTER (WHERE "Department Name" = '') AS empty_department_names,
COUNT(*) FILTER (WHERE "Order City" = '') AS empty_order_cities,
COUNT(*) FILTER (WHERE "Order State" = '') AS empty_order_states,
COUNT(*) FILTER (WHERE "Order Region" = '') AS empty_order_regions,
COUNT(*) FILTER (WHERE "Order Country" = '') AS empty_order_countries,
COUNT(*) FILTER (WHERE "Market" = '') AS empty_markets,
COUNT(*) FILTER (WHERE "Order Status" = '') AS empty_order_statuses,
COUNT(*) FILTER (WHERE "Shipping Mode" = '') AS empty_shipping_modes,
COUNT(*) FILTER (WHERE "Delivery Status" = '') AS empty_delivery_statuses
FROM raw_data;
-- All these above string-columns has 0 empty textstrings, so no need to handle nulls so far. 

-- check how often � appears in names
SELECT DISTINCT
"Order City",
"Order State",
"Order Region",
"Order Country"
FROM raw_data
WHERE 
"Order City" LIKE '%�%' OR
"Order State" LIKE '%�%' OR
"Order Region" LIKE '%�%' OR
"Order Country" LIKE '%�%';
-- Over 800 rows is fetched, which highligth a severe problem. There is too many to 
-- change manually plus it is too uncertain what should be replaced with the mistakes. 
-- So for now, the dashboard can properly not use these columns faithfully. 


/*
Let's now make an overview over the entities, relationsships and cardinalities as the end of the logical model
based on above findings.

Entities: 
The entities are terms that the system stores data about. We have Location, Order, Order Item, Product, 
Category, Department and Shipping. Under each of these terms, data related to them are stored and called 
attributes. 

Location: 
Location Id (PK)
Order City
Order Region
Order State
Order Zipcode
Order Country 
Market

Order: 
Order Id (PK)
Location Id (FK)
Order Status 
Order Date

Order Item:
Order Item Id (PK)
Order Id (FK)
Product Card Id (FK)
Order Item Product Price
Order Item Quantity
Order Item Total 
Benefit per order
Order Item Profit Ratio 
Order Item Discount 
Order Item Discount Rate 
Sales 
Order Profit Per Order

Product:
Product Card Id (PK)
Category Id (FK)
Product Name
Product Price
Product Image 

Category:
Category Id (PK)
Department Id (FK)
Category Name

Department: 
Department Id (PK)
Department Name

Shipping: 
Order Id (PK, FK)
Shipping Mode
Days for shipping (real)
Days for shipment (scheduled)
Delivery Status 
Late Delivery Risk 
Shipping date  

The relationsships between the entities: 
Location describes the destination of the order, and order describes the Items. Items describes Products, and products describe 
the category. Category describes the department. Order also describes shipping details and since there cannot be shipping details
without an order, they are connected to each other. The foreign keys are placed in x and x and x because...  

Cardinalities between the entities: 
An order can have exactly one location, while locations can have no or many orders. An order can have one or many order items, while 
order items belong to one order. Order item belong to exactly one product, while a product can be connected to one or many order items.
A product belong to one category, while categories can consist of one or many products. The same goes for categories and 
departments - A category belong to one department, while departments can consist of one of many categories. The
last relationsship is between Order and Shipping. An order has exatcly one shipping and one shipping has exatcly one order. 
Now that the cardinalities are in place, it is often easier to see where FK goes, which is usually on each many side. 
For example, between Location and Order, orders is on the many-side, which is why we need Location Id as a foreign key in 
the Order entity. The Order Item entity is the many side on each side, which is why we need to place the primary keys from
both the Order entity and Product entity into Order Item entity as foreign keys. Between Product and Category, Product is the many side, 
so Category Id needs to be a FK in Product. Between Category and Department, Category is the many side, so Department Id goes into 
Category as a FK. Lastly we have Order and Shipping. Allthough there is no many side in this relationsship, there is a one to one 
relationsship, which still require a foreign key, otherwise the database does not know, which shipping row is connected to an order. 
Since it is nice to have shipping details seperate from order details, allthough they are connected, we add Order Id as the
primary key and as the foreign key in the Shipping entity. 
*/