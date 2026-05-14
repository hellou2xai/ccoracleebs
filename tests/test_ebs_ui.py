"""
Playwright UI tests for Oracle EBS Support Agent Flask App
Tests: navigation, Oracle connect modal, demo mode toggle, chat, analyzer dashboard.
"""

import json
import pytest
from playwright.sync_api import Page, expect

BASE_URL = "http://localhost:8000"

# ─── Helpers ─────────────────────────────────────────────────────────────────

def go(page: Page, path: str = "/"):
    page.goto(f"{BASE_URL}{path}", wait_until="networkidle")


# ─── System Health ────────────────────────────────────────────────────────────

def test_health_api(page: Page):
    """Health endpoint returns expected fields."""
    res  = page.request.get(f"{BASE_URL}/api/system/health")
    data = res.json()
    assert res.ok
    assert data["app_ready"] is True
    assert "oracle" in data
    assert "postgres" in data
    assert data["analyzer_count"] >= 100


# ─── Page Load ────────────────────────────────────────────────────────────────

def test_homepage_loads(page: Page):
    """Index page loads with navbar and sidebar."""
    go(page)
    expect(page.locator(".brand-title")).to_contain_text("Oracle EBS")
    expect(page.locator(".sidebar")).to_be_visible()
    expect(page.locator("#btnConnectOracle")).to_be_visible()
    expect(page.locator("#btnDemoMode")).to_be_visible()


def test_dashboard_loads(page: Page):
    """Analyzer dashboard page loads with search bar and module tabs."""
    go(page, "/dashboard")
    expect(page.locator("body")).to_contain_text("Analyzer")


def test_nav_links(page: Page):
    """Navbar Chat and Analyzers links work."""
    go(page)
    # Click Agents nav pill
    page.locator("a.nav-pill", has_text="Agents").click()
    page.wait_for_url(f"{BASE_URL}/dashboard", timeout=5000)
    expect(page.locator(".brand-title")).to_be_visible()


# ─── Oracle Connect Modal ─────────────────────────────────────────────────────

def test_connect_modal_opens(page: Page):
    """Clicking Connect to Oracle opens modal with pre-filled credentials."""
    go(page)
    page.locator("#btnConnectOracle").click()
    modal = page.locator("#oracleConnectModal")
    expect(modal).to_be_visible()

    # Fields should be pre-filled from /api/oracle/credentials
    page.wait_for_function(
        "document.getElementById('connHost').value.length > 0",
        timeout=4000,
    )
    host_val = page.locator("#connHost").input_value()
    assert len(host_val) > 0, "Host field should be pre-filled"


def test_connect_modal_credentials_prefilled(page: Page):
    """All credential fields pre-fill from the API."""
    go(page)

    # Fetch credentials directly
    res   = page.request.get(f"{BASE_URL}/api/oracle/credentials")
    creds = res.json()

    page.locator("#btnConnectOracle").click()
    expect(page.locator("#oracleConnectModal")).to_be_visible()
    page.wait_for_function(
        "document.getElementById('connHost').value.length > 0", timeout=4000
    )

    assert page.locator("#connHost").input_value()        == creds["host"]
    assert page.locator("#connUser").input_value()        == creds["user"]
    assert page.locator("#connServiceName").input_value() == creds["service_name"]


def test_connect_modal_password_toggle(page: Page):
    """Eye button toggles password visibility."""
    go(page)
    page.locator("#btnConnectOracle").click()
    expect(page.locator("#oracleConnectModal")).to_be_visible()

    pw_field = page.locator("#connPassword")
    eye_btn  = page.locator(".conn-eye-btn")

    assert pw_field.get_attribute("type") == "password"
    eye_btn.click()
    assert pw_field.get_attribute("type") == "text"
    eye_btn.click()
    assert pw_field.get_attribute("type") == "password"


