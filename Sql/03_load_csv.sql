/* ============================================================================
   NEXORA SUPPLY CHAIN ANALYTICS PLATFORM
   File          : 03_load_csv.sql
   Purpose       : Load the analytics-ready CSV into the MySQL staging layer.
   Compatibility : MySQL 8.0+ / MySQL Workbench

   IMPORTANT
   1. Run 01_create_database.sql and 02_create_staging_table.sql first.
   2. Edit the CSV path below. On Windows, use forward slashes.
   3. The CSV must be produced by 03_feature_engineering.ipynb and must retain
      the original exported column order (91 data columns).
   4. Enable "OPT_LOCAL_INFILE=1" in the Workbench connection if LOCAL INFILE
      is blocked, then reconnect.
   ============================================================================ */
USE nexora_supply_chain;

SET SESSION sql_mode =
    'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
SET SESSION time_zone = '+00:00';

-- Confirm LOCAL INFILE availability. A value of ON is required for this script.
SHOW VARIABLES LIKE 'local_infile';

-- ---------------------------------------------------------------------------
-- LOAD SETTINGS
-- ---------------------------------------------------------------------------
SET @source_file_name = 'dataco_supply_chain_analytics_ready.csv';
SET @load_batch_id = CONCAT('DATACO_', DATE_FORMAT(NOW(6), '%Y%m%d_%H%i%s_%f'));
SET @expected_rows = 180519;
SET @started_at = NOW(6);

-- Edit this literal path before running the LOAD DATA statement.
-- Example Windows path:
-- C:/Users/USER/Downloads/dataco_supply_chain_analytics_ready.csv

INSERT INTO etl_run_log (
    pipeline_name,
    source_file_name,
    process_name,
    process_status,
    started_at
)
VALUES (
    'nexora_supply_chain_pipeline',
    @source_file_name,
    'load_staging_csv',
    'STARTED',
    @started_at
);

SET @etl_run_id = LAST_INSERT_ID();

-- Full-refresh staging load.
-- This prevents duplicate rows when the script is executed again.
TRUNCATE TABLE stg_supply_chain;
SET @rows_before = 0;

