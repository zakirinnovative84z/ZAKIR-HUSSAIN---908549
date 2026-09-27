-- TASK 1 --
SELECT
    o.order_id,
    o.order_date,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    s.store_name,
    CONCAT(st.first_name, ' ', st.last_name) AS staff_name,
    p.product_name,
    cat.category_name,
    b.brand_name,
    oi.quantity,
    oi.list_price,
    oi.discount,
    oi.quantity * oi.list_price * (1 - oi.discount)
        AS net_line_revenue
FROM sales.orders AS o
JOIN sales.customers AS c
    ON o.customer_id = c.customer_id
JOIN sales.stores AS s
    ON o.store_id = s.store_id
JOIN sales.staffs AS st
    ON o.staff_id = st.staff_id
JOIN sales.order_items AS oi
    ON o.order_id = oi.order_id
JOIN production.products AS p
    ON oi.product_id = p.product_id
JOIN production.categories AS cat
    ON p.category_id = cat.category_id
JOIN production.brands AS b
    ON p.brand_id = b.brand_id
WHERE o.order_status = 4
ORDER BY o.order_date DESC; 

-- TASK 2 --
select
    s.store_name,
    COUNT(DISTINCT o.order_id) AS number_of_orders,
    SUM(oi.quantity) AS total_units_sold,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_net_revenue,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount))
        / COUNT(DISTINCT o.order_id) AS average_order_value
FROM sales.stores AS s
JOIN sales.orders AS o
    ON s.store_id = o.store_id
JOIN sales.order_items AS oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 4
GROUP BY
    s.store_id,
    s.store_name
ORDER BY total_net_revenue DESC;

-- TASK 3 -- 

WITH CustomerSpending AS
(
    SELECT
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        COUNT(DISTINCT o.order_id) AS completed_order_count,
        SUM(
            oi.quantity * oi.list_price * (1 - oi.discount)
        ) AS total_spending
    FROM sales.customers AS c

    JOIN sales.orders AS o
        ON c.customer_id = o.customer_id

    JOIN sales.order_items AS oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 4

    GROUP BY
        c.customer_id,
        c.first_name,
        c.last_name
)

SELECT
    customer_id,
    customer_name,
    completed_order_count,
    total_spending
FROM CustomerSpending
WHERE total_spending >
(
    SELECT AVG(total_spending)
    FROM CustomerSpending
)
ORDER BY total_spending DESC;

-- TASK 4 --

SELECT
    p.product_name,
    s.store_name,
    st.quantity AS current_quantity,
    c.category_name,
    b.brand_name

FROM production.stocks AS st

JOIN production.products AS p
    ON st.product_id = p.product_id

JOIN sales.stores AS s
    ON st.store_id = s.store_id

JOIN production.categories AS c
    ON p.category_id = c.category_id

JOIN production.brands AS b
    ON p.brand_id = b.brand_id

WHERE st.quantity < 5

ORDER BY
    st.quantity ASC,
    p.product_name;

-- TASK 5 --
WITH ProductSales AS
(
    SELECT
        cat.category_name,
        p.product_id,
        p.product_name,

        SUM(oi.quantity) AS total_units_sold,

        SUM(
            oi.quantity * oi.list_price * (1 - oi.discount)
        ) AS total_net_revenue

    FROM production.products AS p

    JOIN production.categories AS cat
        ON p.category_id = cat.category_id

    JOIN sales.order_items AS oi
        ON p.product_id = oi.product_id

    JOIN sales.orders AS o
        ON oi.order_id = o.order_id

    WHERE o.order_status = 4

    GROUP BY
        cat.category_name,
        p.product_id,
        p.product_name
),

RankedProducts AS
(
    SELECT
        category_name,
        product_name,
        total_units_sold,
        total_net_revenue,

        DENSE_RANK() OVER
        (
            PARTITION BY category_name
            ORDER BY total_net_revenue DESC
        ) AS product_position

    FROM ProductSales
)