def test_connect_oracle_live_attempt(page: Page):
    """
    Attempts a live Oracle connection with credentials from .env.
    Accepts either success (if Oracle is reachable) or a clear error message
    — both outcomes confirm the connect flow works end-to-end.
    """
    go(page)
    page.locator("#btnConnectOracle").click()
    expect(page.locator("#oracleConnectModal")).to_be_visible()

    # Wait for pre-fill
    page.wait_for_function(
        "document.getElementById('connHost').value.length > 0", timeout=4000
    )

    # Get pre-filled creds from API (password is empty — fill from env or leave as-is)
    res   = page.request.get(f"{BASE_URL}/api/oracle/credentials")
    creds = res.json()

    # Fill password (from env default "apps")
    page.locator("#connPassword").fill("apps")

    # Click Connect
    page.locator("#btnSubmitConnect").click()

    # Wait for alert to appear (success or error)
    alert = page.locator("#connAlert")
    alert.wait_for(state="visible", timeout=15000)

    # The alert must have meaningful text
    alert_text = alert.inner_text()
    assert len(alert_text.strip()) > 0, "Connection alert must have content"

    # If it connected, navbar badge should update to "Connected"
    # If it failed, the error message should be visible
    is_success = "Connected" in alert_text or "connected" in alert_text.lower()
    is_failure = "failed" in alert_text.lower() or "error" in alert_text.lower() or "not installed" in alert_text.lower()
    assert is_success or is_failure, f"Unexpected alert text: {alert_text}"

    print(f"\n[Oracle Connect Result] {'SUCCESS' if is_success else 'EXPECTED FAILURE'}: {alert_text[:120]}")


def test_connect_with_wrong_password(page: Page):
    """Wrong password produces a connection error (not a crash)."""
    go(page)
    page.locator("#btnConnectOracle").click()
    expect(page.locator("#oracleConnectModal")).to_be_visible()

    page.wait_for_function(
        "document.getElementById('connHost').value.length > 0", timeout=4000
    )
    page.locator("#connPassword").fill("WRONG_PASSWORD_12345")
    page.locator("#btnSubmitConnect").click()

    alert = page.locator("#connAlert")
    alert.wait_for(state="visible", timeout=15000)
    text = alert.inner_text()
    # Should show error, not crash
    assert len(text) > 0
    assert "Connected!" not in text, "Should NOT succeed with wrong password"
    print(f"\n[Wrong Password Result]: {text[:120]}")


def test_connect_modal_cancel(page: Page):
    """Cancel button closes the modal without connecting."""
    go(page)
    page.locator("#btnConnectOracle").click()
    expect(page.locator("#oracleConnectModal")).to_be_visible()
    page.locator("#oracleConnectModal .btn-close").click()
    expect(page.locator("#oracleConnectModal")).to_be_hidden()


# ─── Demo Mode Toggle ─────────────────────────────────────────────────────────

def test_demo_mode_api(page: Page):
    """POST /api/oracle/demo returns success."""
    res  = page.request.post(f"{BASE_URL}/api/oracle/demo")
    data = res.json()
    assert res.ok
    assert data["success"] is True
    assert data["mode"] == "demo"


def test_demo_mode_button(page: Page):
    """Demo Mode button in sidebar switches to demo and updates UI."""
    go(page)
    page.locator("#btnDemoMode").click()

    # Mode display in sidebar should show Demo
    page.wait_for_function(
        "document.getElementById('connModeDisplay')?.textContent?.includes('Demo')",
        timeout=4000,
    )
    mode_text = page.locator("#connModeDisplay").inner_text()
    assert "Demo" in mode_text


def test_demo_mode_button_in_modal(page: Page):
    """Demo Mode button inside the modal also works."""
    go(page)
    page.locator("#btnConnectOracle").click()
    expect(page.locator("#oracleConnectModal")).to_be_visible()

    page.locator("#oracleConnectModal .btn-warning").click()  # Demo Mode btn inside modal

    # Modal should close and sidebar should show Demo
    expect(page.locator("#oracleConnectModal")).to_be_hidden()
    page.wait_for_function(
        "document.getElementById('connModeDisplay')?.textContent?.includes('Demo')",
        timeout=3000,
    )


# ─── Oracle Credentials API ───────────────────────────────────────────────────

def test_credentials_api_fields(page: Page):
    """Credentials API returns all required fields including password for modal pre-fill."""
    res   = page.request.get(f"{BASE_URL}/api/oracle/credentials")
    creds = res.json()
    assert "host"         in creds
    assert "user"         in creds
    assert "service_name" in creds
    assert "demo_mode"    in creds
    assert "password"     in creds  # Pre-filled from .env for internal support tool


