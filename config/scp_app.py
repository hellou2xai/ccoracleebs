"""
Oracle EBS — Supply Chain Planning Agentic App Configuration
15 SQL queries, KPIs, findings, exception actions, demo data.
Mirrors the payables_app.py pattern exactly.
"""

# ─── SQL Queries ─────────────────────────────────────────────────────────────

SCP_QUERIES = {

    "plan_summary": {
        "label": "Active Plans Overview",
        "sql": """
            SELECT /*+ FIRST_ROWS(20) */
                   p.plan_id,
                   p.compile_designator                               plan_name,
                   DECODE(p.plan_type, 1,'MRP', 2,'MPS', 3,'DRP',
                          4,'MPS-MRP', 5,'SOP', TO_CHAR(p.plan_type)) plan_type_name,
                   p.plan_completion_date,
                   p.plan_start_date,
                   p.cutoff_date,
                   ROUND(SYSDATE - p.plan_completion_date, 1)         days_since_run,
                   (SELECT COUNT(*) FROM msc_exception_details e
                    WHERE e.plan_id = p.plan_id
                      AND e.sr_instance_id = p.sr_instance_id)        exception_count,
                   (SELECT COUNT(DISTINCT e.inventory_item_id)
                    FROM msc_exception_details e
                    WHERE e.plan_id = p.plan_id
                      AND e.sr_instance_id = p.sr_instance_id)        items_with_exceptions,
                   (SELECT COUNT(DISTINCT po.organization_id)
                    FROM msc_plan_organizations po
                    WHERE po.plan_id = p.plan_id
                      AND po.sr_instance_id = p.sr_instance_id)       org_count,
                   COUNT(*) OVER()                                    total_plans
            FROM   msc_plans p
            WHERE  (p.plan_completion_date IS NOT NULL OR p.data_completion_date IS NOT NULL)
            ORDER  BY p.plan_completion_date DESC
            FETCH FIRST 20 ROWS ONLY
        """,
    },

    "demand_supply_balance": {
        "label": "Demand vs Supply Balance",
        "sql": """
            SELECT /*+ FIRST_ROWS(100) */
                   msi.item_name,
                   msi.inventory_item_id,
                   msi.planner_code,
                   DECODE(msi.planning_make_buy_code, 1,'MAKE', 2,'BUY') make_buy,
                   NVL(d.total_demand, 0)                              total_demand_qty,
                   NVL(s.total_supply, 0)                              total_supply_qty,
                   NVL(s.total_supply, 0) - NVL(d.total_demand, 0)     net_position,
                   0                            safety_stock,
                   CASE WHEN NVL(s.total_supply,0) < NVL(d.total_demand,0) THEN 'SHORT'
                        WHEN NVL(s.total_supply,0) - NVL(d.total_demand,0)
                             < NVL(0,0) THEN 'BELOW_SS'
                        ELSE 'OK' END                                  balance_status,
                   COUNT(*) OVER()                                     total_items
            FROM   msc_system_items msi
            JOIN   (SELECT inventory_item_id, sr_instance_id, plan_id,
                           ROUND(SUM(using_requirement_quantity), 2) total_demand
                    FROM   msc_demands
                    WHERE  plan_id = (SELECT MAX(plan_id) FROM msc_plans
                                      WHERE plan_completion_date IS NOT NULL OR data_completion_date IS NOT NULL)
                      AND  using_assembly_demand_date BETWEEN {plan_date} AND {plan_date} + {days_back}
                    GROUP BY inventory_item_id, sr_instance_id, plan_id) d
              ON   d.inventory_item_id = msi.inventory_item_id
              AND  d.sr_instance_id    = msi.sr_instance_id
              AND  d.plan_id           = msi.plan_id
            LEFT JOIN (SELECT inventory_item_id, sr_instance_id, plan_id,
                              ROUND(SUM(new_order_quantity), 2) total_supply
                       FROM   msc_supplies
                       WHERE  plan_id = (SELECT MAX(plan_id) FROM msc_plans
                                         WHERE plan_completion_date IS NOT NULL OR data_completion_date IS NOT NULL)
                         AND  new_schedule_date BETWEEN {plan_date} AND {plan_date} + {days_back}
                       GROUP BY inventory_item_id, sr_instance_id, plan_id) s
              ON   s.inventory_item_id = msi.inventory_item_id
              AND  s.sr_instance_id    = msi.sr_instance_id
              AND  s.plan_id           = msi.plan_id
            WHERE  NVL(s.total_supply, 0) < NVL(d.total_demand, 0)
               OR  NVL(s.total_supply, 0) - NVL(d.total_demand, 0)
                   < NVL(0, 0)
            ORDER  BY (NVL(s.total_supply,0) - NVL(d.total_demand,0))
            FETCH FIRST 100 ROWS ONLY
        """,
    },

    "plan_exceptions": {
        "label": "Plan Exceptions",
        "sql": """
            SELECT /*+ FIRST_ROWS(200) */
                   e.exception_type,
                   mle.meaning                                         exception_name,
                   e.inventory_item_id,
                   msi.item_name,
                   msi.planner_code,
                   DECODE(msi.planning_make_buy_code, 1,'MAKE', 2,'BUY') make_buy,
                   e.organization_id,
                   e.quantity,
                   e.date1                                             exception_date,
                   e.date2                                             suggested_date,
                   ROUND(e.date2 - e.date1, 0)                        days_delta,
                   COUNT(*) OVER()                                     total_exceptions,
                   COUNT(*) OVER(PARTITION BY e.exception_type)        count_by_type
            FROM   msc_exception_details e
            JOIN   msc_system_items msi
              ON   msi.inventory_item_id = e.inventory_item_id
              AND  msi.plan_id           = e.plan_id
              AND  msi.sr_instance_id    = e.sr_instance_id
            LEFT JOIN mfg_lookups mle
              ON   mle.lookup_type = 'MSC_EXCEPTION_TYPE'
              AND  mle.lookup_code = e.exception_type
            WHERE  e.plan_id = (SELECT MAX(plan_id) FROM msc_plans
                                WHERE plan_completion_date IS NOT NULL OR data_completion_date IS NOT NULL)
            ORDER  BY e.exception_type, e.quantity DESC
            FETCH FIRST 200 ROWS ONLY
        """,
    },

    "forecast_accuracy": {
        "label": "Forecast Accuracy",
        "sql": """
            SELECT /*+ FIRST_ROWS(100) */
                   f.forecast_designator,
                   f.inventory_item_id,
                   msi.segment1                                        item_name,
                   msi.planner_code,
                   ROUND(SUM(f.original_forecast_quantity), 2)         forecast_qty,
                   ROUND(SUM(f.current_forecast_quantity), 2)          consumed_qty,
                   CASE WHEN SUM(f.original_forecast_quantity) > 0
                        THEN ROUND(ABS(SUM(f.original_forecast_quantity) -
                                     SUM(f.current_forecast_quantity)) /
                                 SUM(f.original_forecast_quantity) * 100, 1)
                        ELSE 0 END                                     mape_pct,
                   CASE WHEN SUM(f.current_forecast_quantity) > SUM(f.original_forecast_quantity)
                        THEN 'OVER_FORECAST'
                        WHEN SUM(f.current_forecast_quantity) < SUM(f.original_forecast_quantity) * 0.8
                        THEN 'UNDER_FORECAST'
                        ELSE 'ON_TRACK' END                            accuracy_band,
                   COUNT(*) OVER()                                     total_items
            FROM   mrp_forecast_dates f
            JOIN   mtl_system_items_b msi
              ON   msi.inventory_item_id = f.inventory_item_id
              AND  msi.organization_id   = f.organization_id
            WHERE  f.forecast_date BETWEEN {plan_date} - {days_back} AND {plan_date}
            GROUP  BY f.forecast_designator, f.inventory_item_id, msi.segment1, msi.planner_code
            HAVING ABS(SUM(f.original_forecast_quantity) - SUM(f.current_forecast_quantity)) /
                   NULLIF(SUM(f.original_forecast_quantity), 0) > 0.1
            ORDER  BY mape_pct DESC
            FETCH FIRST 100 ROWS ONLY
        """,
    },

    "safety_stock_violations": {
        "label": "Safety Stock Violations",
        "sql": """
            SELECT /*+ FIRST_ROWS(100) */
                   msi.item_name,
                   msi.inventory_item_id,
                   msi.organization_id,
                   msi.planner_code,
                   DECODE(msi.planning_make_buy_code, 1,'MAKE', 2,'BUY') make_buy,
                   ROUND(NVL(oh.on_hand, 0), 2)                       on_hand_qty,
                   ROUND(NVL(ss.safety_stock_quantity,
                             0), 2)            safety_stock_qty,
                   ROUND(NVL(oh.on_hand, 0) - NVL(ss.safety_stock_quantity,
                         0), 2)                gap,
                   CASE WHEN NVL(oh.on_hand, 0) = 0 THEN 'ZERO_STOCK'
                        WHEN NVL(oh.on_hand, 0) < NVL(ss.safety_stock_quantity,
                             0) * 0.5 THEN 'CRITICAL'
                        ELSE 'BELOW_SS' END                            violation_severity,
                   msi.full_lead_time,
                   COUNT(*) OVER()                                     total_violations
            FROM   msc_system_items msi
            LEFT JOIN (SELECT inventory_item_id, organization_id,
                              SUM(transaction_quantity) on_hand
                       FROM mtl_onhand_quantities_detail
                       GROUP BY inventory_item_id, organization_id) oh
              ON   oh.inventory_item_id = msi.inventory_item_id
              AND  oh.organization_id   = msi.organization_id
            LEFT JOIN msc_safety_stocks ss
              ON   ss.inventory_item_id = msi.inventory_item_id
              AND  ss.plan_id           = msi.plan_id
              AND  ss.sr_instance_id    = msi.sr_instance_id
              AND  ss.period_start_date <= {plan_date}
              AND  ss.period_start_date = (SELECT MAX(ss2.period_start_date)
                   FROM msc_safety_stocks ss2
                   WHERE ss2.inventory_item_id = ss.inventory_item_id
                     AND ss2.plan_id = ss.plan_id
                     AND ss2.sr_instance_id = ss.sr_instance_id
                     AND ss2.period_start_date <= {plan_date})
            WHERE  msi.plan_id = (SELECT MAX(plan_id) FROM msc_plans
                                  WHERE plan_completion_date IS NOT NULL OR data_completion_date IS NOT NULL)
              AND  NVL(oh.on_hand, 0) < NVL(ss.safety_stock_quantity,
                   0)
            ORDER  BY gap
            FETCH FIRST 100 ROWS ONLY
        """,
    },

    "planned_orders": {
        "label": "Planned Orders (Unreleased)",
        "sql": """
            SELECT /*+ FIRST_ROWS(100) */
                   r.inventory_item_id,
                   msi.item_name,
                   msi.planner_code,
                   DECODE(msi.planning_make_buy_code, 1,'MAKE', 2,'BUY') make_buy,
                   DECODE(r.order_type, 1,'PO', 2,'PURCH REQ', 3,'WORK ORDER',
                          5,'PLANNED ORDER', 7,'INTRANSIT', 8,'INT REQ',
                          TO_CHAR(r.order_type))                       order_type_name,
                   ROUND(r.new_order_quantity, 2)                      quantity,
                   r.new_schedule_date                                 schedule_date,
                   r.old_schedule_date                                 original_date,
                   r.disposition_status_type                            firm_status,
                   ROUND(r.new_schedule_date - SYSDATE, 0)             days_out,
                   CASE WHEN r.new_schedule_date < SYSDATE THEN 'PAST_DUE'
                        WHEN r.new_schedule_date < SYSDATE + 3 THEN 'URGENT'
                        WHEN r.new_schedule_date < SYSDATE + 7 THEN 'THIS_WEEK'
                        ELSE 'UPCOMING' END                            urgency,
                   COUNT(*) OVER()                                     total_planned
            FROM   msc_supplies r
            JOIN   msc_system_items msi
              ON   msi.inventory_item_id = r.inventory_item_id
              AND  msi.plan_id           = r.plan_id
              AND  msi.sr_instance_id    = r.sr_instance_id
            WHERE  r.plan_id = (SELECT MAX(plan_id) FROM msc_plans
                                WHERE plan_completion_date IS NOT NULL OR data_completion_date IS NOT NULL)
              AND  r.disposition_status_type IS NULL
              AND  r.new_schedule_date BETWEEN {plan_date} - 7
                                           AND {plan_date} + {days_back}
            ORDER  BY r.new_schedule_date
            FETCH FIRST 100 ROWS ONLY
        """,
    },

    "late_supply": {
        "label": "Late Supply",
        "sql": """
            SELECT /*+ FIRST_ROWS(100) */
                   s.transaction_id,
                   msi.item_name,
                   msi.inventory_item_id,
                   msi.planner_code,
                   DECODE(msi.planning_make_buy_code, 1,'MAKE', 2,'BUY') make_buy,
                   DECODE(s.order_type, 1,'PO', 3,'WO', 5,'PLANNED',
                          7,'INTRANSIT', TO_CHAR(s.order_type))        supply_type,
                   ROUND(s.new_order_quantity, 2)                      supply_qty,
                   s.new_schedule_date                                 supply_date,
                   d.using_assembly_demand_date                                       need_date,
                   ROUND(s.new_schedule_date - d.using_assembly_demand_date, 0)       days_late,
                   ROUND(d.using_requirement_quantity, 2)               demand_qty,
                   COUNT(*) OVER()                                     total_late
            FROM   msc_supplies s
            JOIN   msc_full_pegging fp
              ON   fp.transaction_id    = s.transaction_id
              AND  fp.plan_id           = s.plan_id
              AND  fp.sr_instance_id    = s.sr_instance_id
            JOIN   msc_demands d
              ON   d.demand_id          = fp.demand_id
              AND  d.plan_id            = fp.plan_id
              AND  d.sr_instance_id     = fp.sr_instance_id
            JOIN   msc_system_items msi
              ON   msi.inventory_item_id = s.inventory_item_id
              AND  msi.plan_id           = s.plan_id
              AND  msi.sr_instance_id    = s.sr_instance_id
            WHERE  s.plan_id = (SELECT MAX(plan_id) FROM msc_plans
                                WHERE plan_completion_date IS NOT NULL OR data_completion_date IS NOT NULL)
              AND  s.new_schedule_date > d.using_assembly_demand_date
            ORDER  BY (s.new_schedule_date - d.using_assembly_demand_date) DESC
            FETCH FIRST 100 ROWS ONLY
        """,
    },

    "excess_inventory": {
        "label": "Excess Inventory",
        "sql": """
            SELECT /*+ FIRST_ROWS(100) */
                   msi.item_name,
                   msi.inventory_item_id,
                   msi.planner_code,
                   DECODE(msi.planning_make_buy_code, 1,'MAKE', 2,'BUY') make_buy,
                   ROUND(oh.on_hand, 2)                               on_hand_qty,
                   ROUND(msi.max_minmax_quantity, 2)                   max_qty,
                   ROUND(oh.on_hand - msi.max_minmax_quantity, 2)      excess_qty,
                   ROUND(oh.on_hand - msi.max_minmax_quantity, 2)       excess_value,
                   msi.full_lead_time,
                   COUNT(*) OVER()                                     total_excess
            FROM   msc_system_items msi
            JOIN   (SELECT inventory_item_id, organization_id,
                           SUM(transaction_quantity) on_hand
                    FROM mtl_onhand_quantities_detail
                    GROUP BY inventory_item_id, organization_id) oh
              ON   oh.inventory_item_id = msi.inventory_item_id
              AND  oh.organization_id   = msi.organization_id
            WHERE  msi.plan_id = (SELECT MAX(plan_id) FROM msc_plans
                                  WHERE plan_completion_date IS NOT NULL OR data_completion_date IS NOT NULL)
              AND  msi.max_minmax_quantity IS NOT NULL
              AND  oh.on_hand > msi.max_minmax_quantity
            ORDER  BY (oh.on_hand - msi.max_minmax_quantity) DESC
            FETCH FIRST 100 ROWS ONLY
        """,
    },

    "supplier_capacity": {
        "label": "Supplier Capacity Utilization",
        "sql": """
            SELECT /*+ FIRST_ROWS(50) */
                   sc.supplier_id,
                   tp.partner_name                                     supplier_name,
                   msi.item_name,
                   msi.inventory_item_id,
                   ROUND(sc.capacity, 2)                               max_capacity,
                   ROUND(NVL(sl.allocated_qty, 0), 2)                  allocated_qty,
                   ROUND(NVL(sl.allocated_qty, 0) / NULLIF(sc.capacity, 0) * 100, 1)
                                                                       utilization_pct,
                   CASE WHEN NVL(sl.allocated_qty, 0) / NULLIF(sc.capacity, 0) > 0.95
                        THEN 'CRITICAL'
                        WHEN NVL(sl.allocated_qty, 0) / NULLIF(sc.capacity, 0) > 0.80
                        THEN 'HIGH'
                        ELSE 'OK' END                                  capacity_risk,
                   sc.from_date,
                   sc.to_date,
                   COUNT(*) OVER()                                     total_constraints
            FROM   msc_supplier_capacities sc
            JOIN   msc_trading_partners tp
              ON   tp.partner_id = sc.supplier_id
              AND  tp.sr_instance_id = sc.sr_instance_id
            JOIN   msc_system_items msi
              ON   msi.inventory_item_id = sc.inventory_item_id
              AND  msi.plan_id           = sc.plan_id
              AND  msi.sr_instance_id    = sc.sr_instance_id
            LEFT JOIN (SELECT inventory_item_id, supplier_id, plan_id, sr_instance_id,
                              SUM(new_order_quantity) allocated_qty
                       FROM msc_supplies
                       WHERE order_type IN (1, 2, 8)
                       GROUP BY inventory_item_id, supplier_id, plan_id, sr_instance_id) sl
              ON   sl.inventory_item_id = sc.inventory_item_id
              AND  sl.supplier_id       = sc.supplier_id
              AND  sl.plan_id           = sc.plan_id
              AND  sl.sr_instance_id    = sc.sr_instance_id
            WHERE  sc.plan_id = (SELECT MAX(plan_id) FROM msc_plans
                                 WHERE plan_completion_date IS NOT NULL OR data_completion_date IS NOT NULL)
              AND  NVL(sl.allocated_qty, 0) / NULLIF(sc.capacity, 0) > 0.8
            ORDER  BY utilization_pct DESC
            FETCH FIRST 50 ROWS ONLY
        """,
    },

    "sourcing_compliance": {
        "label": "Sourcing Rule Compliance",
        "sql": """
            SELECT /*+ FIRST_ROWS(100) */
                   sr.sourcing_rule_name,
                   msi.item_name,
                   msi.inventory_item_id,
                   msi.planner_code,
                   sro.source_partner_id                               supplier_id,
                   tp.partner_name                                     preferred_supplier,
                   ROUND(NVL(sro.allocation_percent, 0), 1)            target_pct,
                   sro.rank                                            source_rank,
                   CASE WHEN sro.source_type = 1 THEN 'TRANSFER'
                        WHEN sro.source_type = 2 THEN 'MAKE'
                        WHEN sro.source_type = 3 THEN 'BUY'
                        ELSE TO_CHAR(sro.source_type) END              source_type,
                   COUNT(*) OVER()                                     total_rules
            FROM   msc_sourcing_rules sr
            JOIN   msc_sr_receipt_org sra
              ON   sra.sourcing_rule_id = sr.sourcing_rule_id
            JOIN   msc_sr_source_org sro
              ON   sro.sr_receipt_id = sra.sr_receipt_id
            LEFT JOIN msc_trading_partners tp
              ON   tp.partner_id = sro.source_partner_id
              AND  tp.sr_instance_id = sro.sr_instance_id
            LEFT JOIN msc_system_items msi
              ON   msi.inventory_item_id = sra.inventory_item_id
              AND  msi.sr_instance_id    = sra.sr_instance_id
              AND  msi.plan_id = (SELECT MAX(plan_id) FROM msc_plans
                                  WHERE plan_completion_date IS NOT NULL OR data_completion_date IS NOT NULL)
            ORDER  BY sr.sourcing_rule_name, sro.rank
            FETCH FIRST 100 ROWS ONLY
        """,
    },

    "demand_variability": {
        "label": "Demand Variability",
        "sql": """
            SELECT /*+ FIRST_ROWS(100) */
                   msi.item_name,
                   msi.inventory_item_id,
                   msi.planner_code,
                   DECODE(msi.planning_make_buy_code, 1,'MAKE', 2,'BUY') make_buy,
                   COUNT(d.demand_id)                                  demand_count,
                   ROUND(AVG(d.using_requirement_quantity), 2)         avg_demand,
                   ROUND(STDDEV(d.using_requirement_quantity), 2)      stddev_demand,
                   CASE WHEN AVG(d.using_requirement_quantity) > 0
                        THEN ROUND(STDDEV(d.using_requirement_quantity) /
                                   AVG(d.using_requirement_quantity) * 100, 1)
                        ELSE 0 END                                     cov_pct,
                   CASE WHEN STDDEV(d.using_requirement_quantity) /
                             NULLIF(AVG(d.using_requirement_quantity), 0) > 1.0
                        THEN 'LUMPY'
                        WHEN STDDEV(d.using_requirement_quantity) /
                             NULLIF(AVG(d.using_requirement_quantity), 0) > 0.5
                        THEN 'VARIABLE'
                        ELSE 'STABLE' END                              demand_pattern,
                   COUNT(*) OVER()                                     total_items
            FROM   msc_demands d
            JOIN   msc_system_items msi
              ON   msi.inventory_item_id = d.inventory_item_id
              AND  msi.plan_id           = d.plan_id
              AND  msi.sr_instance_id    = d.sr_instance_id
            WHERE  d.plan_id = (SELECT MAX(plan_id) FROM msc_plans
                                WHERE plan_completion_date IS NOT NULL OR data_completion_date IS NOT NULL)
              AND  d.using_assembly_demand_date BETWEEN {plan_date} - {days_back}
                                     AND {plan_date} + {days_back}
            GROUP  BY msi.item_name, msi.inventory_item_id, msi.planner_code,
                      msi.planning_make_buy_code
            HAVING COUNT(d.demand_id) >= 3
            ORDER  BY cov_pct DESC
            FETCH FIRST 100 ROWS ONLY
        """,
    },

    "item_coverage": {
        "label": "Days of Supply / Coverage",
        "sql": """
            SELECT /*+ FIRST_ROWS(100) */
                   msi.item_name,
                   msi.inventory_item_id,
                   msi.planner_code,
                   DECODE(msi.planning_make_buy_code, 1,'MAKE', 2,'BUY') make_buy,
                   ROUND(NVL(oh.on_hand, 0), 2)                       on_hand_qty,
                   ROUND(NVL(avg_d.daily_demand, 0), 2)                avg_daily_demand,
                   CASE WHEN NVL(avg_d.daily_demand, 0) > 0
                        THEN ROUND(NVL(oh.on_hand, 0) / avg_d.daily_demand, 1)
                        ELSE 999 END                                   days_of_supply,
                   msi.full_lead_time,
                   CASE WHEN NVL(oh.on_hand,0) / NULLIF(avg_d.daily_demand,0) < msi.full_lead_time
                        THEN 'CRITICAL'
                        WHEN NVL(oh.on_hand,0) / NULLIF(avg_d.daily_demand,0) < msi.full_lead_time * 1.5
                        THEN 'LOW'
                        WHEN NVL(oh.on_hand,0) / NULLIF(avg_d.daily_demand,0) > msi.full_lead_time * 4
                        THEN 'EXCESS'
                        ELSE 'OK' END                                  coverage_band,
                   COUNT(*) OVER()                                     total_items
            FROM   msc_system_items msi
            JOIN   (SELECT inventory_item_id, organization_id,
                           SUM(transaction_quantity) on_hand
                    FROM mtl_onhand_quantities_detail
                    GROUP BY inventory_item_id, organization_id) oh
              ON   oh.inventory_item_id = msi.inventory_item_id
              AND  oh.organization_id   = msi.organization_id
            JOIN   (SELECT inventory_item_id, plan_id, sr_instance_id,
                           ROUND(SUM(using_requirement_quantity) /
                                 NULLIF(MAX(using_assembly_demand_date) - MIN(using_assembly_demand_date), 0), 2)
                           daily_demand
                    FROM msc_demands
                    WHERE using_assembly_demand_date BETWEEN {plan_date} AND {plan_date} + 90
                    GROUP BY inventory_item_id, plan_id, sr_instance_id) avg_d
              ON   avg_d.inventory_item_id = msi.inventory_item_id
              AND  avg_d.plan_id           = msi.plan_id
              AND  avg_d.sr_instance_id    = msi.sr_instance_id
            WHERE  msi.plan_id = (SELECT MAX(plan_id) FROM msc_plans
                                  WHERE plan_completion_date IS NOT NULL OR data_completion_date IS NOT NULL)
            ORDER  BY days_of_supply
            FETCH FIRST 100 ROWS ONLY
        """,
    },

    "safety_stock_analysis": {
        "label": "Safety Stock Policy Analysis",
        "sql": """
            SELECT /*+ FIRST_ROWS(100) */
                   msi.item_name,
                   msi.inventory_item_id,
                   msi.planner_code,
                   DECODE(msi.planning_make_buy_code, 1,'MAKE', 2,'BUY') make_buy,
                   DECODE(msi.safety_stock_code, 1,'FIXED', 2,'MRP_PLANNED',
                          NULL,'NOT_SET')                              ss_method,
                   ROUND(NVL(ss.safety_stock_quantity,
                             0), 2)            current_ss,
                   ROUND(NVL(ss.target_safety_stock, 0), 2)           target_ss,
                   ROUND(NVL(oh.on_hand, 0), 2)                       on_hand_qty,
                   ROUND(NVL(avg_d.daily_demand, 0), 2)               avg_daily_demand,
                   CASE WHEN NVL(avg_d.daily_demand, 0) > 0
                        THEN ROUND(NVL(ss.safety_stock_quantity,
                             0) / avg_d.daily_demand, 1)
                        ELSE NULL END                                  ss_days_cover,
                   msi.full_lead_time,
                   CASE WHEN msi.safety_stock_code IS NULL THEN 'NO_POLICY'
                        WHEN NVL(ss.safety_stock_quantity,
                             0) = 0 THEN 'ZERO_SS'
                        WHEN NVL(ss.safety_stock_quantity,
                             0) /
                             NULLIF(avg_d.daily_demand, 0) < msi.full_lead_time * 0.3
                        THEN 'SS_TOO_LOW'
                        WHEN NVL(ss.safety_stock_quantity,
                             0) /
                             NULLIF(avg_d.daily_demand, 0) > msi.full_lead_time * 3
                        THEN 'SS_TOO_HIGH'
                        ELSE 'ADEQUATE' END                            ss_assessment,
                   ROUND(NVL(cov.cov_pct, 0), 1)                      demand_cov_pct,
                   CASE WHEN NVL(cov.cov_pct, 0) > 80 AND msi.safety_stock_code = 1
                        THEN 'REVIEW_POLICY' ELSE 'OK' END            policy_flag,
                   COUNT(*) OVER()                                     total_items
            FROM   msc_system_items msi
            LEFT JOIN msc_safety_stocks ss
              ON   ss.inventory_item_id = msi.inventory_item_id
              AND  ss.plan_id           = msi.plan_id
              AND  ss.sr_instance_id    = msi.sr_instance_id
              AND  ss.period_start_date = (SELECT MAX(ss2.period_start_date)
                   FROM msc_safety_stocks ss2
                   WHERE ss2.inventory_item_id = ss.inventory_item_id
                     AND ss2.plan_id = ss.plan_id AND ss2.sr_instance_id = ss.sr_instance_id
                     AND ss2.period_start_date <= {plan_date})
            LEFT JOIN (SELECT inventory_item_id, organization_id,
                              SUM(transaction_quantity) on_hand
                       FROM mtl_onhand_quantities_detail
                       GROUP BY inventory_item_id, organization_id) oh
              ON   oh.inventory_item_id = msi.inventory_item_id
              AND  oh.organization_id   = msi.organization_id
            LEFT JOIN (SELECT inventory_item_id, plan_id, sr_instance_id,
                              ROUND(SUM(using_requirement_quantity) /
                                    NULLIF(MAX(using_assembly_demand_date) - MIN(using_assembly_demand_date), 0), 2)
                              daily_demand
                       FROM msc_demands
                       WHERE using_assembly_demand_date BETWEEN {plan_date} AND {plan_date} + 90
                       GROUP BY inventory_item_id, plan_id, sr_instance_id) avg_d
              ON   avg_d.inventory_item_id = msi.inventory_item_id
              AND  avg_d.plan_id           = msi.plan_id
              AND  avg_d.sr_instance_id    = msi.sr_instance_id
            LEFT JOIN (SELECT inventory_item_id, plan_id, sr_instance_id,
                              CASE WHEN AVG(using_requirement_quantity) > 0
                                   THEN ROUND(STDDEV(using_requirement_quantity) /
                                        AVG(using_requirement_quantity) * 100, 1)
                                   ELSE 0 END cov_pct
                       FROM msc_demands
                       WHERE using_assembly_demand_date BETWEEN {plan_date} - 90 AND {plan_date}
                       GROUP BY inventory_item_id, plan_id, sr_instance_id) cov
              ON   cov.inventory_item_id = msi.inventory_item_id
              AND  cov.plan_id           = msi.plan_id
              AND  cov.sr_instance_id    = msi.sr_instance_id
            WHERE  msi.plan_id = (SELECT MAX(plan_id) FROM msc_plans
                                  WHERE plan_completion_date IS NOT NULL OR data_completion_date IS NOT NULL)
              AND  (msi.safety_stock_code IS NULL
                 OR NVL(ss.safety_stock_quantity, 0) = 0
                 OR NVL(ss.safety_stock_quantity, 0) /
                    NULLIF(avg_d.daily_demand, 0) < msi.full_lead_time * 0.3
                 OR NVL(ss.safety_stock_quantity, 0) /
                    NULLIF(avg_d.daily_demand, 0) > msi.full_lead_time * 3
                 OR (NVL(cov.cov_pct, 0) > 80 AND msi.safety_stock_code = 1))
            ORDER  BY ss_assessment, msi.item_name
            FETCH FIRST 100 ROWS ONLY
        """,
    },

    "pegging_analysis": {
        "label": "Supply-Demand Pegging",
        "sql": """
            SELECT /*+ FIRST_ROWS(100) */
                   fp.pegging_id,
                   msi.item_name,
                   msi.inventory_item_id,
                   msi.planner_code,
                   DECODE(msi.planning_make_buy_code, 1,'MAKE', 2,'BUY') make_buy,
                   DECODE(s.order_type, 1,'PO', 3,'WO', 5,'PLANNED',
                          7,'INTRANSIT', TO_CHAR(s.order_type))        supply_type,
                   ROUND(fp.allocated_quantity, 2)                     pegged_qty,
                   s.new_schedule_date                                 supply_date,
                   d.using_assembly_demand_date                        demand_date,
                   DECODE(d.origination_type, 1,'MPS', 2,'MRP', 3,'FORECAST',
                          6,'SALES_ORDER', 7,'MANUAL', 8,'INTERORG',
                          24,'FLOW_SCHEDULE', TO_CHAR(d.origination_type))
                                                                       demand_source,
                   d.order_number                                      demand_order,
                   ROUND(s.new_schedule_date - d.using_assembly_demand_date, 0)       days_gap,
                   CASE WHEN s.new_schedule_date > d.using_assembly_demand_date THEN 'LATE'
                        WHEN s.new_schedule_date > d.using_assembly_demand_date - 3 THEN 'TIGHT'
                        ELSE 'OK' END                                  pegging_status,
                   NVL(fp.end_item_usage, 1)                            end_item_factor,
                   msi.item_name                                       end_item_name,
                   COUNT(*) OVER()                                     total_pegs,
                   COUNT(*) OVER(PARTITION BY CASE
                        WHEN s.new_schedule_date > d.using_assembly_demand_date THEN 'LATE'
                        WHEN s.new_schedule_date > d.using_assembly_demand_date - 3 THEN 'TIGHT'
                        ELSE 'OK' END)                                 count_by_status
            FROM   msc_full_pegging fp
            JOIN   msc_supplies s
              ON   s.transaction_id   = fp.transaction_id
              AND  s.plan_id          = fp.plan_id
              AND  s.sr_instance_id   = fp.sr_instance_id
            JOIN   msc_demands d
              ON   d.demand_id         = fp.demand_id
              AND  d.plan_id           = fp.plan_id
              AND  d.sr_instance_id    = fp.sr_instance_id
            JOIN   msc_system_items msi
              ON   msi.inventory_item_id = fp.inventory_item_id
              AND  msi.plan_id           = fp.plan_id
              AND  msi.sr_instance_id    = fp.sr_instance_id
            WHERE  fp.plan_id = (SELECT MAX(plan_id) FROM msc_plans
                                 WHERE plan_completion_date IS NOT NULL OR data_completion_date IS NOT NULL)
              AND  (s.new_schedule_date > d.using_assembly_demand_date
                 OR s.new_schedule_date > d.using_assembly_demand_date - 3)
            ORDER  BY (s.new_schedule_date - d.using_assembly_demand_date) DESC
            FETCH FIRST 100 ROWS ONLY
        """,
    },

    "spare_parts": {
        "label": "Spare Parts / MRO Planning",
        "sql": """
            SELECT /*+ FIRST_ROWS(100) */
                   msi.segment1                                        item_name,
                   msi.inventory_item_id,
                   msi.planner_code,
                   msi.organization_id,
                   'BUY'                                               make_buy,
                   ROUND(NVL(oh.on_hand, 0), 2)                       on_hand_qty,
                   msi.min_minmax_quantity                             reorder_point,
                   msi.max_minmax_quantity                             max_qty,
                   msi.fixed_lot_multiplier                            order_qty,
                   msi.full_lead_time,
                   NVL(usage.avg_monthly_usage, 0)                     avg_monthly_usage,
                   NVL(usage.months_of_history, 0)                     months_of_history,
                   CASE WHEN NVL(oh.on_hand, 0) = 0 AND NVL(usage.avg_monthly_usage, 0) > 0
                        THEN 'STOCKOUT_RISK'
                        WHEN NVL(oh.on_hand, 0) < NVL(msi.min_minmax_quantity, 0)
                        THEN 'BELOW_ROP'
                        WHEN NVL(oh.on_hand, 0) > NVL(msi.max_minmax_quantity, 0) * 2
                             AND NVL(usage.avg_monthly_usage, 0) > 0
                        THEN 'OVERSTOCKED'
                        WHEN NVL(usage.avg_monthly_usage, 0) = 0
                             AND NVL(oh.on_hand, 0) > 0
                        THEN 'SLOW_MOVING'
                        ELSE 'OK' END                                  spare_status,
                   CASE WHEN NVL(usage.avg_monthly_usage, 0) > 0
                        THEN ROUND(NVL(oh.on_hand, 0) / usage.avg_monthly_usage, 1)
                        ELSE NULL END                                  months_of_supply,
                   ROUND(NVL(oh.on_hand, 0) * NVL(msi.list_price, 0), 2)
                                                                       inventory_value,
                   COUNT(*) OVER()                                     total_spares
            FROM   mtl_system_items_b msi
            LEFT JOIN (SELECT inventory_item_id, organization_id,
                              SUM(transaction_quantity) on_hand
                       FROM mtl_onhand_quantities_detail
                       GROUP BY inventory_item_id, organization_id) oh
              ON   oh.inventory_item_id = msi.inventory_item_id
              AND  oh.organization_id   = msi.organization_id
            LEFT JOIN (SELECT inventory_item_id, organization_id,
                              ROUND(SUM(ABS(primary_quantity)) /
                                    GREATEST(MONTHS_BETWEEN(MAX(transaction_date),
                                                           MIN(transaction_date)), 1), 2)
                              avg_monthly_usage,
                              ROUND(MONTHS_BETWEEN(MAX(transaction_date),
                                                   MIN(transaction_date)), 0)
                              months_of_history
                       FROM mtl_material_transactions
                       WHERE transaction_type_id IN (33, 34, 35, 93, 112)
                         AND transaction_date >= ADD_MONTHS({plan_date}, -12)
                       GROUP BY inventory_item_id, organization_id) usage
              ON   usage.inventory_item_id = msi.inventory_item_id
              AND  usage.organization_id   = msi.organization_id
            WHERE  msi.planning_make_buy_code = 2
              AND  msi.inventory_item_status_code = 'Active'
              AND  (NVL(oh.on_hand, 0) < NVL(msi.min_minmax_quantity, 0)
                 OR NVL(oh.on_hand, 0) = 0
                 OR (NVL(oh.on_hand, 0) > NVL(msi.max_minmax_quantity, 0) * 2
                     AND NVL(usage.avg_monthly_usage, 0) > 0)
                 OR (NVL(usage.avg_monthly_usage, 0) = 0 AND NVL(oh.on_hand, 0) > 0))
            ORDER  BY spare_status, inventory_value DESC
            FETCH FIRST 100 ROWS ONLY
        """,
    },
}


