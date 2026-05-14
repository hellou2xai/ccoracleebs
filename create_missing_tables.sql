-- ============================================================
-- Create all missing Oracle EBS tables in PostgreSQL
-- and populate with realistic demo data
-- ============================================================

BEGIN;

-- ============================================================
-- FINANCE TABLES
-- ============================================================

-- 1. AP_INVOICES_ALL
CREATE TABLE IF NOT EXISTS ap_invoices_all (
    invoice_id INTEGER PRIMARY KEY,
    invoice_num VARCHAR(50),
    invoice_date TIMESTAMP,
    vendor_id INTEGER,
    invoice_amount NUMERIC(15,2),
    currency_code VARCHAR(15),
    wfapproval_status VARCHAR(50),
    posting_status VARCHAR(1),
    source VARCHAR(80),
    creation_date TIMESTAMP,
    cancelled_date TIMESTAMP
);

-- 2. AP_HOLDS_ALL
CREATE TABLE IF NOT EXISTS ap_holds_all (
    hold_id SERIAL PRIMARY KEY,
    invoice_id INTEGER,
    hold_lookup_code VARCHAR(25),
    hold_reason TEXT,
    creation_date TIMESTAMP,
    release_lookup_code VARCHAR(25)
);

-- 3. AP_INV_SELECTION_CRITERIA_ALL
CREATE TABLE IF NOT EXISTS ap_inv_selection_criteria_all (
    checkrun_id INTEGER PRIMARY KEY,
    checkrun_name VARCHAR(100),
    status VARCHAR(25),
    vendor_pay_group VARCHAR(25),
    check_date TIMESTAMP,
    creation_date TIMESTAMP,
    currency_code VARCHAR(15)
);

-- 4. AP_PAYMENT_SCHEDULES_ALL
CREATE TABLE IF NOT EXISTS ap_payment_schedules_all (
    payment_schedule_id SERIAL PRIMARY KEY,
    invoice_id INTEGER,
    payment_num INTEGER,
    discount_date TIMESTAMP,
    discount_amount_remaining NUMERIC(15,2),
    gross_amount NUMERIC(15,2),
    currency_code VARCHAR(15),
    payment_status_flag VARCHAR(1)
);

-- 5. AR_PAYMENT_SCHEDULES_ALL
CREATE TABLE IF NOT EXISTS ar_payment_schedules_all (
    payment_schedule_id INTEGER PRIMARY KEY,
    status VARCHAR(30),
    due_date TIMESTAMP,
    amount_due_remaining NUMERIC(15,2),
    invoice_currency_code VARCHAR(15)
);

-- 6. AR_CASH_RECEIPTS_ALL
CREATE TABLE IF NOT EXISTS ar_cash_receipts_all (
    cash_receipt_id INTEGER PRIMARY KEY,
    receipt_number VARCHAR(30),
    receipt_date TIMESTAMP,
    amount NUMERIC(15,2),
    currency_code VARCHAR(15),
    status VARCHAR(30),
    pay_from_customer INTEGER
);

-- 7. GL_JE_HEADERS
CREATE TABLE IF NOT EXISTS gl_je_headers (
    je_header_id INTEGER PRIMARY KEY,
    name VARCHAR(100),
    je_source VARCHAR(25),
    je_category VARCHAR(25),
    period_name VARCHAR(15),
    ledger_id INTEGER,
    status VARCHAR(1),
    running_total_dr NUMERIC(15,2),
    running_total_cr NUMERIC(15,2),
    creation_date TIMESTAMP,
    created_by INTEGER,
    actual_flag VARCHAR(1)
);

-- 8. GL_PERIOD_STATUSES
CREATE TABLE IF NOT EXISTS gl_period_statuses (
    period_status_id SERIAL PRIMARY KEY,
    period_name VARCHAR(15),
    closing_status VARCHAR(1),
    ledger_id INTEGER,
    period_type VARCHAR(15)
);

-- 9. GL_PERIODS
CREATE TABLE IF NOT EXISTS gl_periods (
    period_name VARCHAR(15) PRIMARY KEY,
    start_date TIMESTAMP,
    end_date TIMESTAMP,
    period_type VARCHAR(15),
    period_year INTEGER,
    period_num INTEGER
);

-- 10. GL_BALANCES
CREATE TABLE IF NOT EXISTS gl_balances (
    balance_id SERIAL PRIMARY KEY,
    ledger_id INTEGER,
    period_name VARCHAR(15),
    code_combination_id INTEGER,
    period_net_dr NUMERIC(15,2),
    period_net_cr NUMERIC(15,2),
    actual_flag VARCHAR(1),
    period_year INTEGER
);

-- 11. XLA_EVENTS
CREATE TABLE IF NOT EXISTS xla_events (
    event_id INTEGER PRIMARY KEY,
    event_type_code VARCHAR(30),
    event_date TIMESTAMP,
    process_status_code VARCHAR(1),
    entity_code VARCHAR(25),
    source_id_int_1 INTEGER,
    application_id INTEGER,
    creation_date TIMESTAMP
);

