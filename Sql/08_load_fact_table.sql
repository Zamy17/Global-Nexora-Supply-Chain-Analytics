/* ============================================================================
   NEXORA SUPPLY CHAIN ANALYTICS PLATFORM
   File          : 08_load_fact_table.sql
   Purpose       : Load the central order-item fact table from staging.
   Compatibility : MySQL 8.0+ / MySQL Workbench

   FACT GRAIN
   One row = one source order_item_id.

   ETL CHARACTERISTICS
   - Idempotent: rerunning updates existing order-item facts.
   - Dimension lookup failures resolve to Unknown key 0.
   - Duplicate staging order_item_id values are deduplicated using the latest
     staging row.
   - Source-to-target row counts and surrogate-key coverage are validated.
   ============================================================================ */

USE nexora_supply_chain;

SET SESSION sql_mode =
    'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

SET @fact_load_started_at = NOW(6);

/* ---------------------------------------------------------------------------
   1. PRE-LOAD VALIDATION
   --------------------------------------------------------------------------- */
SELECT
    'staging_rows' AS metric,
    COUNT(*) AS metric_value
FROM stg_supply_chain

UNION ALL

SELECT
    'staging_distinct_order_item_id',
    COUNT(DISTINCT order_item_id)
FROM stg_supply_chain
WHERE order_item_id IS NOT NULL

UNION ALL

SELECT
    'staging_null_order_item_id',
    COUNT(*)
FROM stg_supply_chain
WHERE order_item_id IS NULL

UNION ALL

SELECT
    'duplicate_order_item_id_groups',
    COUNT(*)
FROM (
    SELECT order_item_id
    FROM stg_supply_chain
    WHERE order_item_id IS NOT NULL
    GROUP BY order_item_id
    HAVING COUNT(*) > 1
) AS duplicate_groups;

/* Every dimension must contain the Unknown member key 0. */
SELECT
    'dim_customer' AS dimension_name,
    SUM(customer_key = 0) AS unknown_member_count
FROM dim_customer
UNION ALL
SELECT 'dim_product', SUM(product_key = 0) FROM dim_product
UNION ALL
SELECT 'dim_category', SUM(category_key = 0) FROM dim_category
UNION ALL
SELECT 'dim_date', SUM(date_key = 0) FROM dim_date
UNION ALL
SELECT 'dim_shipping_mode', SUM(shipping_mode_key = 0) FROM dim_shipping_mode
UNION ALL
SELECT 'dim_geography', SUM(geography_key = 0) FROM dim_geography;

/* ---------------------------------------------------------------------------
   2. START ETL AUDIT
   --------------------------------------------------------------------------- */
INSERT INTO etl_run_log (
    pipeline_name,
    source_file_name,
    process_name,
    process_status,
    rows_read,
    started_at
)
SELECT
    'nexora_supply_chain_pipeline',
    COALESCE(MAX(source_file_name), 'stg_supply_chain'),
    'load_fact_order_item',
    'STARTED',
    COUNT(*),
    @fact_load_started_at
FROM stg_supply_chain;

SET @etl_run_id = LAST_INSERT_ID();

START TRANSACTION;

