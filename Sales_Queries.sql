-- EXCEL + SQL + POWER BI PROJECT END TO END SALES ANALYSIS

-- importing csv files from local machine 

select * 
from "Sales Canada"; 

select * 
from "Sales China";

select * 
from "Sales India";


select * 
from "Sales UK";

select * 
from "Sales US";

-- NOW WILL UNION ALL THE 5 TABLES SO TO FORM 1 LARGER TABLE AND 
--THEN DO DATA CLEANING AND EXPLORATION PART


CREATE TABLE sales_data as 
	
select * from "Sales Canada"

UNION ALL

select * from "Sales China"

UNION ALL

select * from "Sales India"

UNION ALL

select * from "Sales UK"

UNION ALL

select * from "Sales US";

-- INITIAL DATA EXPLORATION 

SELECT * FROM sales_data;

-- TOP 5 ROWS 
	
SELECT  * FROM sales_data LIMIT 5

-- BOTTOM 5 ROWS 
SELECT *
FROM sales_data
ORDER BY "Transaction ID" DESC
LIMIT 5 
	
-- CHECK FOR DATA TYPES 
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'sales_data';


-- DATA CLEANING

-- Checking for missing values

select * 
from sales_data
where
	 "Country" is null 
		or "Cost Price" is null  
		or " Discount Applied" is null
		or " Quantity Purchased" is null 
		or "Price Per Unit" is null;

-- There's only one missing value in "Price Per Unit" Column will update it.
		
-- Updating "Price Per Unit"

UPDATE sales_data 
SET "Price Per Unit" = (SELECT AVG("Price Per Unit")
						FROM sales_data)
WHERE "Transaction ID" = '001898f7-b696-4356-91dc-8f2b73d09c63';

--Checking for duplicates records

SELECT "Transaction ID", COUNT(*)
FROM sales_data
GROUP BY 1
HAVING COUNT(*) > 1;

--No duplicates in the dataset

--Removing the inconsistencies present in the dataset

SELECT 
  column_name,
  LENGTH(column_name) AS actual_length,
  LENGTH(TRIM(column_name)) AS trimmed_length
FROM information_schema.columns
WHERE table_name = 'sales_data';

--From here it is clear only two columns has leading spaces i.e.
--" Quantity Purchased" and " Discount Applied"

ALTER TABLE sales_data RENAME COLUMN "quantity_purchased" TO "Quantity Purchased";
ALTER TABLE sales_data RENAME COLUMN "discount_applied" TO "Discount Applied";


--Converting all columns to lowercases to avoid writing column names in quotes
--again and again.

ALTER TABLE sales_data RENAME COLUMN "Transaction ID" TO transaction_id;
ALTER TABLE sales_data RENAME COLUMN "Date" TO date;
ALTER TABLE sales_data RENAME COLUMN "Country" TO country;
ALTER TABLE sales_data RENAME COLUMN "Product ID" TO product_id;
ALTER TABLE sales_data RENAME COLUMN "Product Name" TO product_name;
ALTER TABLE sales_data RENAME COLUMN "Category" TO category;
ALTER TABLE sales_data RENAME COLUMN "Price Per Unit" TO price_per_unit;
ALTER TABLE sales_data RENAME COLUMN "Quantity Purchased" TO quantity_purchased;
ALTER TABLE sales_data RENAME COLUMN "Cost Price" TO cost_price;
ALTER TABLE sales_data RENAME COLUMN "Discount Applied" TO discount_applied;
ALTER TABLE sales_data RENAME COLUMN "Payment Method" TO payment_method;
ALTER TABLE sales_data RENAME COLUMN "Customer Age Group" TO customer_age_group;
ALTER TABLE sales_data RENAME COLUMN "Customer Gender" TO customer_gender;
ALTER TABLE sales_data RENAME COLUMN "Store Location" TO store_location;
ALTER TABLE sales_data RENAME COLUMN "Sales Representative" TO sales_representative;


SELECT * FROM sales_data

--Adding a 'total_amount' column

ALTER TABLE sales_data ADD total_amount numeric

--Updating total_amount column

UPDATE sales_data SET total_amount = (price_per_unit * quantity_purchased) - discount_applied;

--Adding a 'profit' column

ALTER TABLE sales_data ADD profit numeric

--Updating profit column

UPDATE sales_data SET profit = total_amount - (cost_price*quantity_purchased);




--Business Questions

--Q1.What is the total revenue generated?

SELECT SUM(total_amount) as total_revenue
FROM sales_data;

--Q2.Which product sold the most units?

