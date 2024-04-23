
/***BE SURE TO DROP ALL TABLES IN WORK THAT BEGIN WITH "CASE_"***/

/*Set Time Zone*/
set time_zone='-4:00';
select now();

/***PRELIMINARY ANALYSIS***/

/*Create a VIEW in WORK called CASE_SCOOT_NAMES that is a subset of the prod table
which only contains scooters.
Result should have 7 records.*/
CREATE OR REPLACE VIEW work.case_scoot_names AS
	SELECT * FROM ba710case.ba710_prod
    WHERE product_type = 'scooter';


select * from work.case_scoot_names;

/*The following code uses a join to combine the view above with the sales information.
  Can the expected performance be improved using an index?
  A) Calculate the EXPLAIN COST.
  B) Create the appropriate indexes.
  C) Calculate the new EXPLAIN COST.
  D) What is your conclusion?:
  
  
*/

select a.model, a.product_type, a.product_id,
    b.customer_id, b.sales_transaction_date, date(b.sales_transaction_date) as sale_date,
    b.sales_amount, b.channel, b.dealership_id
from work.case_scoot_names a 
inner join ba710case.ba710_sales b
    on a.product_id=b.product_id;
    

/*ALTER TABLE ba710case.ba710_sales
DROP INDEX index_product_id;*/
    
-- A) Calculate the EXPLAIN COST
	-- The cost of the given query is 4590.09.
EXPLAIN FORMAT = JSON
select a.model, a.product_type, a.product_id,
    b.customer_id, b.sales_transaction_date, date(b.sales_transaction_date) as sale_date,
    b.sales_amount, b.channel, b.dealership_id
from work.case_scoot_names a 
inner join ba710case.ba710_sales b
    on a.product_id=b.product_id;    
 
/*
{
  "query_block": {
    "select_id": 1,
    "cost_info": {
      "query_cost": "4590.09"
    },
    "nested_loop": [
      {
        "table": {
          "table_name": "ba710_prod",
          "access_type": "ALL",
          "rows_examined_per_scan": 12,
          "rows_produced_per_join": 1,
          "filtered": "10.00",
          "cost_info": {
            "read_cost": "1.33",
            "eval_cost": "0.12",
            "prefix_cost": "1.45",
            "data_read_per_join": "67"
          },
          "used_columns": [
            "product_id",
            "model",
            "product_type"
          ],
          "attached_condition": "(`ba710case`.`ba710_prod`.`product_type` = 'scooter')"
        }
      },
      {
        "table": {
          "table_name": "b",
          "access_type": "ALL",
          "rows_examined_per_scan": 37767,
          "rows_produced_per_join": 4532,
          "filtered": "10.00",
          "using_join_buffer": "hash join",
          "cost_info": {
            "read_cost": "56.60",
            "eval_cost": "453.20",
            "prefix_cost": "4590.09",
            "data_read_per_join": "212K"
          },
          "used_columns": [
            "customer_id",
            "product_id",
            "sales_transaction_date",
            "sales_amount",
            "channel",
            "dealership_id"
          ],
          "attached_condition": "(`ba710case`.`b`.`product_id` = `ba710case`.`ba710_prod`.`product_id`)"
        }
      }
    ]
  }
}
*/

-- B) Create the appropriate indexes
ALTER TABLE ba710case.ba710_sales
ADD INDEX index_product_id(product_id);

-- C) Calculate the new EXPLAIN COST.
	-- The cost of the given query after creating an index of customerid is 615.95.
EXPLAIN FORMAT = JSON
select a.model, a.product_type, a.product_id,
    b.customer_id, b.sales_transaction_date, date(b.sales_transaction_date) as sale_date,
    b.sales_amount, b.channel, b.dealership_id
from work.case_scoot_names a 
inner join ba710case.ba710_sales b
    on a.product_id=b.product_id;
    
