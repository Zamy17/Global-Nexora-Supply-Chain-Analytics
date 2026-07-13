/* ============================================================================
   NEXORA SUPPLY CHAIN ANALYTICS PLATFORM
   File          : 07_create_fact_table.sql
   Purpose       : Create the central order-item fact table for the star schema.
   Compatibility : MySQL 8.0+ / MySQL Workbench

   Grain:
   - One row represents one order item.

   Required dimensions:
   - dim_customer
   - dim_product
   - dim_category
   - dim_date
   - dim_shipping_mode
   - dim_geography

   IMPORTANT:
   - Run 06_load_dimension_tables.sql first.
   - This script recreates fact_order_item.
   - It does not modify staging or dimension tables.
   ============================================================================ */

USE nexora_supply_chain;

SET SESSION sql_mode =
    'STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION';

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS fact_order_item;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================================
-- 1. CREATE FACT TABLE
-- ============================================================================
CREATE TABLE fact_order_item (
    fact_order_item_key BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    -- Dimension surrogate keys
    customer_key BIGINT UNSIGNED NOT NULL DEFAULT 0,
    product_key BIGINT UNSIGNED NOT NULL DEFAULT 0,
    category_key INT UNSIGNED NOT NULL DEFAULT 0,
    order_date_key INT NOT NULL DEFAULT 0,
    shipping_date_key INT NOT NULL DEFAULT 0,
    shipping_mode_key SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    geography_key BIGINT UNSIGNED NOT NULL DEFAULT 0,

    -- Degenerate dimensions / operational identifiers
    order_item_id BIGINT NOT NULL,
    order_id BIGINT NOT NULL,
    order_customer_id BIGINT NULL,
    order_item_cardprod_id BIGINT NULL,

    payment_type VARCHAR(50) NULL,
    delivery_status VARCHAR(50) NULL,
    order_status VARCHAR(50) NULL,

    -- Quantity and commercial measures
    order_item_quantity INT NULL,
    sales DECIMAL(18,4) NULL,
    sales_per_customer DECIMAL(18,4) NULL,
    order_item_total DECIMAL(18,4) NULL,
    order_item_product_price DECIMAL(18,4) NULL,
    product_price DECIMAL(18,4) NULL,

    order_item_discount DECIMAL(18,4) NULL,
    order_item_discount_rate DECIMAL(12,6) NULL,
    discount_pct_calculated DECIMAL(18,6) NULL,
    discount_rate_pct DECIMAL(18,6) NULL,
    gross_sales_before_discount DECIMAL(18,4) NULL,

    -- Profitability measures
    order_profit DECIMAL(18,4) NULL,
    order_profit_per_order DECIMAL(18,4) NULL,
    order_item_profit_ratio DECIMAL(18,6) NULL,
    profit_margin_pct DECIMAL(18,6) NULL,
    profitability_status VARCHAR(30) NULL,
    is_profitable_item TINYINT NULL,
    is_loss_item TINYINT NULL,

    -- Shipping and delivery measures
    days_for_shipping_real SMALLINT NULL,
    days_for_shipment_scheduled SMALLINT NULL,
    shipping_delay_days SMALLINT NULL,
    absolute_schedule_variance_days SMALLINT NULL,
    shipping_efficiency_ratio DECIMAL(18,6) NULL,

    late_delivery_risk TINYINT NULL,
    is_late_delivery TINYINT NULL,
    is_on_time_delivery TINYINT NULL,
    delivery_performance VARCHAR(30) NULL,
    delivery_delay_severity VARCHAR(30) NULL,
    shipping_speed_segment VARCHAR(30) NULL,

    -- Order-level engineered measures
    order_total_sales DECIMAL(20,4) NULL,
    order_total_profit DECIMAL(20,4) NULL,
    order_total_quantity INT NULL,
    order_item_count INT NULL,
    order_profit_margin_pct DECIMAL(18,6) NULL,

    -- Customer-level engineered measures
    customer_order_count INT NULL,
    customer_lifetime_sales DECIMAL(20,4) NULL,
    customer_average_item_sales DECIMAL(18,4) NULL,
    customer_lifetime_profit DECIMAL(20,4) NULL,
    customer_tenure_days INT NULL,
    customer_frequency_segment VARCHAR(30) NULL,

    -- Segmentation and risk flags
    sales_value_tier VARCHAR(20) NULL,
    margin_band VARCHAR(20) NULL,
    discount_band VARCHAR(20) NULL,
    requires_management_attention TINYINT NULL,
    operational_risk_segment VARCHAR(30) NULL,

    -- Source audit fields
    source_file_name VARCHAR(255) NULL,
    load_batch_id VARCHAR(64) NULL,
    staging_row_id BIGINT UNSIGNED NULL,
    loaded_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),

    PRIMARY KEY (fact_order_item_key),

    -- Enforce the declared fact grain.
    UNIQUE KEY uk_fact_order_item_order_item_id (order_item_id),

    -- Foreign-key indexes
    KEY idx_fact_customer_key (customer_key),
    KEY idx_fact_product_key (product_key),
    KEY idx_fact_category_key (category_key),
    KEY idx_fact_order_date_key (order_date_key),
    KEY idx_fact_shipping_date_key (shipping_date_key),
    KEY idx_fact_shipping_mode_key (shipping_mode_key),
    KEY idx_fact_geography_key (geography_key),

    -- Frequently used analytical indexes
    KEY idx_fact_order_id (order_id),
    KEY idx_fact_load_batch_id (load_batch_id),
    KEY idx_fact_delivery_status (delivery_status),
    KEY idx_fact_order_status (order_status),
    KEY idx_fact_late_delivery (is_late_delivery),
    KEY idx_fact_profitability_status (profitability_status),
    KEY idx_fact_operational_risk (operational_risk_segment),

    CONSTRAINT fk_fact_customer
        FOREIGN KEY (customer_key)
        REFERENCES dim_customer (customer_key),

    CONSTRAINT fk_fact_product
        FOREIGN KEY (product_key)
        REFERENCES dim_product (product_key),

    CONSTRAINT fk_fact_category
        FOREIGN KEY (category_key)
        REFERENCES dim_category (category_key),

    CONSTRAINT fk_fact_order_date
        FOREIGN KEY (order_date_key)
        REFERENCES dim_date (date_key),

    CONSTRAINT fk_fact_shipping_date
        FOREIGN KEY (shipping_date_key)
        REFERENCES dim_date (date_key),

    CONSTRAINT fk_fact_shipping_mode
        FOREIGN KEY (shipping_mode_key)
        REFERENCES dim_shipping_mode (shipping_mode_key),

    CONSTRAINT fk_fact_geography
        FOREIGN KEY (geography_key)
        REFERENCES dim_geography (geography_key),

    CONSTRAINT chk_fact_order_item_quantity
        CHECK (
            order_item_quantity IS NULL
            OR order_item_quantity > 0
        ),

    CONSTRAINT chk_fact_late_delivery
        CHECK (
            is_late_delivery IS NULL
            OR is_late_delivery IN (0, 1)
        ),

    CONSTRAINT chk_fact_on_time_delivery
        CHECK (
            is_on_time_delivery IS NULL
            OR is_on_time_delivery IN (0, 1)
        ),

    CONSTRAINT chk_fact_profitable_item
        CHECK (
            is_profitable_item IS NULL
            OR is_profitable_item IN (0, 1)
        ),

    CONSTRAINT chk_fact_loss_item
        CHECK (
            is_loss_item IS NULL
            OR is_loss_item IN (0, 1)
        ),

    CONSTRAINT chk_fact_management_attention
        CHECK (
            requires_management_attention IS NULL
            OR requires_management_attention IN (0, 1)
        )
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Order-item fact table; one row represents one order item';

