/* ============================================================================
   NEXORA SUPPLY CHAIN ANALYTICS PLATFORM
   File          : 08_load_fact_table.sql
   Purpose       : Load the validated staging dataset into fact_order_item.
   Compatibility : MySQL 8.0+ / MySQL Workbench

   Grain:
   - One row represents one order item.

   Prerequisites:
   - 03_load_csv_header_aligned.sql completed successfully.
   - 04_data_quality_check_final.sql returned READY.
   - 05_create_dimension_tables.sql completed successfully.
   - 06_load_dimension_tables.sql returned READY FOR FACT LOAD.
   - 07_create_fact_table.sql completed successfully.

   Load strategy:
   - Full refresh of fact_order_item.
   - Uses the latest staging load_batch_id.
   - Resolves natural keys to dimension surrogate keys.
   - Falls back to Unknown key 0 only when a dimension cannot be resolved.
   ============================================================================ */

USE nexora_supply_chain;

SET SESSION sql_mode = 'STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION';
SET SESSION time_zone = '+00:00';

-- Preserve and temporarily disable Workbench Safe Updates for ETL operations.
SET @previous_sql_safe_updates = @@SQL_SAFE_UPDATES;
SET SQL_SAFE_UPDATES = 0;

-- ============================================================================
-- 1. IDENTIFY THE LATEST VALID STAGING BATCH
-- ============================================================================
SET @latest_batch_id = (
    SELECT load_batch_id
    FROM stg_supply_chain
    WHERE load_batch_id IS NOT NULL
    ORDER BY loaded_at DESC
    LIMIT 1
);

SET @source_file_name = (
    SELECT source_file_name
    FROM stg_supply_chain
    WHERE load_batch_id = @latest_batch_id
    ORDER BY loaded_at DESC
    LIMIT 1
);

SET @expected_rows = 180519;
SET @started_at = NOW(6);

SELECT
    @latest_batch_id AS latest_batch_id,
    @source_file_name AS source_file_name,
    COUNT(*) AS staging_rows,
    COUNT(DISTINCT order_item_id) AS staging_unique_order_items,
    COUNT(order_date) AS valid_order_dates,
    COUNT(shipping_date) AS valid_shipping_dates
FROM stg_supply_chain
WHERE load_batch_id = @latest_batch_id;

-- ============================================================================
-- 2. PRE-LOAD DIMENSION RESOLUTION CHECK
-- All unresolved counts should be 0 before continuing.
-- ============================================================================
SELECT
    SUM(c.customer_key IS NULL) AS unresolved_customers,
    SUM(p.product_key IS NULL) AS unresolved_products,
    SUM(cat.category_key IS NULL) AS unresolved_categories,
    SUM(od.date_key IS NULL) AS unresolved_order_dates,
    SUM(sd.date_key IS NULL) AS unresolved_shipping_dates,
    SUM(sm.shipping_mode_key IS NULL) AS unresolved_shipping_modes,
    SUM(g.geography_key IS NULL) AS unresolved_geographies,
    CASE
        WHEN
            SUM(c.customer_key IS NULL) = 0
            AND SUM(p.product_key IS NULL) = 0
            AND SUM(cat.category_key IS NULL) = 0
            AND SUM(od.date_key IS NULL) = 0
            AND SUM(sd.date_key IS NULL) = 0
            AND SUM(sm.shipping_mode_key IS NULL) = 0
            AND SUM(g.geography_key IS NULL) = 0
        THEN 'PASS'
        ELSE 'REVIEW BEFORE FACT LOAD'
    END AS dimension_resolution_status
FROM stg_supply_chain AS s
LEFT JOIN dim_customer AS c
    ON c.customer_id = s.customer_id
LEFT JOIN dim_product AS p
    ON p.product_card_id = s.product_card_id
LEFT JOIN dim_category AS cat
    ON cat.category_id = s.category_id
LEFT JOIN dim_date AS od
    ON od.full_date = DATE(s.order_date)