-- ============================================================
-- SCM TABLES
-- ============================================================

-- 12. ENG_ENGINEERING_CHANGES
CREATE TABLE IF NOT EXISTS eng_engineering_changes (
    change_notice VARCHAR(10) PRIMARY KEY,
    change_name VARCHAR(240),
    status_code INTEGER,
    initiation_date TIMESTAMP,
    scheduled_date TIMESTAMP
);

-- 13. PO_REQUISITION_HEADERS_ALL
CREATE TABLE IF NOT EXISTS po_requisition_headers_all (
    requisition_header_id INTEGER PRIMARY KEY,
    segment1 VARCHAR(20),
    type_lookup_code VARCHAR(25),
    authorization_status VARCHAR(25),
    preparer_id INTEGER,
    creation_date TIMESTAMP
);

-- 14. PO_HEADERS_ALL
CREATE TABLE IF NOT EXISTS po_headers_all (
    po_header_id INTEGER PRIMARY KEY,
    segment1 VARCHAR(20),
    type_lookup_code VARCHAR(25),
    authorization_status VARCHAR(25),
    vendor_id INTEGER,
    currency_code VARCHAR(15),
    creation_date TIMESTAMP
);

-- 15. WSH_DELIVERY_DETAILS
CREATE TABLE IF NOT EXISTS wsh_delivery_details (
    delivery_detail_id INTEGER PRIMARY KEY,
    source_line_id INTEGER,
    released_status VARCHAR(1),
    organization_id INTEGER,
    requested_quantity NUMERIC(15,2),
    inventory_item_id INTEGER,
    date_scheduled TIMESTAMP,
    source_code VARCHAR(30)
);

-- 16. OE_ORDER_HOLDS_ALL
CREATE TABLE IF NOT EXISTS oe_order_holds_all (
    order_hold_id SERIAL PRIMARY KEY,
    header_id INTEGER,
    hold_source_id INTEGER,
    creation_date TIMESTAMP,
    released_flag VARCHAR(1)
);

-- 17. OE_ORDER_HEADERS_ALL
CREATE TABLE IF NOT EXISTS oe_order_headers_all (
    header_id INTEGER PRIMARY KEY,
    order_number INTEGER,
    flow_status_code VARCHAR(30),
    booked_flag VARCHAR(1),
    booked_date TIMESTAMP,
    transactional_curr_code VARCHAR(15)
);

-- 18. OE_ORDER_LINES_ALL
CREATE TABLE IF NOT EXISTS oe_order_lines_all (
    line_id INTEGER PRIMARY KEY,
    header_id INTEGER,
    flow_status_code VARCHAR(30),
    schedule_ship_date TIMESTAMP,
    ordered_quantity NUMERIC(15,2),
    unit_selling_price NUMERIC(15,2),
    order_quantity_uom VARCHAR(3)
);

-- 19. MTL_CYCLE_COUNT_ENTRIES
CREATE TABLE IF NOT EXISTS mtl_cycle_count_entries (
    cycle_count_entry_id INTEGER PRIMARY KEY,
    inventory_item_id INTEGER,
    organization_id INTEGER,
    subinventory VARCHAR(10),
    count_quantity NUMERIC(15,2),
    system_quantity NUMERIC(15,2),
    entry_status_code INTEGER,
    count_date TIMESTAMP
);

-- ============================================================
-- PLANNING / WORKFLOW TABLES
-- ============================================================

-- 20. FND_CONCURRENT_QUEUES_VL
CREATE TABLE IF NOT EXISTS fnd_concurrent_queues_vl (
    concurrent_queue_id INTEGER PRIMARY KEY,
    user_concurrent_queue_name VARCHAR(240),
    max_processes INTEGER,
    running_processes INTEGER,
    enabled_flag VARCHAR(1),
    manager_type INTEGER
);

-- 21. FND_CONCURRENT_REQUESTS
CREATE TABLE IF NOT EXISTS fnd_concurrent_requests (
    request_id INTEGER PRIMARY KEY,
    phase_code VARCHAR(1),
    status_code VARCHAR(1),
    concurrent_program_id INTEGER,
    requested_by INTEGER,
    actual_start_date TIMESTAMP,
    controlling_manager INTEGER
);

-- 22. WF_ITEM_ACTIVITY_STATUSES
CREATE TABLE IF NOT EXISTS wf_item_activity_statuses (
    activity_status_id SERIAL PRIMARY KEY,
    item_type VARCHAR(8),
    item_key VARCHAR(240),
    activity_status VARCHAR(8),
    activity_result_code VARCHAR(30),
    error_name VARCHAR(30),
    begin_date TIMESTAMP
);

