SELECT
  PRODUCT_ID,
  PRODUCT_NAME,
  CATEGORY,
  UNIT_PRICE
FROM {{ source('raw', 'products') }}