/* ---------------------------------------------------------------------------
   3. LOAD FACT TABLE
   The latest staging record wins when duplicate order_item_id values exist.
   --------------------------------------------------------------------------- */
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
    order_status,
    delivery_status,
    delivery_performance,
    profitability_status,
    operational_risk_segment,

    order_item_quantity,
    sales,
    gross_sales_before_discount,
    order_item_discount,
    order_item_discount_rate,
    discount_rate_pct,
    discount_pct_calculated,
    order_item_product_price,
    order_item_total,
    order_profit,
    order_profit_per_order,
    order_item_profit_ratio,
    profit_margin_pct,

    days_for_shipping_real,
    days_for_shipment_scheduled,
    shipping_delay_days,
    absolute_schedule_variance_days,
    shipping_efficiency_ratio,

    late_delivery_risk,
    is_late_delivery,
    is_on_time_delivery,
    is_profitable_item,
    is_loss_item,
    requires_management_attention,

    delivery_delay_severity,
    shipping_speed_segment,
    sales_value_tier,
    margin_band,
    discount_band,

    order_total_sales,
    order_total_profit,
    order_total_quantity,
    order_item_count,
    order_profit_margin_pct,

    source_staging_row_id,
    source_file_name,
    load_batch_id,
    warehouse_loaded_at
)
SELECT
    COALESCE(dc.customer_key, 0) AS customer_key,
    COALESCE(dp.product_key, 0) AS product_key,
    COALESCE(dcat.category_key, 0) AS category_key,
    COALESCE(dod.date_key, 0) AS order_date_key,
    COALESCE(dsd.date_key, 0) AS shipping_date_key,
    COALESCE(dsm.shipping_mode_key, 0) AS shipping_mode_key,
    COALESCE(dg.geography_key, 0) AS geography_key,

    src.order_item_id,
    src.order_id,
    src.order_customer_id,
    src.order_item_cardprod_id,

    src.payment_type,
    src.order_status,
    src.delivery_status,
    src.delivery_performance,
    src.profitability_status,
    src.operational_risk_segment,

    src.order_item_quantity,
    src.sales,
    src.gross_sales_before_discount,
    src.order_item_discount,
    src.order_item_discount_rate,
    src.discount_rate_pct,
    src.discount_pct_calculated,
    src.order_item_product_price,
    src.order_item_total,
    src.order_profit,
    src.order_profit_per_order,
    src.order_item_profit_ratio,
    src.profit_margin_pct,

    src.days_for_shipping_real,
    src.days_for_shipment_scheduled,
    src.shipping_delay_days,
    src.absolute_schedule_variance_days,
    src.shipping_efficiency_ratio,

    src.late_delivery_risk,
    src.is_late_delivery,
    src.is_on_time_delivery,
    src.is_profitable_item,
    src.is_loss_item,
    src.requires_management_attention,

    src.delivery_delay_severity,
    src.shipping_speed_segment,
    src.sales_value_tier,
    src.margin_band,
    src.discount_band,

    src.order_total_sales,
    src.order_total_profit,
    src.order_total_quantity,
    src.order_item_count,
    src.order_profit_margin_pct,

    src.staging_row_id,
    src.source_file_name,
    src.load_batch_id,
    NOW(6)
FROM (
    SELECT ranked.*
    FROM (
        SELECT
            s.*,
            ROW_NUMBER() OVER (
                PARTITION BY s.order_item_id
                ORDER BY s.loaded_at DESC, s.staging_row_id DESC
            ) AS rn
        FROM stg_supply_chain AS s
        WHERE s.order_item_id IS NOT NULL
    ) AS ranked
    WHERE ranked.rn = 1
) AS src

LEFT JOIN dim_customer AS dc
    ON dc.customer_id = src.customer_id

LEFT JOIN dim_product AS dp
    ON dp.product_card_id = src.product_card_id

LEFT JOIN dim_category AS dcat
    ON dcat.category_id = src.category_id

LEFT JOIN dim_date AS dod
    ON dod.date_key = COALESCE(
        src.order_date_key,
        CAST(DATE_FORMAT(src.order_date, '%Y%m%d') AS UNSIGNED)
    )

LEFT JOIN dim_date AS dsd
    ON dsd.date_key = COALESCE(
        src.shipping_date_key,
        CAST(DATE_FORMAT(src.shipping_date, '%Y%m%d') AS UNSIGNED)
    )

LEFT JOIN dim_shipping_mode AS dsm
    ON dsm.shipping_mode = NULLIF(TRIM(src.shipping_mode), '')

LEFT JOIN dim_geography AS dg
    ON dg.geography_hash = SHA2(
        CONCAT_WS(
            '|',
            COALESCE(NULLIF(TRIM(src.market), ''), 'Unknown'),
            COALESCE(NULLIF(TRIM(src.order_region), ''), 'Unknown'),
            COALESCE(NULLIF(TRIM(src.order_country), ''), 'Unknown'),
            COALESCE(NULLIF(TRIM(src.order_state), ''), 'Unknown'),
            COALESCE(NULLIF(TRIM(src.order_city), ''), 'Unknown')
        ),
        256
    )