LOAD DATA LOCAL INFILE
'C:/Users/USER/Downloads/dataco_supply_chain_analytics_ready.csv'
INTO TABLE stg_supply_chain
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
ESCAPED BY '\\'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    @payment_type,
    @days_for_shipping_real,
    @days_for_shipment_scheduled,
    @order_profit,
    @sales_per_customer,
    @delivery_status,
    @late_delivery_risk,
    @category_id,
    @category_name,
    @customer_city,
    @customer_country,
    @customer_id,
    @customer_segment,
    @customer_state,
    @customer_zipcode,
    @department_id,
    @department_name,
    @latitude,
    @longitude,
    @market,
    @order_city,
    @order_country,
    @order_customer_id,
    @order_date,
    @order_id,
    @order_item_cardprod_id,
    @order_item_discount,
    @order_item_discount_rate,
    @order_item_id,
    @order_item_product_price,
    @order_item_profit_ratio,
    @order_item_quantity,
    @sales,
    @order_item_total,
    @order_profit_per_order,
    @order_region,
    @order_state,
    @order_status,
    @shipping_date,
    @shipping_mode,
    @product_card_id,
    @product_category_id,
    @product_name,
    @product_price,
    @product_status,
    @shipping_delay_days,
    @delivery_performance,
    @is_late_delivery,
    @profit_margin_pct,
    @gross_sales_before_discount,
    @profitability_status,
    @order_year,
    @order_quarter,
    @order_month,
    @order_month_name,
    @order_week,
    @order_day_name,
    @order_date_key,
    @shipping_date_key,
    @order_quarter_number,
    @order_year_month,
    @order_day,
    @is_weekend_order,
    @shipping_year_month,
    @absolute_schedule_variance_days,
    @is_on_time_delivery,
    @shipping_efficiency_ratio,
    @delivery_delay_severity,
    @shipping_speed_segment,
    @discount_pct_calculated,
    @discount_rate_pct,
    @is_profitable_item,
    @is_loss_item,
    @sales_value_tier,
    @margin_band,
    @discount_band,
    @order_total_sales,
    @order_total_profit,
    @order_total_quantity,
    @order_item_count,
    @order_profit_margin_pct,
    @customer_order_count,
    @customer_lifetime_sales,
    @customer_average_item_sales,
    @customer_lifetime_profit,
    @customer_first_order_date,
    @customer_last_order_date,
    @customer_tenure_days,
    @customer_frequency_segment,
    @requires_management_attention,
    @operational_risk_segment
)
SET
    source_file_name = @source_file_name,
    load_batch_id = @load_batch_id,
    loaded_at = NOW(6),
    payment_type = NULLIF(TRIM(@payment_type), ''),
    days_for_shipping_real = NULLIF(TRIM(@days_for_shipping_real), ''),
    days_for_shipment_scheduled = NULLIF(TRIM(@days_for_shipment_scheduled), ''),
    order_profit = NULLIF(TRIM(@order_profit), ''),
    sales_per_customer = NULLIF(TRIM(@sales_per_customer), ''),
    delivery_status = NULLIF(TRIM(@delivery_status), ''),
    late_delivery_risk = NULLIF(TRIM(@late_delivery_risk), ''),
    category_id = NULLIF(TRIM(@category_id), ''),
    category_name = NULLIF(TRIM(@category_name), ''),
    customer_city = NULLIF(TRIM(@customer_city), ''),
    customer_country = NULLIF(TRIM(@customer_country), ''),
    customer_id = NULLIF(TRIM(@customer_id), ''),
    customer_segment = NULLIF(TRIM(@customer_segment), ''),
    customer_state = NULLIF(TRIM(@customer_state), ''),
    customer_zipcode = NULLIF(TRIM(@customer_zipcode), ''),
    department_id = NULLIF(TRIM(@department_id), ''),
    department_name = NULLIF(TRIM(@department_name), ''),
    latitude = NULLIF(TRIM(@latitude), ''),
    longitude = NULLIF(TRIM(@longitude), ''),
    market = NULLIF(TRIM(@market), ''),
    order_city = NULLIF(TRIM(@order_city), ''),
    order_country = NULLIF(TRIM(@order_country), ''),
    order_customer_id = NULLIF(TRIM(@order_customer_id), ''),
    order_date = CASE
        WHEN NULLIF(TRIM(@order_date), '') IS NULL THEN NULL
        WHEN TRIM(@order_date) REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4} [0-9]{1,2}:[0-9]{2}$'
            THEN STR_TO_DATE(TRIM(@order_date), '%c/%e/%Y %k:%i')
        WHEN TRIM(@order_date) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$'
            THEN STR_TO_DATE(TRIM(@order_date), '%Y-%m-%d %H:%i:%s')
        WHEN TRIM(@order_date) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN STR_TO_DATE(TRIM(@order_date), '%Y-%m-%d')
        ELSE NULL
    END,
    order_id = NULLIF(TRIM(@order_id), ''),
    order_item_cardprod_id = NULLIF(TRIM(@order_item_cardprod_id), ''),
    order_item_discount = NULLIF(TRIM(@order_item_discount), ''),
    order_item_discount_rate = NULLIF(TRIM(@order_item_discount_rate), ''),
    order_item_id = NULLIF(TRIM(@order_item_id), ''),
    order_item_product_price = NULLIF(TRIM(@order_item_product_price), ''),
    order_item_profit_ratio = NULLIF(TRIM(@order_item_profit_ratio), ''),
    order_item_quantity = NULLIF(TRIM(@order_item_quantity), ''),
    sales = NULLIF(TRIM(@sales), ''),
    order_item_total = NULLIF(TRIM(@order_item_total), ''),
    order_profit_per_order = NULLIF(TRIM(@order_profit_per_order), ''),
    order_region = NULLIF(TRIM(@order_region), ''),
    order_state = NULLIF(TRIM(@order_state), ''),
    order_status = NULLIF(TRIM(@order_status), ''),
    shipping_date = CASE
        WHEN NULLIF(TRIM(@shipping_date), '') IS NULL THEN NULL
        WHEN TRIM(@shipping_date) REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4} [0-9]{1,2}:[0-9]{2}$'
            THEN STR_TO_DATE(TRIM(@shipping_date), '%c/%e/%Y %k:%i')
        WHEN TRIM(@shipping_date) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$'
            THEN STR_TO_DATE(TRIM(@shipping_date), '%Y-%m-%d %H:%i:%s')
        WHEN TRIM(@shipping_date) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN STR_TO_DATE(TRIM(@shipping_date), '%Y-%m-%d')
        ELSE NULL
    END,
    shipping_mode = NULLIF(TRIM(@shipping_mode), ''),
    product_card_id = NULLIF(TRIM(@product_card_id), ''),
    product_category_id = NULLIF(TRIM(@product_category_id), ''),
    product_name = NULLIF(TRIM(@product_name), ''),
    product_price = NULLIF(TRIM(@product_price), ''),
    product_status = NULLIF(TRIM(@product_status), ''),
    shipping_delay_days = NULLIF(TRIM(@shipping_delay_days), ''),
    delivery_performance = NULLIF(TRIM(@delivery_performance), ''),
    is_late_delivery = NULLIF(TRIM(@is_late_delivery), ''),
    profit_margin_pct = NULLIF(TRIM(@profit_margin_pct), ''),
    gross_sales_before_discount = NULLIF(TRIM(@gross_sales_before_discount), ''),
    profitability_status = NULLIF(TRIM(@profitability_status), ''),
    order_year = NULLIF(TRIM(@order_year), ''),
    order_quarter = NULLIF(TRIM(@order_quarter), ''),
    order_month = NULLIF(TRIM(@order_month), ''),
    order_month_name = NULLIF(TRIM(@order_month_name), ''),
    order_week = NULLIF(TRIM(@order_week), ''),
    order_day_name = NULLIF(TRIM(@order_day_name), ''),
    order_date_key = NULLIF(TRIM(@order_date_key), ''),
    shipping_date_key = NULLIF(TRIM(@shipping_date_key), ''),
    order_quarter_number = NULLIF(TRIM(@order_quarter_number), ''),
    order_year_month = NULLIF(TRIM(@order_year_month), ''),
    order_day = NULLIF(TRIM(@order_day), ''),
    is_weekend_order = NULLIF(TRIM(@is_weekend_order), ''),
    shipping_year_month = NULLIF(TRIM(@shipping_year_month), ''),
    absolute_schedule_variance_days = NULLIF(TRIM(@absolute_schedule_variance_days), ''),
    is_on_time_delivery = NULLIF(TRIM(@is_on_time_delivery), ''),
    shipping_efficiency_ratio = NULLIF(TRIM(@shipping_efficiency_ratio), ''),
    delivery_delay_severity = NULLIF(TRIM(@delivery_delay_severity), ''),
    shipping_speed_segment = NULLIF(TRIM(@shipping_speed_segment), ''),
    discount_pct_calculated = NULLIF(TRIM(@discount_pct_calculated), ''),
    discount_rate_pct = NULLIF(TRIM(@discount_rate_pct), ''),
    is_profitable_item = NULLIF(TRIM(@is_profitable_item), ''),
    is_loss_item = NULLIF(TRIM(@is_loss_item), ''),
    sales_value_tier = NULLIF(TRIM(@sales_value_tier), ''),
    margin_band = NULLIF(TRIM(@margin_band), ''),
    discount_band = NULLIF(TRIM(@discount_band), ''),
    order_total_sales = NULLIF(TRIM(@order_total_sales), ''),
    order_total_profit = NULLIF(TRIM(@order_total_profit), ''),
    order_total_quantity = NULLIF(TRIM(@order_total_quantity), ''),
    order_item_count = NULLIF(TRIM(@order_item_count), ''),
    order_profit_margin_pct = NULLIF(TRIM(@order_profit_margin_pct), ''),
    customer_order_count = NULLIF(TRIM(@customer_order_count), ''),
    customer_lifetime_sales = NULLIF(TRIM(@customer_lifetime_sales), ''),
    customer_average_item_sales = NULLIF(TRIM(@customer_average_item_sales), ''),
    customer_lifetime_profit = NULLIF(TRIM(@customer_lifetime_profit), ''),
    customer_first_order_date = CASE
        WHEN NULLIF(TRIM(@customer_first_order_date), '') IS NULL THEN NULL
        WHEN TRIM(@customer_first_order_date) REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4} [0-9]{1,2}:[0-9]{2}$'
            THEN STR_TO_DATE(TRIM(@customer_first_order_date), '%c/%e/%Y %k:%i')
        WHEN TRIM(@customer_first_order_date) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$'
            THEN STR_TO_DATE(TRIM(@customer_first_order_date), '%Y-%m-%d %H:%i:%s')
        WHEN TRIM(@customer_first_order_date) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN STR_TO_DATE(TRIM(@customer_first_order_date), '%Y-%m-%d')
        ELSE NULL
    END,
    customer_last_order_date = CASE
        WHEN NULLIF(TRIM(@customer_last_order_date), '') IS NULL THEN NULL
        WHEN TRIM(@customer_last_order_date) REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4} [0-9]{1,2}:[0-9]{2}$'
            THEN STR_TO_DATE(TRIM(@customer_last_order_date), '%c/%e/%Y %k:%i')
        WHEN TRIM(@customer_last_order_date) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$'
            THEN STR_TO_DATE(TRIM(@customer_last_order_date), '%Y-%m-%d %H:%i:%s')
        WHEN TRIM(@customer_last_order_date) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN STR_TO_DATE(TRIM(@customer_last_order_date), '%Y-%m-%d')
        ELSE NULL
    END,
    customer_tenure_days = NULLIF(TRIM(@customer_tenure_days), ''),
    customer_frequency_segment = NULLIF(TRIM(@customer_frequency_segment), ''),
    requires_management_attention = NULLIF(TRIM(@requires_management_attention), ''),
    operational_risk_segment = NULLIF(TRIM(TRAILING '\r' FROM @operational_risk_segment), '');

