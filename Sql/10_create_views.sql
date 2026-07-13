/* ============================================================================
   NEXORA SUPPLY CHAIN ANALYTICS PLATFORM
   File          : 10_create_views.sql
   Purpose       : Create the business intelligence view layer.
   Compatibility : MySQL 8.0+ / MySQL Workbench

   Prerequisites:
   - 08_load_fact_table.sql completed successfully.
   - 09_create_indexes.sql completed successfully.

   Main use cases:
   - Tableau dashboards
   - Power BI dashboards
   - Streamlit analytics
   - Business SQL analysis
   ============================================================================ */

USE nexora_supply_chain;

SET SESSION sql_mode = 'STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION';

-- ============================================================================
-- 1. EXECUTIVE OVERVIEW
-- ============================================================================
CREATE OR REPLACE VIEW vw_executive_overview AS
SELECT
    COUNT(*) AS total_order_items,
    COUNT(DISTINCT f.order_id) AS total_orders,
    COUNT(DISTINCT f.customer_key) AS total_customers,
    COUNT(DISTINCT f.product_key) AS total_products,
    COUNT(DISTINCT f.category_key) AS total_categories,

    ROUND(SUM(f.sales), 2) AS total_sales,
    ROUND(SUM(f.order_profit_per_order), 2) AS total_profit,
    ROUND(
        SUM(f.order_profit_per_order)
        / NULLIF(SUM(f.sales), 0) * 100,
        2
    ) AS overall_profit_margin_pct,

    ROUND(
        SUM(f.sales)
        / NULLIF(COUNT(DISTINCT f.order_id), 0),
        2
    ) AS average_order_value,

    ROUND(AVG(f.order_item_quantity), 2)
        AS average_item_quantity,

    ROUND(AVG(f.days_for_shipping_real), 2)
        AS average_actual_shipping_days,

    ROUND(AVG(f.days_for_shipment_scheduled), 2)
        AS average_scheduled_shipping_days,

    ROUND(AVG(f.shipping_delay_days), 2)
        AS average_shipping_delay_days,

    ROUND(AVG(f.is_late_delivery) * 100, 2)
        AS late_delivery_rate_pct,

    ROUND(AVG(f.is_on_time_delivery) * 100, 2)
        AS on_time_delivery_rate_pct,

    ROUND(AVG(f.is_loss_item) * 100, 2)
        AS loss_item_rate_pct,

    ROUND(
        AVG(f.requires_management_attention) * 100,
        2
    ) AS management_attention_rate_pct
FROM fact_order_item AS f;

-- ============================================================================
-- 2. MONTHLY SALES TREND
-- ============================================================================
CREATE OR REPLACE VIEW vw_monthly_sales_trend AS
SELECT
    d.calendar_year,
    d.calendar_month,
    d.month_name,
    d.calendar_year_month,

    COUNT(*) AS order_item_rows,
    COUNT(DISTINCT f.order_id) AS total_orders,
    COUNT(DISTINCT f.customer_key) AS total_customers,

    ROUND(SUM(f.sales), 2) AS total_sales,
    ROUND(SUM(f.order_profit_per_order), 2) AS total_profit,

    ROUND(
        SUM(f.order_profit_per_order)
        / NULLIF(SUM(f.sales), 0) * 100,
        2
    ) AS profit_margin_pct,

    ROUND(
        SUM(f.sales)
        / NULLIF(COUNT(DISTINCT f.order_id), 0),
        2
    ) AS average_order_value,

    ROUND(AVG(f.is_late_delivery) * 100, 2)
        AS late_delivery_rate_pct
FROM fact_order_item AS f
JOIN dim_date AS d
    ON d.date_key = f.order_date_key
WHERE d.date_key <> 0
GROUP BY
    d.calendar_year,
    d.calendar_month,
    d.month_name,
    d.calendar_year_month;