ON DUPLICATE KEY UPDATE
    customer_key = VALUES(customer_key),
    product_key = VALUES(product_key),
    category_key = VALUES(category_key),
    order_date_key = VALUES(order_date_key),
    shipping_date_key = VALUES(shipping_date_key),
    shipping_mode_key = VALUES(shipping_mode_key),
    geography_key = VALUES(geography_key),

    order_id = VALUES(order_id),
    order_customer_id = VALUES(order_customer_id),
    order_item_cardprod_id = VALUES(order_item_cardprod_id),

    payment_type = VALUES(payment_type),
    order_status = VALUES(order_status),
    delivery_status = VALUES(delivery_status),
    delivery_performance = VALUES(delivery_performance),
    profitability_status = VALUES(profitability_status),
    operational_risk_segment = VALUES(operational_risk_segment),

    order_item_quantity = VALUES(order_item_quantity),
    sales = VALUES(sales),
    gross_sales_before_discount = VALUES(gross_sales_before_discount),
    order_item_discount = VALUES(order_item_discount),
    order_item_discount_rate = VALUES(order_item_discount_rate),
    discount_rate_pct = VALUES(discount_rate_pct),
    discount_pct_calculated = VALUES(discount_pct_calculated),
    order_item_product_price = VALUES(order_item_product_price),
    order_item_total = VALUES(order_item_total),
    order_profit = VALUES(order_profit),
    order_profit_per_order = VALUES(order_profit_per_order),
    order_item_profit_ratio = VALUES(order_item_profit_ratio),
    profit_margin_pct = VALUES(profit_margin_pct),

    days_for_shipping_real = VALUES(days_for_shipping_real),
    days_for_shipment_scheduled = VALUES(days_for_shipment_scheduled),
    shipping_delay_days = VALUES(shipping_delay_days),
    absolute_schedule_variance_days = VALUES(absolute_schedule_variance_days),
    shipping_efficiency_ratio = VALUES(shipping_efficiency_ratio),

    late_delivery_risk = VALUES(late_delivery_risk),
    is_late_delivery = VALUES(is_late_delivery),
    is_on_time_delivery = VALUES(is_on_time_delivery),
    is_profitable_item = VALUES(is_profitable_item),
    is_loss_item = VALUES(is_loss_item),
    requires_management_attention = VALUES(requires_management_attention),

    delivery_delay_severity = VALUES(delivery_delay_severity),
    shipping_speed_segment = VALUES(shipping_speed_segment),
    sales_value_tier = VALUES(sales_value_tier),
    margin_band = VALUES(margin_band),
    discount_band = VALUES(discount_band),

    order_total_sales = VALUES(order_total_sales),
    order_total_profit = VALUES(order_total_profit),
    order_total_quantity = VALUES(order_total_quantity),
    order_item_count = VALUES(order_item_count),
    order_profit_margin_pct = VALUES(order_profit_margin_pct),

    source_staging_row_id = VALUES(source_staging_row_id),
    source_file_name = VALUES(source_file_name),
    load_batch_id = VALUES(load_batch_id),
    warehouse_updated_at = CURRENT_TIMESTAMP(6);

SET @fact_etl_activity_rows = ROW_COUNT();

COMMIT;

/* ---------------------------------------------------------------------------
   4. POST-LOAD METRICS
   --------------------------------------------------------------------------- */
SET @staging_valid_rows = (
    SELECT COUNT(DISTINCT order_item_id)
    FROM stg_supply_chain
    WHERE order_item_id IS NOT NULL
);

SET @fact_total_rows = (
    SELECT COUNT(*)
    FROM fact_order_item
);

SET @fact_rejected_rows = (
    SELECT COUNT(*)
    FROM stg_supply_chain
    WHERE order_item_id IS NULL
);

UPDATE etl_run_log
SET
    process_status = CASE
        WHEN @fact_total_rows = @staging_valid_rows THEN 'SUCCESS'
        ELSE 'WARNING'
    END,
    rows_read = (SELECT COUNT(*) FROM stg_supply_chain),
    rows_inserted = @fact_total_rows,
    rows_rejected = @fact_rejected_rows,
    completed_at = NOW(6),
    error_message = CASE
        WHEN @fact_total_rows = @staging_valid_rows THEN NULL
        ELSE CONCAT(
            'Expected ',
            @staging_valid_rows,
            ' distinct non-null order_item_id rows but fact contains ',
            @fact_total_rows,
            ' rows.'
        )
    END