-- ============================================================================
-- 2. STRUCTURE VALIDATION
-- ============================================================================
SELECT
    table_name,
    engine,
    table_collation,
    table_comment
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name = 'fact_order_item';

SELECT
    ordinal_position,
    column_name,
    column_type,
    is_nullable,
    column_key,
    column_default
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND table_name = 'fact_order_item'
ORDER BY ordinal_position;

-- ============================================================================
-- 3. FOREIGN-KEY VALIDATION
-- ============================================================================
SELECT
    constraint_name,
    column_name,
    referenced_table_name,
    referenced_column_name
FROM information_schema.key_column_usage
WHERE table_schema = DATABASE()
  AND table_name = 'fact_order_item'
  AND referenced_table_name IS NOT NULL
ORDER BY constraint_name;

-- ============================================================================
-- 4. FACT GRAIN VALIDATION
-- ============================================================================
SELECT
    index_name,
    non_unique,
    GROUP_CONCAT(
        column_name
        ORDER BY seq_in_index
        SEPARATOR ', '
    ) AS indexed_columns
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND table_name = 'fact_order_item'
GROUP BY index_name, non_unique
ORDER BY
    CASE WHEN index_name = 'PRIMARY' THEN 0 ELSE 1 END,
    index_name;

-- ============================================================================
-- 5. INITIAL ROW COUNT
-- Expected result: 0 before running 08_load_fact_table.sql
-- ============================================================================
SELECT
    COUNT(*) AS fact_rows,
    CASE
        WHEN COUNT(*) = 0 THEN 'READY FOR FACT LOAD'
        ELSE 'REVIEW EXISTING FACT DATA'
    END AS fact_table_status
FROM fact_order_item;