-- 23. WF_NOTIFICATIONS
CREATE TABLE IF NOT EXISTS wf_notifications (
    notification_id INTEGER PRIMARY KEY,
    message_type VARCHAR(8),
    message_name VARCHAR(30),
    status VARCHAR(8),
    mail_status VARCHAR(8),
    recipient_role VARCHAR(320),
    begin_date TIMESTAMP,
    due_date TIMESTAMP,
    subject TEXT
);

-- ============================================================
-- TRUNCATE ALL TABLES BEFORE INSERT (idempotent reruns)
-- ============================================================
TRUNCATE ap_invoices_all CASCADE;
TRUNCATE ap_holds_all CASCADE;
TRUNCATE ap_inv_selection_criteria_all CASCADE;
TRUNCATE ap_payment_schedules_all CASCADE;
TRUNCATE ar_payment_schedules_all CASCADE;
TRUNCATE ar_cash_receipts_all CASCADE;
TRUNCATE gl_je_headers CASCADE;
TRUNCATE gl_period_statuses CASCADE;
TRUNCATE gl_periods CASCADE;
TRUNCATE gl_balances CASCADE;
TRUNCATE xla_events CASCADE;
TRUNCATE eng_engineering_changes CASCADE;
TRUNCATE po_requisition_headers_all CASCADE;
TRUNCATE po_headers_all CASCADE;
TRUNCATE wsh_delivery_details CASCADE;
TRUNCATE oe_order_holds_all CASCADE;
TRUNCATE oe_order_headers_all CASCADE;
TRUNCATE oe_order_lines_all CASCADE;
TRUNCATE mtl_cycle_count_entries CASCADE;
TRUNCATE fnd_concurrent_queues_vl CASCADE;
TRUNCATE fnd_concurrent_requests CASCADE;
TRUNCATE wf_item_activity_statuses CASCADE;
TRUNCATE wf_notifications CASCADE;

-- ============================================================
-- DATA: AP_INVOICES_ALL (70 rows)
-- ============================================================
INSERT INTO ap_invoices_all (invoice_id, invoice_num, invoice_date, vendor_id, invoice_amount, currency_code, wfapproval_status, posting_status, source, creation_date, cancelled_date)
SELECT
    s.id,
    'INV-' || LPAD(s.id::text, 6, '0'),
    CURRENT_DATE - (random()*90)::int * INTERVAL '1 day',
    (ARRAY[1001,1002,1003,1004,1005,1006,1007,1008,1009,1010])[1 + (s.id % 10)],
    round((random()*50000 + 500)::numeric, 2),
    (ARRAY['USD','USD','USD','EUR','GBP','INR','USD','USD','CAD','USD'])[1 + (s.id % 10)],
    (ARRAY['APPROVED','APPROVED','APPROVED','WFAPPROVED','REJECTED','NOT REQUIRED','INITIATED','APPROVED','APPROVED','MANUALLY APPROVED'])[1 + (s.id % 10)],
    (ARRAY['Y','Y','Y','Y','N','Y','N','Y','Y','Y'])[1 + (s.id % 10)],
    (ARRAY['Manual Invoice Entry','ERS','Manual Invoice Entry','SelfService','EDI Gateway','Manual Invoice Entry','XML GATEWAY','Manual Invoice Entry','ERS','Recurring'])[1 + (s.id % 10)],
    CURRENT_DATE - (random()*95)::int * INTERVAL '1 day',
    CASE WHEN s.id % 15 = 0 THEN CURRENT_DATE - (random()*30)::int * INTERVAL '1 day' ELSE NULL END
FROM generate_series(1,70) AS s(id);

-- ============================================================
-- DATA: AP_HOLDS_ALL (60 rows) - some released, some active
-- ============================================================
INSERT INTO ap_holds_all (invoice_id, hold_lookup_code, hold_reason, creation_date, release_lookup_code)
SELECT
    1 + (s.id % 70),
    (ARRAY['PRICE','QTY REC','QTY ORD','TAX AMOUNT','AWT ERROR','DIST VARIANCE','AMOUNT','VENDOR','INSUFFICIENT FUNDS','FINAL MATCHING'])[1 + (s.id % 10)],
    (ARRAY[
        'Price variance exceeds tolerance',
        'Quantity received mismatch',
        'Quantity ordered mismatch',
        'Tax amount discrepancy',
        'AWT calculation error',
        'Distribution variance found',
        'Amount exceeds PO limit',
        'Vendor on hold',
        'Budget not available',
        'Final match quantity differs'
    ])[1 + (s.id % 10)],
    CURRENT_DATE - (random()*60)::int * INTERVAL '1 day',
    CASE WHEN s.id % 3 = 0 THEN 'MANUAL RELEASE' WHEN s.id % 5 = 0 THEN 'HOLDS QUICK RELEASE' ELSE NULL END
FROM generate_series(1,60) AS s(id);