WHERE etl_run_id = @etl_run_id;

/* ---------------------------------------------------------------------------
   5. ROW-COUNT RECONCILIATION
   Expected target for this dataset is approximately 180,519 rows.
   --------------------------------------------------------------------------- */
SELECT
    (SELECT COUNT(*) FROM stg_supply_chain) AS staging_rows,
    (SELECT COUNT(DISTINCT order_item_id)
     FROM stg_supply_chain
     WHERE order_item_id IS NOT NULL) AS expected_fact_rows,
    (SELECT COUNT(*) FROM fact_order_item) AS actual_fact_rows,
    (SELECT COUNT(*)
     FROM stg_supply_chain
     WHERE order_item_id IS NULL) AS rejected_null_business_keys,
    CASE
        WHEN
            (SELECT COUNT(*) FROM fact_order_item)
            =
            (SELECT COUNT(DISTINCT order_item_id)
             FROM stg_supply_chain
             WHERE order_item_id IS NOT NULL)
        THEN 'PASS'
        ELSE 'FAIL'
    END AS reconciliation_status;

/* ---------------------------------------------------------------------------
   6. FOREIGN-KEY AND UNKNOWN-MEMBER COVERAGE
   Key 0 is valid, but high counts indicate unresolved dimension lookups.
   --------------------------------------------------------------------------- */
SELECT
    'customer_key' AS dimension_key,
    SUM(customer_key = 0) AS unknown_rows,
    ROUND(SUM(customer_key = 0) / NULLIF(COUNT(*), 0) * 100, 4) AS unknown_pct
FROM fact_order_item

UNION ALL

SELECT
    'product_key',
    SUM(product_key = 0),
    ROUND(SUM(product_key = 0) / NULLIF(COUNT(*), 0) * 100, 4)
FROM fact_order_item

UNION ALL

SELECT
    'category_key',
    SUM(category_key = 0),
    ROUND(SUM(category_key = 0) / NULLIF(COUNT(*), 0) * 100, 4)
FROM fact_order_item

UNION ALL

SELECT
    'order_date_key',
    SUM(order_date_key = 0),
    ROUND(SUM(order_date_key = 0) / NULLIF(COUNT(*), 0) * 100, 4)
FROM fact_order_item

UNION ALL

SELECT
    'shipping_date_key',
    SUM(shipping_date_key = 0),
    ROUND(SUM(shipping_date_key = 0) / NULLIF(COUNT(*), 0) * 100, 4)
FROM fact_order_item

UNION ALL

SELECT
    'shipping_mode_key',
    SUM(shipping_mode_key = 0),
    ROUND(SUM(shipping_mode_key = 0) / NULLIF(COUNT(*), 0) * 100, 4)
FROM fact_order_item

UNION ALL

SELECT
    'geography_key',
    SUM(geography_key = 0),
    ROUND(SUM(geography_key = 0) / NULLIF(COUNT(*), 0) * 100, 4)
FROM fact_order_item;

/* ---------------------------------------------------------------------------
   7. BUSINESS-MEASURE RECONCILIATION
   Small differences may occur only from decimal rounding.
   --------------------------------------------------------------------------- */
SELECT
    'sales' AS metric,
    ROUND((SELECT SUM(sales) FROM stg_supply_chain), 4) AS staging_value,
    ROUND((SELECT SUM(sales) FROM fact_order_item), 4) AS fact_value,
    ROUND(
        (SELECT SUM(sales) FROM fact_order_item)
        -
        (SELECT SUM(sales) FROM stg_supply_chain),
        4
    ) AS difference

UNION ALL

SELECT
    'order_profit',
    ROUND((SELECT SUM(order_profit) FROM stg_supply_chain), 4),
    ROUND((SELECT SUM(order_profit) FROM fact_order_item), 4),
    ROUND(
        (SELECT SUM(order_profit) FROM fact_order_item)
        -
        (SELECT SUM(order_profit) FROM stg_supply_chain),
        4
    )

UNION ALL

SELECT
    'order_item_discount',
    ROUND((SELECT SUM(order_item_discount) FROM stg_supply_chain), 4),
    ROUND((SELECT SUM(order_item_discount) FROM fact_order_item), 4),
    ROUND(
        (SELECT SUM(order_item_discount) FROM fact_order_item)
        -
        (SELECT SUM(order_item_discount) FROM stg_supply_chain),
        4
    )