# ─── Exception type → action recommendation mapping ─────────────────────────

EXCEPTION_ACTIONS = {
    'SHORTAGE': {
        'owner': 'Planner',
        'actionTpl': "Item {item_name}: short {quantity} units, need date {exception_date}. "
                     "{make_buy_action} Check alternate suppliers or substitutes if lead time is a concern.",
    },
    'EXCESS': {
        'owner': 'Planner',
        'actionTpl': "Item {item_name}: {quantity} excess units. "
                     "Defer or cancel incoming supply via ASCP > Planner Workbench > {item_name} > "
                     "Supply tab > select excess order > Reschedule Out or Cancel.",
    },
    'RESCHEDULE IN': {
        'owner': 'Buyer/Planner',
        'actionTpl': "Item {item_name}: expedite supply from {exception_date} to {suggested_date} "
                     "({days_delta} days earlier). Contact supplier or expedite WO. "
                     "Update in PO > Change Order or WIP > Update Job.",
    },
    'RESCHEDULE OUT': {
        'owner': 'Planner',
        'actionTpl': "Item {item_name}: defer supply from {exception_date} to {suggested_date} "
                     "({days_delta} days later). Reschedule via ASCP > Planner Workbench > Implement > Reschedule.",
    },
    'LATE SUPPLY': {
        'owner': 'Buyer',
        'actionTpl': "Item {item_name}: supply arrives {days_late} days after need date. "
                     "Supply date: {supply_date}, Need date: {need_date}. "
                     "Expedite with supplier or find alternate source. Check substitutes via ASCP > Item > Substitutes.",
    },
    'CAPACITY OVERLOAD': {
        'owner': 'Production Planner',
        'actionTpl': "Resource overloaded: {utilization_pct}% utilized (capacity: {max_capacity}). "
                     "Shift load to alternate resource, authorize overtime, or subcontract. "
                     "Navigate to ASCP > Planner Workbench > Resource tab.",
    },
    'FORECAST DEVIATION': {
        'owner': 'Demand Planner',
        'actionTpl': "Item {item_name}: forecast MAPE {mape_pct}% (forecast: {forecast_qty}, "
                     "actual: {consumed_qty}). Review demand history in Demantra or ASCP > Demand tab. "
                     "Adjust forecast parameters.",
    },
    'BELOW SAFETY STOCK': {
        'owner': 'Planner',
        'actionTpl': "Item {item_name}: on-hand {on_hand_qty} vs safety stock {safety_stock_qty} "
                     "(gap: {gap} units, lead time: {full_lead_time} days). "
                     "{make_buy_action} Consider temporary safety stock override if demand pattern changed.",
    },
    'SOURCING DEVIATION': {
        'owner': 'Buyer',
        'actionTpl': "Item {item_name}: sourcing rule says {target_pct}% from {preferred_supplier} "
                     "but actual is {actual_pct}% (deviation: {deviation_pct}%). "
                     "Review in ASCP > Sourcing > Sourcing Rules. Re-balance if needed.",
    },
    'SS_TOO_LOW': {
        'owner': 'Planner',
        'actionTpl': "Item {item_name}: safety stock covers only {ss_days_cover} days vs lead time "
                     "{full_lead_time} days. Demand CoV: {demand_cov_pct}%. Increase SS quantity or "
                     "switch to MRP-planned SS. Navigate to Item Master > Planning tab.",
    },
    'SS_TOO_HIGH': {
        'owner': 'Planner',
        'actionTpl': "Item {item_name}: safety stock covers {ss_days_cover} days (lead time only "
                     "{full_lead_time} days). Reduce SS quantity or set upper bound. "
                     "Navigate to Item Master > Planning tab.",
    },
    'NO_SS_POLICY': {
        'owner': 'Planner',
        'actionTpl': "Item {item_name} has no safety stock policy defined. Avg daily demand: "
                     "{avg_daily_demand}, lead time: {full_lead_time} days. Set up MRP-planned safety "
                     "stock in ASCP > Planning > Safety Stock Rules or fixed SS in Item Master.",
    },
    'PEGGING_LATE': {
        'owner': 'Planner/Buyer',
        'actionTpl': "Supply for {item_name} ({supply_type}, qty {pegged_qty}) arrives {supply_date} "
                     "but demand needs it by {demand_date} ({days_gap} days late). "
                     "Demand: {demand_source} order {demand_order}. End item: {end_item_name}. "
                     "Expedite or find alternate source.",
    },
    'SPARE_STOCKOUT': {
        'owner': 'MRO Planner',
        'actionTpl': "Spare part {item_name}: ZERO stock, avg monthly usage {avg_monthly_usage} units, "
                     "lead time {full_lead_time} days. Production line at risk. "
                     "Create emergency requisition: PO > Requisitions > New > enter {item_name}.",
    },
    'SPARE_OVERSTOCKED': {
        'owner': 'MRO Planner',
        'actionTpl': "Spare part {item_name}: on-hand {on_hand_qty} vs max {max_qty} "
                     "({months_of_supply} months of supply, value ${inventory_value}). "
                     "Cancel open POs or transfer to other locations.",
    },
    'SPARE_SLOW_MOVING': {
        'owner': 'MRO Planner',
        'actionTpl': "Spare part {item_name}: on-hand {on_hand_qty} units (${inventory_value}) "
                     "but zero usage in last 12 months. Candidate for disposition or return to supplier.",
    },
}