-- ============================================================
-- DATA: AP_INV_SELECTION_CRITERIA_ALL (15 rows)
-- ============================================================
INSERT INTO ap_inv_selection_criteria_all (checkrun_id, checkrun_name, status, vendor_pay_group, check_date, creation_date, currency_code)
SELECT
    s.id,
    'PAYRUN-' || TO_CHAR(CURRENT_DATE - (s.id * 7) * INTERVAL '1 day', 'YYYYMMDD'),
    (ARRAY['CONFIRMED','CONFIRMED','SELECTING','FORMATTED','CONFIRMING','OVERFLOW','CONFIRMED','SET UP','CONFIRMED','CALCULATED','CONFIRMED','CONFIRMED','SELECTING','CONFIRMED','UNSTARTED'])[s.id],
    (ARRAY['STANDARD','STANDARD','EMPLOYEE','STANDARD','STANDARD','PRIORITY','EMPLOYEE','STANDARD','STANDARD','PRIORITY','STANDARD','STANDARD','EMPLOYEE','STANDARD','STANDARD'])[s.id],
    CURRENT_DATE - (s.id * 7 - 2) * INTERVAL '1 day',
    CURRENT_DATE - (s.id * 7) * INTERVAL '1 day',
    (ARRAY['USD','USD','USD','EUR','USD','GBP','USD','USD','INR','USD','USD','CAD','USD','USD','USD'])[s.id]
FROM generate_series(1,15) AS s(id);

-- ============================================================
-- DATA: AP_PAYMENT_SCHEDULES_ALL (70 rows)
-- ============================================================
INSERT INTO ap_payment_schedules_all (invoice_id, payment_num, discount_date, discount_amount_remaining, gross_amount, currency_code, payment_status_flag)
SELECT
    s.id,
    1,
    CURRENT_DATE + ((15 - random()*30)::int) * INTERVAL '1 day',
    CASE WHEN s.id % 4 = 0 THEN round((random()*500)::numeric, 2) ELSE 0 END,
    round((random()*50000 + 500)::numeric, 2),
    (ARRAY['USD','USD','EUR','USD','GBP','USD','INR','USD','USD','CAD'])[1 + (s.id % 10)],
    (ARRAY['N','N','N','Y','N','N','Y','N','N','P'])[1 + (s.id % 10)]
FROM generate_series(1,70) AS s(id);

-- ============================================================
-- DATA: AR_PAYMENT_SCHEDULES_ALL (65 rows)
-- ============================================================
INSERT INTO ar_payment_schedules_all (payment_schedule_id, status, due_date, amount_due_remaining, invoice_currency_code)
SELECT
    s.id,
    (ARRAY['OP','OP','OP','CL','OP','OP','CL','OP','OP','CL'])[1 + (s.id % 10)],
    CURRENT_DATE + ((30 - random()*90)::int) * INTERVAL '1 day',
    CASE WHEN s.id % 4 = 0 THEN 0 ELSE round((random()*25000 + 100)::numeric, 2) END,
    (ARRAY['USD','USD','EUR','USD','GBP','USD','INR','USD','CAD','USD'])[1 + (s.id % 10)]
FROM generate_series(1,65) AS s(id);

-- ============================================================
-- DATA: AR_CASH_RECEIPTS_ALL (55 rows)
-- ============================================================
INSERT INTO ar_cash_receipts_all (cash_receipt_id, receipt_number, receipt_date, amount, currency_code, status, pay_from_customer)
SELECT
    s.id,
    'RCT-' || LPAD(s.id::text, 6, '0'),
    CURRENT_DATE - (random()*60)::int * INTERVAL '1 day',
    round((random()*30000 + 200)::numeric, 2),
    (ARRAY['USD','USD','EUR','USD','GBP','USD','INR','USD','USD','CAD'])[1 + (s.id % 10)],
    (ARRAY['APP','APP','UNAPP','APP','REV','APP','NSF','APP','UNID','APP'])[1 + (s.id % 10)],
    2000 + (s.id % 20)
FROM generate_series(1,55) AS s(id);

-- ============================================================
-- DATA: GL_PERIODS (18 rows - 18 months)
-- ============================================================
INSERT INTO gl_periods (period_name, start_date, end_date, period_type, period_year, period_num)
SELECT
    TO_CHAR(d, 'MON-YY'),
    date_trunc('month', d),
    (date_trunc('month', d) + INTERVAL '1 month' - INTERVAL '1 day'),
    'Month',
    EXTRACT(YEAR FROM d)::int,
    EXTRACT(MONTH FROM d)::int
FROM generate_series(
    date_trunc('month', CURRENT_DATE - INTERVAL '12 months'),
    date_trunc('month', CURRENT_DATE + INTERVAL '5 months'),
    INTERVAL '1 month'
) AS d
ON CONFLICT (period_name) DO NOTHING;

-- ============================================================
-- DATA: GL_PERIOD_STATUSES (18 rows per ledger, 2 ledgers)
-- ============================================================
INSERT INTO gl_period_statuses (period_name, closing_status, ledger_id, period_type)
SELECT
    gp.period_name,
    CASE
        WHEN gp.end_date < CURRENT_DATE - INTERVAL '2 months' THEN 'C'
        WHEN gp.end_date < CURRENT_DATE THEN 'O'
        WHEN gp.start_date <= CURRENT_DATE AND gp.end_date >= CURRENT_DATE THEN 'O'
        ELSE 'F'
    END,
    ledger.id,
    'Month'
