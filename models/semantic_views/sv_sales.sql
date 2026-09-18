{{ config(materialized='semantic_view') }}

TABLES (
  orders AS {{ ref('stg_orders') }}
    PRIMARY KEY (ORDER_ID)
    COMMENT = 'Customer orders with fulfillment status, channel, and region',

  products AS {{ ref('stg_products') }}
    PRIMARY KEY (PRODUCT_ID)
    COMMENT = 'Product catalog with categories and list pricing',

  order_items AS {{ ref('stg_order_items') }}
    PRIMARY KEY (LINE_ITEM_ID)
    COMMENT = 'Line-level detail linking orders to products with quantity, discount, and computed line total'
)

RELATIONSHIPS (
  items_to_orders AS
    order_items (ORDER_ID) REFERENCES orders,
  items_to_products AS
    order_items (PRODUCT_ID) REFERENCES products
)

FACTS (
  order_items.line_total AS order_items.LINE_TOTAL
    COMMENT = 'Revenue per line item after discount: qty * unit_price * (1 - discount)',

  order_items.quantity_sold AS order_items.QUANTITY
    COMMENT = 'Units sold per line item'
)

DIMENSIONS (
  orders.order_date AS orders.ORDER_DATE
    COMMENT = 'Date the order was placed',

  orders.status AS orders.STATUS
    WITH SYNONYMS = ('order status')
    COMMENT = 'Current order status'
    SAMPLE_VALUES ('Placed', 'Fulfilled', 'Shipped', 'Cancelled')
    IS_ENUM,

  orders.channel AS orders.CHANNEL
    WITH SYNONYMS = ('sales channel')
    COMMENT = 'Sales channel'
    SAMPLE_VALUES ('Online', 'In-Store', 'Mobile App')
    IS_ENUM,

  orders.region AS orders.REGION
    WITH SYNONYMS = ('geographic region')
    COMMENT = 'Geographic region of the order'
    SAMPLE_VALUES ('US-West', 'US-East', 'US-Central', 'Canada', 'UK')
    IS_ENUM,

  orders.customer_id AS orders.CUSTOMER_ID
    COMMENT = 'Unique customer identifier',

  products.product_name AS products.PRODUCT_NAME
    WITH SYNONYMS = ('item', 'sku')
    COMMENT = 'Product display name',

  products.category AS products.CATEGORY
    WITH SYNONYMS = ('product type', 'product group')
    COMMENT = 'Product category grouping'
)

METRICS (
  order_items.total_revenue AS SUM(order_items.line_total)
    WITH SYNONYMS = ('total sales', 'revenue')
    COMMENT = 'Total revenue after discounts',

  order_items.total_units_sold AS SUM(order_items.quantity_sold)
    COMMENT = 'Total units sold across all line items',

  order_items.avg_line_value AS AVG(order_items.line_total)
    COMMENT = 'Average revenue per line item',

  orders.order_count AS COUNT(orders.ORDER_ID)
    WITH SYNONYMS = ('number of orders')
    COMMENT = 'Number of distinct orders',

  orders.avg_order_value AS AVG(orders.ORDER_TOTAL)
    COMMENT = 'Average order total'
)

COMMENT = 'Sales analytics semantic view covering orders, products, and line items. Use for revenue, volume, and channel/region analysis.'

AI_SQL_GENERATION
  'Default to the most recent 30 days if no date range is specified.
   Round all currency values to 2 decimal places.
   When asked about sales or revenue, use the total_revenue metric.
   When asked about top products, order by total_revenue DESC.'

AI_QUESTION_CATEGORIZATION
  'This view covers sales, orders, products, and revenue data only.
   Reject questions about employee data, HR, or topics outside of sales analytics.
   If the question is ambiguous, ask for clarification about the time period or metric.'

AI_VERIFIED_QUERIES (
  revenue_by_region AS (
    QUESTION 'What is the total revenue by region?'
    VERIFIED_AT 1726531200
    ONBOARDING_QUESTION TRUE
    SQL $$SELECT REGION, TOTAL_REVENUE
         FROM SEMANTIC_VIEW(sv_sales
           DIMENSIONS orders.region
           METRICS order_items.total_revenue)
         ORDER BY TOTAL_REVENUE DESC$$
  ),
  top_products AS (
    QUESTION 'What are the top selling products?'
    VERIFIED_AT 1726531200
    ONBOARDING_QUESTION TRUE
    SQL $$SELECT PRODUCT_NAME, TOTAL_REVENUE, TOTAL_UNITS_SOLD
         FROM SEMANTIC_VIEW(sv_sales
           DIMENSIONS products.product_name
           METRICS order_items.total_revenue, order_items.total_units_sold)
         ORDER BY TOTAL_REVENUE DESC
         LIMIT 10$$
  ),
  monthly_trend AS (
    QUESTION 'Show me the monthly revenue trend'
    VERIFIED_AT 1726531200
    SQL $$SELECT DATE_TRUNC('MONTH', ORDER_DATE) AS MONTH, TOTAL_REVENUE
         FROM SEMANTIC_VIEW(sv_sales
           DIMENSIONS orders.order_date
           METRICS order_items.total_revenue)
         GROUP BY MONTH
         ORDER BY MONTH$$
  )
)