/*
{
  "query_block": {
    "select_id": 1,
    "cost_info": {
      "query_cost": "615.95"
    },
    "nested_loop": [
      {
        "table": {
          "table_name": "ba710_prod",
          "access_type": "ALL",
          "rows_examined_per_scan": 12,
          "rows_produced_per_join": 1,
          "filtered": "10.00",
          "cost_info": {
            "read_cost": "1.33",
            "eval_cost": "0.12",
            "prefix_cost": "1.45",
            "data_read_per_join": "67"
          },
          "used_columns": [
            "product_id",
            "model",
            "product_type"
          ],
          "attached_condition": "((`ba710case`.`ba710_prod`.`product_type` = 'scooter') and (`ba710case`.`ba710_prod`.`product_id` is not null))"
        }
      },
      {
        "table": {
          "table_name": "b",
          "access_type": "ref",
          "possible_keys": [
            "index_product_id"
          ],
          "key": "index_product_id",
          "used_key_parts": [
            "product_id"
          ],
          "key_length": "9",
          "ref": [
            "ba710case.ba710_prod.product_id"
          ],
          "rows_examined_per_scan": 3433,
          "rows_produced_per_join": 4120,
          "filtered": "100.00",
          "cost_info": {
            "read_cost": "202.50",
            "eval_cost": "412.00",
            "prefix_cost": "615.95",
            "data_read_per_join": "193K"
          },
          "used_columns": [
            "customer_id",
            "product_id",
            "sales_transaction_date",
            "sales_amount",
            "channel",
            "dealership_id"
          ]
        }
      }
    ]
  }
}
*/    

--  D) What is your conclusion?
-- Based on the SQL query results, creating an index on the 'product_id' column in the 'ba710_sales' table significantly improved query performance. Initially costing 4590.09 units, the query's cost dropped to 615.95 units post-index creation. This reduction underscores the importance of indexing for enhancing database operations.
    
/***PART 1: INVESTIGATE BAT SALES TRENDS***/  
    
/*The following creates a table of daily sales with four columns and will be used in the following step.*/

CREATE TABLE work.case_daily_sales AS
	select p.model, p.product_id, date(s.sales_transaction_date) as sale_date, 
		   round(sum(s.sales_amount),2) as daily_sales
	from ba710case.ba710_sales as s 
    inner join ba710case.ba710_prod as p
		on s.product_id=p.product_id
    group by date(s.sales_transaction_date),p.product_id,p.model;

select * from work.case_daily_sales;

/*Create a view (5 columns)of cumulative sales figures for just the Bat scooter from
the daily sales table you created.
Using the table created above, add a column that contains the cumulative
sales amount (one row per date).
Hint: Window Functions, Over*/

CREATE OR REPLACE VIEW work.cumulative_sales AS
	SELECT case_daily_sales.*,
		   SUM(daily_sales) OVER(PARTITION BY model ORDER BY sale_date) AS cumulative_sales
    FROM work.case_daily_sales
    WHERE model = 'Bat';

SELECT * FROM work.cumulative_sales;

/*Using the view above, create a VIEW (6 columns) that computes the cumulative sales 
for the previous 7 days for just the Bat scooter. 
(i.e., running total of sales for 7 rows inclusive of the current row.)
This is calculated as the 7 day lag of cumulative sum of sales
(i.e., each record should contain the sum of sales for the current date plus
the sales for the preceeding 6 records).
*/