FROM gl_periods gp
CROSS JOIN (SELECT 1 AS id UNION SELECT 2) ledger;

-- ============================================================
-- DATA: GL_JE_HEADERS (60 rows)
-- ============================================================
INSERT INTO gl_je_headers (je_header_id, name, je_source, je_category, period_name, ledger_id, status, running_total_dr, running_total_cr, creation_date, created_by, actual_flag)
SELECT
    s.id,
    'Journal Batch ' || s.id,
    (ARRAY['Payables','Receivables','Assets','Manual','Inventory','Payables','Cost Management','Manual','Receivables','Payables'])[1 + (s.id % 10)],
    (ARRAY['Purchase Invoices','Sales Invoices','Depreciation','Adjustment','Material','Accrual','Revaluation','Correction','Misc Receipts','Payments'])[1 + (s.id % 10)],
    TO_CHAR(CURRENT_DATE - (random()*120)::int * INTERVAL '1 day', 'MON-YY'),
    1 + (s.id % 2),
    (ARRAY['P','P','P','U','P','P','E','P','P','P'])[1 + (s.id % 10)],
    round((random()*100000 + 1000)::numeric, 2),
    round((random()*100000 + 1000)::numeric, 2),
    CURRENT_DATE - (random()*120)::int * INTERVAL '1 day',
    1000 + (s.id % 5),
    'A'
FROM generate_series(1,60) AS s(id);

-- ============================================================
-- DATA: GL_BALANCES (80 rows)
-- ============================================================
INSERT INTO gl_balances (ledger_id, period_name, code_combination_id, period_net_dr, period_net_cr, actual_flag, period_year)
SELECT
    1 + (s.id % 2),
    gp.period_name,
    10000 + (s.id % 25),
    round((random()*50000)::numeric, 2),
    round((random()*50000)::numeric, 2),
    'A',
    gp.period_year
FROM generate_series(1,5) AS s(id)
CROSS JOIN gl_periods gp
LIMIT 80;

-- ============================================================
-- DATA: XLA_EVENTS (70 rows)
-- ============================================================
INSERT INTO xla_events (event_id, event_type_code, event_date, process_status_code, entity_code, source_id_int_1, application_id, creation_date)
SELECT
    s.id,
    (ARRAY['INVOICE VALIDATED','INVOICE CANCELLED','PAYMENT CREATED','RECEIPT APPLICATION','DEBIT MEMO','CREDIT MEMO','ADJUSTMENT','RECEIPT CREATION','INVOICE ADJUSTED','PAYMENT CLEARED'])[1 + (s.id % 10)],
    CURRENT_DATE - (random()*60)::int * INTERVAL '1 day',
    (ARRAY['P','P','P','U','P','P','E','P','I','P'])[1 + (s.id % 10)],
    (ARRAY['AP_INVOICES','AP_INVOICES','AP_PAYMENTS','AR_RECEIPTS','AR_TRANSACTIONS','AR_TRANSACTIONS','AR_ADJUSTMENTS','AR_RECEIPTS','AP_INVOICES','AP_PAYMENTS'])[1 + (s.id % 10)],
    s.id,
    (ARRAY[200,200,200,222,222,222,222,222,200,200])[1 + (s.id % 10)],
    CURRENT_DATE - (random()*60)::int * INTERVAL '1 day'
FROM generate_series(1,70) AS s(id);

-- ============================================================
-- DATA: ENG_ENGINEERING_CHANGES (12 rows)
-- ============================================================
INSERT INTO eng_engineering_changes (change_notice, change_name, status_code, initiation_date, scheduled_date)
SELECT
    'ECO-' || LPAD(s.id::text, 4, '0'),
    (ARRAY[
        'Rev B - Motor Assembly Update',
        'Material Change - Casing',
        'Tolerance Update - Shaft',
        'New BOM - Pump Assembly',
        'Design Change - PCB Layout',
        'Supplier Change - Bearings',
        'Spec Update - Paint Coating',
        'Safety Fix - Guard Rail',
        'Cost Reduction - Bracket',
        'Rev C - Sensor Module',
        'Process Change - Welding',
        'Drawing Update - Housing'
    ])[s.id],
    (ARRAY[1,1,4,6,1,7,1,4,1,6,1,7])[s.id],
    CURRENT_DATE - (s.id * 10 + 5) * INTERVAL '1 day',
    CURRENT_DATE + ((30 - s.id * 5)::int) * INTERVAL '1 day'
FROM generate_series(1,12) AS s(id);