def get_exception_action(exception_type, row=None):
    """Return action recommendation for an exception type."""
    key = (exception_type or '').upper().replace('_', ' ')
    for k, v in EXCEPTION_ACTIONS.items():
        if k in key or key in k:
            action_text = v['actionTpl']
            if row:
                mb = row.get('make_buy', '')
                make_buy_action = ('BUY item \u2014 create requisition via ASCP > Planner Workbench > Release > Purchase Req.'
                                   if mb == 'BUY'
                                   else 'MAKE item \u2014 release planned WO via ASCP > Planner Workbench > Release > Discrete Job.')
                fmt = {**{k2: row.get(k2, '\u2014') for k2 in [
                    'item_name', 'quantity', 'exception_date', 'suggested_date', 'days_delta',
                    'days_late', 'supply_date', 'need_date', 'on_hand_qty', 'safety_stock_qty',
                    'gap', 'full_lead_time', 'mape_pct', 'forecast_qty', 'consumed_qty',
                    'target_pct', 'preferred_supplier', 'actual_pct', 'deviation_pct',
                    'utilization_pct', 'max_capacity', 'ss_days_cover', 'demand_cov_pct',
                    'avg_daily_demand', 'supply_type', 'pegged_qty', 'demand_date',
                    'demand_source', 'demand_order', 'end_item_name', 'days_gap',
                    'avg_monthly_usage', 'on_hand_qty', 'max_qty', 'months_of_supply',
                    'inventory_value',
                ]}, 'make_buy_action': make_buy_action}
                try:
                    action_text = action_text.format(**fmt)
                except (KeyError, ValueError):
                    pass
            return {'owner': v['owner'], 'action': action_text}
    r = row or {}
    return {
        'owner': 'Planning Team',
        'action': f"Item {r.get('item_name', '\u2014')}: review exception and contact appropriate team to resolve.",
    }