LEFT JOIN dim_date AS sd
    ON sd.full_date = DATE(s.shipping_date)
LEFT JOIN dim_shipping_mode AS sm
    ON sm.shipping_mode = s.shipping_mode
LEFT JOIN dim_geography AS g
    ON g.geography_natural_key = SHA2(
        CONCAT_WS(
            '|',
            COALESCE(TRIM(s.market), 'Unknown'),
            COALESCE(TRIM(s.order_region), 'Unknown'),
            COALESCE(TRIM(s.order_country), 'Unknown'),
            COALESCE(TRIM(s.order_state), 'Unknown'),
            COALESCE(TRIM(s.order_city), 'Unknown'),
            COALESCE(CAST(ROUND(s.latitude, 6) AS CHAR), 'Unknown'),
            COALESCE(CAST(ROUND(s.longitude, 6) AS CHAR), 'Unknown')
        ),
        256
    )
WHERE s.load_batch_id = @latest_batch_id;

-- ============================================================================
-- 3. CREATE ETL AUDIT RECORD
-- ============================================================================
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
    'load_fact_order_item',
    'STARTED',
    @started_at
);

SET @etl_run_id = LAST_INSERT_ID();

-- ============================================================================
-- 4. FULL-REFRESH FACT TABLE
-- ============================================================================
TRUNCATE TABLE fact_order_item;

-- ============================================================================
-- 5. LOAD FACT_ORDER_ITEM
-- ============================================================================
INSERT INTO fact_order_item (
    customer_key,
    product_key,
    category_key,
    order_date_key,
    shipping_date_key,
    shipping_mode_key,
    geography_key,

    order_item_id,
    order_id,
    order_customer_id,
    order_item_cardprod_id,

    payment_type,
    delivery_status,
    order_status,

    order_item_quantity,
    sales,
    sales_per_customer,
    order_item_total,
    order_item_product_price,
    product_price,

    order_item_discount,
    order_item_discount_rate,
    discount_pct_calculated,
    discount_rate_pct,
    gross_sales_before_discount,

    order_profit,
    order_profit_per_order,
    order_item_profit_ratio,
    profit_margin_pct,
    profitability_status,
    is_profitable_item,
    is_loss_item,

    days_for_shipping_real,
    days_for_shipment_scheduled,
    shipping_delay_days,
    absolute_schedule_variance_days,
    shipping_efficiency_ratio,

    late_delivery_risk,
    is_late_delivery,
    is_on_time_delivery,
    delivery_performance,
    delivery_delay_severity,
    shipping_speed_segment,

    order_total_sales,
    order_total_profit,
    order_total_quantity,
    order_item_count,
    order_profit_margin_pct,

    customer_order_count,
    customer_lifetime_sales,
    customer_average_item_sales,
    customer_lifetime_profit,
    customer_tenure_days,
    customer_frequency_segment,

    sales_value_tier,
    margin_band,
    discount_band,
    requires_management_attention,
    operational_risk_segment,

    source_file_name,
    load_batch_id,
    staging_row_id,
    loaded_at
)
SELECT
    COALESCE(c.customer_key, 0) AS customer_key,
    COALESCE(p.product_key, 0) AS product_key,
    COALESCE(cat.category_key, 0) AS category_key,
    COALESCE(od.date_key, 0) AS order_date_key,
    COALESCE(sd.date_key, 0) AS shipping_date_key,
    COALESCE(sm.shipping_mode_key, 0) AS shipping_mode_key,
    COALESCE(g.geography_key, 0) AS geography_key,

    s.order_item_id,
    s.order_id,
    s.order_customer_id,
    s.order_item_cardprod_id,

    s.payment_type,
    s.delivery_status,
    s.order_status,

    s.order_item_quantity,
    s.sales,
    s.sales_per_customer,
    s.order_item_total,
    s.order_item_product_price,
    s.product_price,

    s.order_item_discount,
    s.order_item_discount_rate,
    s.discount_pct_calculated,
    s.discount_rate_pct,
    s.gross_sales_before_discount,

    s.order_profit,
    s.order_profit_per_order,
    s.order_item_profit_ratio,
    s.profit_margin_pct,
    s.profitability_status,
    s.is_profitable_item,
    s.is_loss_item,

    s.days_for_shipping_real,
    s.days_for_shipment_scheduled,
    s.shipping_delay_days,
    s.absolute_schedule_variance_days,
    s.shipping_efficiency_ratio,

    s.late_delivery_risk,
    s.is_late_delivery,
    s.is_on_time_delivery,
    s.delivery_performance,
    s.delivery_delay_severity,
    s.shipping_speed_segment,

    s.order_total_sales,
    s.order_total_profit,
    s.order_total_quantity,
    s.order_item_count,
    s.order_profit_margin_pct,

    s.customer_order_count,
    s.customer_lifetime_sales,
    s.customer_average_item_sales,
    s.customer_lifetime_profit,
    s.customer_tenure_days,
    s.customer_frequency_segment,

    s.sales_value_tier,
    s.margin_band,
    s.discount_band,
    s.requires_management_attention,
    s.operational_risk_segment,

    s.source_file_name,
    s.load_batch_id,
    s.staging_row_id,
    NOW(6) AS loaded_at