-- ============================================================
-- DATA: PO_REQUISITION_HEADERS_ALL (60 rows)
-- ============================================================
INSERT INTO po_requisition_headers_all (requisition_header_id, segment1, type_lookup_code, authorization_status, preparer_id, creation_date)
SELECT
    s.id,
    'REQ-' || LPAD(s.id::text, 6, '0'),
    (ARRAY['PURCHASE','PURCHASE','INTERNAL','PURCHASE','PURCHASE','PURCHASE','INTERNAL','PURCHASE','PURCHASE','PURCHASE'])[1 + (s.id % 10)],
    (ARRAY['APPROVED','APPROVED','IN PROCESS','APPROVED','REJECTED','APPROVED','PRE-APPROVED','APPROVED','INCOMPLETE','APPROVED'])[1 + (s.id % 10)],
    1000 + (s.id % 8),
    CURRENT_DATE - (random()*90)::int * INTERVAL '1 day'
FROM generate_series(1,60) AS s(id);

-- ============================================================
-- DATA: PO_HEADERS_ALL (55 rows)
-- ============================================================
INSERT INTO po_headers_all (po_header_id, segment1, type_lookup_code, authorization_status, vendor_id, currency_code, creation_date)
SELECT
    s.id,
    'PO-' || LPAD(s.id::text, 6, '0'),
    (ARRAY['STANDARD','STANDARD','BLANKET','STANDARD','CONTRACT','STANDARD','PLANNED','STANDARD','STANDARD','BLANKET'])[1 + (s.id % 10)],
    (ARRAY['APPROVED','APPROVED','IN PROCESS','APPROVED','REQUIRES REAPPROVAL','APPROVED','PRE-APPROVED','APPROVED','INCOMPLETE','APPROVED'])[1 + (s.id % 10)],
    1001 + (s.id % 10),
    (ARRAY['USD','USD','EUR','USD','GBP','USD','INR','USD','USD','CAD'])[1 + (s.id % 10)],
    CURRENT_DATE - (random()*90)::int * INTERVAL '1 day'
FROM generate_series(1,55) AS s(id);

-- ============================================================
-- DATA: WSH_DELIVERY_DETAILS (65 rows)
-- ============================================================
INSERT INTO wsh_delivery_details (delivery_detail_id, source_line_id, released_status, organization_id, requested_quantity, inventory_item_id, date_scheduled, source_code)
SELECT
    s.id,
    s.id,
    (ARRAY['R','R','S','Y','R','B','R','C','R','N'])[1 + (s.id % 10)],
    (ARRAY[101,101,102,101,103,101,102,101,103,101])[1 + (s.id % 10)],
    round((random()*500 + 1)::numeric, 2),
    3000 + (s.id % 30),
    CURRENT_DATE + ((10 - random()*20)::int) * INTERVAL '1 day',
    (ARRAY['OE','OE','OE','OE','OE','OE','OE','OE','OE','OE'])[1 + (s.id % 10)]
FROM generate_series(1,65) AS s(id);

-- ============================================================
-- DATA: OE_ORDER_HEADERS_ALL (50 rows)
-- ============================================================
INSERT INTO oe_order_headers_all (header_id, order_number, flow_status_code, booked_flag, booked_date, transactional_curr_code)
SELECT
    s.id,
    100000 + s.id,
    (ARRAY['BOOKED','BOOKED','ENTERED','CLOSED','BOOKED','AWAITING_SHIPPING','BOOKED','CANCELLED','AWAITING_RETURN','BOOKED'])[1 + (s.id % 10)],
    (ARRAY['Y','Y','N','Y','Y','Y','Y','N','Y','Y'])[1 + (s.id % 10)],
    CASE WHEN s.id % 10 NOT IN (2,7) THEN CURRENT_DATE - (random()*60)::int * INTERVAL '1 day' ELSE NULL END,
    (ARRAY['USD','USD','EUR','USD','GBP','USD','INR','USD','CAD','USD'])[1 + (s.id % 10)]
FROM generate_series(1,50) AS s(id);

-- ============================================================
-- DATA: OE_ORDER_LINES_ALL (75 rows)
-- ============================================================
INSERT INTO oe_order_lines_all (line_id, header_id, flow_status_code, schedule_ship_date, ordered_quantity, unit_selling_price, order_quantity_uom)
SELECT
    s.id,
    1 + (s.id % 50),
    (ARRAY['AWAITING_SHIPPING','SHIPPED','FULFILLED','CANCELLED','BOOKED','AWAITING_SHIPPING','CLOSED','PICKED','AWAITING_SHIPPING','PRODUCTION_COMPLETE'])[1 + (s.id % 10)],
    CURRENT_DATE + ((14 - random()*28)::int) * INTERVAL '1 day',
    round((random()*200 + 1)::numeric, 2),
    round((random()*999 + 10)::numeric, 2),
    (ARRAY['EA','EA','KG','EA','LB','EA','MT','EA','EA','CS'])[1 + (s.id % 10)]
FROM generate_series(1,75) AS s(id);