# ─── KPI computation ────────────────────────────────────────────────────────

def compute_kpis(results: dict) -> dict:
    kpis = {
        "plan_freshness_days": None,
        "demand_supply_gap": 0,
        "exception_count": 0,
        "forecast_mape": None,
        "ss_compliance_pct": None,
        "avg_days_of_supply": None,
        "late_supply_count": 0,
        "planned_order_count": 0,
        "excess_value": 0.0,
        "capacity_at_risk": 0,
    }

    # From plan_summary
    plan_rows = results.get("plan_summary", {}).get("rows", [])
    if plan_rows:
        row = plan_rows[0]
        days = row.get("days_since_run")
        if days is not None:
            kpis["plan_freshness_days"] = round(float(days), 1)
        exc = row.get("exception_count")
        if exc is not None:
            kpis["exception_count"] = int(exc)

    # From demand_supply_balance
    balance_rows = results.get("demand_supply_balance", {}).get("rows", [])
    kpis["demand_supply_gap"] = len(balance_rows)

    # From plan_exceptions (use total from window)
    exc_rows = results.get("plan_exceptions", {}).get("rows", [])
    if exc_rows and exc_rows[0].get("total_exceptions"):
        kpis["exception_count"] = int(exc_rows[0]["total_exceptions"])

    # From forecast_accuracy
    fc_rows = results.get("forecast_accuracy", {}).get("rows", [])
    if fc_rows:
        mapes = [float(r.get("mape_pct") or 0) for r in fc_rows]
        if mapes:
            kpis["forecast_mape"] = round(sum(mapes) / len(mapes), 1)

    # From safety_stock_violations
    ss_rows = results.get("safety_stock_violations", {}).get("rows", [])
    ss_violation_count = len(ss_rows)
    total_from_ss = int(ss_rows[0].get("total_violations", 0)) if ss_rows else 0
    # Approximate compliance — assume total planning items ~ total_violations + ok items
    # This is a rough estimate; in demo mode we set it directly
    if total_from_ss > 0:
        kpis["ss_compliance_pct"] = round(max(0, 100 - total_from_ss), 1)

    # From item_coverage
    cov_rows = results.get("item_coverage", {}).get("rows", [])
    if cov_rows:
        dos_vals = [float(r.get("days_of_supply") or 0) for r in cov_rows if float(r.get("days_of_supply") or 999) < 999]
        if dos_vals:
            kpis["avg_days_of_supply"] = round(sum(dos_vals) / len(dos_vals), 1)

    # From late_supply
    late_rows = results.get("late_supply", {}).get("rows", [])
    kpis["late_supply_count"] = len(late_rows)

    # From planned_orders
    po_rows = results.get("planned_orders", {}).get("rows", [])
    kpis["planned_order_count"] = len(po_rows)

    # From excess_inventory
    exc_inv_rows = results.get("excess_inventory", {}).get("rows", [])
    kpis["excess_value"] = sum(float(r.get("excess_value") or 0) for r in exc_inv_rows)

    # From supplier_capacity
    cap_rows = results.get("supplier_capacity", {}).get("rows", [])
    kpis["capacity_at_risk"] = len(cap_rows)

    return kpis


