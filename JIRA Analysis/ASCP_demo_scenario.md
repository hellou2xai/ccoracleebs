# ASCP Demo Scenario: Memory Based Snapshot failure

## The customer-facing problem

**Module**: Oracle Advanced Supply Chain Planning (ASCP)
**Reported by**: Master Scheduler, NA Manufacturing
**Reported at**: 2026-05-13 07:48 local
**Severity**: P2 (High)

**Customer summary**:

> The overnight ASCP plan did not refresh. Our master scheduling dashboards
> are showing yesterday's data, ATP for new sales orders is wrong, and the
> 03:42 batch failed with a database error. We need this resolved before
> the 10:00 production meeting. Order Management is already escalating
> three customer orders with bad promise dates.

## The failed concurrent program

| Attribute                | Value                                                                  |
| ------------------------ | ---------------------------------------------------------------------- |
| Program (short name)     | MSCNSP                                                                 |
| Program (long name)      | Memory Based Snapshot Workers                                          |
| Request ID               | 8847123                                                                |
| Phase / Status           | COMPLETED / ERROR (Phase=C, Status=E)                                  |
| Submitted by             | APPS                                                                   |
| Submitted at             | 2026-05-13 03:42:18                                                    |
| Actual start             | 2026-05-13 03:42:31                                                    |
| Actual completion        | 2026-05-13 03:58:04                                                    |
| Argument 1 (Plan name)   | ASCP_NA_MFG_PLAN                                                       |
| Argument 2 (Plan ID)     | 401                                                                    |
| Argument 3 (Snapshot)    | MEMORY_BASED                                                           |
| Completion text          | Concurrent Manager encountered an error during snapshot phase          |

## What the log shows

The relevant lines from the request log (FND_CONCURRENT_REQUESTS.LOGFILE_NAME):

```
03:42:31 INFO  MSCNSP-1010: Memory Based Snapshot starting for plan ASCP_NA_MFG_PLAN
03:42:33 INFO  MSCNSP-2003: Spawning 8 parallel workers
03:51:18 ERROR ORA-12801: error signaled in parallel query server P008
03:51:18 ERROR ORA-01555: snapshot too old: rollback segment number 14
                with name "_SYSSMU14_3092830574$" too small
03:51:19 ERROR MSCNSP-9001: Worker P008 failed reading MSC_SYSTEM_ITEMS
03:51:19 ERROR MSCNSP-9100: Snapshot phase aborted. No partial data committed.
03:58:04 INFO  Program completed with error.
```

## What we found in the EBS tables

Cross-referenced four ASCP and database tables.

### MSC_PLAN_RUNS for plan 401

The plan has not had a successful run since 2026-05-11. The last two
attempts (yesterday and today) both failed in the snapshot phase.

```
PLAN_RUN_ID  PLAN_ID  START_DATE           END_DATE             STATUS
2147         401      2026-05-11 03:42:18  2026-05-11 04:38:51  COMPLETE
2148         401      2026-05-12 03:42:14  2026-05-12 03:55:09  ERROR
2149         401      2026-05-13 03:42:31  2026-05-13 03:58:04  ERROR
```

### MSC_EXCEPTION_DETAILS for plan 401

Three exceptions raised by the failed run.

```
EXCEPTION_TYPE                     COUNT  FIRST_SEEN
PLAN_SNAPSHOT_INCOMPLETE             1    2026-05-12 03:55:09
DEMAND_NOT_REFRESHED                 1    2026-05-12 03:55:09
ATP_BASIS_STALE                      1    2026-05-13 03:58:04
```

### MSC_DEMANDS staleness

The MSC_DEMANDS table is 47,832 rows. Last refresh was 2026-05-11 03:55 (when
the last successful plan ran). The two failed runs have not updated it. Any
ATP query is reading data that is 50 hours old.

### Standard Collection (MSCNCS) on the source instance

The Standard Collection job that should populate MSC_SYSTEM_ITEMS,
MSC_BOMS, and MSC_RESOURCES before the snapshot runs:

| Request ID | Submitted          | Status   |
| ---------- | ------------------ | -------- |
| 8841902    | 2026-05-11 23:42   | COMPLETE |
| 8845671    | 2026-05-12 23:42   | ERROR    |
| 8847002    | 2026-05-13 03:25   | RUNNING  |

