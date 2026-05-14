"""
Render the ASCP demo scenario as a PDF inside JIRA Analysis/.
Run from the project root:
    python "JIRA Analysis/build_ascp_pdf.py"
"""
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_JUSTIFY, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, ListFlowable, ListItem,
    Table, TableStyle, PageBreak, HRFlowable, Preformatted,
)


# ─── Theme ──────────────────────────────────────────────────────────────────
ACCENT      = colors.HexColor("#0052cc")
ACCENT_DARK = colors.HexColor("#003d99")
TEXT_DARK   = colors.HexColor("#1f2328")
TEXT_MUTED  = colors.HexColor("#636c76")
BG_PANEL    = colors.HexColor("#f4f7fb")
BG_CODE     = colors.HexColor("#0d1117")
TEXT_CODE   = colors.HexColor("#e6edf3")
RULE        = colors.HexColor("#d0d7de")
SEV_RED     = colors.HexColor("#cf222e")
SEV_AMBER   = colors.HexColor("#9a6700")
SEV_GREEN   = colors.HexColor("#1a7f37")


def _header_footer(canvas, doc):
    width, height = A4
    canvas.saveState()
    canvas.setFillColor(ACCENT)
    canvas.rect(0, height - 18 * mm, width, 18 * mm, stroke=0, fill=1)
    canvas.setFillColor(colors.white)
    canvas.setFont("Helvetica-Bold", 11)
    canvas.drawString(20 * mm, height - 11 * mm,
                      "Oracle EBS Support Agent")
    canvas.setFont("Helvetica", 9)
    canvas.drawRightString(width - 20 * mm, height - 11 * mm,
                           "ASCP Plan Failure: Demo Scenario")
    canvas.setStrokeColor(RULE)
    canvas.setLineWidth(0.4)
    canvas.line(20 * mm, 14 * mm, width - 20 * mm, 14 * mm)
    canvas.setFillColor(TEXT_MUTED)
    canvas.setFont("Helvetica", 8)
    canvas.drawString(20 * mm, 9 * mm,
                      "Confidential. Prepared for internal review.")
    canvas.drawRightString(width - 20 * mm, 9 * mm, f"Page {doc.page}")
    canvas.restoreState()


# ─── Styles ─────────────────────────────────────────────────────────────────
styles = getSampleStyleSheet()
H_TITLE = ParagraphStyle("Title", parent=styles["Title"],
    fontName="Helvetica-Bold", fontSize=24, leading=30,
    textColor=TEXT_DARK, spaceAfter=6)
H_SUB = ParagraphStyle("Sub", parent=styles["Normal"],
    fontName="Helvetica", fontSize=12, leading=16,
    textColor=TEXT_MUTED, spaceAfter=16)
H1 = ParagraphStyle("H1", parent=styles["Heading1"],
    fontName="Helvetica-Bold", fontSize=15, leading=20,
    textColor=ACCENT_DARK, spaceBefore=14, spaceAfter=6)
H2 = ParagraphStyle("H2", parent=styles["Heading2"],
    fontName="Helvetica-Bold", fontSize=11.5, leading=16,
    textColor=TEXT_DARK, spaceBefore=10, spaceAfter=3)
H3 = ParagraphStyle("H3", parent=styles["Heading3"],
    fontName="Helvetica-Bold", fontSize=9.5, leading=13,
    textColor=ACCENT, spaceBefore=6, spaceAfter=2,
    textTransform="uppercase")
BODY = ParagraphStyle("Body", parent=styles["Normal"],
    fontName="Helvetica", fontSize=9.5, leading=13.5,
    textColor=TEXT_DARK, alignment=TA_JUSTIFY, spaceAfter=5)
BODY_LEFT = ParagraphStyle("BodyL", parent=BODY, alignment=TA_LEFT)
QUOTE = ParagraphStyle("Quote", parent=BODY,
    fontName="Helvetica-Oblique", textColor=TEXT_MUTED,
    leftIndent=12, rightIndent=12, spaceBefore=2, spaceAfter=10)
META = ParagraphStyle("Meta", parent=BODY,
    fontSize=9, leading=12, textColor=TEXT_MUTED)
CODE = ParagraphStyle("Code", parent=styles["Code"],
    fontName="Courier", fontSize=8, leading=11,
    textColor=TEXT_CODE, backColor=BG_CODE,
    leftIndent=8, rightIndent=8, spaceBefore=4, spaceAfter=8,
    borderPadding=8, borderRadius=4)
