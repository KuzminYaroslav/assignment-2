use assignment2;

-- select * from shops limit 100;
-- show processlist;

-- not omptimized

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

-- Analysis:
-- the whole table with 5 000 000 rows filtered by address conditions (4.5 sec)
-- employee amount condition leaves 42 rows (<1 sec)
-- device amount filter leaves 17 rows
	-- subselect is running 42 times to filter table (185 sec)
-- join leaves 7 rows (<1 sec)
-- age condition and joining table leaves 2 rows (<1 sec)

-- final result: 2 row(s) returned 202.253 sec / 0.000 sec


-- optimized

-- indexes
DROP INDEX idx_devices_model ON devices;
CREATE INDEX idx_devices_model ON devices(device_model);

DROP INDEX idx_clients_age ON clients;
CREATE INDEX idx_clients_age ON clients(age);

DROP INDEX idx_shops_address ON shops;
CREATE FULLTEXT INDEX idx_shops_address ON shops(shop_address);

SELECT c.name, c.age, d.device_model, s.shop_address, s.amount_sold
FROM clients c
JOIN devices d ON c.device_id = d.device_id
JOIN shops s ON d.shop_id = s.shop_id
WHERE
    d.device_model IN ('Macbook 4 Pro', 'Iphone 15', 'Google watch')
    AND s.employee_amount > 5
    AND s.shop_address LIKE '%Brentfort%'
    AND c.age < 30;

-- 7 row(s) returned 4.640 sec / 0.000 sec

SELECT c.name, c.age, d.device_model, s.shop_address, s.amount_sold
FROM clients c
JOIN devices d ON c.device_id = d.device_id
JOIN shops s ON d.shop_id = s.shop_id
WHERE
    d.device_model IN ('Macbook 4 Pro', 'Iphone 15', 'Google watch')
    AND s.employee_amount > 5
    AND MATCH(s.shop_address) AGAINST("Brentfort" IN BOOLEAN MODE)
    AND c.age < 30;

-- 7 row(s) returned 0.110 sec / 0.000 sec

-- CTE

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
    AND s.shop_address LIKE '%Brentfort%'
    AND s.amount_sold > sa.avg_sold_for_size
    AND c.age < 30;

-- Error Code: 2013. Lost connection to MySQL server during query 300.000 sec

explain analyze
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

-- Analysis:
-- scan ShopAverage table, grouping rows and save as 6 rows table (4.1 sec)
-- shop address filter using index leaves 125 rows (<1 sec)
-- employee amount filter leaves 42 rows (<1 sec)
-- joins leaves 7 rows (<1 sec)
-- age filter leaves 6 rows (<1 sec)
-- device amount filter leaves 2 rows (<1 sec)



-- 2 row(s) returned 8.547 sec / 0.000 sec


