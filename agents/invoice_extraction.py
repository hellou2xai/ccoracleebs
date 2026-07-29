"""Invoice Extraction agent.

Scans a folder for invoice documents (PDF/PNG/JPG), sends each one to Claude
for structured data extraction, and writes the result as JSON and Excel into
`excel/` and `json/` subfolders inside the same invoice folder.

Used both by the Invoice Extraction page (folder path typed by a user) and
by anything else that wants to trigger the same run programmatically —
`run_capture()` is the single entry point for both.
"""

import base64
import json
import logging
import os
from pathlib import Path
from typing import Any, Dict, List

import anthropic
from openpyxl import Workbook

logger = logging.getLogger(__name__)

MODEL = "claude-sonnet-4-6"
SUPPORTED_EXTENSIONS = {".pdf", ".png", ".jpg", ".jpeg"}

SUMMARY_FIELDS = [
    ("invoice_number", "Invoice Number"),
    ("invoice_date", "Invoice Date"),
    ("due_date", "Due Date"),
    ("po_number", "PO Number"),
    ("vendor_name", "Vendor Name"),
    ("vendor_address", "Vendor Address"),
    ("bill_to", "Bill To"),
    ("ship_to", "Ship To"),
    ("currency", "Currency"),
    ("subtotal", "Subtotal"),
    ("tax_amount", "Tax Amount"),
    ("shipping_amount", "Shipping Amount"),
    ("total_amount", "Total Amount"),
    ("payment_terms", "Payment Terms"),
    ("notes", "Notes"),
]

EXTRACTION_TOOL = {
    "name": "record_invoice_data",
    "description": "Record structured data extracted from an invoice document.",
    "input_schema": {
        "type": "object",
        "properties": {
            "invoice_number": {"type": "string"},
            "invoice_date": {"type": "string", "description": "ISO 8601 date (YYYY-MM-DD) if determinable"},
            "due_date": {"type": "string"},
            "po_number": {"type": "string"},
            "vendor_name": {"type": "string"},
            "vendor_address": {"type": "string"},
            "bill_to": {"type": "string"},
            "ship_to": {"type": "string"},
            "currency": {"type": "string"},
            "subtotal": {"type": "number"},
            "tax_amount": {"type": "number"},
            "shipping_amount": {"type": "number"},
            "total_amount": {"type": "number"},
            "payment_terms": {"type": "string"},
            "line_items": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "description": {"type": "string"},
                        "quantity": {"type": "number"},
                        "unit_price": {"type": "number"},
                        "amount": {"type": "number"},
                    },
                    "required": ["description"],
                },
            },
            "notes": {
                "type": "string",
                "description": "Anything ambiguous, missing, or low-confidence about the extraction.",
            },
        },
        "required": ["invoice_number", "vendor_name", "total_amount", "line_items"],
    },
}


def _client() -> anthropic.Anthropic:
    return anthropic.Anthropic(api_key=os.environ.get("ANTHROPIC_API_KEY", ""))


def _content_block(file_path: Path) -> Dict[str, Any]:
    data = base64.standard_b64encode(file_path.read_bytes()).decode("utf-8")
    ext = file_path.suffix.lower()
    if ext == ".pdf":
        return {
            "type": "document",
            "source": {"type": "base64", "media_type": "application/pdf", "data": data},
        }
    media_type = "image/png" if ext == ".png" else "image/jpeg"
    return {
        "type": "image",
        "source": {"type": "base64", "media_type": media_type, "data": data},
    }


def extract_invoice_file(file_path: Path) -> Dict[str, Any]:
    """Send one invoice document to Claude and return the structured fields."""
    client = _client()
    resp = client.messages.create(
        model=MODEL,
        max_tokens=2000,
        tools=[EXTRACTION_TOOL],
        tool_choice={"type": "tool", "name": "record_invoice_data"},
        messages=[{
            "role": "user",
            "content": [
                _content_block(file_path),
                {
                    "type": "text",
                    "text": (
                        "Extract the structured invoice data from this document using the "
                        "record_invoice_data tool. Use null for any field you cannot determine "
                        "from the document. Do not guess numbers you cannot read."
                    ),
                },
            ],
        }],
    )
    for block in resp.content:
        if block.type == "tool_use" and block.name == "record_invoice_data":
            return dict(block.input)
    raise ValueError("Model did not return structured invoice data")


def list_invoice_files(folder: Path) -> List[Path]:
    return sorted(
        p for p in folder.iterdir()
        if p.is_file() and p.suffix.lower() in SUPPORTED_EXTENSIONS
    )


def write_json(json_dir: Path, stem: str, data: Dict[str, Any]) -> Path:
    out = json_dir / f"{stem}.json"
    out.write_text(json.dumps(data, indent=2, default=str, ensure_ascii=False), encoding="utf-8")
    return out


def write_excel(excel_dir: Path, stem: str, data: Dict[str, Any]) -> Path:
    wb = Workbook()
    summary = wb.active
    summary.title = "Summary"
    summary.append(["Field", "Value"])
    for key, label in SUMMARY_FIELDS:
        summary.append([label, data.get(key)])
    summary.column_dimensions["A"].width = 20
    summary.column_dimensions["B"].width = 50

    lines = wb.create_sheet("Line Items")
    lines.append(["Description", "Quantity", "Unit Price", "Amount"])
    for item in data.get("line_items") or []:
        lines.append([
            item.get("description"),
            item.get("quantity"),
            item.get("unit_price"),
            item.get("amount"),
        ])
    lines.column_dimensions["A"].width = 50

    out = excel_dir / f"{stem}.xlsx"
    wb.save(out)
    return out


def run_capture(folder_path: str) -> Dict[str, Any]:
    """Scan `folder_path` for invoices and extract each into json/ and excel/ subfolders.

    This is the single implementation behind both the Invoice Extraction page
    (manual folder entry) and the Invoice Extraction agent (same call, same result).
    """
    if not (os.environ.get("ANTHROPIC_API_KEY") or "").strip():
        return {"error": "ANTHROPIC_API_KEY is not configured on the server.", "results": []}

    folder = Path(folder_path).expanduser()
    if not folder.exists() or not folder.is_dir():
        return {"error": f"Folder not found: {folder_path}", "results": []}

    excel_dir = folder / "excel"
    json_dir = folder / "json"
    excel_dir.mkdir(exist_ok=True)
    json_dir.mkdir(exist_ok=True)

    files = list_invoice_files(folder)
    results = []
    processed = 0
    failed = 0

    for f in files:
        row: Dict[str, Any] = {"filename": f.name}
        try:
            data = extract_invoice_file(f)
            json_path = write_json(json_dir, f.stem, data)
            excel_path = write_excel(excel_dir, f.stem, data)
            row.update({
                "status": "ok",
                "invoice_number": data.get("invoice_number"),
                "vendor_name": data.get("vendor_name"),
                "total_amount": data.get("total_amount"),
                "currency": data.get("currency"),
                "json_path": str(json_path),
                "excel_path": str(excel_path),
            })
            processed += 1
        except Exception as e:
            logger.exception("Invoice extraction failed for %s", f)
            row.update({"status": "error", "error": str(e)})
            failed += 1
        results.append(row)

    return {
        "folder": str(folder),
        "excel_dir": str(excel_dir),
        "json_dir": str(json_dir),
        "total_files": len(files),
        "processed": processed,
        "failed": failed,
        "results": results,
    }