FROM stg_supply_chain AS s
LEFT JOIN dim_customer AS c
    ON c.customer_id = s.customer_id
LEFT JOIN dim_product AS p
    ON p.product_card_id = s.product_card_id
LEFT JOIN dim_category AS cat
    ON cat.category_id = s.category_id
LEFT JOIN dim_date AS od
    ON od.full_date = DATE(s.order_date)
LEFT JOIN dim_date AS sd
    ON sd.full_date = DATE(s.shipping_date)
LEFT JOIN dim_shipping_mode AS sm
    ON sm.shipping_mode = s.shipping_mode
LEFT JOIN dim_geography AS g
    ON g.geography_natural_key = SHA2(
        CONCAT_WS(
            '|',
            COALESCE(TRIM(s.market), 'Unknown'),
            COALESCE(TRIM(s.order_region), 'Unknown'),
            COALESCE(TRIM(s.order_country), 'Unknown'),
            COALESCE(TRIM(s.order_state), 'Unknown'),
            COALESCE(TRIM(s.order_city), 'Unknown'),
            COALESCE(CAST(ROUND(s.latitude, 6) AS CHAR), 'Unknown'),
            COALESCE(CAST(ROUND(s.longitude, 6) AS CHAR), 'Unknown')
        ),
        256
    )
WHERE s.load_batch_id = @latest_batch_id;

SET @rows_inserted = ROW_COUNT();

-- ============================================================================
-- 6. CALCULATE POST-LOAD METRICS
-- ============================================================================
SET @fact_rows = (
    SELECT COUNT(*)
    FROM fact_order_item
);

SET @fact_unique_order_items = (
    SELECT COUNT(DISTINCT order_item_id)
    FROM fact_order_item
);

SET @duplicate_rows = @fact_rows - @fact_unique_order_items;

SET @unknown_dimension_keys = (
    SELECT
        SUM(
            customer_key = 0
            OR product_key = 0
            OR category_key = 0
            OR order_date_key = 0
            OR shipping_date_key = 0
            OR shipping_mode_key = 0
            OR geography_key = 0
        )
    FROM fact_order_item
);

SET @load_status = CASE
    WHEN
        @fact_rows = @expected_rows
        AND @fact_unique_order_items = @expected_rows
        AND @duplicate_rows = 0
        AND @unknown_dimension_keys = 0
    THEN 'SUCCESS'
    WHEN @fact_rows > 0
    THEN 'WARNING'
    ELSE 'FAILED'
END;