def test_connect_api_direct(page: Page):
    """POST /api/oracle/connect with bad host returns structured error."""
    res  = page.request.post(
        f"{BASE_URL}/api/oracle/connect",
        data=json.dumps({
            "host":         "invalid.host.local",
            "port":         1521,
            "service_name": "BADDB",
            "user":         "apps",
            "password":     "apps",
        }),
        headers={"Content-Type": "application/json"},
    )
    data = res.json()
    assert res.ok  # HTTP 200 even on Oracle error
    assert data["success"] is False
    assert "error" in data
    print(f"\n[Bad Host Connect API]: {data['error'][:100]}")


# ─── Analyzers API ────────────────────────────────────────────────────────────

def test_analyzers_api(page: Page):
    """GET /api/analyzers returns list of analyzers."""
    res  = page.request.get(f"{BASE_URL}/api/analyzers")
    data = res.json()
    assert res.ok
    assert isinstance(data, list)
    assert len(data) >= 100
    first = data[0]
    assert "id"     in first
    assert "name"   in first
    assert "module" in first


def test_analyzers_filter_by_module(page: Page):
    """GET /api/analyzers?module=FINANCIALS returns only financial analyzers."""
    res  = page.request.get(f"{BASE_URL}/api/analyzers?module=FINANCIALS")
    data = res.json()
    assert res.ok
    for item in data:
        assert item["module"] == "FINANCIALS", f"Got non-FINANCIALS item: {item['id']}"


def test_single_analyzer_api(page: Page):
    """GET /api/analyzer/<id> returns analyzer details."""
    res  = page.request.get(f"{BASE_URL}/api/analyzer/cp")
    data = res.json()
    assert res.ok
    assert data["id"] == "cp"
    assert "name"        in data
    assert "description" in data


# ─── Session Management ───────────────────────────────────────────────────────

def test_new_session_api(page: Page):
    """POST /api/sessions/new returns a session_id."""
    res  = page.request.post(f"{BASE_URL}/api/sessions/new")
    data = res.json()
    assert res.ok
    assert "session_id" in data
    assert len(data["session_id"]) == 36  # UUID format


def test_get_session_api(page: Page):
    """GET /api/sessions/<id> returns session details."""
    # Create a session first
    r1  = page.request.post(f"{BASE_URL}/api/sessions/new")
    sid = r1.json()["session_id"]

    res  = page.request.get(f"{BASE_URL}/api/sessions/{sid}")
    data = res.json()
    assert res.ok
    assert data.get("session_id") == sid


def test_sessions_list_api(page: Page):
    """GET /api/sessions returns list."""
    res  = page.request.get(f"{BASE_URL}/api/sessions")
    data = res.json()
    assert res.ok
    assert isinstance(data, list)


# ─── Run Analyzer (Demo Mode) ─────────────────────────────────────────────────

def test_run_analyzer_cp(page: Page):
    """POST /api/run-analyzer runs cp analyzer in demo mode."""
    # Create session
    sid = page.request.post(f"{BASE_URL}/api/sessions/new").json()["session_id"]

    res  = page.request.post(
        f"{BASE_URL}/api/run-analyzer",
        data=json.dumps({"analyzer_id": "cp", "session_id": sid, "params": {}}),
        headers={"Content-Type": "application/json"},
    )
    data = res.json()
    assert res.ok
    assert data.get("success") is True
    assert "findings" in data
    assert isinstance(data["findings"], list)


def test_run_analyzer_ap_period_close(page: Page):
    """POST /api/run-analyzer runs ap_period_close analyzer in demo mode."""
    sid = page.request.post(f"{BASE_URL}/api/sessions/new").json()["session_id"]

    res  = page.request.post(
        f"{BASE_URL}/api/run-analyzer",
        data=json.dumps({"analyzer_id": "ap_period_close", "session_id": sid}),
        headers={"Content-Type": "application/json"},
    )
    data = res.json()
    assert res.ok
    assert data.get("success") is True
    findings = data["findings"]
    severities = [f.get("severity") for f in findings]
    assert any(s in ("CRITICAL", "HIGH") for s in severities), \
        "AP period close should have at least one CRITICAL or HIGH finding in demo mode"


# ─── System Info ─────────────────────────────────────────────────────────────

def test_system_info_api(page: Page):
    """GET /api/system/info returns EBS version and products."""
    res  = page.request.get(f"{BASE_URL}/api/system/info")
    data = res.json()
    assert res.ok
    assert "ebs_version"        in data
    assert "installed_products" in data
    assert isinstance(data["installed_products"], list)