SELECT product_name , sum(quantity_purchased) as most_units_sold
FROM sales_data
GROUP BY 1
ORDER BY 2 DESC
LIMIT 1;

--Q3.What are the top 3 countries by total revenue and profit?

SELECT country, sum(total_amount) as total_revenue , sum(profit) as net_profit
FROM sales_data
GROUP BY 1
ORDER BY 2 DESC, 3
LIMIT 3;

--Q4.Which customer gender contributes more to total revenue?

SELECT customer_age_group, customer_gender, sum(total_amount) as total_revenue
FROM sales_data
GROUP BY 1,2
ORDER BY 3 DESC;

--Q5.Which payment method was used most frequently store location wise?

SELECT COUNT(*) as usage_count, payment_method, store_location 
FROM sales_data
GROUP BY 2,3
ORDER BY 1 DESC;

SELECT * FROM sales_data

--Q6.What is the average discount offered per product category?

SELECT category , ROUND(AVG(discount_applied),2) as discount_offered
FROM sales_data
GROUP BY 1
ORDER BY 2 DESC

--Q7.What is the monthly sales trend?

SELECT TO_CHAR(date, 'Month') AS month_name, sum(total_amount) as sales
FROM sales_data
GROUP BY 1
ORDER BY 2 DESC

--Q8.What are the top 3 products by revenue within each category?

WITH CTE AS
(SELECT category,
       product_name,
	   sum(total_amount),
       rank()
       over(partition by category order by sum(total_amount) desc ) as rnk
FROM sales_data
GROUP BY 1,2)

SELECT *
FROM CTE
WHERE rnk<=3

--Q9.What is month-on-month revenue growth?

WITH monthly_revenue AS
	(SELECT EXTRACT(MONTH FROM date) as month ,
			sum(total_amount) as revenue
	FROM sales_data
	GROUP BY 1)

SELECT month, 
	   revenue,
       LAG(revenue) OVER(ORDER BY month) as prev_month ,
       (revenue - LAG(revenue) OVER(ORDER BY month))*100.0 /
       (LAG(revenue) OVER(ORDER BY month)) as growth_percent
FROM monthly_revenue;


--Q10.Identify top 5 customers who bought most frequently 

SELECT customer_name, total_orders
FROM (
  SELECT customer_gender || ' - ' || customer_age_group AS customer_name,
         COUNT(*) AS total_orders
  FROM sales_data
  GROUP BY 1
) sub
ORDER BY total_orders DESC
LIMIT 5;


--Q11.Find products with increasing revenue trend over 3 months

SELECT * FROM sales_data

WITH monthly_prod_sales AS
	(SELECT product_name, EXTRACT(MONTH FROM date) as month ,
			sum(total_amount) as revenue 
	FROM sales_data
	GROUP BY 1,2
	ORDER BY 2 ),

prev_sales AS
( SELECT *,
         LAG(revenue, 1) OVER (PARTITION BY product_name ORDER BY month) AS prev1,
         LAG(revenue, 2) OVER (PARTITION BY product_name ORDER BY month) AS prev2
  FROM monthly_prod_sales
)
SELECT product_name, month, revenue
FROM prev_sales
WHERE revenue > prev1  AND prev1 < prev2;
	

--Q12.Calculate revenue contribution % by store location

SELECT * FROM sales_data

WITH location_revenue AS
(SELECT DISTINCT store_location , sum(total_amount) as revenue 
FROM sales_data
GROUP BY 1)

SELECT store_location , revenue, revenue *100.0/ sum(revenue) over() AS contribution_percent
FROM location_revenue
ORDER BY 3 desc;

--Q13.List down all the over-discounted products (above category average) 

SELECT product_name , category, discount_applied
FROM sales_data
WHERE discount_applied > (SELECT AVG(discount_applied) as discount_on_category
                          FROM sales_data
                          )

--Q14.Find products with declining sales over the last 3 consecutive months

SELECT * FROM sales_data;

WITH monthly_prod_sales AS
	(SELECT product_name, EXTRACT(MONTH FROM date) as month ,
			sum(total_amount) as revenue 
	FROM sales_data
	GROUP BY 1,2
	),
prev_sales AS
( SELECT *,
         LAG(revenue, 1) OVER (PARTITION BY product_name ORDER BY month) AS prev1,
         LAG(revenue, 2) OVER (PARTITION BY product_name ORDER BY month) AS prev2
  FROM monthly_prod_sales
)
SELECT product_name, month, revenue
FROM prev_sales
WHERE revenue < prev1  AND prev1 < prev2;	



	

















