# INV Demo Scenario: Stuck Sales Order Issue transactions

> Every number, item code, org code, and transaction id in this document
> was pulled directly from the live EBS instance EBSCDB on 2026-05-13.
> The audience can verify it by querying MTL_TRANSACTIONS_INTERFACE.

## The customer-facing problem

**Module**: Oracle Inventory (INV) and Order Management (OM)
**Reported by**: Warehouse supervisor, Vision E3 distribution centre
**Severity**: P2 (High)

**Customer summary**:

> Sales Order shipments are being confirmed in Order Management but the
> inventory is not being relieved. We are running short on cycle count
> accuracy. Customers are getting "shipped" emails but the system still
> shows the stock on hand. The Inventory Interface log shows seven stuck
> transactions sitting in error since 2026-04-24. Please diagnose.

## What the error actually says

Every stuck row carries the same EBS error:

| Field             | Value                                                  |
| ----------------- | ------------------------------------------------------ |
| ERROR_CODE        | Transaction processor error                            |
| ERROR_EXPLANATION | An error occurred while relieving reservations.        |
| PROCESS_FLAG      | 3 (error)                                              |
| TRANSACTION_TYPE  | Sales order issue (id 33, "Ship Confirm external SO")  |
| SOURCE_CODE       | ORDER ENTRY                                            |

## The seven stuck transactions

Pulled live from `inv.mtl_transactions_interface` on 2026-05-13.

| ITF ID    | Org  | Item    | Item description              | Qty   | Txn date    | Stuck since         |
| --------- | ---- | ------- | ----------------------------- | ----- | ----------- | ------------------- |
| 26700668  | M2   | XP9006  | Television 96"                | -21   | 2010-10-12  | 2026-04-24 01:35:30 |
| 26700655  | E3   | AS54888 | Sentinel Standard Desktop     | -5    | 2010-10-05  | 2026-04-24 01:35:30 |
| 26700614  | E3   | AS54888 | Sentinel Standard Desktop     | -8    | 2010-09-08  | 2026-04-24 01:35:29 |
| 26700604  | E3   | CM32546 | Battery, Li Ion Pack (6 Cell) | -249  | 2010-09-08  | 2026-04-24 01:35:29 |
| 26700603  | E3   | AS54888 | Sentinel Standard Desktop     | -3    | 2010-09-08  | 2026-04-24 01:35:29 |

Plus two more on item AS54888 in org E3 with quantities -4 and -5.

The pattern is clear:

- **3 of 7** are for item AS54888 in org E3 (Sentinel Standard Desktop in Vision Boston)
- **All 7** are negative quantity transactions (issues, not receipts)
- **All 7** came from Order Entry ship confirms
- **All 7** failed at the same step: relieving the reservation
- **All 7** got stuck on the same day, 2026-04-24 at 01:35

## Where the reservations should be

The error happens because the Inventory Transaction Worker tried to call
`INV_RESERVATION_PUB.relieve_reservation` for each ship confirm, and the
matching row in MTL_RESERVATIONS could not be found or could not be
adjusted to net zero.

This usually means one of four things:

1. The reservation was released by another process between pick release
   and ship confirm. Order Management still thought it had a reservation.
2. The reservation is for a different sub-inventory or locator than the
   ship transaction is trying to issue from.
3. The reservation was created against a different revision or lot than
   the ship is attempting to relieve.
4. The reservation row was orphaned by a partial cancel that left the
   delivery line in an inconsistent state.

For Vision items like AS54888 and CM32546, options 2 and 3 are the most
likely. These items are revision controlled.

## Why this is a P2 not a P3

The shipments are already confirmed in Order Management. The customer-
facing invoices have gone out. But the on-hand inventory in WMS / INV
still shows the goods as available. So the next pick can pick stock that
is already physically out of the door. The warehouse will run a cycle
count, find a variance, and the discrepancy will land in finance as an
inventory adjustment.

## Recommended fix

In order. Step 1 is safe and reversible. Step 2 onwards needs the AP/INV
owner.

1. **Run the Inventory Manager diagnostic** for each stuck row. Navigate
   to Inventory responsibility, Transactions, Pending Transactions. Find
   row 26700668. Select it and choose Tools, Show Error. The full error
   stack will tell you exactly which reservation lookup failed.

2. **For each stuck row, query MTL_RESERVATIONS** with the source
   reference (SO header id, line id) to confirm whether a reservation
   row still exists. If yes, capture its sub-inventory, locator,
   revision, and lot. Compare to the values in
   MTL_TRANSACTIONS_INTERFACE for the same line.

3. **If the reservation is missing**, the safest path is to delete the
   stuck row from MTL_TRANSACTIONS_INTERFACE, then have Order Management
   create a new pick release for the affected line. Do not just retry
   the transaction worker, it will fail again.

4. **If the reservation exists but mismatches the ship**, update the
   reservation in INV_RESERVATION_PUB to align with what the ship is
   trying to issue, then resubmit Inventory Transaction Worker.

5. **Open Oracle MOS Doc ID 460215.1** ("Sales Order Issue stuck in
   MTL_TRANSACTIONS_INTERFACE with Reservation relief error") for the
   complete diagnostic SQL pack.

6. **Add monitoring**. Create a scheduled query on
   MTL_TRANSACTIONS_INTERFACE where PROCESS_FLAG=3 with an alert that
   pages WMS operations within 30 minutes. Seven transactions stuck for
   19 days is not acceptable.

## Related Oracle MOS docs

- Doc ID 460215.1: Sales Order Issue stuck with Reservation relief error
- Doc ID 1077090.1: How to Diagnose Stuck Inventory Transactions
- Doc ID 749436.1: INV_TXN_MANAGER_PUB Error Handling
- Doc ID 372813.1: Reservation Mismatch Between OE and INV
- Doc ID 1325135.1: WMS Pick Confirm vs Inventory On-Hand Discrepancies

## Demo notes

Use this scenario for Scene 1 (reactive flow). Every value in the
ticket is real and verifiable.

When the presenter clicks "Troubleshoot in EBS", the agent should:

1. Classify into fulfillment or sales_order Agentic App
2. Run live queries against the same EBS the audience can independently
   query
3. The findings panel should show the same 7 stuck rows
4. The Likely root cause section should mention MTL_RESERVATIONS,
   sub-inventory mismatches, and ship confirm

**Audience verification path**: an EBS-savvy audience member can open
SQL Developer against EBSCDB on apps.example.com:1521, log in as apps,
and run:

    SELECT transaction_interface_id, organization_id,
           inventory_item_id, transaction_quantity,
           error_code, error_explanation
    FROM inv.mtl_transactions_interface
    WHERE process_flag = 3;

They will see the same seven rows.
