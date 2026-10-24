# Logistics & Delivery Performance BI Project

**SQL Project from data source to dimensional modeling. Finalizing with Power BI dashboards**

## Problem

The project aims to transform raw supply chain data into a structured BI solution that provides clear insights into logistics and delivery performance.

The main objective is to make it easier to monitor key areas such as order volume, delivery performance, delays, sales and product profitability through a dimensional data model and interactive Power BI dashboards.

## Final Dashboard

**Dashboard Overview**
![Dashboard Overview](images/dashboard-overview.png) 

**Delivery Performance**
![Delivery Performance](images/dashboard-delivery-performance.png)

**Product Performance**
![Product Performance](images/dashboard-product-performance.png)

## Project Architecture 

SOR: raw DataCo dataset
SOI: staging, cleaning, normalization
SOA: Logistics Data Mart / star schema
BI: Power BI dashboards

![Project Architecture](images/architecture.png)

## Data Modeling Process

**Relational Model**

![Relational Model](images/relational-model.png)

**Dimensional Model (Star Schema)**

![Dimensional Model](images/star-schema.png)

The dimensional model was imported into Power BI with one-to-many relationships from dimensions to fact tables. The date dimension is used for both order and shipping dates.

## SQL Pipeline

sql/
├── 01_data_profiling.sql
├── 02_staging.sql
├── 03_relational_model.sql
└── 04_dimensional_model.sql

## Tools
- DuckDB
- DBeaver
- SQL
- Power BI
- DAX
- Power Query

## Key Takeaways
- data profiling og data quality
- relational + dimensional modeling
- grain management
- SQL transformations
- Power BI modeling og dashboard design
