
-- Windows function
SELECT * ,
SUM(unit_price) OVER(ORDER BY unit_price DESC) AS CUM_SUM
FROM dim_product;

-- Frames
SELECT * ,
SUM(unit_price) OVER (ORDER BY launch_date ROWS BETWEEN unbounded preceding AND	current row)
FROM dim_product;

SELECT * ,
SUM(unit_price) OVER (ORDER BY launch_date ROWS BETWEEN unbounded preceding AND	unbounded following)
FROM dim_product;

-- Rank, Dense Rank , Row number
SELECT 
	*,
    ROW_NUMBER() OVER ( ORDER BY unit_price ) AS 'row_number',
    RANK() OVER( ORDER BY unit_price) AS 'rank',
    DENSE_RANK() OVER (ORDER BY unit_price) AS 'dense_rank'
    
FROM 
	dim_product;
    
SELECT 
	*,
    ROW_NUMBER() OVER (PARTITION BY category ORDER BY unit_price ) AS 'row_number',
    RANK() OVER(PARTITION BY category ORDER BY unit_price) AS 'rank',
    DENSE_RANK() OVER (PARTITION BY category ORDER BY unit_price) AS 'dense_rank'
    
FROM 
	dim_product;
    
-- Subqueries
SELECT AVG(unit_price) FROM dim_product;

SELECT 
	*
FROM dim_product WHERE unit_price>495;

SELECT 
	*
FROM dim_product WHERE unit_price > (SELECT AVG(unit_price) FROM dim_product);

-- We can use whole query after FROM, treating it like a table
SELECT * FROM
(SELECT 
	*
FROM dim_product WHERE unit_price > (SELECT AVG(unit_price) FROM dim_product)
) AS subquery_table
WHERE product_name = 'Figure Method';
    

-- CTES (You have to use ctes in From clause Cte is temporary table)
WITH cte_table AS
( SELECT 
	*
FROM dim_product 

WHERE unit_price > (SELECT AVG(unit_price) FROM dim_product)
)
SELECT * FROM cte_table;

WITH cte_table AS
( SELECT 
	*
FROM dim_product 

WHERE unit_price > (SELECT AVG(unit_price) FROM dim_product)
),
cte_table_2 AS
(
SELECT * FROM cte_table

WHERE product_name IN ('Figure Method', 'Pressure That')

)
SELECT * FROM cte_table WHERE product_name ='Figure Method';

-- Scenario Use cases 
-- 1. Find fifth highest number
SELECT * 
FROM
(SELECT *,
	DENSE_RANK() OVER (PARTITION BY  category ORDER BY unit_price) as ranking
FROM dim_product) subquery
WHERE ranking = 10;

-- Scenarion 2 removing duplicates
SELECT * 
FROM 
( SELECT *, DENSE_RANK() OVER ( PARTITION BY product_id ) as ranking FROM dim_product) subquery
WHERE ranking =1;

-- Views ( stored query ) 
CREATE VIEW dedup AS 
SELECT subquery.*
FROM ( SELECT *, DENSE_RANK() OVER ( PARTITION BY product_id ) as ranking FROM dim_product) subquery
WHERE ranking = 1