BULLET = ParagraphStyle("Bullet", parent=BODY, leftIndent=2,
    spaceAfter=2, alignment=TA_LEFT)


# ─── Helpers ────────────────────────────────────────────────────────────────
def bullets(items):
    return ListFlowable(
        [ListItem(Paragraph(t, BULLET), leftIndent=6) for t in items],
        bulletType="bullet", bulletColor=ACCENT, leftIndent=14,
    )


def numbered(items):
    return ListFlowable(
        [ListItem(Paragraph(t, BULLET), leftIndent=6) for t in items],
        bulletType="1", bulletColor=ACCENT_DARK, leftIndent=14,
        bulletFontName="Helvetica-Bold",
    )


def info_panel(title, paragraphs, bg=BG_PANEL, border=RULE):
    inner = [Paragraph(f"<b>{title}</b>", H3)]
    inner.extend(paragraphs)
    t = Table([[inner]], colWidths=[170 * mm])
    t.setStyle(TableStyle([
        ("BACKGROUND",   (0, 0), (-1, -1), bg),
        ("BOX",          (0, 0), (-1, -1), 0.5, border),
        ("LEFTPADDING",  (0, 0), (-1, -1), 10),
        ("RIGHTPADDING", (0, 0), (-1, -1), 10),
        ("TOPPADDING",   (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING",(0, 0), (-1, -1), 10),
    ]))
    return t


def sev_badge_table(rows):
    """Severity strip at the top of the page: P2, ASCP, ERROR, Request 8847123."""
    cells = []
    for label, value, color in rows:
        cells.append([
            Paragraph(f'<font color="white" size=7><b>{label}</b></font>', BODY_LEFT),
            Paragraph(f'<font color="white" size=10><b>{value}</b></font>', BODY_LEFT),
        ])
    table_rows = [
        [Table([cell], colWidths=[None],
               style=TableStyle([
                   ("BACKGROUND", (0, 0), (-1, -1), color),
                   ("TOPPADDING", (0, 0), (-1, -1), 6),
                   ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
                   ("LEFTPADDING", (0, 0), (-1, -1), 10),
                   ("RIGHTPADDING", (0, 0), (-1, -1), 10),
               ]))
         for cell, color in zip(cells, [r[2] for r in rows])]
    ]
    t = Table(table_rows, colWidths=[170 * mm / len(rows)] * len(rows))
    t.setStyle(TableStyle([
        ("LEFTPADDING",  (0, 0), (-1, -1), 1),
        ("RIGHTPADDING", (0, 0), (-1, -1), 1),
        ("TOPPADDING",   (0, 0), (-1, -1), 0),
        ("BOTTOMPADDING",(0, 0), (-1, -1), 0),
    ]))
    return t


def kv_table(rows, widths=(55 * mm, 115 * mm)):
    data = [[Paragraph(f"<b>{k}</b>", META), Paragraph(v, META)] for k, v in rows]
    t = Table(data, colWidths=list(widths))
    t.setStyle(TableStyle([
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LINEBELOW", (0, 0), (-1, -2), 0.25, RULE),
        ("TOPPADDING", (0, 0), (-1, -1), 3),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
    ]))
    return t


def data_table(headers, rows, widths=None, row_colors=None):
    head_para = [Paragraph(f"<font color='white'><b>{h}</b></font>", BODY_LEFT)
                 for h in headers]
    body = [[Paragraph(str(c), BODY_LEFT) for c in r] for r in rows]
    data = [head_para] + body

    if widths is None:
        widths = [170 * mm / len(headers)] * len(headers)
    t = Table(data, colWidths=widths, repeatRows=1)
    style = TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), ACCENT_DARK),
        ("TEXTCOLOR",  (0, 0), (-1, 0), colors.white),
        ("FONT",       (0, 0), (-1, 0), "Helvetica-Bold", 9),
        ("FONT",       (0, 1), (-1, -1), "Helvetica", 8.5),
        ("LEFTPADDING",  (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("TOPPADDING",   (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING",(0, 0), (-1, -1), 5),
        ("LINEBELOW",  (0, 0), (-1, -1), 0.25, RULE),
        ("VALIGN",     (0, 0), (-1, -1), "MIDDLE"),
    ])
    if row_colors:
        for i, c in enumerate(row_colors, start=1):
            if c:
                style.add("BACKGROUND", (0, i), (-1, i), c)
    t.setStyle(style)
    return t


def code_block(text):
    return Preformatted(text, CODE)


# ─── Build ──────────────────────────────────────────────────────────────────

def build():
    here = Path(__file__).parent
    out = here / "ASCP_Demo_Scenario.pdf"

    doc = SimpleDocTemplate(
        str(out), pagesize=A4,
        leftMargin=20 * mm, rightMargin=20 * mm,
        topMargin=28 * mm, bottomMargin=22 * mm,
        title="ASCP Demo Scenario", author="Oracle EBS Support Agent",
    )

    story = []

    # ── Cover-ish title ────────────────────────────────────────────────────
    story += [
        Spacer(1, 6 * mm),
        Paragraph("ASCP Plan Failure", H_TITLE),
        Paragraph("Memory Based Snapshot Workers (MSCNSP) failed during the overnight refresh, "
                  "blocking master scheduling and producing wrong ATP for new sales orders.",
                  H_SUB),
        sev_badge_table([
            ("PRIORITY", "P2 / High", SEV_AMBER),
            ("MODULE",   "ASCP",      ACCENT),
            ("STATUS",   "ERROR",     SEV_RED),
            ("REQUEST",  "8847123",   colors.HexColor("#1f2328")),
        ]),
        Spacer(1, 6 * mm),
    ]

    # ── Customer-facing problem ────────────────────────────────────────────
    story += [
        Paragraph("Customer-facing problem", H1),
        kv_table([
            ("Module",        "Oracle Advanced Supply Chain Planning (ASCP)"),
            ("Reported by",   "Master Scheduler, NA Manufacturing"),
            ("Reported at",   "2026-05-13 07:48 local"),
            ("Severity",      "P2 (High). Production meeting at 10:00 is at risk."),
            ("Business impact", "Master scheduling dashboards on stale data. "
                                "ATP wrong for at least three customer orders. "
                                "Order Management already escalating."),
        ]),
        Spacer(1, 4 * mm),
        info_panel("Customer summary (verbatim)", [Paragraph(
            "The overnight ASCP plan did not refresh. Our master scheduling "
            "dashboards are showing yesterday's data, ATP for new sales orders "
            "is wrong, and the 03:42 batch failed with a database error. We "
            "need this resolved before the 10:00 production meeting. Order "
            "Management is already escalating three customer orders with bad "
            "promise dates.",
            QUOTE,
        )]),

        # ── Failed program details ─────────────────────────────────────────
        Paragraph("The failed concurrent program", H1),
        kv_table([
            ("Program (short name)", "MSCNSP"),
            ("Program (long name)",  "Memory Based Snapshot Workers"),
            ("Request ID",           "8847123"),
            ("Phase / Status",       "COMPLETED / ERROR (Phase=C, Status=E)"),
            ("Submitted by",         "APPS"),
            ("Submitted at",         "2026-05-13 03:42:18"),
            ("Actual start",         "2026-05-13 03:42:31"),
            ("Actual completion",    "2026-05-13 03:58:04"),
            ("Plan name",            "ASCP_NA_MFG_PLAN"),
            ("Plan ID",              "401"),
            ("Snapshot mode",        "MEMORY_BASED"),
            ("Completion text",      "Concurrent Manager encountered an error during snapshot phase."),
        ]),

        PageBreak(),

        # ── Log excerpt ────────────────────────────────────────────────────
        Paragraph("Request log excerpt", H1),
        Paragraph("Relevant lines from the request log "
                  "(FND_CONCURRENT_REQUESTS.LOGFILE_NAME). The error is an "
                  "ORA-01555 raised inside a parallel query worker.",
                  BODY),
        code_block(
            "03:42:31 INFO  MSCNSP-1010: Memory Based Snapshot starting for plan ASCP_NA_MFG_PLAN\n"
            "03:42:33 INFO  MSCNSP-2003: Spawning 8 parallel workers\n"
            "03:51:18 ERROR ORA-12801: error signaled in parallel query server P008\n"
            "03:51:18 ERROR ORA-01555: snapshot too old: rollback segment number 14\n"
            "                with name \"_SYSSMU14_3092830574$\" too small\n"
            "03:51:19 ERROR MSCNSP-9001: Worker P008 failed reading MSC_SYSTEM_ITEMS\n"
            "03:51:19 ERROR MSCNSP-9100: Snapshot phase aborted. No partial data committed.\n"
            "03:58:04 INFO  Program completed with error."
        ),

        # ── Plan runs ──────────────────────────────────────────────────────
        Paragraph("MSC_PLAN_RUNS for plan 401", H1),
        Paragraph("The plan has not had a successful run since 2026-05-11. "
                  "The last two attempts both failed in the snapshot phase.",
                  BODY),
        data_table(
            ["PLAN_RUN_ID", "PLAN_ID", "START_DATE", "END_DATE", "STATUS"],
            [
                ["2147", "401", "2026-05-11 03:42:18", "2026-05-11 04:38:51", "COMPLETE"],
                ["2148", "401", "2026-05-12 03:42:14", "2026-05-12 03:55:09", "ERROR"],
                ["2149", "401", "2026-05-13 03:42:31", "2026-05-13 03:58:04", "ERROR"],
            ],
            widths=[22 * mm, 18 * mm, 42 * mm, 42 * mm, 26 * mm],
            row_colors=[None,
                        colors.HexColor("#fde8ea"),
                        colors.HexColor("#fde8ea")],
        ),

        Spacer(1, 4 * mm),

        # ── Exceptions ─────────────────────────────────────────────────────
        Paragraph("MSC_EXCEPTION_DETAILS raised by the failed runs", H1),
        data_table(
            ["EXCEPTION_TYPE", "COUNT", "FIRST_SEEN"],
            [
                ["PLAN_SNAPSHOT_INCOMPLETE", "1", "2026-05-12 03:55:09"],
                ["DEMAND_NOT_REFRESHED",     "1", "2026-05-12 03:55:09"],
                ["ATP_BASIS_STALE",          "1", "2026-05-13 03:58:04"],
            ],
            widths=[70 * mm, 30 * mm, 50 * mm],
        ),

        Spacer(1, 4 * mm),

        Paragraph("MSC_DEMANDS staleness", H1),
        Paragraph("The MSC_DEMANDS table is 47,832 rows. Last refresh was "
                  "2026-05-11 03:55 (the last successful run). Any ATP query "
                  "is currently reading data that is 50 hours old.",
                  BODY),

        Spacer(1, 4 * mm),

        # ── Standard Collection ────────────────────────────────────────────
        Paragraph("Standard Collection runs on the source instance", H1),
        Paragraph("The Standard Collection job that populates "
                  "MSC_SYSTEM_ITEMS, MSC_BOMS, and MSC_RESOURCES before the "
                  "snapshot runs.",
                  BODY),
        data_table(
            ["REQUEST_ID", "SUBMITTED",         "STATUS"],
            [
                ["8841902", "2026-05-11 23:42", "COMPLETE"],
                ["8845671", "2026-05-12 23:42", "ERROR"],
                ["8847002", "2026-05-13 03:25", "RUNNING"],
            ],
            widths=[40 * mm, 70 * mm, 40 * mm],
            row_colors=[None,
                        colors.HexColor("#fde8ea"),
                        colors.HexColor("#fff4d6")],
        ),
        Spacer(1, 2 * mm),
        Paragraph("The 23:42 collection on 2026-05-12 failed (which is why "
                  "the 03:42 snapshot also failed). Someone resubmitted at "
                  "03:25 today, and that resubmission is still running. It "
                  "started 17 minutes before the snapshot, then both "
                  "processes were touching MSC_SYSTEM_ITEMS at the same time.",
                  BODY),

        PageBreak(),

        # ── Root cause ─────────────────────────────────────────────────────
        Paragraph("Likely root cause", H1),
        Paragraph("Two issues stacked on top of each other.", BODY),
        numbered([
            "<b>UNDO_RETENTION is too low.</b> The database undo retention is "
            "set to 900 seconds (15 minutes). The Memory Based Snapshot in "
            "parallel mode reads MSC_SYSTEM_ITEMS, MSC_BOMS, and "
            "MSC_RESOURCES with a read-consistent query that takes 8 to 10 "
            "minutes. When the concurrent Standard Collection on instance 2 "
            "updated MSC_SYSTEM_ITEMS during that read window, the snapshot "
            "lost its rollback view and worker P008 raised ORA-01555.",

            "<b>Standard Collection 23:42 schedule is too close to Snapshot "
            "03:42.</b> When the 23:42 collection runs long (because of "
            "overnight Item Open Interface batches feeding MSC_SYSTEM_ITEMS), "
            "the operator pattern is to resubmit in the morning. That "
            "resubmission collides with the 03:42 snapshot window. Once the "
            "resubmission was triggered at 03:25, the collision was "
            "guaranteed.",
        ]),
        Spacer(1, 4 * mm),
        info_panel("Primary vs proximate", [Paragraph(
            "The primary cause is the schedule collision. The undo retention "
            "is the proximate cause of the error, but raising it without "
            "fixing the schedule will only push the problem out by a few "
            "minutes.",
            BODY,
        )]),

        # ── Fix ────────────────────────────────────────────────────────────
        Paragraph("Recommended fix", H1),
        numbered([
            "<b>Resubmit the failed snapshot</b> once the in-progress "
            "collection completes. ASCP Plan Workbench, Plan "
            "ASCP_NA_MFG_PLAN, then Plan, Launch Plan, with Snapshot phase "
            "enabled. Or resubmit request 8847123 from System Administrator, "
            "Concurrent, Requests.",

            "<b>Increase UNDO_RETENTION</b> on the destination database to "
            "3600 seconds (one hour) and confirm the UNDO tablespace has "
            "AUTOEXTEND on. SQL: ALTER SYSTEM SET UNDO_RETENTION=3600 "
            "SCOPE=BOTH; then verify with SELECT TUNED_UNDORETENTION FROM "
            "V$UNDOSTAT WHERE ROWNUM=1.",

            "<b>Reschedule Standard Collection</b> to complete at least 60 "
            "minutes before the Snapshot runs. Move the nightly Standard "
            "Collection from 23:42 to 22:00. Confirm there is no other "
            "process that updates MSC_SYSTEM_ITEMS during the 03:00 to 04:00 "
            "window.",

            "<b>Stop manual resubmissions during the snapshot window.</b> "
            "Add an operational rule: if Standard Collection fails, alert "
            "the DBA and skip that day's snapshot rather than resubmit at "
            "03:25.",

            "<b>Add monitoring.</b> Configure an alert on MSC_PLAN_RUNS so "
            "any plan run with STATUS=ERROR pages the on-call DBA. Finding "
            "out at 07:48 when master schedulers open their dashboards is "
            "too late.",

            "<b>Verify after the run.</b> Confirm MSC_PLAN_RUNS shows "
            "STATUS=COMPLETE, MSC_DEMANDS row count matches expected (about "
            "48,000), and MSC_EXCEPTION_DETAILS no longer shows "
            "PLAN_SNAPSHOT_INCOMPLETE for plan 401.",
        ]),

        PageBreak(),

        # ── MOS docs ───────────────────────────────────────────────────────
        Paragraph("Related Oracle MOS docs", H1),
        bullets([
            "Doc ID 1326260.1: How to Diagnose ASCP Memory Based Snapshot Errors",
            "Doc ID 432384.1: ORA-01555 Snapshot Too Old in ASCP Plan Run",
            "Doc ID 1357887.1: ASCP Plan Run Performance Tuning",
            "Doc ID 269021.1: Troubleshooting ASCP Collections",
            "Doc ID 1083387.1: Configuring UNDO_RETENTION for Long-Running Reports",
        ]),

        # ── Demo notes ─────────────────────────────────────────────────────
        Paragraph("How to use this in the demo", H1),
        Paragraph("Use this scenario for Scene 1 (reactive flow). It is "
                  "specific enough to feel real and short enough to fit in "
                  "four minutes.",
                  BODY),
        Paragraph("Recommended live flow", H2),
        numbered([
            "Pre-create a JIRA ticket in the SUP project titled "
            "<i>ASCP overnight plan run failed. Master scheduling on stale data.</i> "
            "Paste the customer summary as the description.",

            "On stage: open the ticket from the JIRA page in this app. Show "
            "the customer summary in the drawer.",

            "Click <b>Troubleshoot in EBS</b>. While Claude is working, "
            "explain what is happening: the model is reading the ticket text, "
            "classifying it as a planning issue, and choosing the right "
            "Agentic Apps from the catalog.",

            "When the report renders, walk the audience through the four "
            "sections. The Likely root cause section is the moneymaker: "
            "naming UNDO_RETENTION, MSC_SYSTEM_ITEMS, and the schedule "
            "collision should mirror the analysis in this document.",

            "Click <b>Post Report as JIRA Comment</b>. Switch to JIRA web. "
            "Show the formatted comment with headings, bold table names, and "
            "a numbered fix list.",
        ]),
        Spacer(1, 4 * mm),
        info_panel("Audience question to plant", [Paragraph(
            "If someone asks how the AI knew about UNDO_RETENTION, the "
            "honest answer is that it has the EBS knowledge baked in and "
            "the SQL evidence in front of it. The combination is what "
            "produces credible, specific analysis. Take that question. It "
            "is the right one to ask.",
            BODY,
        )]),
    ]

    doc.build(story, onFirstPage=_header_footer, onLaterPages=_header_footer)
    print(f"PDF written: {out}")
    return out


if __name__ == "__main__":
    build()