SELECT
    category_name,
    product_name,
    total_units_sold,
    total_net_revenue,
    product_position

FROM RankedProducts

WHERE product_position <= 3

ORDER BY
    category_name,
    product_position;

-- TASK 6 --

WITH MonthlySales AS
(
    SELECT
        YEAR(o.order_date) AS sales_year,
        MONTH(o.order_date) AS sales_month,

        SUM(
            oi.quantity * oi.list_price * (1 - oi.discount)
        ) AS total_net_revenue

    FROM sales.orders AS o

    JOIN sales.order_items AS oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 4

    GROUP BY
        YEAR(o.order_date),
        MONTH(o.order_date)
)

SELECT
    sales_year AS [year],
    sales_month AS [month],
    total_net_revenue,

    LAG(total_net_revenue) OVER
    (
        ORDER BY sales_year, sales_month
    ) AS previous_month_revenue,

    total_net_revenue
    -
    LAG(total_net_revenue) OVER
    (
        ORDER BY sales_year, sales_month
    ) AS revenue_change

FROM MonthlySales

ORDER BY
    sales_year,
    sales_month;

-- TASK 7 --  
CREATE OR ALTER VIEW sales.vw_customer_sales_summary
AS
SELECT
    c.customer_id,

    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,

    COUNT(DISTINCT o.order_id) AS total_completed_orders,

    COALESCE(SUM(oi.quantity), 0) AS total_units_purchased,

    COALESCE(
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)),
        0
    ) AS total_net_revenue,

    MAX(o.order_date) AS most_recent_completed_order_date

FROM sales.customers AS c

LEFT JOIN sales.orders AS o
    ON c.customer_id = o.customer_id
    AND o.order_status = 4

LEFT JOIN sales.order_items AS oi
    ON o.order_id = oi.order_id

GROUP BY
    c.customer_id,
    c.first_name,
    c.last_name;
GO

SELECT *
FROM sales.vw_customer_sales_summary;

-- TASK 8 --
BEGIN TRANSACTION;
UPDATE sales.customers
SET phone = '(999) 555-0101'
WHERE customer_id = 1;
SELECT
    customer_id,
    first_name,
    last_name,
    phone
FROM sales.customers
WHERE customer_id = 1;
ROLLBACK TRANSACTION;

-- TASK 9 --
CREATE OR ALTER PROCEDURE sales.usp_store_sales_report
    @store_id INT,
    @start_date DATE,
    @end_date DATE
AS
BEGIN
    SET NOCOUNT ON;

    IF @start_date > @end_date
    BEGIN
        THROW 50001, 'Start date cannot be later than end date.', 1;
    END;

    SELECT
        p.product_name,
        SUM(oi.quantity) AS total_units_sold,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_net_revenue
    FROM sales.orders AS o
    JOIN sales.order_items AS oi
        ON o.order_id = oi.order_id
    JOIN production.products AS p
        ON oi.product_id = p.product_id
    WHERE o.store_id = @store_id
      AND o.order_status = 4
      AND o.order_date >= @start_date
      AND o.order_date < DATEADD(DAY, 1, @end_date)
    GROUP BY
        p.product_id,
        p.product_name
    ORDER BY total_net_revenue DESC;
END;
GO
-- TASK 10 --
SELECT
    s.store_name,
    p.product_name,
    SUM(oi.quantity) AS total_units_sold,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_net_revenue,
    st.quantity AS current_stock
FROM sales.stores AS s
JOIN sales.orders AS o
    ON s.store_id = o.store_id
JOIN sales.order_items AS oi
    ON o.order_id = oi.order_id
JOIN production.products AS p
    ON oi.product_id = p.product_id
JOIN production.stocks AS st
    ON p.product_id = st.product_id
    AND s.store_id = st.store_id
WHERE o.order_status = 4
GROUP BY
    s.store_name,
    p.product_id,
    p.product_name,
    st.quantity
ORDER BY total_net_revenue DESC;