# ─── Findings computation ────────────────────────────────────────────────────

def compute_findings(kpis: dict, results: dict) -> list:
    findings = []

    # Plan freshness
    freshness = kpis["plan_freshness_days"]
    if freshness is not None and freshness > 3:
        findings.append({"severity": "CRITICAL", "category": "Stale Plan",
                          "count": 1,
                          "description": f"Plan not run in {freshness} days \u2014 data is stale"})
    elif freshness is not None and freshness > 1:
        findings.append({"severity": "HIGH", "category": "Plan Aging",
                          "count": 1,
                          "description": f"Plan last run {freshness} days ago"})

    # Exceptions
    exc = kpis["exception_count"]
    if exc > 100:
        findings.append({"severity": "CRITICAL", "category": "Plan Exceptions",
                          "count": exc,
                          "description": f"{exc} planning exceptions require attention"})
    elif exc > 20:
        findings.append({"severity": "HIGH", "category": "Plan Exceptions",
                          "count": exc,
                          "description": f"{exc} planning exceptions found"})
    elif exc > 0:
        findings.append({"severity": "MEDIUM", "category": "Plan Exceptions",
                          "count": exc,
                          "description": f"{exc} planning exceptions"})

    # Demand-supply gap
    gap = kpis["demand_supply_gap"]
    if gap > 50:
        findings.append({"severity": "CRITICAL", "category": "Supply Shortages",
                          "count": gap,
                          "description": f"{gap} items where demand exceeds supply"})
    elif gap > 10:
        findings.append({"severity": "HIGH", "category": "Supply Shortages",
                          "count": gap,
                          "description": f"{gap} items with supply gaps"})

    # Forecast MAPE
    mape = kpis["forecast_mape"]
    if mape is not None and mape > 30:
        findings.append({"severity": "HIGH", "category": "Forecast Accuracy",
                          "count": len(results.get("forecast_accuracy", {}).get("rows", [])),
                          "description": f"Average forecast MAPE {mape}% \u2014 above 30% threshold"})
    elif mape is not None and mape > 15:
        findings.append({"severity": "MEDIUM", "category": "Forecast Accuracy",
                          "count": len(results.get("forecast_accuracy", {}).get("rows", [])),
                          "description": f"Average forecast MAPE {mape}%"})

    # Late supply
    late = kpis["late_supply_count"]
    if late > 10:
        findings.append({"severity": "HIGH", "category": "Late Supply",
                          "count": late,
                          "description": f"{late} supplies arriving after demand date"})
    elif late > 0:
        findings.append({"severity": "MEDIUM", "category": "Late Supply",
                          "count": late,
                          "description": f"{late} late supplies detected"})

    # Excess
    excess = kpis["excess_value"]
    if excess > 500000:
        findings.append({"severity": "MEDIUM", "category": "Excess Inventory",
                          "count": len(results.get("excess_inventory", {}).get("rows", [])),
                          "description": f"${excess:,.0f} in excess inventory \u2014 tied-up capital"})

    # Capacity
    cap = kpis["capacity_at_risk"]
    if cap > 5:
        findings.append({"severity": "HIGH", "category": "Capacity Bottleneck",
                          "count": cap,
                          "description": f"{cap} supplier-item combos above 80% capacity"})
    elif cap > 0:
        findings.append({"severity": "MEDIUM", "category": "Capacity Constraint",
                          "count": cap,
                          "description": f"{cap} suppliers approaching capacity limits"})

    return findings