-- ============================================================================
-- 3. CATEGORY PERFORMANCE
-- ============================================================================
CREATE OR REPLACE VIEW vw_category_performance AS
SELECT
    c.category_key,
    c.category_id,
    c.category_name,
    c.department_id,
    c.department_name,

    COUNT(*) AS order_item_rows,
    COUNT(DISTINCT f.order_id) AS total_orders,
    COUNT(DISTINCT f.customer_key) AS total_customers,
    COUNT(DISTINCT f.product_key) AS total_products,

    ROUND(SUM(f.sales), 2) AS total_sales,
    ROUND(SUM(f.order_profit_per_order), 2) AS total_profit,

    ROUND(
        SUM(f.order_profit_per_order)
        / NULLIF(SUM(f.sales), 0) * 100,
        2
    ) AS profit_margin_pct,

    ROUND(AVG(f.order_item_discount), 2)
        AS average_discount_amount,

    ROUND(AVG(f.discount_rate_pct), 2)
        AS average_discount_rate_pct,

    ROUND(AVG(f.is_late_delivery) * 100, 2)
        AS late_delivery_rate_pct,

    ROUND(AVG(f.is_loss_item) * 100, 2)
        AS loss_item_rate_pct
FROM fact_order_item AS f
JOIN dim_category AS c
    ON c.category_key = f.category_key
WHERE c.category_key <> 0
GROUP BY
    c.category_key,
    c.category_id,
    c.category_name,
    c.department_id,
    c.department_name;

-- ============================================================================
-- 4. PRODUCT PERFORMANCE
-- ============================================================================
CREATE OR REPLACE VIEW vw_product_performance AS
SELECT
    p.product_key,
    p.product_card_id,
    p.product_name,
    p.product_price,
    p.product_status,
    p.product_category_id,
    p.category_name,
    p.department_name,

    COUNT(*) AS order_item_rows,
    COUNT(DISTINCT f.order_id) AS total_orders,
    SUM(f.order_item_quantity) AS total_quantity,

    ROUND(SUM(f.sales), 2) AS total_sales,
    ROUND(SUM(f.order_profit_per_order), 2)
        AS total_profit,

    ROUND(
        SUM(f.order_profit_per_order)
        / NULLIF(SUM(f.sales), 0) * 100,
        2
    ) AS profit_margin_pct,

    ROUND(AVG(f.sales), 2) AS average_item_sales,
    ROUND(AVG(f.order_item_discount), 2)
        AS average_discount_amount,

    ROUND(AVG(f.is_late_delivery) * 100, 2)
        AS late_delivery_rate_pct,

    ROUND(AVG(f.is_loss_item) * 100, 2)
        AS loss_item_rate_pct
FROM fact_order_item AS f
JOIN dim_product AS p
    ON p.product_key = f.product_key
WHERE p.product_key <> 0
GROUP BY
    p.product_key,
    p.product_card_id,
    p.product_name,
    p.product_price,
    p.product_status,
    p.product_category_id,
    p.category_name,
    p.department_name;

-- ============================================================================
-- 5. CUSTOMER PERFORMANCE
-- ============================================================================
CREATE OR REPLACE VIEW vw_customer_performance AS
SELECT
    c.customer_key,
    c.customer_id,
    c.customer_segment,
    c.customer_city,
    c.customer_state,
    c.customer_country,
    c.customer_frequency_segment,

    COUNT(*) AS order_item_rows,
    COUNT(DISTINCT f.order_id) AS total_orders,
    COUNT(DISTINCT f.product_key) AS distinct_products,

    ROUND(SUM(f.sales), 2) AS total_sales,
    ROUND(SUM(f.order_profit_per_order), 2)
        AS total_profit,

    ROUND(
        SUM(f.order_profit_per_order)
        / NULLIF(SUM(f.sales), 0) * 100,
        2
    ) AS profit_margin_pct,

    ROUND(
        SUM(f.sales)
        / NULLIF(COUNT(DISTINCT f.order_id), 0),
        2
    ) AS average_order_value,

    ROUND(AVG(f.is_late_delivery) * 100, 2)
        AS late_delivery_rate_pct,

    MAX(c.customer_lifetime_sales)
        AS customer_lifetime_sales,

    MAX(c.customer_lifetime_profit)
        AS customer_lifetime_profit,

    MAX(c.customer_tenure_days)
        AS customer_tenure_days