SET @rows_after = (SELECT COUNT(*) FROM stg_supply_chain);
SET @rows_inserted = @rows_after - @rows_before;
SET @distinct_order_items = (
    SELECT COUNT(DISTINCT order_item_id)
    FROM stg_supply_chain
    WHERE load_batch_id = @load_batch_id
);
SET @duplicate_rows = @rows_inserted - @distinct_order_items;

SET @load_status = CASE
    WHEN @rows_inserted = @expected_rows
         AND @duplicate_rows = 0 THEN 'SUCCESS'
    WHEN @rows_inserted > 0 THEN 'WARNING'
    ELSE 'FAILED'
END;

UPDATE etl_run_log
SET process_status = @load_status,
    rows_read = @rows_inserted,
    rows_inserted = @rows_inserted,
    rows_rejected = 0,
    completed_at = NOW(6),
    error_message = CASE
        WHEN @rows_inserted = @expected_rows AND @duplicate_rows = 0 THEN NULL
        WHEN @rows_inserted > 0 THEN CONCAT(
            'Loaded ', FORMAT(@rows_inserted, 0),
            ' rows; expected exactly ', FORMAT(@expected_rows, 0),
            '. Duplicate rows detected: ', FORMAT(@duplicate_rows, 0), '.'
        )
        ELSE 'No rows were loaded. Review path, LOCAL INFILE, delimiter, and CSV structure.'
    END
