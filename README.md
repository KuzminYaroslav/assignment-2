Query Optimization

Environment
* Database: generated with python using random values.
* Schema: 3 tables (`clients`, `devices`, `shops`)
* Data Volume: 5 000 000 rows per table.

## 1. The Unoptimized Query

The goal was to find high-value clients (under 30) who bought specific high-end devices from larger shops (5+ employees) in a specific location ("Brentfort") that were performing better than their peers (shops with the same employee count).

```sql
EXPLAIN ANALYZE
SELECT c.name, c.age, d.device_model, s.shop_address, s.amount_sold
FROM clients c
JOIN devices d ON c.device_id = d.device_id
JOIN shops s ON d.shop_id = s.shop_id
WHERE
    d.device_model IN ('Macbook 4 Pro', 'Iphone 15', 'Google watch')
    AND s.employee_amount > 5
    AND s.shop_address LIKE '%Brentfort%'
    AND s.amount_sold > (
        SELECT AVG(s2.amount_sold)
        FROM shops s2
        WHERE s2.employee_amount = s.employee_amount
    )
    AND c.age < 30;
```

# Analysis

-- the whole table with 5 000 000 rows filtered by address conditions (4.5 sec)
-- employee amount condition leaves 42 rows (<1 sec)
-- device amount filter leaves 17 rows
	-- subselect is running 42 times to filter table (185 sec)
-- join leaves 7 rows (<1 sec)
-- age condition and joining table leaves 2 rows (<1 sec)

-- final result: 2 row(s) returned 202.253 sec / 0.000 sec


# Optimization Process

I applied three optimization techniques as required: Indexing, Query Rewriting, and CTEs.

# Step 1: Indexing
I added three new indexes to fix the table scan bottlenecks:
  DROP INDEX idx_devices_model ON devices;
  CREATE INDEX idx_devices_model ON devices(device_model);

  DROP INDEX idx_clients_age ON clients;
  CREATE INDEX idx_clients_age ON clients(age);

  DROP INDEX idx_shops_address ON shops;
  CREATE FULLTEXT INDEX idx_shops_address ON shops(shop_address);


# Step 2: Query Rewriting (`LIKE` to `MATCH`)
To *use* the new `FULLTEXT` index, I rewrote the `LIKE` filter:
* Before: `AND s.shop_address LIKE '%Brentfort%'`
* After: `AND MATCH(s.shop_address) AGAINST("Brentfort" IN BOOLEAN MODE)`

# Step 3: Common Table Expression (CTE)
To fix the correlated subquery, I rewrote it as a CTE. This calculates the average for each shop size *only once* at the beginning and stores it in a small, 6-row temporary table.

* Before: `AND s.amount_sold > (SELECT AVG(...) ...)`
* After:
    ```sql
    WITH ShopAverages AS (
        SELECT employee_amount, AVG(amount_sold) AS avg_sold_for_size
        FROM shops
        GROUP BY employee_amount
    )
    ...
    JOIN ShopAverages sa ON s.employee_amount = sa.employee_amount
    ...
    AND s.amount_sold > sa.avg_sold_for_size
    ```

---

# Final Optimized Query

```sql
EXPLAIN ANALYZE
WITH ShopAverages AS (
    SELECT employee_amount, AVG(amount_sold) AS avg_sold_for_size
    FROM shops
    GROUP BY employee_amount
)
SELECT c.name, c.age, d.device_model, s.shop_address, s.amount_sold
FROM clients c
JOIN devices d ON c.device_id = d.device_id
JOIN shops s ON d.shop_id = s.shop_id
JOIN ShopAverages sa ON s.employee_amount = sa.employee_amount
WHERE
    d.device_model IN ('Macbook 4 Pro', 'Iphone 15', 'Google watch')
    AND s.employee_amount > 5
    AND MATCH(s.shop_address) AGAINST("Brentfort" IN BOOLEAN MODE)
    AND s.amount_sold > sa.avg_sold_for_size
    AND c.age < 30;
```

---

# Final Results

The optimization was a success, returning the exact same 2 rows but at a fraction of the cost.

| Metric | 🐢 Unoptimized | 🚀 Optimized | Improvement |
| Execution Time | ~202.2 seconds | ~8.5 seconds | ~95.8% Faster |