FROM fact_order_item AS f
JOIN dim_customer AS c
    ON c.customer_key = f.customer_key
WHERE c.customer_key <> 0
GROUP BY
    c.customer_key,
    c.customer_id,
    c.customer_segment,
    c.customer_city,
    c.customer_state,
    c.customer_country,
    c.customer_frequency_segment;

-- ============================================================================
-- 6. CUSTOMER SEGMENT SUMMARY
-- ============================================================================
CREATE OR REPLACE VIEW vw_customer_segment_summary AS
SELECT
    c.customer_segment,

    COUNT(DISTINCT c.customer_key) AS total_customers,
    COUNT(DISTINCT f.order_id) AS total_orders,

    ROUND(SUM(f.sales), 2) AS total_sales,
    ROUND(SUM(f.order_profit_per_order), 2)
        AS total_profit,

    ROUND(
        SUM(f.sales)
        / NULLIF(COUNT(DISTINCT c.customer_key), 0),
        2
    ) AS sales_per_customer,

    ROUND(
        SUM(f.sales)
        / NULLIF(COUNT(DISTINCT f.order_id), 0),
        2
    ) AS average_order_value,

    ROUND(
        SUM(f.order_profit_per_order)
        / NULLIF(SUM(f.sales), 0) * 100,
        2
    ) AS profit_margin_pct,

    ROUND(AVG(f.is_late_delivery) * 100, 2)
        AS late_delivery_rate_pct
FROM fact_order_item AS f
JOIN dim_customer AS c
    ON c.customer_key = f.customer_key
WHERE c.customer_key <> 0
GROUP BY c.customer_segment;

-- ============================================================================
-- 7. SHIPPING MODE PERFORMANCE
-- ============================================================================
CREATE OR REPLACE VIEW vw_shipping_mode_performance AS
SELECT
    sm.shipping_mode_key,
    sm.shipping_mode,
    sm.service_level_group,
    sm.default_scheduled_days,

    COUNT(*) AS order_item_rows,
    COUNT(DISTINCT f.order_id) AS total_orders,

    ROUND(SUM(f.sales), 2) AS total_sales,
    ROUND(SUM(f.order_profit_per_order), 2)
        AS total_profit,

    ROUND(AVG(f.days_for_shipping_real), 2)
        AS average_actual_shipping_days,

    ROUND(AVG(f.days_for_shipment_scheduled), 2)
        AS average_scheduled_shipping_days,

    ROUND(AVG(f.shipping_delay_days), 2)
        AS average_delay_days,

    ROUND(AVG(f.shipping_efficiency_ratio), 4)
        AS average_shipping_efficiency_ratio,

    ROUND(AVG(f.is_late_delivery) * 100, 2)
        AS late_delivery_rate_pct,

    ROUND(AVG(f.is_on_time_delivery) * 100, 2)
        AS on_time_delivery_rate_pct
FROM fact_order_item AS f
JOIN dim_shipping_mode AS sm
    ON sm.shipping_mode_key = f.shipping_mode_key
WHERE sm.shipping_mode_key <> 0
GROUP BY
    sm.shipping_mode_key,
    sm.shipping_mode,
    sm.service_level_group,
    sm.default_scheduled_days;