WHERE etl_run_id = @etl_run_id;

-- ---------------------------------------------------------------------------
-- POST-LOAD RECONCILIATION
-- ---------------------------------------------------------------------------
SELECT
    @load_batch_id AS load_batch_id,
    @source_file_name AS source_file_name,
    @rows_before AS rows_before,
    @rows_after AS rows_after,
    @rows_inserted AS rows_inserted,
    @distinct_order_items AS distinct_order_item_ids,
    @duplicate_rows AS duplicate_rows,
    @load_status AS load_status,
    CASE
        WHEN @rows_inserted = @expected_rows AND @duplicate_rows = 0 THEN 'PASS'
        ELSE 'REVIEW REQUIRED'
    END AS volume_and_uniqueness_check;

SELECT
    COUNT(*) AS batch_rows,
    COUNT(DISTINCT order_item_id) AS distinct_order_item_ids,
    COUNT(DISTINCT order_id) AS distinct_orders,
    COUNT(DISTINCT customer_id) AS distinct_customers,
    MIN(order_date) AS minimum_order_date,
    MAX(order_date) AS maximum_order_date,
    ROUND(SUM(sales), 2) AS total_sales,
    ROUND(SUM(order_profit_per_order), 2) AS total_profit
FROM stg_supply_chain
WHERE load_batch_id = @load_batch_id;

SELECT *
FROM etl_run_log
WHERE etl_run_id = @etl_run_id;

-- Display warnings generated by LOAD DATA, if any.
SHOW WARNINGS LIMIT 100;

-- Date parsing validation.
SELECT
    COUNT(*) AS total_rows,
    COUNT(order_date) AS valid_order_dates,
    SUM(order_date IS NULL) AS null_order_dates,
    COUNT(shipping_date) AS valid_shipping_dates,
    SUM(shipping_date IS NULL) AS null_shipping_dates,
    MIN(order_date) AS minimum_order_date,
    MAX(order_date) AS maximum_order_date,
    MIN(shipping_date) AS minimum_shipping_date,
    MAX(shipping_date) AS maximum_shipping_date
FROM stg_supply_chain;

-- Final staging validation.
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_item_id) AS unique_order_item_ids,
    COUNT(*) - COUNT(DISTINCT order_item_id) AS duplicate_rows,
    CASE
        WHEN COUNT(*) = @expected_rows
         AND COUNT(*) = COUNT(DISTINCT order_item_id)
        THEN 'READY'
        ELSE 'REVIEW REQUIRED'
    END AS staging_status
FROM stg_supply_chain;
