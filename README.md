# Logistics & Delivery Performance BI Project

**SQL Project from data source to dimensional modeling. Finalizing with Power BI dashboards**

## Problem

mangler at skrive

## Final Dashboard

3 images 

## Project Architecture 

image af data achitekturen (slide 8)

SOR: raw DataCo dataset
SOI: staging, cleaning, normalization
SOA: Logistics Data Mart / star schema
BI: Power BI dashboards

## Data Modeling Process

**Relational Model**

ERD image

**Dimensional Model (Star Schema)**

image af star schema in power bi (slide 7)

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