The 23:42 collection on 2026-05-12 failed (which is why the 03:42 snapshot
also failed). Someone resubmitted at 03:25 today, and that resubmission is
still running. It started 17 minutes before the snapshot, then both
processes were touching MSC_SYSTEM_ITEMS at the same time.

## Likely root cause

Two issues stacked on top of each other.

1. **UNDO_RETENTION is too low**. The database undo retention is set to 900
   seconds (15 minutes). The Memory Based Snapshot in parallel mode reads
   MSC_SYSTEM_ITEMS, MSC_BOMS, and MSC_RESOURCES with a read-consistent
   query that takes 8 to 10 minutes. When the concurrent Standard
   Collection on instance 2 updated MSC_SYSTEM_ITEMS during that read
   window, the snapshot lost its rollback view and worker P008 raised
   ORA-01555.

2. **Standard Collection 23:42 schedule is too close to Snapshot 03:42**.
   When the 23:42 collection runs long (because of overnight Item Open
   Interface batches feeding MSC_SYSTEM_ITEMS), the operator pattern is to
   resubmit in the morning. That resubmission collides with the 03:42
   snapshot window. Once the resubmission was triggered at 03:25, the
   collision was guaranteed.

The primary cause is the schedule collision. The undo retention is the
proximate cause of the error, but raising it without fixing the schedule
will only push the problem out by a few minutes.

## Recommended fix

1. **Resubmit the failed snapshot** once the in-progress collection
   completes. Navigate to ASCP Plan Workbench, Plan ASCP_NA_MFG_PLAN, then
   Plan, Launch Plan, with Snapshot phase enabled. Or resubmit request
   8847123 from System Administrator, Concurrent, Requests.

2. **Increase UNDO_RETENTION** on the destination database to 3600 seconds
   (one hour) and confirm the UNDO tablespace has AUTOEXTEND on. SQL:
   `ALTER SYSTEM SET UNDO_RETENTION=3600 SCOPE=BOTH;` then verify with
   `SELECT TUNED_UNDORETENTION FROM V$UNDOSTAT WHERE ROWNUM=1;`

3. **Reschedule Standard Collection** to complete at least 60 minutes
   before the Snapshot runs. Move the nightly Standard Collection from
   23:42 to 22:00. Set its argument REFRESH_NUMBER appropriately so
   downstream targeted refresh still works. Confirm there is no other
   process that updates MSC_SYSTEM_ITEMS during the 03:00 to 04:00 window.

4. **Stop manual resubmissions during the snapshot window**. Add an
   operational rule: if Standard Collection fails, alert the DBA and skip
   that day's snapshot rather than resubmit at 03:25.

5. **Add monitoring**. Configure an alert on MSC_PLAN_RUNS so any plan run
   with STATUS=ERROR pages the on-call DBA. The current pattern of finding
   out at 07:48 (when master schedulers open their dashboards) is too
   late.

6. **Verify after the run**. Once the resubmitted snapshot completes,
   confirm MSC_PLAN_RUNS shows STATUS=COMPLETE, MSC_DEMANDS row count
   matches expected (~48K), and MSC_EXCEPTION_DETAILS no longer shows
   PLAN_SNAPSHOT_INCOMPLETE for plan 401.

## Related Oracle MOS docs

- Doc ID 1326260.1: How to Diagnose ASCP Memory Based Snapshot Errors
- Doc ID 432384.1: ORA-01555 Snapshot Too Old in ASCP Plan Run
- Doc ID 1357887.1: ASCP Plan Run Performance Tuning
- Doc ID 269021.1: Troubleshooting ASCP Collections
- Doc ID 1083387.1: Configuring UNDO_RETENTION for Long-Running Reports

## Demo notes

Use this scenario for Scene 1 of the L1/L2 demo (reactive flow).

The agent should:

1. Be classified into the ASCP / planning module by Claude
2. Run the cycle_count or resilience Agentic Apps for evidence
3. Surface MSC_PLAN_RUNS error rows and the ORA-01555 pattern
4. Produce a report that names UNDO_RETENTION, MSC_SYSTEM_ITEMS, and the
   schedule collision

When the demo presenter clicks "Troubleshoot in EBS", the AI report should
match the manual analysis above closely. If it does not, that is a useful
talking point: the AI surfaces the data, the human still controls the
narrative.
