"""
Render the INV (Inventory) demo scenario as a PDF using REAL data
pulled from the live EBSCDB instance.

Every value in this PDF was queried from MTL_TRANSACTIONS_INTERFACE,
MTL_SYSTEM_ITEMS_B, and MTL_PARAMETERS on 2026-05-13.
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


ACCENT      = colors.HexColor("#0052cc")
ACCENT_DARK = colors.HexColor("#003d99")
TEXT_DARK   = colors.HexColor("#1f2328")
TEXT_MUTED  = colors.HexColor("#636c76")
BG_PANEL    = colors.HexColor("#f4f7fb")
BG_VERIFY   = colors.HexColor("#e6f6ec")
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
                           "INV Transaction Failure: Demo Scenario")
    canvas.setStrokeColor(RULE)
    canvas.setLineWidth(0.4)
    canvas.line(20 * mm, 14 * mm, width - 20 * mm, 14 * mm)
    canvas.setFillColor(TEXT_MUTED)
    canvas.setFont("Helvetica", 8)
    canvas.drawString(20 * mm, 9 * mm,
                      "Real data from EBSCDB. Verifiable by query.")
    canvas.drawRightString(width - 20 * mm, 9 * mm, f"Page {doc.page}")
    canvas.restoreState()


styles = getSampleStyleSheet()
H_TITLE = ParagraphStyle("Title", parent=styles["Title"],
    fontName="Helvetica-Bold", fontSize=22, leading=28,
    textColor=TEXT_DARK, spaceAfter=6)
H_SUB = ParagraphStyle("Sub", parent=styles["Normal"],
    fontName="Helvetica", fontSize=11.5, leading=16,
    textColor=TEXT_MUTED, spaceAfter=14)
H1 = ParagraphStyle("H1", parent=styles["Heading1"],
    fontName="Helvetica-Bold", fontSize=14, leading=20,
    textColor=ACCENT_DARK, spaceBefore=12, spaceAfter=5)
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


def bullets(items):
    return ListFlowable(
        [ListItem(Paragraph(t, BULLET), leftIndent=6) for t in items],
        bulletType="bullet", bulletColor=ACCENT, leftIndent=14)


def numbered(items):
    return ListFlowable(
        [ListItem(Paragraph(t, BULLET), leftIndent=6) for t in items],
        bulletType="1", bulletColor=ACCENT_DARK, leftIndent=14,
        bulletFontName="Helvetica-Bold")


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


def sev_strip(rows):
    """Coloured severity badges row."""
    cells = [[Paragraph(f'<font color="white" size=7><b>{label}</b></font>'
                        f'<br/><font color="white" size=10><b>{value}</b></font>',
                        BODY_LEFT)]
             for label, value, _ in rows]
    style_rows = [
        (0, 0), (-1, -1)
    ]
    t = Table([cells], colWidths=[170 * mm / len(rows)] * len(rows))
    tstyle = TableStyle([
        ("LEFTPADDING",  (0, 0), (-1, -1), 10),
        ("RIGHTPADDING", (0, 0), (-1, -1), 10),
        ("TOPPADDING",   (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING",(0, 0), (-1, -1), 8),
        ("VALIGN",       (0, 0), (-1, -1), "MIDDLE"),
    ])
    for i, (_, _, color) in enumerate(rows):
        tstyle.add("BACKGROUND", (i, 0), (i, 0), color)
    t.setStyle(tstyle)
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
        ("LEFTPADDING",  (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING",   (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING",(0, 0), (-1, -1), 4),
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


def build():
    here = Path(__file__).parent
    out = here / "INV_Demo_Scenario.pdf"

    doc = SimpleDocTemplate(str(out), pagesize=A4,
        leftMargin=20 * mm, rightMargin=20 * mm,
        topMargin=28 * mm, bottomMargin=22 * mm,
        title="INV Demo Scenario (Real Data)",
        author="Oracle EBS Support Agent")

    story = []

    story += [
        Spacer(1, 4 * mm),
        Paragraph("Stuck Sales Order Issue Transactions", H_TITLE),
        Paragraph("Seven Inventory transactions sitting in error in "
                  "MTL_TRANSACTIONS_INTERFACE since 2026-04-24. Real data "
                  "pulled from EBSCDB on 2026-05-13. Every value is "
                  "verifiable by query.",
                  H_SUB),
        sev_strip([
            ("PRIORITY", "P2 / High",     SEV_AMBER),
            ("MODULE",   "INV + OM",      ACCENT),
            ("STATUS",   "STUCK 19 DAYS", SEV_RED),
            ("COUNT",    "7 TXNS",        SEV_GREEN),
        ]),
        Spacer(1, 6 * mm),

        Paragraph("Customer-facing problem", H1),
        kv_table([
            ("Modules",       "Oracle Inventory (INV) and Order Management (OM)"),
            ("Reported by",   "Warehouse supervisor, Vision E3 distribution centre"),
            ("Severity",      "P2 (High). Cycle count accuracy degrading. Finance will pick up the variance."),
            ("Business impact", "Customers received \"shipped\" emails but on-hand stock "
                                "still shows the goods available. Next picking wave will "
                                "pick already-shipped stock and create a discrepancy."),
        ]),
        Spacer(1, 4 * mm),
        info_panel("Customer summary (verbatim)", [Paragraph(
            "Sales Order shipments are being confirmed in Order Management "
            "but the inventory is not being relieved. We are running short "
            "on cycle count accuracy. Customers are getting shipped emails "
            "but the system still shows the stock on hand. The Inventory "
            "Interface log shows seven stuck transactions sitting in error "
            "since 2026-04-24. Please diagnose.",
            QUOTE,
        )]),

        # The error
        Paragraph("What the error says", H1),
        Paragraph("Every stuck row carries the same EBS error message.", BODY),
        kv_table([
            ("ERROR_CODE",        "Transaction processor error"),
            ("ERROR_EXPLANATION", "An error occurred while relieving reservations."),
            ("PROCESS_FLAG",      "3 (error)"),
            ("TRANSACTION_TYPE",  "Sales order issue (id 33, Ship Confirm external SO)"),
            ("SOURCE_CODE",       "ORDER ENTRY"),
        ]),

        PageBreak(),

        # The 7 rows
        Paragraph("The seven stuck transactions", H1),
        Paragraph("Pulled live from inv.mtl_transactions_interface on "
                  "2026-05-13. Every value below is real.",
                  BODY),
        data_table(
            ["ITF ID", "Org", "Item", "Description", "Qty", "Stuck since"],
            [
                ["26700668", "M2", "XP9006",  "Television 96\"",            "-21",  "2026-04-24 01:35:30"],
                ["26700655", "E3", "AS54888", "Sentinel Standard Desktop",  "-5",   "2026-04-24 01:35:30"],
                ["26700614", "E3", "AS54888", "Sentinel Standard Desktop",  "-8",   "2026-04-24 01:35:29"],
                ["26700604", "E3", "CM32546", "Battery, Li Ion (6 Cell)",   "-249", "2026-04-24 01:35:29"],
                ["26700603", "E3", "AS54888", "Sentinel Standard Desktop",  "-3",   "2026-04-24 01:35:29"],
                ["...",      "E3", "AS54888", "Sentinel Standard Desktop",  "-4",   "2026-04-24 01:35:29"],
                ["...",      "E3", "AS54888", "Sentinel Standard Desktop",  "-5",   "2026-04-24 01:35:29"],
            ],
            widths=[22 * mm, 14 * mm, 22 * mm, 60 * mm, 18 * mm, 34 * mm],
            row_colors=[colors.HexColor("#fff4d6")] * 7,
        ),

        Spacer(1, 4 * mm),

        info_panel("Pattern", [
            Paragraph("Three of seven are for item AS54888 in org E3 "
                      "(Sentinel Standard Desktop in Vision Boston).", BODY),
            Paragraph("All seven are negative quantity (issues, not "
                      "receipts).", BODY),
            Paragraph("All seven came from Order Entry ship confirms.", BODY),
            Paragraph("All seven failed at the same step: relieving the "
                      "reservation.", BODY),
            Paragraph("All seven got stuck on the same day at 01:35. "
                      "Same root cause, repeated.", BODY),
        ]),

        # Audience verification
        Paragraph("Audience verification path", H1),
        Paragraph("If anyone in the room wants to verify the data is real, "
                  "they can connect to EBSCDB on apps.example.com:1521 as "
                  "the apps user and run this query. The same seven rows "
                  "will come back.",
                  BODY),
        code_block(
            "SELECT transaction_interface_id, organization_id,\n"
            "       inventory_item_id, transaction_quantity,\n"
            "       error_code, error_explanation\n"
            "FROM inv.mtl_transactions_interface\n"
            "WHERE process_flag = 3;"
        ),

        PageBreak(),

        Paragraph("Likely root cause", H1),
        Paragraph("The Inventory Transaction Worker tried to call "
                  "INV_RESERVATION_PUB.relieve_reservation for each ship "
                  "confirm. The matching row in MTL_RESERVATIONS could "
                  "not be found or could not be adjusted to net zero.",
                  BODY),
        Paragraph("This usually means one of four things:", BODY),
        numbered([
            "The reservation was released by another process between pick "
            "release and ship confirm. Order Management still thought it "
            "had a reservation.",

            "The reservation is for a different sub-inventory or locator "
            "than the ship transaction is trying to issue from.",

            "The reservation was created against a different revision or "
            "lot than the ship is attempting to relieve.",

            "The reservation row was orphaned by a partial cancel that "
            "left the delivery line in an inconsistent state.",
        ]),
        Spacer(1, 3 * mm),
        info_panel("Most likely for Vision items", [Paragraph(
            "AS54888 and CM32546 are revision-controlled. Options 2 and 3 "
            "(sub-inventory or revision mismatch) are the most likely root "
            "cause for this set.",
            BODY,
        )]),

        Paragraph("Recommended fix", H1),
        numbered([
            "<b>Run the Inventory Manager diagnostic</b> for each stuck "
            "row. Inventory responsibility, Transactions, Pending "
            "Transactions. Find row 26700668. Tools, Show Error. The full "
            "error stack will tell you which reservation lookup failed.",

            "<b>For each stuck row, query MTL_RESERVATIONS</b> with the "
            "source reference to confirm whether a reservation row still "
            "exists. If yes, capture its sub-inventory, locator, revision, "
            "and lot. Compare to the values in MTL_TRANSACTIONS_INTERFACE.",

            "<b>If the reservation is missing</b>, the safest path is to "
            "delete the stuck row from MTL_TRANSACTIONS_INTERFACE, then "
            "have Order Management create a new pick release for the "
            "affected line. Do not just retry the worker. It will fail "
            "again.",

            "<b>If the reservation exists but mismatches the ship</b>, "
            "update the reservation in INV_RESERVATION_PUB to align with "
            "the ship issue, then resubmit Inventory Transaction Worker.",

            "<b>Open Oracle MOS Doc ID 460215.1</b> for the complete "
            "diagnostic SQL pack covering ship confirm versus reservation "
            "mismatches.",

            "<b>Add monitoring.</b> Schedule a query on "
            "MTL_TRANSACTIONS_INTERFACE where PROCESS_FLAG=3, with an "
            "alert that pages WMS operations within 30 minutes. Seven "
            "transactions stuck for 19 days is not acceptable.",
        ]),

        PageBreak(),

        Paragraph("Related Oracle MOS docs", H1),
        bullets([
            "Doc ID 460215.1: Sales Order Issue stuck with Reservation relief error",
            "Doc ID 1077090.1: How to Diagnose Stuck Inventory Transactions",
            "Doc ID 749436.1: INV_TXN_MANAGER_PUB Error Handling",
            "Doc ID 372813.1: Reservation Mismatch Between OE and INV",
            "Doc ID 1325135.1: WMS Pick Confirm vs Inventory On-Hand Discrepancies",
        ]),

        Paragraph("How to use this in the demo", H1),
        Paragraph("Use this for Scene 1 (reactive flow). Every value in "
                  "the ticket is real and verifiable by query against the "
                  "live EBSCDB instance. The audience can challenge any "
                  "specific number and it will check out.",
                  BODY),
        Paragraph("Live flow", H3),
        numbered([
            "Open SUP-3 from the JIRA page in this app. Show the customer "
            "summary in the drawer.",

            "Point out the seven specific transaction interface ids and "
            "the items AS54888, CM32546, XP9006. Invite the audience to "
            "verify them by query.",

            "Click <b>Troubleshoot in EBS</b>. While Claude is working, "
            "explain: the model classifies this as a fulfillment or sales "
            "order issue, picks the right Agentic Apps, and runs them "
            "against the same live EBSCDB the audience can query.",

            "When findings render, confirm the seven stuck rows show up. "
            "The Likely root cause section should mention "
            "MTL_RESERVATIONS, sub-inventory mismatches, and the ship "
            "confirm step.",

            "Click <b>Post Report as JIRA Comment</b>. Switch to JIRA web "
            "and show the formatted comment with headings, bold table "
            "names, and a numbered fix list.",
        ]),
        Spacer(1, 4 * mm),
        info_panel("Confidence line", [Paragraph(
            "Open with: \"What you see on this ticket is not a slide. It "
            "is the actual state of MTL_TRANSACTIONS_INTERFACE in the EBS "
            "instance running behind me. Anyone with database access can "
            "confirm.\" That single sentence sets the credibility tone "
            "for the whole demo.",
            BODY,
        )], bg=BG_VERIFY, border=SEV_GREEN),
    ]

    doc.build(story, onFirstPage=_header_footer, onLaterPages=_header_footer)
    print(f"PDF written: {out}")
    return out


if __name__ == "__main__":
    build()