CREATE OR REPLACE VIEW work.cumulative_sales2 AS
	SELECT cumulative_sales.*,
		   SUM(daily_sales) OVER(PARTITION BY model ORDER BY sale_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS 
           cumu_sales_7_days
    FROM work.cumulative_sales
    WHERE model = 'Bat';
    
SELECT * FROM work.cumulative_sales2;    


/*Using the view you just created, create a new view (7 columns) that calculates
the weekly sales growth as a percentage change of cumulative sales
compared to the cumulative sales from the previous week (seven days ago).

See the Word document for an example of the expected output for the Blade scooter.*/

/*Paste a screenshot of at least the first 10 records of the table
  and answer the questions in the Word document*/
CREATE OR REPLACE VIEW work.cumulative_sales3 AS
	SELECT cumulative_sales2.*,
           (cumulative_sales - LAG(cumulative_sales,7) OVER(ORDER BY sale_date))  / LAG(cumulative_sales, 7) OVER(ORDER BY sale_date) * 100.0 AS pot_weekly_increase_cumu_sales
    FROM work.cumulative_sales2
    WHERE model = 'Bat';
    
SELECT * FROM work.cumulative_sales3; 

/* For Questions in Word Doc*/   

SELECT * FROM work.cumulative_sales3
    WHERE pot_weekly_increase_cumu_sales < 10;


SELECT MIN(sale_date) FROM work.cumulative_sales3;

SELECT DATEDIFF('2016-12-06', MIN(sale_date))
	FROM work.cumulative_sales3;  
  

/*********************************************************************************************
Is the launch timing (October) a potential cause for the drop?
Replicate the Bat sales cumulative analysis for the Bat Limited Edition.
*/
CREATE OR REPLACE VIEW work.cumulative_sales4 AS
	SELECT case_daily_sales.*,
		   SUM(daily_sales) OVER(PARTITION BY model ORDER BY sale_date) AS cumulative_sales
    FROM work.case_daily_sales
    WHERE model = 'Bat Limited Edition';


SELECT * FROM work.cumulative_sales4;


CREATE OR REPLACE VIEW work.cumulative_sales5 AS
	SELECT cumulative_sales4.*,
		   SUM(daily_sales) OVER(PARTITION BY model ORDER BY sale_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS 
           cumu_sales_7_days
    FROM work.cumulative_sales4
    WHERE model = 'Bat Limited Edition';
    
SELECT * FROM work.cumulative_sales5;

CREATE OR REPLACE VIEW work.cumulative_sales6 AS
	SELECT cumulative_sales5.*,
           (cumulative_sales - LAG(cumulative_sales,7) OVER(ORDER BY sale_date))  / LAG(cumulative_sales, 7) OVER(ORDER BY sale_date) * 100.0 AS pot_weekly_increase_cumu_sales
    FROM work.cumulative_sales5
    WHERE model = 'Bat Limited Edition';

SELECT * FROM work.cumulative_sales6;

/*Paste a screenshot of at least the first 10 records of the table
  and answer the questions in the Word document*/
  
/* For Questions in Word Doc*/

SELECT * FROM work.cumulative_sales6
    WHERE pot_weekly_increase_cumu_sales < 10;  
    
SELECT MIN(sale_date) FROM work.cumulative_sales6;    
  
SELECT DATEDIFF('2017-04-29', MIN(sale_date)) FROM work.cumulative_sales6;

SELECT * FROM work.cumulative_sales3
    WHERE DATE(sale_date) BETWEEN '2017-02-15' AND '2019-05-31';  

/*********************************************************************************************
However, the Bat Limited was at a higher price point.
Let's take a look at the 2013 Lemon model, since it's a similar price point.  
Is the launch timing (October) a potential cause for the drop?
Replicate the Bat sales cumulative analysis for the 2013 Lemon model.*/

CREATE OR REPLACE VIEW work.cumulative_sales7 AS
	SELECT case_daily_sales.*,
		   SUM(daily_sales) OVER(PARTITION BY model ORDER BY sale_date) AS cumulative_sales
    FROM work.case_daily_sales
    WHERE model = 'Lemon'
    AND YEAR(sale_date) = 2013;
    
SELECT * FROM work.cumulative_sales7;    

CREATE OR REPLACE VIEW work.cumulative_sales8 AS
	SELECT cumulative_sales7.*,
		   SUM(daily_sales) OVER(PARTITION BY model ORDER BY sale_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS 
           cumu_sales_7_days
    FROM work.cumulative_sales7
    WHERE model = 'Lemon'
	AND YEAR(sale_date) = 2013;
    
SELECT * FROM work.cumulative_sales8;    


CREATE OR REPLACE VIEW work.cumulative_sales9 AS
	SELECT cumulative_sales8.*,
           (cumulative_sales - LAG(cumulative_sales,7) OVER(ORDER BY sale_date))  / LAG(cumulative_sales, 7) OVER(ORDER BY sale_date) * 100.0 AS pot_weekly_increase_cumu_sales
    FROM work.cumulative_sales8
    WHERE model = 'Lemon'
	AND YEAR(sale_date) = 2013;
    
SELECT * FROM work.cumulative_sales9;    

/*Paste a screenshot of at least the first 10 records of the table
  and answer the questions in the Word document*/
  
/* For Questions in Word Doc*/

SELECT * FROM work.cumulative_sales9
    WHERE pot_weekly_increase_cumu_sales < 10;
    
SELECT MIN(sale_date) FROM work.cumulative_sales9;

SELECT DATEDIFF('2013-07-01', MIN(sale_date)) FROM work.cumulative_sales9;

SELECT * FROM work.cumulative_sales3
    WHERE DATE(sale_date) BETWEEN '2016-10-10' AND '2016-12-31'
    AND pot_weekly_increase_cumu_sales < 10;

SELECT * FROM work.cumulative_sales9
	WHERE DATE(sale_date) BETWEEN '2013-10-10' AND '2013-12-31'
	AND pot_weekly_increase_cumu_sales < 10;    