-- ============================================================================
-- 7. UPDATE ETL AUDIT RECORD
-- ============================================================================
UPDATE etl_run_log
SET
    process_status = @load_status,
    rows_read = @expected_rows,
    rows_inserted = @rows_inserted,
    rows_rejected = @expected_rows - @rows_inserted,
    completed_at = NOW(6),
    error_message = CASE
        WHEN @load_status = 'SUCCESS' THEN NULL
        ELSE CONCAT(
            'fact_rows=', @fact_rows,
            '; unique_order_items=', @fact_unique_order_items,
            '; duplicate_rows=', @duplicate_rows,
            '; rows_with_unknown_dimension_key=', @unknown_dimension_keys
        )
    END
WHERE etl_run_id = @etl_run_id;

-- ============================================================================
-- 8. FACT GRAIN AND VOLUME VALIDATION
-- ============================================================================
SELECT
    COUNT(*) AS fact_rows,
    COUNT(DISTINCT order_item_id) AS unique_order_item_ids,
    COUNT(*) - COUNT(DISTINCT order_item_id) AS duplicate_rows,
    CASE
        WHEN
            COUNT(*) = @expected_rows
            AND COUNT(DISTINCT order_item_id) = @expected_rows
        THEN 'PASS'
        ELSE 'FAIL'
    END AS grain_and_volume_status
FROM fact_order_item;

-- ============================================================================
-- 9. DIMENSION KEY VALIDATION
-- ============================================================================
SELECT
    SUM(customer_key = 0) AS unknown_customer_keys,
    SUM(product_key = 0) AS unknown_product_keys,
    SUM(category_key = 0) AS unknown_category_keys,
    SUM(order_date_key = 0) AS unknown_order_date_keys,
    SUM(shipping_date_key = 0) AS unknown_shipping_date_keys,
    SUM(shipping_mode_key = 0) AS unknown_shipping_mode_keys,
    SUM(geography_key = 0) AS unknown_geography_keys,
    CASE
        WHEN
            SUM(customer_key = 0) = 0
            AND SUM(product_key = 0) = 0
            AND SUM(category_key = 0) = 0
            AND SUM(order_date_key = 0) = 0
            AND SUM(shipping_date_key = 0) = 0
            AND SUM(shipping_mode_key = 0) = 0
            AND SUM(geography_key = 0) = 0
        THEN 'PASS'
        ELSE 'REVIEW'
    END AS dimension_key_status
FROM fact_order_item;

-- ============================================================================
-- 10. FOREIGN-KEY ORPHAN CHECK
-- Expected result: 0 for every orphan count.
-- ============================================================================
SELECT
    SUM(c.customer_key IS NULL) AS orphan_customer_keys,
    SUM(p.product_key IS NULL) AS orphan_product_keys,
    SUM(cat.category_key IS NULL) AS orphan_category_keys,
    SUM(od.date_key IS NULL) AS orphan_order_date_keys,
    SUM(sd.date_key IS NULL) AS orphan_shipping_date_keys,
    SUM(sm.shipping_mode_key IS NULL) AS orphan_shipping_mode_keys,
    SUM(g.geography_key IS NULL) AS orphan_geography_keys
FROM fact_order_item AS f
LEFT JOIN dim_customer AS c
    ON c.customer_key = f.customer_key
LEFT JOIN dim_product AS p
    ON p.product_key = f.product_key
LEFT JOIN dim_category AS cat
    ON cat.category_key = f.category_key
LEFT JOIN dim_date AS od
    ON od.date_key = f.order_date_key
LEFT JOIN dim_date AS sd
    ON sd.date_key = f.shipping_date_key
LEFT JOIN dim_shipping_mode AS sm
    ON sm.shipping_mode_key = f.shipping_mode_key
LEFT JOIN dim_geography AS g
    ON g.geography_key = f.geography_key;

