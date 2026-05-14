"""
Generate the L1/L2 demo flow as a PDF inside JIRA Analysis/.
Run from the project root:
    python "JIRA Analysis/build_demo_pdf.py"
"""
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT, TA_JUSTIFY
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, ListFlowable, ListItem,
    Table, TableStyle, PageBreak, HRFlowable,
)


# ─── Page-level theme ───────────────────────────────────────────────────────

ACCENT      = colors.HexColor("#0052cc")   # JIRA blue
ACCENT_DARK = colors.HexColor("#003d99")
TEXT_DARK   = colors.HexColor("#1f2328")
TEXT_MUTED  = colors.HexColor("#636c76")
BG_PANEL    = colors.HexColor("#f4f7fb")
RULE        = colors.HexColor("#d0d7de")
SEV_RED     = colors.HexColor("#cf222e")


def _header_footer(canvas, doc):
    """Header bar + footer for every page."""
    width, height = A4
    canvas.saveState()

    # Header bar
    canvas.setFillColor(ACCENT)
    canvas.rect(0, height - 18 * mm, width, 18 * mm, stroke=0, fill=1)
    canvas.setFillColor(colors.white)
    canvas.setFont("Helvetica-Bold", 11)
    canvas.drawString(20 * mm, height - 11 * mm,
                      "Oracle EBS Support Agent")
    canvas.setFont("Helvetica", 9)
    canvas.drawRightString(width - 20 * mm, height - 11 * mm,
                           "Demo Flow: L1 and L2 Ticket Resolution")

    # Footer
    canvas.setStrokeColor(RULE)
    canvas.setLineWidth(0.4)
    canvas.line(20 * mm, 14 * mm, width - 20 * mm, 14 * mm)
    canvas.setFillColor(TEXT_MUTED)
    canvas.setFont("Helvetica", 8)
    canvas.drawString(20 * mm, 9 * mm,
                      "Confidential. Prepared for internal review.")
    canvas.drawRightString(width - 20 * mm, 9 * mm,
                           f"Page {doc.page}")
    canvas.restoreState()


# ─── Styles ─────────────────────────────────────────────────────────────────

styles = getSampleStyleSheet()

H_COVER_TITLE = ParagraphStyle(
    "CoverTitle", parent=styles["Title"],
    fontName="Helvetica-Bold", fontSize=26, leading=32,
    textColor=TEXT_DARK, spaceAfter=8,
)
H_COVER_SUB = ParagraphStyle(
    "CoverSub", parent=styles["Normal"],
    fontName="Helvetica", fontSize=13, leading=18,
    textColor=TEXT_MUTED, spaceAfter=24,
)

H1 = ParagraphStyle(
    "H1", parent=styles["Heading1"],
    fontName="Helvetica-Bold", fontSize=16, leading=22,
    textColor=ACCENT_DARK, spaceBefore=14, spaceAfter=8,
)
H2 = ParagraphStyle(
    "H2", parent=styles["Heading2"],
    fontName="Helvetica-Bold", fontSize=12.5, leading=18,
    textColor=TEXT_DARK, spaceBefore=10, spaceAfter=4,
)
H3 = ParagraphStyle(
    "H3", parent=styles["Heading3"],
    fontName="Helvetica-Bold", fontSize=10.5, leading=14,
    textColor=ACCENT, spaceBefore=8, spaceAfter=3,
    textTransform="uppercase",
)
BODY = ParagraphStyle(
    "Body", parent=styles["Normal"],
    fontName="Helvetica", fontSize=10, leading=14.5,
    textColor=TEXT_DARK, alignment=TA_JUSTIFY,
    spaceAfter=6,
)
BODY_LEFT = ParagraphStyle(
    "BodyLeft", parent=BODY, alignment=TA_LEFT,
)
NARRATION = ParagraphStyle(
    "Narration", parent=BODY,
    fontName="Helvetica-Oblique", textColor=TEXT_MUTED,
    leftIndent=10, rightIndent=10, spaceBefore=2, spaceAfter=8,
)
PROVES = ParagraphStyle(
    "Proves", parent=BODY,
    fontName="Helvetica-Bold", textColor=ACCENT_DARK,
    spaceBefore=4, spaceAfter=8,
)
META = ParagraphStyle(
    "Meta", parent=BODY,
    fontName="Helvetica", fontSize=9, leading=12,
    textColor=TEXT_MUTED,
)
BULLET = ParagraphStyle(
    "Bullet", parent=BODY, leftIndent=4,
    spaceAfter=2, alignment=TA_LEFT,
)