# ─── Demo data ───────────────────────────────────────────────────────────────

DEMO_KPIS = {
    "plan_freshness_days": 0.8,
    "demand_supply_gap": 18,
    "exception_count": 87,
    "forecast_mape": 22.4,
    "ss_compliance_pct": 82.0,
    "avg_days_of_supply": 14.2,
    "late_supply_count": 11,
    "planned_order_count": 34,
    "excess_value": 345200.00,
    "capacity_at_risk": 4,
}

DEMO_FINDINGS = [
    {"severity": "HIGH", "category": "Plan Exceptions", "count": 87,
     "description": "87 planning exceptions \u2014 42 shortages, 28 excess, 11 late supply, 6 capacity"},
    {"severity": "HIGH", "category": "Supply Shortages", "count": 18,
     "description": "18 items where demand exceeds available supply"},
    {"severity": "MEDIUM", "category": "Forecast Accuracy", "count": 15,
     "description": "Average forecast MAPE 22.4% \u2014 15 items with >10% deviation"},
    {"severity": "HIGH", "category": "Late Supply", "count": 11,
     "description": "11 supplies arriving after demand date \u2014 customer orders at risk"},
    {"severity": "MEDIUM", "category": "Excess Inventory", "count": 8,
     "description": "$345,200 in excess inventory across 8 items"},
]