-- ============================================================================
-- 8. DELIVERY STATUS SUMMARY
-- ============================================================================
CREATE OR REPLACE VIEW vw_delivery_status_summary AS
SELECT
    f.delivery_status,
    f.delivery_performance,

    COUNT(*) AS order_item_rows,
    COUNT(DISTINCT f.order_id) AS total_orders,

    ROUND(SUM(f.sales), 2) AS total_sales,
    ROUND(SUM(f.order_profit_per_order), 2)
        AS total_profit,

    ROUND(AVG(f.days_for_shipping_real), 2)
        AS average_actual_shipping_days,

    ROUND(AVG(f.shipping_delay_days), 2)
        AS average_delay_days,

    ROUND(AVG(f.is_late_delivery) * 100, 2)
        AS late_delivery_rate_pct,

    ROUND(
        AVG(f.requires_management_attention) * 100,
        2
    ) AS management_attention_rate_pct
FROM fact_order_item AS f
GROUP BY
    f.delivery_status,
    f.delivery_performance;

-- ============================================================================
-- 9. GEOGRAPHY PERFORMANCE
-- ============================================================================
CREATE OR REPLACE VIEW vw_geography_performance AS
SELECT
    g.geography_key,
    g.market,
    g.order_region,
    g.order_country,
    g.order_state,
    g.order_city,
    g.latitude,
    g.longitude,

    COUNT(*) AS order_item_rows,
    COUNT(DISTINCT f.order_id) AS total_orders,
    COUNT(DISTINCT f.customer_key) AS total_customers,

    ROUND(SUM(f.sales), 2) AS total_sales,
    ROUND(SUM(f.order_profit_per_order), 2)
        AS total_profit,

    ROUND(
        SUM(f.order_profit_per_order)
        / NULLIF(SUM(f.sales), 0) * 100,
        2
    ) AS profit_margin_pct,

    ROUND(AVG(f.is_late_delivery) * 100, 2)
        AS late_delivery_rate_pct,

    ROUND(AVG(f.shipping_delay_days), 2)
        AS average_delay_days
FROM fact_order_item AS f
JOIN dim_geography AS g
    ON g.geography_key = f.geography_key
WHERE g.geography_key <> 0
GROUP BY
    g.geography_key,
    g.market,
    g.order_region,
    g.order_country,
    g.order_state,
    g.order_city,
    g.latitude,
    g.longitude;

-- ============================================================================
-- 10. MARKET PERFORMANCE
-- ============================================================================
CREATE OR REPLACE VIEW vw_market_performance AS
SELECT
    g.market,

    COUNT(*) AS order_item_rows,
    COUNT(DISTINCT f.order_id) AS total_orders,
    COUNT(DISTINCT f.customer_key) AS total_customers,

    ROUND(SUM(f.sales), 2) AS total_sales,
    ROUND(SUM(f.order_profit_per_order), 2)
        AS total_profit,

    ROUND(
        SUM(f.order_profit_per_order)
        / NULLIF(SUM(f.sales), 0) * 100,
        2
    ) AS profit_margin_pct,

    ROUND(
        SUM(f.sales)
        / NULLIF(COUNT(DISTINCT f.order_id), 0),
        2
    ) AS average_order_value,

    ROUND(AVG(f.is_late_delivery) * 100, 2)
        AS late_delivery_rate_pct,

    ROUND(AVG(f.shipping_delay_days), 2)
        AS average_delay_days
FROM fact_order_item AS f
JOIN dim_geography AS g
    ON g.geography_key = f.geography_key
WHERE g.geography_key <> 0
GROUP BY g.market;

-- ============================================================================
-- 11. PROFITABILITY ANALYSIS
-- ============================================================================
CREATE OR REPLACE VIEW vw_profitability_analysis AS
SELECT
    f.profitability_status,
    f.margin_band,
    f.discount_band,

    COUNT(*) AS order_item_rows,
    COUNT(DISTINCT f.order_id) AS total_orders,

    ROUND(SUM(f.sales), 2) AS total_sales,
    ROUND(SUM(f.order_profit_per_order), 2)
        AS total_profit,

    ROUND(AVG(f.profit_margin_pct), 2)
        AS average_profit_margin_pct,

    ROUND(AVG(f.discount_rate_pct), 2)
        AS average_discount_rate_pct,

    ROUND(AVG(f.is_late_delivery) * 100, 2)
        AS late_delivery_rate_pct,

    ROUND(AVG(f.is_loss_item) * 100, 2)
        AS loss_item_rate_pct