# ─── Helpers ────────────────────────────────────────────────────────────────

def bullets(items, style=BULLET):
    return ListFlowable(
        [ListItem(Paragraph(t, style), leftIndent=6, value="circle")
         for t in items],
        bulletType="bullet", bulletColor=ACCENT, leftIndent=14,
    )


def numbered(items, style=BULLET):
    return ListFlowable(
        [ListItem(Paragraph(t, style), leftIndent=6) for t in items],
        bulletType="1", bulletColor=ACCENT, leftIndent=14,
        bulletFontName="Helvetica-Bold",
    )


def info_panel(title, body_paragraphs):
    """Soft blue-tinted callout used for 'What this proves' blocks."""
    inner = [Paragraph(f"<b>{title}</b>", H3)]
    inner.extend(body_paragraphs)
    t = Table([[inner]], colWidths=[170 * mm])
    t.setStyle(TableStyle([
        ("BACKGROUND",  (0, 0), (-1, -1), BG_PANEL),
        ("BOX",         (0, 0), (-1, -1), 0.5, RULE),
        ("LEFTPADDING", (0, 0), (-1, -1), 12),
        ("RIGHTPADDING",(0, 0), (-1, -1), 12),
        ("TOPPADDING",  (0, 0), (-1, -1), 10),
        ("BOTTOMPADDING",(0, 0), (-1, -1), 12),
    ]))
    return t


def scene_header(num, title, duration):
    """Coloured strip with scene number and timing."""
    cell = [
        Paragraph(f'<font color="white"><b>SCENE {num}</b></font>', BODY_LEFT),
        Paragraph(f'<font color="white"><b>{title}</b></font>', BODY_LEFT),
        Paragraph(f'<font color="white">{duration}</font>', BODY_LEFT),
    ]
    t = Table([cell], colWidths=[28 * mm, 110 * mm, 32 * mm])
    t.setStyle(TableStyle([
        ("BACKGROUND",   (0, 0), (-1, -1), ACCENT),
        ("LEFTPADDING",  (0, 0), (-1, -1), 10),
        ("RIGHTPADDING", (0, 0), (-1, -1), 10),
        ("TOPPADDING",   (0, 0), (-1, -1), 6),
        ("BOTTOMPADDING",(0, 0), (-1, -1), 6),
        ("VALIGN",       (0, 0), (-1, -1), "MIDDLE"),
        ("ALIGN",        (2, 0), (2, 0), "RIGHT"),
    ]))
    return t