-- ============================================================
-- DATA: OE_ORDER_HOLDS_ALL (30 rows)
-- ============================================================
INSERT INTO oe_order_holds_all (header_id, hold_source_id, creation_date, released_flag)
SELECT
    1 + (s.id % 50),
    s.id,
    CURRENT_DATE - (random()*45)::int * INTERVAL '1 day',
    (ARRAY['N','N','N','Y','N','N','Y','N','N','N'])[1 + (s.id % 10)]
FROM generate_series(1,30) AS s(id);

-- ============================================================
-- DATA: MTL_CYCLE_COUNT_ENTRIES (55 rows)
-- ============================================================
INSERT INTO mtl_cycle_count_entries (cycle_count_entry_id, inventory_item_id, organization_id, subinventory, count_quantity, system_quantity, entry_status_code, count_date)
SELECT
    s.id,
    3000 + (s.id % 30),
    (ARRAY[101,101,102,101,103,101,102,101,103,101])[1 + (s.id % 10)],
    (ARRAY['FGI','RAW','WIP','FGI','RAW','RECV','FGI','RAW','WIP','PACK'])[1 + (s.id % 10)],
    round((random()*1000)::numeric, 2),
    round((random()*1000)::numeric, 2),
    (ARRAY[1,2,5,1,3,5,1,2,4,5])[1 + (s.id % 10)],
    CURRENT_DATE - (random()*30)::int * INTERVAL '1 day'
FROM generate_series(1,55) AS s(id);

-- ============================================================
-- DATA: FND_CONCURRENT_QUEUES_VL (10 rows)
-- ============================================================
INSERT INTO fnd_concurrent_queues_vl (concurrent_queue_id, user_concurrent_queue_name, max_processes, running_processes, enabled_flag, manager_type)
VALUES
    (1, 'Standard Manager', 10, 8, 'Y', 1),
    (2, 'Conflict Resolution Manager', 1, 1, 'Y', 4),
    (3, 'Inventory Manager', 5, 3, 'Y', 1),
    (4, 'Output Post Processor', 3, 2, 'Y', 3),
    (5, 'Internal Monitor', 1, 0, 'Y', 2),
    (6, 'Workflow Agent Listener', 2, 2, 'Y', 6),
    (7, 'MRP Manager', 4, 0, 'N', 1),
    (8, 'PO Document Approval Manager', 3, 3, 'Y', 1),
    (9, 'Receivables Tax Manager', 2, 1, 'Y', 1),
    (10, 'Shipping Transaction Manager', 3, 2, 'Y', 1);

-- ============================================================
-- DATA: FND_CONCURRENT_REQUESTS (80 rows)
-- ============================================================
INSERT INTO fnd_concurrent_requests (request_id, phase_code, status_code, concurrent_program_id, requested_by, actual_start_date, controlling_manager)
SELECT
    50000 + s.id,
    (ARRAY['C','C','C','R','C','C','C','P','C','C'])[1 + (s.id % 10)],
    (ARRAY['C','C','E','I','C','C','W','I','C','G'])[1 + (s.id % 10)],
    100 + (s.id % 25),
    1000 + (s.id % 8),
    CURRENT_DATE - (random()*7)::int * INTERVAL '1 day' + (random()*24)::int * INTERVAL '1 hour',
    1 + (s.id % 10)
FROM generate_series(1,80) AS s(id);

-- ============================================================
-- DATA: WF_ITEM_ACTIVITY_STATUSES (60 rows)
-- ============================================================
INSERT INTO wf_item_activity_statuses (item_type, item_key, activity_status, activity_result_code, error_name, begin_date)
SELECT
    (ARRAY['APINV','APINV','POAPPRV','OEOH','OEOL','APINV','POAPPRV','REQAPPRV','APINV','OEOH'])[1 + (s.id % 10)],
    s.id::text,
    (ARRAY['COMPLETE','COMPLETE','ERROR','ACTIVE','COMPLETE','SUSPEND','COMPLETE','NOTIFIED','DEFERRED','COMPLETE'])[1 + (s.id % 10)],
    (ARRAY['APPROVED','APPROVED','#EXCEPTION','#NULL','COMPLETE','#NULL','REJECTED','#NULL','#NULL','APPROVED'])[1 + (s.id % 10)],
    CASE WHEN (s.id % 10) = 2 THEN 'WFENG_EXCEPTION' WHEN (s.id % 10) = 5 THEN 'TIMEOUT' ELSE NULL END,
    CURRENT_DATE - (random()*30)::int * INTERVAL '1 day'
FROM generate_series(1,60) AS s(id);