UNION ALL

SELECT
    'order_item_quantity',
    ROUND((SELECT SUM(order_item_quantity) FROM stg_supply_chain), 4),
    ROUND((SELECT SUM(order_item_quantity) FROM fact_order_item), 4),
    ROUND(
        (SELECT SUM(order_item_quantity) FROM fact_order_item)
        -
        (SELECT SUM(order_item_quantity) FROM stg_supply_chain),
        4
    );

/* ---------------------------------------------------------------------------
   8. DUPLICATE AND REFERENTIAL-INTEGRITY CHECKS
   All results should be zero.
   --------------------------------------------------------------------------- */
SELECT
    'duplicate_order_item_id_groups' AS check_name,
    COUNT(*) AS failed_groups
FROM (
    SELECT order_item_id
    FROM fact_order_item
    GROUP BY order_item_id
    HAVING COUNT(*) > 1
) AS duplicate_fact_items

UNION ALL

SELECT
    'orphan_customer_keys',
    COUNT(*)
FROM fact_order_item AS f
LEFT JOIN dim_customer AS d
    ON d.customer_key = f.customer_key
WHERE d.customer_key IS NULL

UNION ALL

SELECT
    'orphan_product_keys',
    COUNT(*)
FROM fact_order_item AS f
LEFT JOIN dim_product AS d
    ON d.product_key = f.product_key
WHERE d.product_key IS NULL

UNION ALL

SELECT
    'orphan_category_keys',
    COUNT(*)
FROM fact_order_item AS f
LEFT JOIN dim_category AS d
    ON d.category_key = f.category_key
WHERE d.category_key IS NULL

UNION ALL

SELECT
    'orphan_order_date_keys',
    COUNT(*)
FROM fact_order_item AS f
LEFT JOIN dim_date AS d
    ON d.date_key = f.order_date_key
WHERE d.date_key IS NULL

UNION ALL

SELECT
    'orphan_shipping_date_keys',
    COUNT(*)
FROM fact_order_item AS f
LEFT JOIN dim_date AS d
    ON d.date_key = f.shipping_date_key
WHERE d.date_key IS NULL

UNION ALL

SELECT
    'orphan_shipping_mode_keys',
    COUNT(*)
FROM fact_order_item AS f
LEFT JOIN dim_shipping_mode AS d
    ON d.shipping_mode_key = f.shipping_mode_key
WHERE d.shipping_mode_key IS NULL

UNION ALL

SELECT
    'orphan_geography_keys',
    COUNT(*)
FROM fact_order_item AS f
LEFT JOIN dim_geography AS d
    ON d.geography_key = f.geography_key
WHERE d.geography_key IS NULL;

/* ---------------------------------------------------------------------------
   9. FINAL READINESS STATUS
   --------------------------------------------------------------------------- */
SELECT
    COUNT(*) AS fact_rows,
    COUNT(DISTINCT order_item_id) AS distinct_order_item_ids,
    COUNT(DISTINCT order_id) AS distinct_orders,
    ROUND(SUM(sales), 2) AS total_sales,
    ROUND(SUM(order_profit), 2) AS total_profit,
    ROUND(AVG(is_late_delivery) * 100, 2) AS late_delivery_rate_pct,
    CASE
        WHEN COUNT(*) = COUNT(DISTINCT order_item_id)
         AND COUNT(*) >= 180000
         AND SUM(customer_key = 0) = 0
         AND SUM(product_key = 0) = 0
         AND SUM(category_key = 0) = 0
         AND SUM(order_date_key = 0) = 0
         AND SUM(shipping_date_key = 0) = 0
         AND SUM(shipping_mode_key = 0) = 0
         AND SUM(geography_key = 0) = 0
        THEN 'READY'
        WHEN COUNT(*) = COUNT(DISTINCT order_item_id)
         AND COUNT(*) >= 180000
        THEN 'READY WITH WARNINGS'
        ELSE 'NOT READY'
    END AS fact_readiness_status
FROM fact_order_item;

/* Latest ETL audit record. */
SELECT *
FROM etl_run_log
WHERE etl_run_id = @etl_run_id;