def kv_table(rows):
    """Two-column key:value table for setup checklists."""
    data = [[Paragraph(f"<b>{k}</b>", META), Paragraph(v, META)] for k, v in rows]
    t = Table(data, colWidths=[45 * mm, 125 * mm])
    t.setStyle(TableStyle([
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LINEBELOW", (0, 0), (-1, -2), 0.25, RULE),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]))
    return t


# ─── Document content ──────────────────────────────────────────────────────

def build():
    here = Path(__file__).parent
    out = here / "L1_L2_Demo_Flow.pdf"

    doc = SimpleDocTemplate(
        str(out),
        pagesize=A4,
        leftMargin=20 * mm, rightMargin=20 * mm,
        topMargin=28 * mm, bottomMargin=22 * mm,
        title="L1 and L2 Demo Flow",
        author="Oracle EBS Support Agent",
    )

    story = []

    # ── Cover ──────────────────────────────────────────────────────────────
    story += [
        Spacer(1, 20 * mm),
        Paragraph("Oracle EBS Support Agent", H_COVER_SUB),
        Paragraph("Demo Flow", H_COVER_TITLE),
        Paragraph("Analyzing and Resolving L1 and L2 Tickets with JIRA",
                  H_COVER_SUB),
        HRFlowable(width="40%", thickness=1.5, color=ACCENT,
                   hAlign="LEFT", spaceBefore=2, spaceAfter=18),
        Paragraph(
            "A twelve-minute walk-through that demonstrates how the agent "
            "handles support tickets in both directions. Inbound tickets get "
            "diagnosed and answered with structured evidence from live EBS. "
            "Outbound, the agent detects problems before they are reported "
            "and creates fully researched tickets with recommended fixes. "
            "Both directions use the same tool surface, the same audit "
            "trail, and the same JIRA integration.",
            BODY,
        ),
        Spacer(1, 18 * mm),

        kv_table([
            ("Duration",        "12 minutes"),
            ("Audience",        "Support leadership, ops managers, EBS owners"),
            ("Prerequisites",   "Flask app running on port 8000. JIRA credentials configured. Demo mode is fine."),
            ("Scenes",          "Four scenes plus opening and closing"),
            ("Outcome shown",   "Two real tickets in JIRA, one diagnosed and one created from scratch"),
        ]),

        Spacer(1, 14 * mm),
        info_panel(
            "Why this flow",
            [Paragraph(
                "The strongest demo narrative is the contrast between the two "
                "modes. Most support teams only have a reactive workflow: a "
                "ticket arrives, a human investigates, a fix is proposed. "
                "Showing both reactive and proactive in the same twelve "
                "minutes lands the message that the agent is not a chatbot "
                "bolted onto JIRA. It is the same engine driving both "
                "directions, with the audit trail to back every action.",
                BODY,
            )],
        ),

        PageBreak(),
    ]

    # ── Setup ──────────────────────────────────────────────────────────────
    story += [
        Paragraph("Setup before you start", H1),
        Paragraph(
            "Five minutes of preparation makes the difference between a "
            "smooth demo and a stalled one.",
            BODY,
        ),
        bullets([
            "Flask app running on port 8000. Visit "
            "<font color='#0052cc'>http://localhost:8000/jira</font> in advance to warm up the singletons.",
            "Three browser tabs ready: the JIRA page in this app, the JIRA web UI at "
            "u2xai.atlassian.net, and the chat page.",
            "Pre-create one JIRA ticket with a realistic title such as "
            "<i>'Period close failing. 45 invoices stuck unposted'</i>. Assign it to support.",
            "Do not open SUP-2 in front of the audience. Its first comment was generated "
            "before the formatting fix and contains em-dashes.",
            "If demoing on a laptop, plug in. Every Claude call is 2 to 5 seconds and battery "
            "throttling makes that worse.",
        ]),
        Spacer(1, 6 * mm),

        # ── Scene 1 ─────────────────────────────────────────────────────────
        scene_header(1, "Reactive flow. An L1 ticket comes in.", "4 minutes"),
        Spacer(1, 4 * mm),
        Paragraph("Narrative", H3),
        Paragraph(
            "A support engineer starts their day. There is a P2 ticket "
            "waiting in JIRA. The customer is asking why the period close "
            "is blocked.",
            NARRATION,
        ),
        Paragraph("Walk-through", H3),
        numbered([
            "Open <b>/jira</b>. Search for the pre-created ticket. Click the row.",
            "Drawer slides open with the description and any prior comments.",
            "Click <b>Troubleshoot in EBS</b>.",
            "While Claude is working, narrate what is happening on screen: "
            "the model is classifying the ticket against the catalog of 15 "
            "Agentic Apps, picking one to three, then running them against "
            "live Oracle EBS.",
            "Findings appear with severity chips, counts, and the rule that "
            "fired. The AI report renders below with Summary, Evidence, "
            "Likely root cause, Recommended next steps, and Confidence.",
            "Click <b>Post Report as JIRA Comment</b>.",
            "Switch to the JIRA web tab and refresh. Show the comment with "
            "proper headings, bold EBS table names, and a numbered list of "
            "fixes. No literal markdown characters.",
        ]),
        Spacer(1, 4 * mm),
        info_panel(
            "What this proves",
            [Paragraph(
                "An L1 engineer who used to spend 1 to 2 hours diagnosing "
                "gets a structured root cause and a recommended fix in under "
                "thirty seconds, posted back to the same ticket the customer "
                "is watching. The engineer stays in the loop. The agent does "
                "the legwork.",
                BODY,
            )],
        ),

        PageBreak(),

        # ── Scene 2 ─────────────────────────────────────────────────────────
        scene_header(2, "Proactive flow. L2 finds issues before they are reported.", "4 minutes"),
        Spacer(1, 4 * mm),
        Paragraph("Narrative", H3),
        Paragraph(
            "The best L2 work is catching problems before anyone files a "
            "ticket. The agent can run that pass on demand.",
            NARRATION,
        ),
        Paragraph("Walk-through", H3),
        numbered([
            "Back to <b>/jira</b>. Click <b>Scan EBS for Errors</b> in the hero.",
            "Modal opens. Confirm the look-back window. Click <b>Run Scan</b>.",
            "Show the results table sorted by severity. Twenty-six findings "
            "across the 15 Agentic Apps.",
            "Pick one CRITICAL row, for example Payables unposted invoices.",
            "Click <b>Generate &amp; Create</b>.",
            "Claude drafts the ticket: summary, sectioned description, "
            "suggested priority Highest, labels, issue type Bug. Walk the "
            "audience through what the AI included: the actual SQL evidence, "
            "the root cause analysis citing real EBS tables, the six step "
            "fix plan, and real Oracle MOS doc references.",
            "Briefly edit one field to show that the human stays in control. "
            "Add a label or tweak the priority.",
            "Click <b>Create JIRA Ticket</b>.",
            "Toast appears with the new ticket key. Click <b>Open</b>. JIRA "
            "web tab opens the new ticket. Show the formatting: real "
            "headings, bold table names, numbered fix list, MOS docs as a "
            "bullet list.",
        ]),
        Spacer(1, 4 * mm),
        info_panel(
            "What this proves",
            [Paragraph(
                "The same engine flips direction. No human had to find the "
                "problem. The ticket arrives in JIRA fully researched, "
                "prioritised, and ready for an engineer to action. The "
                "research that an L2 engineer would have done over a half "
                "day is in the description from the start.",
                BODY,
            )],
        ),

        Spacer(1, 6 * mm),

        # ── Scene 3 ─────────────────────────────────────────────────────────
        scene_header(3, "Composability. Pull the same evidence into chat.", "2 minutes"),
        Spacer(1, 4 * mm),
        Paragraph("Narrative", H3),
        Paragraph(
            "When an engineer wants to dig deeper, the same data is "
            "available conversationally. The JIRA page, the Scan modal, and "
            "the chat all share one tool surface.",
            NARRATION,
        ),
        Paragraph("Walk-through", H3),
        numbered([
            "Switch to the chat tab.",
            "Ask: <i>'Show me the top five invoices on hold for the past 30 days, with vendor names.'</i>",
            "The agent uses the MCP tool payables_list_holds. A data table "
            "renders inline in the chat.",
            "Follow up: <i>'For invoice 80123, give me the supplier 360 view.'</i>",
            "Tool chain runs. Supplier profile, recent bank changes, and "
            "aging buckets all return.",
        ]),
        Spacer(1, 4 * mm),
        info_panel(
            "What this proves",
            [Paragraph(
                "The integration is composable. The chat surface, the JIRA "
                "page, and the fusion apps all call the same 61 MCP tools. "
                "Whatever the engineer prefers, they get the same data and "
                "the same answers.",
                BODY,
            )],
        ),

        PageBreak(),

        # ── Scene 4 ─────────────────────────────────────────────────────────
        scene_header(4, "Audit trail. Every step is logged.", "1 minute"),
        Spacer(1, 4 * mm),
        Paragraph("Narrative", H3),
        Paragraph(
            "AI assistance only works in production if the work is "
            "traceable. Every tool call, every SQL query, every JIRA write "
            "is observable.",
            NARRATION,
        ),
        Paragraph("Walk-through", H3),
        numbered([
            "Open <b>/observability</b>.",
            "Show the agent flow strip and the recent run events stream.",
            "Highlight the per-agent state grid and the in-flight pill.",
            "Note: every AI step, every SQL query, every JIRA write is "
            "logged. Compliance and reproducibility are not an afterthought.",
        ]),

        Spacer(1, 8 * mm),

        # ── Closing ─────────────────────────────────────────────────────────
        Paragraph("Closing", H1),
        Paragraph(
            "Wrap with three numbers and a single sentence per number.",
            BODY,
        ),
        bullets([
            "<b>One system</b> handles both reactive (ticket in) and proactive (ticket out). "
            "The same Claude orchestrator, the same MCP tools, the same JIRA writer.",
            "<b>15 Agentic Apps and 61 MCP tools</b> behind the AI. All callable from chat, "
            "from the JIRA page, or from Claude Desktop over stdio.",
            "<b>Time per ticket</b>: a 1 to 2 hour manual diagnosis becomes 30 seconds of AI "
            "work plus engineer review. The savings compound across the team.",
        ]),

        Spacer(1, 6 * mm),

        # ── Pitfalls ────────────────────────────────────────────────────────
        Paragraph("Things to watch out for", H1),
        bullets([
            "Demo on a fast network. Each Claude call is 2 to 5 seconds. "
            "Dead air feels long on stage. Have something to say during the wait.",
            "If JIRA latency spikes the Troubleshoot button looks frozen. "
            "Have a backup screenshot of a completed report.",
            "Do not open SUP-2 live. Its first comment has em-dashes from "
            "before the formatting fix. Use a fresh ticket created during the demo.",
            "Keep the audience focused. Resist the urge to detour into the "
            "Supply Chain Planning page or the analyzer registry. They are real "
            "but they are not this story.",
            "Have an answer ready for cost questions. Each end-to-end resolution "
            "is roughly one Sonnet call for classify, one for synthesis, and one "
            "for draft. Cheap relative to an engineer hour.",
        ]),

        Spacer(1, 8 * mm),

        # ── Appendix: tools touched ─────────────────────────────────────────
        Paragraph("Appendix. Capabilities exercised in this demo", H1),
        Paragraph(
            "For an audience that wants the technical surface, here is the "
            "exact set of capabilities the demo touches.",
            BODY,
        ),
        Paragraph("MCP tools called", H3),
        bullets([
            "<b>jira_get_issue</b> and <b>jira_search_issues</b>. Read the ticket and similar prior issues.",
            "<b>jira_scan_ebs_errors</b>. Run all 15 Agentic Apps and rank ticketable findings.",
            "<b>jira_generate_ticket_draft</b>. Claude drafts a fully sectioned ticket from one finding.",
            "<b>jira_troubleshoot_issue</b>. Classify, run the chosen apps, synthesize a report.",
            "<b>jira_create_issue</b>, <b>jira_add_comment</b>, <b>jira_update_issue</b>. Writes to JIRA with markdown-to-ADF conversion.",
            "<b>payables_list_holds</b>, <b>payables_get_supplier_360</b>. Composability demo in chat.",
        ]),
        Paragraph("Pages touched", H3),
        bullets([
            "<b>/jira</b>. The main demo surface. Scan, draft, create, troubleshoot.",
            "<b>/</b>. The chat surface for the composability scene.",
            "<b>/observability</b>. The audit trail.",
        ]),
        Paragraph("Outputs the audience sees", H3),
        bullets([
            "A JIRA comment posted to an existing ticket, with proper formatting.",
            "A new JIRA ticket created from a scan finding, fully researched.",
            "Inline data tables in the chat answering ad-hoc support questions.",
            "Real-time observability of every AI step.",
        ]),
    ]

    doc.build(story, onFirstPage=_header_footer, onLaterPages=_header_footer)
    print(f"PDF written: {out}")
    return out


if __name__ == "__main__":
    build()