-- ============================================================
-- DATA: WF_NOTIFICATIONS (65 rows)
-- ============================================================
INSERT INTO wf_notifications (notification_id, message_type, message_name, status, mail_status, recipient_role, begin_date, due_date, subject)
SELECT
    s.id,
    (ARRAY['APINV','APINV','POAPPRV','OEOH','REQAPPRV','APINV','POAPPRV','REQAPPRV','APINV','OEOH'])[1 + (s.id % 10)],
    (ARRAY['APPROVE_INV','APPROVE_INV','APPROVE_PO','BOOK_ORDER','APPROVE_REQ','FYI_INV','REJECT_PO','FYI_REQ','APPROVE_INV','CANCEL_ORDER'])[1 + (s.id % 10)],
    (ARRAY['OPEN','OPEN','CLOSED','OPEN','OPEN','CANCELED','CLOSED','OPEN','OPEN','CLOSED'])[1 + (s.id % 10)],
    (ARRAY['SENT','SENT','SENT','FAILED','SENT','SENT','SENT','SENT','MAIL','SENT'])[1 + (s.id % 10)],
    (ARRAY['JSMITH','MJONES','KPATEL','LCHEN','JSMITH','RDAVIS','MJONES','KPATEL','AWILSON','LCHEN'])[1 + (s.id % 10)],
    CURRENT_DATE - (random()*30)::int * INTERVAL '1 day',
    CURRENT_DATE + ((7 - random()*14)::int) * INTERVAL '1 day',
    (ARRAY[
        'Invoice INV-' || LPAD(s.id::text,6,'0') || ' requires your approval - Amount: $' || (1000 + s.id * 100)::text,
        'Invoice INV-' || LPAD(s.id::text,6,'0') || ' pending review - Vendor: ACME Corp',
        'Purchase Order PO-' || LPAD(s.id::text,6,'0') || ' approved successfully',
        'Sales Order ' || (100000+s.id)::text || ' ready for booking',
        'Requisition REQ-' || LPAD(s.id::text,6,'0') || ' requires approval - IT Equipment',
        'FYI: Invoice processed for payment batch',
        'Purchase Order PO-' || LPAD(s.id::text,6,'0') || ' has been rejected',
        'FYI: Requisition auto-approved per policy',
        'Urgent: Invoice INV-' || LPAD(s.id::text,6,'0') || ' on hold - action required',
        'Order cancellation request - Order ' || (100000+s.id)::text
    ])[1 + (s.id % 10)]
FROM generate_series(1,65) AS s(id);

-- ============================================================
-- UPDATE SYNC_STATUS TABLE
-- ============================================================
INSERT INTO sync_status (table_name, status, last_sync_at, last_sync_mode, rows_synced, started_at, finished_at)
VALUES
    ('ap_invoices_all', 'success', CURRENT_TIMESTAMP, 'full', 70, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('ap_holds_all', 'success', CURRENT_TIMESTAMP, 'full', 60, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('ap_inv_selection_criteria_all', 'success', CURRENT_TIMESTAMP, 'full', 15, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('ap_payment_schedules_all', 'success', CURRENT_TIMESTAMP, 'full', 70, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('ar_payment_schedules_all', 'success', CURRENT_TIMESTAMP, 'full', 65, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('ar_cash_receipts_all', 'success', CURRENT_TIMESTAMP, 'full', 55, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('gl_je_headers', 'success', CURRENT_TIMESTAMP, 'full', 60, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('gl_period_statuses', 'success', CURRENT_TIMESTAMP, 'full', 36, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('gl_periods', 'success', CURRENT_TIMESTAMP, 'full', 18, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('gl_balances', 'success', CURRENT_TIMESTAMP, 'full', 80, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('xla_events', 'success', CURRENT_TIMESTAMP, 'full', 70, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('eng_engineering_changes', 'success', CURRENT_TIMESTAMP, 'full', 12, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('po_requisition_headers_all', 'success', CURRENT_TIMESTAMP, 'full', 60, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('po_headers_all', 'success', CURRENT_TIMESTAMP, 'full', 55, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('wsh_delivery_details', 'success', CURRENT_TIMESTAMP, 'full', 65, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('oe_order_holds_all', 'success', CURRENT_TIMESTAMP, 'full', 30, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('oe_order_headers_all', 'success', CURRENT_TIMESTAMP, 'full', 50, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('oe_order_lines_all', 'success', CURRENT_TIMESTAMP, 'full', 75, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('mtl_cycle_count_entries', 'success', CURRENT_TIMESTAMP, 'full', 55, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('fnd_concurrent_queues_vl', 'success', CURRENT_TIMESTAMP, 'full', 10, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('fnd_concurrent_requests', 'success', CURRENT_TIMESTAMP, 'full', 80, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('wf_item_activity_statuses', 'success', CURRENT_TIMESTAMP, 'full', 60, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('wf_notifications', 'success', CURRENT_TIMESTAMP, 'full', 65, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON CONFLICT (table_name) DO UPDATE
SET status = EXCLUDED.status,
    last_sync_at = EXCLUDED.last_sync_at,
    last_sync_mode = EXCLUDED.last_sync_mode,
    rows_synced = EXCLUDED.rows_synced,
    started_at = EXCLUDED.started_at,
    finished_at = EXCLUDED.finished_at;

COMMIT;