FROM fact_order_item AS f
GROUP BY
    f.profitability_status,
    f.margin_band,
    f.discount_band;

-- ============================================================================
-- 12. OPERATIONAL RISK SUMMARY
-- ============================================================================
CREATE OR REPLACE VIEW vw_operational_risk_summary AS
SELECT
    f.operational_risk_segment,
    f.requires_management_attention,

    COUNT(*) AS order_item_rows,
    COUNT(DISTINCT f.order_id) AS total_orders,

    ROUND(SUM(f.sales), 2) AS total_sales,
    ROUND(SUM(f.order_profit_per_order), 2)
        AS total_profit,

    ROUND(AVG(f.shipping_delay_days), 2)
        AS average_delay_days,

    ROUND(AVG(f.profit_margin_pct), 2)
        AS average_profit_margin_pct,

    ROUND(AVG(f.discount_rate_pct), 2)
        AS average_discount_rate_pct
FROM fact_order_item AS f
GROUP BY
    f.operational_risk_segment,
    f.requires_management_attention;

-- ============================================================================
-- 13. ORDER SUMMARY
-- One row represents one order.
-- ============================================================================
CREATE OR REPLACE VIEW vw_order_summary AS
SELECT
    f.order_id,

    MIN(od.full_date) AS order_date,
    MAX(sd.full_date) AS shipping_date,

    MAX(c.customer_id) AS customer_id,
    MAX(c.customer_segment) AS customer_segment,

    MAX(g.market) AS market,
    MAX(g.order_region) AS order_region,
    MAX(g.order_country) AS order_country,

    MAX(sm.shipping_mode) AS shipping_mode,
    MAX(f.payment_type) AS payment_type,
    MAX(f.order_status) AS order_status,
    MAX(f.delivery_status) AS delivery_status,

    COUNT(*) AS order_item_rows,
    COUNT(DISTINCT f.product_key) AS distinct_products,
    SUM(f.order_item_quantity) AS total_quantity,

    ROUND(SUM(f.sales), 2) AS total_sales,
    ROUND(SUM(f.order_profit_per_order), 2)
        AS total_profit,

    ROUND(
        SUM(f.order_profit_per_order)
        / NULLIF(SUM(f.sales), 0) * 100,
        2
    ) AS profit_margin_pct,

    MAX(f.days_for_shipping_real)
        AS actual_shipping_days,

    MAX(f.days_for_shipment_scheduled)
        AS scheduled_shipping_days,

    MAX(f.shipping_delay_days)
        AS shipping_delay_days,

    MAX(f.is_late_delivery)
        AS is_late_delivery,

    MAX(f.requires_management_attention)
        AS requires_management_attention
FROM fact_order_item AS f
JOIN dim_customer AS c
    ON c.customer_key = f.customer_key
JOIN dim_date AS od
    ON od.date_key = f.order_date_key
JOIN dim_date AS sd
    ON sd.date_key = f.shipping_date_key
JOIN dim_shipping_mode AS sm
    ON sm.shipping_mode_key = f.shipping_mode_key
JOIN dim_geography AS g
    ON g.geography_key = f.geography_key
GROUP BY f.order_id;