-- ============================================================================
-- 11. STAGING-TO-FACT FINANCIAL RECONCILIATION
-- ============================================================================
SELECT
    s.staging_rows,
    f.fact_rows,
    ROUND(s.staging_sales, 2) AS staging_sales,
    ROUND(f.fact_sales, 2) AS fact_sales,
    ROUND(f.fact_sales - s.staging_sales, 2) AS sales_difference,
    ROUND(s.staging_profit, 2) AS staging_profit,
    ROUND(f.fact_profit, 2) AS fact_profit,
    ROUND(f.fact_profit - s.staging_profit, 2) AS profit_difference,
    CASE
        WHEN
            s.staging_rows = f.fact_rows
            AND ABS(f.fact_sales - s.staging_sales) <= 0.01
            AND ABS(f.fact_profit - s.staging_profit) <= 0.01
        THEN 'PASS'
        ELSE 'FAIL'
    END AS reconciliation_status
FROM (
    SELECT
        COUNT(*) AS staging_rows,
        SUM(sales) AS staging_sales,
        SUM(order_profit_per_order) AS staging_profit
    FROM stg_supply_chain
    WHERE load_batch_id = @latest_batch_id
) AS s
CROSS JOIN (
    SELECT
        COUNT(*) AS fact_rows,
        SUM(sales) AS fact_sales,
        SUM(order_profit_per_order) AS fact_profit
    FROM fact_order_item
) AS f;

-- ============================================================================
-- 12. BUSINESS SUMMARY
-- ============================================================================
SELECT
    COUNT(*) AS order_item_rows,
    COUNT(DISTINCT order_id) AS distinct_orders,
    COUNT(DISTINCT customer_key) AS represented_customer_keys,
    COUNT(DISTINCT product_key) AS represented_product_keys,
    COUNT(DISTINCT category_key) AS represented_category_keys,
    ROUND(SUM(sales), 2) AS total_sales,
    ROUND(SUM(order_profit_per_order), 2) AS total_profit,
    ROUND(
        SUM(order_profit_per_order)
        / NULLIF(SUM(sales), 0)
        * 100,
        2
    ) AS overall_profit_margin_pct,
    ROUND(AVG(days_for_shipping_real), 2)
        AS average_actual_shipping_days,
    ROUND(AVG(is_late_delivery) * 100, 2)
        AS late_delivery_rate_pct
FROM fact_order_item;

-- ============================================================================
-- 13. SAMPLE STAR-SCHEMA JOIN
-- ============================================================================
SELECT
    f.order_item_id,
    f.order_id,
    od.full_date AS order_date,
    sd.full_date AS shipping_date,
    c.customer_segment,
    p.product_name,
    cat.category_name,
    sm.shipping_mode,
    g.market,
    g.order_country,
    f.sales,
    f.order_profit_per_order,
    f.is_late_delivery
FROM fact_order_item AS f
JOIN dim_customer AS c
    ON c.customer_key = f.customer_key
JOIN dim_product AS p
    ON p.product_key = f.product_key
JOIN dim_category AS cat
    ON cat.category_key = f.category_key
JOIN dim_date AS od
    ON od.date_key = f.order_date_key
JOIN dim_date AS sd
    ON sd.date_key = f.shipping_date_key
JOIN dim_shipping_mode AS sm
    ON sm.shipping_mode_key = f.shipping_mode_key
JOIN dim_geography AS g
    ON g.geography_key = f.geography_key
ORDER BY f.fact_order_item_key
LIMIT 20;

-- ============================================================================
-- 14. FINAL FACT-LOAD DECISION
-- ============================================================================
SELECT
    @fact_rows AS fact_rows,
    @fact_unique_order_items AS unique_order_item_ids,
    @duplicate_rows AS duplicate_rows,
    @unknown_dimension_keys AS rows_with_unknown_dimension_key,
    @load_status AS etl_status,
    CASE
        WHEN
            @fact_rows = @expected_rows
            AND @fact_unique_order_items = @expected_rows
            AND @duplicate_rows = 0
            AND @unknown_dimension_keys = 0
        THEN 'FACT LOAD COMPLETE'
        ELSE 'REVIEW FACT LOAD'
    END AS final_fact_readiness;

SELECT *
FROM etl_run_log
WHERE etl_run_id = @etl_run_id;

-- Restore the previous Safe Updates setting.
SET SQL_SAFE_UPDATES = @previous_sql_safe_updates;