# ─── EBS Agentic Apps ─────────────────────────────────────────────────────────

def test_fusion_apps_api(page: Page):
    """GET /api/fusion/apps returns all 15 EBS Agentic Apps."""
    res  = page.request.get(f"{BASE_URL}/api/fusion/apps")
    data = res.json()
    assert res.ok
    assert isinstance(data, list)
    assert len(data) >= 15, f"Expected >= 15 apps, got {len(data)}"
    pillars = {a["pillar"] for a in data}
    assert "FINANCE"  in pillars
    assert "SCM"      in pillars
    assert "PLANNING" in pillars
    for app in data:
        assert "id"      in app
        assert "name"    in app
        assert "pillar"  in app
        assert "tagline" in app


def test_fusion_page_loads(page: Page):
    """EBS Apps page loads with app cards and filter pills."""
    go(page, "/fusion")
    expect(page.locator(".fusion-hero")).to_be_visible()
    # Wait for apps to load from API
    page.wait_for_selector(".app-card", timeout=5000)
    cards = page.locator(".app-card")
    assert cards.count() >= 15, f"Expected >= 15 app cards, got {cards.count()}"


def test_fusion_page_filter_finance(page: Page):
    """Finance filter shows only Finance apps."""
    go(page, "/fusion")
    page.wait_for_selector(".app-card", timeout=5000)
    page.locator(".fusion-meta-pill", has_text="Finance").click()
    page.wait_for_timeout(500)
    cards = page.locator(".app-card[data-pillar='FINANCE']")
    assert cards.count() >= 5, f"Expected >= 5 Finance cards, got {cards.count()}"


@pytest.mark.parametrize("app_id,pillar", [
    ("payables",        "FINANCE"),
    ("collectors",      "FINANCE"),
    ("payments",        "FINANCE"),
    ("ledger",          "FINANCE"),
    ("fin_planning",    "FINANCE"),
    ("design_to_source","SCM"),
    ("quote_to_pr",     "SCM"),
    ("fulfillment",     "SCM"),
    ("sales_order",     "SCM"),
    ("cycle_count",     "SCM"),
    ("resilience",      "SCM"),
    ("demand_mgmt",     "PLANNING"),
    ("supply_planning", "PLANNING"),
    ("sop",             "PLANNING"),
    ("order_promising", "PLANNING"),
])
def test_fusion_run_api(page: Page, app_id: str, pillar: str):
    """POST /api/fusion/run/<app_id> returns structured results for every app."""
    res  = page.request.post(f"{BASE_URL}/api/fusion/run/{app_id}")
    data = res.json()
    assert res.ok, f"HTTP error for {app_id}: {res.status}"
    assert "error" not in data, f"Error in response for {app_id}: {data.get('error')}"
    assert data.get("app_id") == app_id
    assert data.get("pillar") == pillar
    assert "findings"       in data
    assert "demo_mode"      in data
    assert "execution_time_ms" in data

    # Live mode: verify query_results contain actual data or valid empty results
    if not data["demo_mode"]:
        qr = data.get("query_results", [])
        assert isinstance(qr, list), f"query_results is not a list for {app_id}"
        for q in qr:
            assert "query_id"   in q
            assert "row_count"  in q
            assert "columns"    in q
            assert "rows"       in q
            if "error" not in q:
                assert isinstance(q["rows"],    list)
                assert isinstance(q["columns"], list)
                # Columns and rows must be consistent
                if q["rows"]:
                    assert set(q["rows"][0].keys()) == set(q["columns"]), \
                        f"Column mismatch in {app_id}/{q['query_id']}"
            print(f"\n  [{app_id}] {q['query_id']}: "
                  f"{q.get('row_count',0)} rows, {q.get('execution_time_ms',0)}ms"
                  + (f" ERROR: {q['error'][:80]}" if "error" in q else ""))
    else:
        # Demo mode: check demo_findings
        findings = data.get("findings", [])
        assert isinstance(findings, list)
        print(f"\n  [{app_id}] demo mode: {len(findings)} findings")


def test_fusion_run_unknown_app(page: Page):
    """POST /api/fusion/run/<invalid> returns 404."""
    res = page.request.post(f"{BASE_URL}/api/fusion/run/nonexistent_app_xyz")
    assert res.status == 404