-- ============================================================================
-- 14. TABLEAU DETAIL VIEW
-- Denormalized view for dashboard-level exploration.
-- ============================================================================
CREATE OR REPLACE VIEW vw_tableau_order_item_detail AS
SELECT
    f.fact_order_item_key,
    f.order_item_id,
    f.order_id,

    od.full_date AS order_date,
    od.calendar_year AS order_year,
    od.calendar_quarter AS order_quarter,
    od.quarter_name,
    od.calendar_month AS order_month,
    od.month_name AS order_month_name,
    od.calendar_year_month,
    od.week_of_year,
    od.day_name AS order_day_name,
    od.is_weekend AS is_weekend_order,

    sd.full_date AS shipping_date,

    c.customer_id,
    c.customer_segment,
    c.customer_city,
    c.customer_state,
    c.customer_country,
    c.customer_frequency_segment,

    p.product_card_id,
    p.product_name,
    p.product_price,
    p.product_status,

    cat.category_id,
    cat.category_name,
    cat.department_id,
    cat.department_name,

    sm.shipping_mode,
    sm.service_level_group,

    g.market,
    g.order_region,
    g.order_country,
    g.order_state,
    g.order_city,
    g.latitude,
    g.longitude,

    f.payment_type,
    f.delivery_status,
    f.order_status,

    f.order_item_quantity,
    f.sales,
    f.order_item_total,
    f.order_item_product_price,

    f.order_item_discount,
    f.order_item_discount_rate,
    f.discount_pct_calculated,
    f.discount_rate_pct,
    f.gross_sales_before_discount,

    f.order_profit,
    f.order_profit_per_order,
    f.order_item_profit_ratio,
    f.profit_margin_pct,
    f.profitability_status,
    f.is_profitable_item,
    f.is_loss_item,

    f.days_for_shipping_real,
    f.days_for_shipment_scheduled,
    f.shipping_delay_days,
    f.absolute_schedule_variance_days,
    f.shipping_efficiency_ratio,
    f.late_delivery_risk,
    f.is_late_delivery,
    f.is_on_time_delivery,
    f.delivery_performance,
    f.delivery_delay_severity,
    f.shipping_speed_segment,

    f.sales_value_tier,
    f.margin_band,
    f.discount_band,
    f.requires_management_attention,
    f.operational_risk_segment,

    f.load_batch_id,
    f.loaded_at
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
    ON g.geography_key = f.geography_key;

-- ============================================================================
-- 15. VIEW INVENTORY
-- ============================================================================
SELECT
    table_name AS view_name,
    check_option,
    is_updatable,
    security_type
FROM information_schema.views
WHERE table_schema = DATABASE()
ORDER BY table_name;

-- ============================================================================
-- 16. VIEW VALIDATION
-- ============================================================================
SELECT
    'vw_executive_overview' AS view_name,
    COUNT(*) AS row_count
FROM vw_executive_overview

UNION ALL

SELECT
    'vw_monthly_sales_trend',
    COUNT(*)
FROM vw_monthly_sales_trend

UNION ALL

SELECT
    'vw_category_performance',
    COUNT(*)
FROM vw_category_performance

UNION ALL

SELECT
    'vw_product_performance',
    COUNT(*)
FROM vw_product_performance

UNION ALL

SELECT
    'vw_customer_performance',
    COUNT(*)
FROM vw_customer_performance

UNION ALL

SELECT
    'vw_shipping_mode_performance',
    COUNT(*)
FROM vw_shipping_mode_performance

UNION ALL

SELECT
    'vw_geography_performance',
    COUNT(*)
FROM vw_geography_performance

UNION ALL

SELECT
    'vw_order_summary',
    COUNT(*)
FROM vw_order_summary

UNION ALL

SELECT
    'vw_tableau_order_item_detail',
    COUNT(*)
FROM vw_tableau_order_item_detail;

-- ============================================================================
-- 17. SAMPLE OUTPUTS
-- ============================================================================
SELECT *
FROM vw_executive_overview;

SELECT *
FROM vw_monthly_sales_trend
ORDER BY calendar_year, calendar_month
LIMIT 24;

SELECT *
FROM vw_category_performance
ORDER BY total_sales DESC
LIMIT 10;

SELECT *
FROM vw_shipping_mode_performance
ORDER BY late_delivery_rate_pct DESC;

SELECT
    'BUSINESS INTELLIGENCE VIEW LAYER COMPLETE'
        AS view_layer_status,
    NOW(6) AS completed_at;
    
    SELECT *
FROM vw_executive_overview;
