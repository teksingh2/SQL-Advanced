# Advanced SQL: A Deep Dive into Window Functions, Subqueries, CTEs & More

If you've been writing SQL for a while and feel comfortable with `SELECT`, `JOIN`, `GROUP BY`, and aggregations, it's time to level up. This guide walks through the advanced SQL concepts that separate everyday queries from truly powerful data analysis.

All examples use a `dim_product` table with columns like `product_id`, `product_name`, `category`, `unit_price`, and `launch_date`.

---

## Table of Contents

1. [Window Functions](#1-window-functions)
2. [Frame Specifications](#2-frame-specifications)
3. [Ranking Functions](#3-ranking-functions---row_number-rank--dense_rank)
4. [Subqueries](#4-subqueries)
5. [Common Table Expressions (CTEs)](#5-common-table-expressions-ctes)
6. [Real-World Scenarios](#6-real-world-scenarios)

---

## 1. Window Functions

### What is a Window Function?

A window function performs a calculation across a **set of rows** that are related to the current row — without collapsing them into a single output row like `GROUP BY` does. Think of it as adding an extra calculated column to every row while keeping all your original data intact.

### Why do we need them?

With `GROUP BY`, you lose the individual row detail. For example, if you want to see each product **and** a running total of prices, `GROUP BY` can't do that — you'd only get the total. Window functions solve this by letting you aggregate **without grouping**.

### Syntax

```
<function>() OVER (
    [PARTITION BY column]
    [ORDER BY column]
    [frame_clause]
)
```

- **`OVER()`** — this is what makes it a window function. It defines the "window" of rows the function operates on.
- **`PARTITION BY`** — splits the data into groups (like `GROUP BY`, but without collapsing rows).
- **`ORDER BY`** — defines the order of rows within each partition.

### Example: Cumulative Sum

```sql
SELECT *,
    SUM(unit_price) OVER (ORDER BY unit_price DESC) AS cum_sum
FROM dim_product;
```

This returns every product along with a running total of `unit_price`, ordered from the most expensive to the cheapest. Each row shows the sum of its own price plus all previous rows.

| product_name | unit_price | cum_sum |
|---|---|---|
| Product A | 900 | 900 |
| Product B | 700 | 1600 |
| Product C | 500 | 2100 |

---

## 2. Frame Specifications

### What are Frames?

Frames let you control **exactly which rows** within the window are included in the calculation. By default, when you use `ORDER BY` inside `OVER()`, SQL uses a frame from the start of the partition up to the current row. But you can customize this.

### Syntax

```
ROWS BETWEEN <start> AND <end>
```

Common frame boundaries:

| Boundary | Meaning |
|---|---|
| `UNBOUNDED PRECEDING` | First row of the partition |
| `CURRENT ROW` | The current row |
| `UNBOUNDED FOLLOWING` | Last row of the partition |
| `N PRECEDING` | N rows before the current row |
| `N FOLLOWING` | N rows after the current row |

### Example: Running Total (Default Behavior)

```sql
SELECT *,
    SUM(unit_price) OVER (
        ORDER BY launch_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )
FROM dim_product;
```

This calculates a running sum from the **first row** up to the **current row** — essentially a cumulative total ordered by launch date.

### Example: Grand Total on Every Row

```sql
SELECT *,
    SUM(unit_price) OVER (
        ORDER BY launch_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    )
FROM dim_product;
```

This gives you the **total sum of all prices** on every single row, because the frame spans from the first row to the last row regardless of position. Useful when you want to calculate each product's percentage of the total.

### Visual: How Frames Work

Imagine rows ordered by `launch_date`:

```
Row 1:  [=======]                          <- UNBOUNDED PRECEDING
Row 2:  [===========]
Row 3:  [===============] <- CURRENT ROW   <- frame covers Row 1 to Row 3
Row 4:               ...
Row 5:               ...                   <- UNBOUNDED FOLLOWING
```

---

## 3. Ranking Functions — ROW_NUMBER, RANK & DENSE_RANK

### What are Ranking Functions?

These functions assign a **position number** to each row based on the order you specify. They look similar but handle **ties** (duplicate values) differently.

### The Three Functions

| Function | Ties? | Gaps? | Example for values: 100, 200, 200, 300 |
|---|---|---|---|
| `ROW_NUMBER()` | No — always unique | N/A | 1, 2, 3, 4 |
| `RANK()` | Yes — same rank for ties | Yes — skips numbers | 1, 2, 2, 4 |
| `DENSE_RANK()` | Yes — same rank for ties | No — no gaps | 1, 2, 2, 3 |

### Example: Ranking All Products by Price

```sql
SELECT
    *,
    ROW_NUMBER() OVER (ORDER BY unit_price) AS row_num,
    RANK()       OVER (ORDER BY unit_price) AS rnk,
    DENSE_RANK() OVER (ORDER BY unit_price) AS dense_rnk
FROM dim_product;
```

### Example: Ranking Within Each Category

```sql
SELECT
    *,
    ROW_NUMBER() OVER (PARTITION BY category ORDER BY unit_price) AS row_num,
    RANK()       OVER (PARTITION BY category ORDER BY unit_price) AS rnk,
    DENSE_RANK() OVER (PARTITION BY category ORDER BY unit_price) AS dense_rnk
FROM dim_product;
```

Adding `PARTITION BY category` restarts the ranking for each category. So the cheapest product in "Electronics" gets rank 1, and the cheapest in "Clothing" also gets rank 1 — they're ranked independently.

### When to Use Which?

- **`ROW_NUMBER()`** — when you need a unique number per row (e.g., pagination, deduplication).
- **`RANK()`** — when ties matter and you want to reflect the gap (e.g., competition rankings: 1st, 2nd, 2nd, 4th).
- **`DENSE_RANK()`** — when ties matter but you don't want gaps (e.g., "find the 3rd highest price" — you want the actual 3rd distinct value).

---

## 4. Subqueries

### What is a Subquery?

A subquery is a **query nested inside another query**. The inner query runs first, and its result is used by the outer query. Think of it as breaking a complex question into smaller steps.

### Types of Subqueries

#### a) Scalar Subquery (in WHERE clause)

Returns a **single value** and is used for comparison.

**Problem:** Find all products priced above average.

Step 1 — What's the average price?

```sql
SELECT AVG(unit_price) FROM dim_product;
-- Result: 495
```

Step 2 — Filter products above that value. Instead of hardcoding 495:

```sql
SELECT *
FROM dim_product
WHERE unit_price > (SELECT AVG(unit_price) FROM dim_product);
```

The subquery `(SELECT AVG(unit_price) FROM dim_product)` runs first, returns a single number, and then the outer query uses it as a filter. This is dynamic — if the data changes, the average updates automatically.

#### b) Derived Table (Subquery in FROM clause)

You can use an entire query as if it were a **temporary table** by placing it in the `FROM` clause.

```sql
SELECT * FROM
(
    SELECT *
    FROM dim_product
    WHERE unit_price > (SELECT AVG(unit_price) FROM dim_product)
) AS subquery_table
WHERE product_name = 'Figure Method';
```

**How it works:**
1. The innermost subquery calculates the average price.
2. The middle query filters products above average — this becomes `subquery_table`.
3. The outer query filters `subquery_table` further for a specific product.

> **Note:** Derived tables **must** have an alias (the `AS subquery_table` part), or the query will fail.

### Limitations of Subqueries

- Can get **hard to read** when deeply nested.
- Each subquery is **defined inline**, making it difficult to reuse.
- Debugging is tough — you have to work inside-out.

This is exactly where CTEs come in.

---

## 5. Common Table Expressions (CTEs)

### What is a CTE?

A CTE (Common Table Expression) is a **named temporary result set** that you define at the top of your query using the `WITH` keyword. It exists only for the duration of that single query — think of it as giving a name to a subquery so you can reference it cleanly.

### Syntax

```sql
WITH cte_name AS (
    -- your query here
)
SELECT * FROM cte_name;
```

### CTE vs Subquery

| Feature | Subquery | CTE |
|---|---|---|
| Readability | Nested, hard to follow | Flat, top-to-bottom |
| Reusability | Must duplicate the query | Define once, use multiple times |
| Debugging | Work inside-out | Test each CTE independently |
| Scope | Inline only | Named and referenced by name |

### Example: Single CTE

```sql
WITH cte_table AS (
    SELECT *
    FROM dim_product
    WHERE unit_price > (SELECT AVG(unit_price) FROM dim_product)
)
SELECT * FROM cte_table;
```

This does the same thing as the subquery example above, but the logic is separated: first you define `cte_table`, then you query from it. Much easier to read.

### Example: Chaining Multiple CTEs

You can define multiple CTEs separated by commas, and each one can reference the previous ones.

```sql
WITH cte_table AS (
    SELECT *
    FROM dim_product
    WHERE unit_price > (SELECT AVG(unit_price) FROM dim_product)
),
cte_table_2 AS (
    SELECT * FROM cte_table
    WHERE product_name IN ('Figure Method', 'Pressure That')
)
SELECT * FROM cte_table
WHERE product_name = 'Figure Method';
```

**How it works:**
1. `cte_table` — filters products above average price.
2. `cte_table_2` — further filters `cte_table` for specific product names.
3. The final `SELECT` can reference **any** of the defined CTEs.

### When to Use CTEs

- When you have **complex queries** that benefit from being broken into logical steps.
- When the same intermediate result is **referenced multiple times**.
- When you want your SQL to read like a **story** — top to bottom, step by step.

---

## 6. Real-World Scenarios

### Scenario 1: Find the Nth Highest Price per Category

**Problem:** Find products with the 10th highest price in each category.

**Approach:** Use `DENSE_RANK()` with `PARTITION BY` inside a subquery, then filter by rank.

```sql
SELECT *
FROM (
    SELECT *,
        DENSE_RANK() OVER (PARTITION BY category ORDER BY unit_price) AS ranking
    FROM dim_product
) subquery
WHERE ranking = 10;
```

**Why `DENSE_RANK()` and not `RANK()`?** If two products share the same price, `RANK()` would skip a number (1, 2, 2, 4), meaning "rank 3" wouldn't exist. `DENSE_RANK()` ensures no gaps (1, 2, 2, 3), so you always get the Nth distinct value.

### Scenario 2: Removing Duplicate Rows

**Problem:** The `dim_product` table has duplicate rows for some `product_id` values. Keep only one row per product.

**Approach:** Use `ROW_NUMBER()` partitioned by `product_id` — duplicates will get row numbers 2, 3, etc. Keep only row number 1.

```sql
SELECT *
FROM (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY product_id) AS row_num
    FROM dim_product
) subquery
WHERE row_num = 1;
```

> **Note:** `ROW_NUMBER()` is preferred here over `DENSE_RANK()` because we want exactly **one** row per `product_id`, regardless of whether other columns differ.

---

## Quick Reference Cheat Sheet

| Concept | Use When |
|---|---|
| `SUM() OVER()` | Running totals without losing row detail |
| `ROWS BETWEEN ... AND ...` | Custom control over which rows are in the calculation |
| `ROW_NUMBER()` | Unique numbering, pagination, deduplication |
| `RANK()` | Rankings with gaps on ties |
| `DENSE_RANK()` | Rankings without gaps — finding Nth values |
| Subquery in `WHERE` | Filtering based on a dynamically calculated value |
| Subquery in `FROM` | Treating a query result as a temporary table |
| CTE (`WITH ... AS`) | Readable, reusable, step-by-step query building |

---

## How to Use

1. Clone this repository.
2. Run the queries in `sql_adv.sql` against a database that contains a `dim_product` table.
3. Experiment by modifying the `PARTITION BY`, `ORDER BY`, and frame clauses to see how results change.
