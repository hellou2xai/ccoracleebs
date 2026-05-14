"""
Oracle EBS Support Agent — Flask Application
Replaces the Streamlit UI with a professional Flask web interface.
"""

import os
import json
import uuid
import logging
import time
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional

from dotenv import load_dotenv
load_dotenv()

from flask import (
    Flask,
    render_template,
    request,
    jsonify,
    Response,
    stream_with_context,
    session,
)
from flask_cors import CORS

# ─── Application Factory ──────────────────────────────────────────────────────

app = Flask(__name__)
app.secret_key = os.environ.get("SECRET_KEY", os.urandom(32).hex())
app.config["PERMANENT_SESSION_LIFETIME"] = timedelta(hours=8)
app.config["JSON_SORT_KEYS"] = False
app.config["JSONIFY_PRETTYPRINT_REGULAR"] = False

CORS(app)

logging.basicConfig(
    level=os.environ.get("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

APP_VERSION = "1.0.0"

# ─── Backend Imports ──────────────────────────────────────────────────────────

APP_READY = False
_import_error = None

try:
    from agents.orchestrator import OrchestratorAgent
    from tools.oracle_db import OracleDB
    from tools.pg_store import PostgreSQLStore
    from tools.result_parser import ResultParser, Finding
    from tools.report_generator import ReportGenerator
    from config.analyzer_registry import (
        ANALYZER_REGISTRY,
        get_analyzers_by_module,
        search_analyzers,
        MODULE_ATG,
        MODULE_FINANCIALS,
        MODULE_MANUFACTURING,
        MODULE_HCM,
        MODULE_CRM,
    )
    APP_READY = True
except Exception as e:
    _import_error = str(e)
    logger.error("Failed to import backend modules: %s", e)

# ─── Global Singletons ────────────────────────────────────────────────────────

_oracle_db = None
_pg_store = None
_orchestrator = None
_report_gen = None


def get_singletons():
    """Lazy-initialize global singletons."""
    global _oracle_db, _pg_store, _orchestrator, _report_gen
    if not APP_READY:
        return None, None, None, None
    if _oracle_db is None:
        _oracle_db = OracleDB()
        _oracle_db.connect()
        _oracle_db.create_pool()
        _pg_store = PostgreSQLStore()
        _pg_store.init_schema()
        _orchestrator = OrchestratorAgent(oracle_db=_oracle_db, pg_store=_pg_store)
        _report_gen = ReportGenerator()
        logger.info("Singletons initialized.")
    return _oracle_db, _pg_store, _orchestrator, _report_gen


# Initialize on startup
with app.app_context():
    get_singletons()

# ─── Template Context Processor ───────────────────────────────────────────────

@app.context_processor
def inject_globals():
    """Inject common variables into all templates."""
    oracle_db, pg_store, _, _ = get_singletons()
    oracle_connected = False
    oracle_demo = True
    pg_connected = False
    oracle_host = os.environ.get("ORACLE_HOST", "apps.example.com")

    if oracle_db:
        oracle_demo = getattr(oracle_db, "demo_mode", True)
        oracle_connected = not oracle_demo
        oracle_host = getattr(oracle_db, "host", oracle_host)
    if pg_store:
        pg_connected = pg_store.is_postgres_available()

    return {
        "app_version": APP_VERSION,
        "oracle_connected": oracle_connected,
        "oracle_demo": oracle_demo,
        "oracle_host": oracle_host,
        "pg_connected": pg_connected,
        "app_ready": APP_READY,
    }


# ─── Page Routes ──────────────────────────────────────────────────────────────

@app.route("/")
def index():
    """Main chat interface."""
    _, pg_store, _, _ = get_singletons()
    recent_sessions = []
    if pg_store:
        try:
            recent_sessions = pg_store.list_recent_sessions(5)
            for s in recent_sessions:
                for k, v in s.items():
                    if hasattr(v, "isoformat"):
                        s[k] = v.isoformat()
        except Exception:
            pass
    return render_template("index.html", recent_sessions=recent_sessions)


@app.route("/dashboard")
def dashboard():
    """Analyzer browser dashboard."""
    if not APP_READY:
        return render_template("index.html", error=_import_error)
    analyzers = list(ANALYZER_REGISTRY.values())
    modules = [MODULE_ATG, MODULE_FINANCIALS, MODULE_MANUFACTURING, MODULE_HCM, MODULE_CRM]
    _, pg_store, _, _ = get_singletons()
    recent_sessions = []
    if pg_store:
        try:
            recent_sessions = pg_store.list_recent_sessions(5)
            for s in recent_sessions:
                for k, v in s.items():
                    if hasattr(v, "isoformat"):
                        s[k] = v.isoformat()
        except Exception:
            pass
    return render_template("dashboard.html", analyzers=analyzers, modules=modules,
                           recent_sessions=recent_sessions)


@app.route("/fusion")
def fusion():
    """Oracle Fusion AI Agentic Applications reference dashboard."""
    return render_template("fusion.html")


@app.route("/report/<session_id>")
def report(session_id: str):
    """Incident report viewer."""
    _, pg_store, _, report_gen = get_singletons()
    session_data = {}
    findings = []
    audit_trail = []
    report_md = ""
    severity_counts = {"CRITICAL": 0, "HIGH": 0, "MEDIUM": 0, "LOW": 0, "INFO": 0}

    if pg_store:
        try:
            session_data = pg_store.get_session(session_id) or {}
            for k, v in session_data.items():
                if hasattr(v, "isoformat"):
                    session_data[k] = v.isoformat()
            raw_findings = pg_store.get_session_findings(session_id)
            for fd in raw_findings:
                clean = {}
                for k, v in fd.items():
                    clean[k] = v.isoformat() if hasattr(v, "isoformat") else v
                findings.append(clean)
            audit_trail_raw = pg_store.get_audit_trail(session_id)
            for entry in audit_trail_raw:
                clean = {}
                for k, v in entry.items():
                    clean[k] = v.isoformat() if hasattr(v, "isoformat") else v
                audit_trail.append(clean)
            severity_counts = pg_store.get_findings_summary(session_id)
        except Exception as e:
            logger.error("report route error: %s", e)

        if report_gen and findings:
            try:
                finding_objs = []
                for fd in findings:
                    try:
                        finding_objs.append(Finding(**{k: v for k, v in fd.items()
                                                       if k in Finding.model_fields}))
                    except Exception:
                        pass
                report_md = report_gen.generate_markdown_report(session_data, finding_objs)
            except Exception as e:
                logger.error("report generation error: %s", e)

    recent_sessions = []
    if pg_store:
        try:
            recent_sessions = pg_store.list_recent_sessions(5)
            for s in recent_sessions:
                for k, v in s.items():
                    if hasattr(v, "isoformat"):
                        s[k] = v.isoformat()
        except Exception:
            pass

    return render_template(
        "report.html",
        session_id=session_id,
        session_data=session_data,
        findings=findings,
        audit_trail=audit_trail,
        report_md=report_md,
        severity_counts=severity_counts,
        recent_sessions=recent_sessions,
    )


@app.route("/audit/<session_id>")
def audit(session_id: str):
    """Audit trail viewer."""
    _, pg_store, _, _ = get_singletons()
    audit_trail = []
    session_data = {}

    if pg_store:
        try:
            session_data = pg_store.get_session(session_id) or {}
            for k, v in session_data.items():
                if hasattr(v, "isoformat"):
                    session_data[k] = v.isoformat()
            audit_trail_raw = pg_store.get_audit_trail(session_id)
            for entry in audit_trail_raw:
                clean = {}
                for k, v in entry.items():
                    clean[k] = v.isoformat() if hasattr(v, "isoformat") else v
                audit_trail.append(clean)
        except Exception as e:
            logger.error("audit route error: %s", e)

    recent_sessions = []
    if pg_store:
        try:
            recent_sessions = pg_store.list_recent_sessions(5)
            for s in recent_sessions:
                for k, v in s.items():
                    if hasattr(v, "isoformat"):
                        s[k] = v.isoformat()
        except Exception:
            pass

    return render_template(
        "audit.html",
        session_id=session_id,
        session_data=session_data,
        audit_trail=audit_trail,
        recent_sessions=recent_sessions,
    )


# ─── API Routes ───────────────────────────────────────────────────────────────

@app.route("/api/chat", methods=["POST"])
def api_chat():
    """
    SSE streaming chat endpoint.
    Accepts: {"message": "...", "session_id": "...", "history": [...]}
    Streams Server-Sent Events.
    """
    if not APP_READY:
        return jsonify({"error": f"App not ready: {_import_error}"}), 503

    data = request.get_json(force=True, silent=True) or {}
    message = data.get("message", "").strip()
    session_id = data.get("session_id", str(uuid.uuid4()))
    history = data.get("history", [])

    if not message:
        return jsonify({"error": "message is required"}), 400

    _, pg_store, orchestrator, _ = get_singletons()
    if not orchestrator:
        return jsonify({"error": "Orchestrator not initialized"}), 503

    # Ensure session exists
    if pg_store:
        try:
            if not pg_store.get_session(session_id):
                pg_store.create_session(session_id, {"session_id": session_id,
                                                      "created_at": datetime.now().isoformat()})
        except Exception:
            pass

    def generate():
        try:
            for event in orchestrator.chat_stream(
                message=message,
                session_id=session_id,
                conversation_history=history,
            ):
                yield f"data: {json.dumps(event, default=str)}\n\n"
        except Exception as e:
            logger.error("SSE generation error: %s", e)
            yield f"data: {json.dumps({'type': 'error', 'text': str(e)})}\n\n"
            yield f"data: {json.dumps({'type': 'done', 'finding_count': 0, 'session_id': session_id})}\n\n"

    return Response(
        stream_with_context(generate()),
        mimetype="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        },
    )


@app.route("/api/run-analyzer", methods=["POST"])
def api_run_analyzer():
    """Run a single analyzer by ID."""
    if not APP_READY:
        return jsonify({"error": f"App not ready: {_import_error}"}), 503

    data = request.get_json(force=True, silent=True) or {}
    analyzer_id = data.get("analyzer_id", "").strip()
    session_id = data.get("session_id", str(uuid.uuid4()))
    params = data.get("params", {})

    if not analyzer_id:
        return jsonify({"error": "analyzer_id is required"}), 400

    _, pg_store, orchestrator, _ = get_singletons()
    if not orchestrator:
        return jsonify({"error": "Orchestrator not initialized"}), 503

    # Ensure session exists
    if pg_store:
        try:
            if not pg_store.get_session(session_id):
                pg_store.create_session(session_id, {"session_id": session_id,
                                                      "created_at": datetime.now().isoformat()})
        except Exception:
            pass

    start = time.time()
    try:
        result = orchestrator.run_analyzer_direct(
            analyzer_id=analyzer_id,
            session_id=session_id,
            params=params,
        )
        elapsed = int((time.time() - start) * 1000)
        return jsonify({
            "success": result.get("success", True),
            "findings": result.get("findings", []),
            "raw_output": result.get("raw_output_preview", ""),
            "execution_time_ms": result.get("execution_time_ms", elapsed),
            "analyzer_name": result.get("analyzer_name", analyzer_id),
            "session_id": session_id,
        })
    except Exception as e:
        logger.error("run-analyzer error: %s", e)
        return jsonify({"success": False, "error": str(e), "findings": [],
                        "execution_time_ms": int((time.time() - start) * 1000)}), 500


@app.route("/api/analyzers")
def api_analyzers():
    """List all analyzers, optionally filtered by ?module="""
    if not APP_READY:
        return jsonify({"error": f"App not ready: {_import_error}"}), 503

    module = request.args.get("module", "").upper()
    q = request.args.get("q", "").strip()

    if q:
        results = search_analyzers(q.split())
    elif module:
        results = get_analyzers_by_module(module)
    else:
        results = list(ANALYZER_REGISTRY.values())

    # Strip file paths from response for security
    safe = []
    for a in results:
        safe.append({
            "id": a.get("id"),
            "name": a.get("name"),
            "module": a.get("module"),
            "sub_module": a.get("sub_module", ""),
            "description": a.get("description", ""),
            "keywords": a.get("keywords", []),
            "mos_doc_id": a.get("mos_doc_id", ""),
            "severity_mappings": a.get("severity_mappings", {}),
        })
    return jsonify(safe)


@app.route("/api/analyzer/<analyzer_id>")
def api_analyzer_detail(analyzer_id: str):
    """Get metadata for a single analyzer."""
    if not APP_READY:
        return jsonify({"error": f"App not ready: {_import_error}"}), 503

    a = ANALYZER_REGISTRY.get(analyzer_id)
    if not a:
        return jsonify({"error": f"Analyzer '{analyzer_id}' not found"}), 404

    return jsonify({
        "id": a.get("id"),
        "name": a.get("name"),
        "module": a.get("module"),
        "sub_module": a.get("sub_module", ""),
        "description": a.get("description", ""),
        "keywords": a.get("keywords", []),
        "mos_doc_id": a.get("mos_doc_id", ""),
        "severity_mappings": a.get("severity_mappings", {}),
    })


@app.route("/api/agents")
def api_agents():
    """Alias for /api/analyzers — list all agents."""
    return api_analyzers()


@app.route("/api/agents/<agent_id>")
def api_agent_detail(agent_id: str):
    """Alias for /api/analyzer/<id> — get metadata for a single agent."""
    return api_analyzer_detail(agent_id)


@app.route("/api/sessions")
def api_sessions():
    """List recent sessions."""
    _, pg_store, _, _ = get_singletons()
    if not pg_store:
        return jsonify([])

    limit = min(int(request.args.get("limit", 20)), 100)
    try:
        sessions = pg_store.list_recent_sessions(limit)
        clean = []
        for s in sessions:
            cs = {}
            for k, v in s.items():
                cs[k] = v.isoformat() if hasattr(v, "isoformat") else v
            clean.append(cs)
        return jsonify(clean)
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/sessions/new", methods=["POST"])
def api_sessions_new():
    """Create a new session and return its ID."""
    _, pg_store, _, _ = get_singletons()
    new_id = str(uuid.uuid4())

    if pg_store:
        try:
            pg_store.create_session(new_id, {"session_id": new_id,
                                              "created_at": datetime.now().isoformat()})
        except Exception as e:
            logger.warning("create_session error: %s", e)

    return jsonify({"session_id": new_id})


@app.route("/api/sessions/<session_id>")
def api_session_detail(session_id: str):
    """Get session details with findings."""
    _, pg_store, _, _ = get_singletons()
    if not pg_store:
        return jsonify({"error": "Storage not available"}), 503

    try:
        s = pg_store.get_session(session_id)
        if not s:
            return jsonify({"error": "Session not found"}), 404
        clean = {}
        for k, v in s.items():
            clean[k] = v.isoformat() if hasattr(v, "isoformat") else v
        findings = pg_store.get_session_findings(session_id)
        clean_findings = []
        for fd in findings:
            cf = {}
            for k, v in fd.items():
                cf[k] = v.isoformat() if hasattr(v, "isoformat") else v
            clean_findings.append(cf)
        clean["findings"] = clean_findings
        clean["findings_count"] = len(clean_findings)
        clean["severity_counts"] = pg_store.get_findings_summary(session_id)
        return jsonify(clean)
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/sessions/<session_id>/findings")
def api_session_findings(session_id: str):
    """Return findings list for a session."""
    _, pg_store, _, _ = get_singletons()
    if not pg_store:
        return jsonify({"findings": [], "count": 0})

    try:
        findings = pg_store.get_session_findings(session_id)
        clean = []
        for fd in findings:
            cf = {}
            for k, v in fd.items():
                cf[k] = v.isoformat() if hasattr(v, "isoformat") else v
            clean.append(cf)
        return jsonify({"findings": clean, "count": len(clean),
                        "severity_counts": pg_store.get_findings_summary(session_id)})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/sessions/<session_id>/report")
def api_session_report(session_id: str):
    """Generate and return full report as JSON."""
    _, pg_store, _, report_gen = get_singletons()
    if not pg_store or not report_gen:
        return jsonify({"error": "Not available"}), 503

    try:
        session_data = pg_store.get_session(session_id) or {}
        raw_findings = pg_store.get_session_findings(session_id)
        finding_objs = []
        for fd in raw_findings:
            try:
                finding_objs.append(Finding(**{k: v for k, v in fd.items()
                                               if k in Finding.model_fields}))
            except Exception:
                pass

        report_md = report_gen.generate_markdown_report(session_data, finding_objs)
        severity_counts = pg_store.get_findings_summary(session_id)

        return jsonify({
            "session_id": session_id,
            "report_markdown": report_md,
            "findings_count": len(finding_objs),
            "severity_counts": severity_counts,
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/sessions/<session_id>/audit")
def api_session_audit(session_id: str):
    """Return audit log for a session."""
    _, pg_store, _, _ = get_singletons()
    if not pg_store:
        return jsonify({"audit": [], "count": 0})

    try:
        audit = pg_store.get_audit_trail(session_id)
        clean = []
        for entry in audit:
            ce = {}
            for k, v in entry.items():
                ce[k] = v.isoformat() if hasattr(v, "isoformat") else v
            clean.append(ce)
        return jsonify({"audit": clean, "count": len(clean)})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/system/health")
def api_system_health():
    """Return system health status."""
    oracle_db, pg_store, _, _ = get_singletons()

    oracle_info = {
        "connected": False,
        "demo_mode": True,
        "host": os.environ.get("ORACLE_HOST", "apps.example.com"),
    }
    pg_info = {"connected": False}

    if oracle_db:
        oracle_info["demo_mode"] = getattr(oracle_db, "demo_mode", True)
        oracle_info["connected"] = not oracle_info["demo_mode"]
        oracle_info["host"] = getattr(oracle_db, "host", oracle_info["host"])

    if pg_store:
        pg_info["connected"] = pg_store.is_postgres_available()

    analyzer_count = len(ANALYZER_REGISTRY) if APP_READY else 0

    ebs_version = "Unknown"
    if oracle_db:
        try:
            ver = oracle_db.get_ebs_version()
            ebs_version = ver.get("release_name", "12.2.x") if isinstance(ver, dict) else str(ver)
        except Exception:
            ebs_version = "12.2.x (demo)"

    return jsonify({
        "oracle": oracle_info,
        "postgres": pg_info,
        "ebs_version": ebs_version,
        "analyzer_count": analyzer_count,
        "app_version": APP_VERSION,
        "app_ready": APP_READY,
        "timestamp": datetime.now().isoformat(),
    })


@app.route("/api/system/info")
def api_system_info():
    """Return EBS system info including installed products."""
    oracle_db, _, _, _ = get_singletons()

    if not oracle_db:
        return jsonify({"error": "Oracle DB not initialized"}), 503

    try:
        version  = oracle_db.get_ebs_version()
        products = oracle_db.get_installed_products()
        managers = oracle_db.get_concurrent_managers()
        return jsonify({
            "ebs_version":          version.get("release_name", "Unknown"),
            "db_version":           version.get("db_version", "Unknown"),
            "instance_name":        version.get("instance_name", ""),
            "host_name":            version.get("host_name", ""),
            "installed_products":   products,
            "concurrent_managers":  managers,
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ─── Oracle Connection Management ────────────────────────────────────────────

@app.route("/api/oracle/credentials")
def api_oracle_credentials():
    """Return current Oracle connection config including password for modal pre-fill."""
    oracle_db, _, _, _ = get_singletons()
    creds = oracle_db.get_credentials_info() if oracle_db else {
        "host":         os.environ.get("ORACLE_HOST", ""),
        "port":         int(os.environ.get("ORACLE_PORT", 1521)),
        "service_name": os.environ.get("ORACLE_SERVICE_NAME", ""),
        "sid":          os.environ.get("ORACLE_SID", ""),
        "user":         os.environ.get("ORACLE_USER", "apps"),
        "client_dir":   os.environ.get("ORACLE_CLIENT_DIR", ""),
        "demo_mode":    True,
        "connected":    False,
    }
    # Include password for modal pre-fill (internal support tool)
    creds["password"] = os.environ.get("ORACLE_PASSWORD", "")
    return jsonify(creds)


@app.route("/api/oracle/connect", methods=["POST"])
def api_oracle_connect():
    """Attempt a live Oracle connection with provided (or default) credentials."""
    oracle_db, _, _, _ = get_singletons()
    if not oracle_db:
        return jsonify({"success": False, "error": "Backend not initialised"}), 503

    data = request.get_json(silent=True) or {}
    result = oracle_db.connect_live(
        host=data.get("host") or None,
        port=data.get("port") or None,
        service_name=data.get("service_name") or None,
        user=data.get("user") or None,
        password=data.get("password") or None,
        client_dir=data.get("client_dir") or None,
    )
    return jsonify(result)


@app.route("/api/oracle/nettest")
def api_oracle_nettest():
    """Quick TCP connectivity test to the Oracle host — no credentials needed."""
    import socket
    host = os.environ.get("ORACLE_HOST", "apps.example.com")
    port = int(os.environ.get("ORACLE_PORT", "1521"))
    ip = os.environ.get("ORACLE_HOST_IP", "")

    results = {"host": host, "port": port, "oracle_host_ip_env": ip}

    # DNS resolution
    try:
        addrs = socket.getaddrinfo(host, port)
        results["dns_resolved"] = [a[4][0] for a in addrs]
    except Exception as e:
        results["dns_resolved"] = None
        results["dns_error"] = str(e)

    # TCP connect
    try:
        sock = socket.create_connection((host, port), timeout=5)
        sock.close()
        results["tcp_reachable"] = True
    except Exception as e:
        results["tcp_reachable"] = False
        results["tcp_error"] = str(e)

    # Also test raw IP if provided
    if ip:
        try:
            sock = socket.create_connection((ip, port), timeout=5)
            sock.close()
            results["ip_tcp_reachable"] = True
        except Exception as e:
            results["ip_tcp_reachable"] = False
            results["ip_tcp_error"] = str(e)

    # Check /etc/hosts entry
    try:
        with open("/etc/hosts") as f:
            results["etc_hosts"] = [l.strip() for l in f if host in l]
    except Exception:
        pass

    return jsonify(results)


@app.route("/api/fusion/apps")
def api_fusion_apps():
    """List all EBS Agentic Apps."""
    from config.fusion_apps import list_fusion_apps
    return jsonify(list_fusion_apps())


@app.route("/api/fusion/run/<app_id>", methods=["POST"])
def api_fusion_run(app_id: str):
    """
    Execute an EBS Agentic App against the live Oracle DB.
    Body (optional JSON): {"days_back": 30}
    Returns structured findings + raw data rows for each query.
    """
    from config.fusion_apps import get_fusion_app
    oracle_db, _, _, _ = get_singletons()

    app_def = get_fusion_app(app_id)
    if not app_def:
        return jsonify({"error": f"Unknown app: {app_id}"}), 404

    # User-defined look-back window; clamp to 1–365 days
    body = request.get_json(silent=True) or {}
    try:
        days_back = max(1, min(365, int(body.get("days_back", 30))))
    except (TypeError, ValueError):
        days_back = 30

    demo_mode = (oracle_db is None) or oracle_db.demo_mode
    results = []
    all_findings = []
    total_start = time.time()

    if demo_mode:
        # Return rich demo findings
        return jsonify({
            "app_id": app_id,
            "app_name": app_def["name"],
            "pillar": app_def["pillar"],
            "demo_mode": True,
            "days_back": days_back,
            "findings": app_def.get("demo_findings", []),
            "query_results": [],
            "execution_time_ms": 50,
            "message": "Demo mode — connect to Oracle for live data",
        })

    # Live mode: run each query with days_back substituted
    for q in app_def.get("queries", []):
        q_start = time.time()
        try:
            sql = q["sql"].strip().format(days_back=days_back)
            rows = oracle_db.execute_query(sql, max_rows=200)
            elapsed = int((time.time() - q_start) * 1000)
            count = len(rows)
            columns = list(rows[0].keys()) if rows else []

            # Apply severity rules
            findings_for_query = []
            for rule in q.get("severity_rules", []):
                op = rule.get("op", ">")
                threshold = rule.get("value", 0)
                meets = (op == ">" and count > threshold) or \
                        (op == ">=" and count >= threshold) or \
                        (op == "==" and count == threshold) or \
                        (op == "==" and count == threshold)
                if meets:
                    msg = rule["message"].format(count=count)
                    findings_for_query.append({
                        "severity": rule["severity"],
                        "category": q["label"],
                        "count": count,
                        "description": msg,
                        "query_id": q["id"],
                    })
                    all_findings.append(findings_for_query[-1])
                    break  # First matching rule wins

            results.append({
                "query_id": q["id"],
                "label": q["label"],
                "row_count": count,
                "columns": columns,
                "rows": rows[:100],   # cap at 100 rows for response
                "execution_time_ms": elapsed,
                "findings": findings_for_query,
            })
        except Exception as exc:
            logger.warning("Fusion app %s query %s error: %s", app_id, q["id"], exc)
            results.append({
                "query_id": q["id"],
                "label": q["label"],
                "row_count": 0,
                "columns": [],
                "rows": [],
                "execution_time_ms": 0,
                "error": str(exc),
                "findings": [],
            })

    total_elapsed = int((time.time() - total_start) * 1000)

    return jsonify({
        "app_id": app_id,
        "app_name": app_def["name"],
        "pillar": app_def["pillar"],
        "demo_mode": False,
        "days_back": days_back,
        "findings": all_findings,
        "query_results": results,
        "execution_time_ms": total_elapsed,
    })


@app.route("/payables")
def payables():
    """Payables Agentic App — dedicated AP workspace."""
    return render_template("payables.html")


@app.route("/api/payables/run", methods=["POST"])
def api_payables_run():
    """
    Execute the Payables Agentic App analysis.
    Body: {"days_back": 30}
    Returns KPIs, findings, and 5 query result sets.
    """
    from config.payables_app import (
        PAYABLES_QUERIES, compute_kpis, compute_findings,
        DEMO_KPIS, DEMO_FINDINGS,
    )
    oracle_db, _, _, _ = get_singletons()

    body = request.get_json(silent=True) or {}
    try:
        days_back = max(1, min(365, int(body.get("days_back", 30))))
    except (TypeError, ValueError):
        days_back = 30

    demo_mode = (oracle_db is None) or oracle_db.demo_mode

    if demo_mode:
        return jsonify({
            "demo_mode": True,
            "days_back": days_back,
            "execution_time_ms": 50,
            "kpis": DEMO_KPIS,
            "findings": DEMO_FINDINGS,
            "queries": {
                "summary":              {"rows": [], "columns": [], "row_count": 0},
                "invoice_health":       {"rows": [], "columns": [], "row_count": 32},
                "holds":                {"rows": [], "columns": [], "row_count": 12},
                "approvers":            {"rows": [], "columns": [], "row_count": 6},
                "discounts":            {"rows": [], "columns": [], "row_count": 18},
                "unapproved_invoices":  {"rows": [], "columns": [], "row_count": 8},
                "duplicate_risk":       {"rows": [], "columns": [], "row_count": 4},
                "non_po_invoices":      {"rows": [], "columns": [], "row_count": 22},
                "supplier_aging":       {"rows": [], "columns": [], "row_count": 15},
                "match_exceptions":     {"rows": [], "columns": [], "row_count": 7},
                "cycle_time":           {"rows": [], "columns": [], "row_count": 45},
                "open_prepayments":     {"rows": [], "columns": [], "row_count": 3},
                "approval_bottleneck":  {"rows": [], "columns": [], "row_count": 5},
            },
        })

    results = {}
    total_start = time.time()

    for qid, q in PAYABLES_QUERIES.items():
        q_start = time.time()
        try:
            sql = q["sql"].strip().format(days_back=days_back)
            rows = oracle_db.execute_query(sql, max_rows=200)
            results[qid] = {
                "rows": rows,
                "columns": list(rows[0].keys()) if rows else [],
                "row_count": len(rows),
                "execution_time_ms": int((time.time() - q_start) * 1000),
            }
        except Exception as exc:
            logger.warning("Payables query %s error: %s", qid, exc)
            results[qid] = {
                "rows": [], "columns": [], "row_count": 0,
                "execution_time_ms": 0, "error": str(exc),
            }

    kpis = compute_kpis(results)
    findings = compute_findings(kpis, results)

    return jsonify({
        "demo_mode": False,
        "days_back": days_back,
        "execution_time_ms": int((time.time() - total_start) * 1000),
        "kpis": kpis,
        "findings": findings,
        "queries": results,
    })


@app.route("/api/payables/invoice_lines/<int:invoice_id>", methods=["GET"])
def api_payables_invoice_lines(invoice_id):
    """Fetch invoice lines for a single invoice (drill-down)."""
    oracle_db, _, _, _ = get_singletons()
    demo_mode = (oracle_db is None) or oracle_db.demo_mode

    if demo_mode:
        # Return plausible demo lines
        import random
        random.seed(invoice_id)
        line_types = ['ITEM', 'ITEM', 'ITEM', 'FREIGHT', 'TAX']
        descriptions = ['Professional Services', 'Software License', 'Hardware Supply',
                        'Freight Charge', 'Tax']
        rows = []
        for i in range(1, random.randint(2, 5)):
            amt = round(random.uniform(200, 15000), 2)
            rows.append({
                'line_number': i,
                'line_type': line_types[i % len(line_types)],
                'description': descriptions[i % len(descriptions)],
                'amount': amt,
                'quantity_invoiced': random.randint(1, 10),
                'unit_price': round(amt / random.randint(1, 10), 2),
                'accounting_date': '2024-03-15',
                'po_header_id': random.randint(10000, 99999) if i == 1 else None,
            })
        return jsonify({'demo_mode': True, 'invoice_id': invoice_id, 'rows': rows, 'row_count': len(rows)})

    sql = """
        SELECT l.line_number,
               l.line_type_lookup_code                                      line_type,
               NVL(l.description,
                   NVL(l.item_description,
                       NVL((SELECT pl.item_description
                            FROM   po_lines_all pl
                            WHERE  pl.po_line_id = l.po_line_id
                              AND  ROWNUM = 1),
                           l.line_type_lookup_code)))                       description,
               ROUND(l.amount, 2)                                          amount,
               l.quantity_invoiced,
               ROUND(NVL(l.unit_price,
                         CASE WHEN l.quantity_invoiced > 0
                              THEN l.amount / l.quantity_invoiced
                         END), 4)                                          unit_price,
               l.accounting_date,
               l.po_header_id,
               l.po_line_id
        FROM ap_invoice_lines_all l
        WHERE l.invoice_id = :invoice_id
          AND NVL(l.cancelled_flag, 'N') = 'N'
        ORDER BY l.line_number
    """
    try:
        rows = oracle_db.execute_query(sql, params={'invoice_id': invoice_id}, max_rows=200)
        return jsonify({'demo_mode': False, 'invoice_id': invoice_id, 'rows': rows, 'row_count': len(rows)})
    except Exception as exc:
        logger.warning("Invoice lines query error (invoice_id=%s): %s", invoice_id, exc)
        return jsonify({'error': str(exc), 'rows': [], 'row_count': 0}), 200


@app.route("/api/payables/vendor_history/<int:vendor_id>", methods=["GET"])
def api_payables_vendor_history(vendor_id):
    """Recent payment history for a vendor (Unapproved + Aging drill-down)."""
    oracle_db, _, _, _ = get_singletons()
    demo_mode = (oracle_db is None) or oracle_db.demo_mode

    if demo_mode:
        import random
        random.seed(vendor_id)
        statuses = ['NEGOTIATED', 'NEGOTIATED', 'CLEARED', 'NEGOTIATED', 'VOIDED']
        methods  = ['EFT', 'CHECK', 'EFT', 'WIRE', 'CHECK']
        rows = []
        for i in range(5):
            m = random.randint(1, 12)
            d = random.randint(1, 28)
            rows.append({
                'check_date':                  f'2024-{str(m).zfill(2)}-{str(d).zfill(2)}',
                'amount':                      round(random.uniform(1000, 50000), 2),
                'currency_code':               'USD',
                'status_lookup_code':          statuses[i % len(statuses)],
                'payment_method_lookup_code':  methods[i % len(methods)],
            })
        return jsonify({'demo_mode': True, 'vendor_id': vendor_id, 'rows': rows, 'row_count': len(rows)})

    sql = """
        SELECT c.check_date,
               ROUND(c.amount, 2)              amount,
               c.currency_code,
               c.status_lookup_code,
               c.payment_method_lookup_code
        FROM   ap_checks_all c
        WHERE  c.vendor_id = :vendor_id
          AND  c.status_lookup_code NOT IN ('VOIDED', 'STOP INITIATED')
        ORDER  BY c.check_date DESC
        FETCH FIRST 10 ROWS ONLY
    """
    try:
        rows = oracle_db.execute_query(sql, params={'vendor_id': vendor_id}, max_rows=10)
        return jsonify({'demo_mode': False, 'vendor_id': vendor_id, 'rows': rows, 'row_count': len(rows)})
    except Exception as exc:
        logger.warning("Vendor history error (vendor_id=%s): %s", vendor_id, exc)
        return jsonify({'error': str(exc), 'rows': [], 'row_count': 0}), 200


@app.route("/api/oracle/demo", methods=["POST"])
def api_oracle_demo():
    """Switch to Demo Mode (disconnects live Oracle if active)."""
    oracle_db, _, _, _ = get_singletons()
    if oracle_db:
        oracle_db.set_demo_mode(True)
    return jsonify({"success": True, "mode": "demo", "message": "Switched to Demo Mode"})


# ─── Error Handlers ───────────────────────────────────────────────────────────

@app.errorhandler(404)
def not_found(e):
    if request.path.startswith("/api/"):
        return jsonify({"error": "Endpoint not found"}), 404
    return render_template("index.html"), 404


# ─── Supply Chain Planning Agentic App ────────────────────────────────────────

@app.route("/scp")
def scp_page():
    """Supply Chain Planning Agentic App — dedicated SCP workspace."""
    return render_template("scp.html")


@app.route("/api/scp/plans", methods=["GET"])
def api_scp_plans():
    """List available ASCP/MRP plans for the plan selector dropdown."""
    oracle_db, _, _, _ = get_singletons()
    demo_mode = (oracle_db is None) or oracle_db.demo_mode

    if demo_mode:
        return jsonify({
            "demo_mode": True,
            "plans": [
                {"plan_id": 1001, "plan_name": "MRP-DAILY", "plan_type": "MRP", "days_since_run": 0.8, "exception_count": 87, "org_count": 3},
                {"plan_id": 1002, "plan_name": "MPS-WEEKLY", "plan_type": "MPS", "days_since_run": 2.1, "exception_count": 34, "org_count": 2},
                {"plan_id": 1003, "plan_name": "DRP-CENTRAL", "plan_type": "DRP", "days_since_run": 1.5, "exception_count": 22, "org_count": 5},
                {"plan_id": 1004, "plan_name": "SOP-Q2", "plan_type": "SOP", "days_since_run": 4.0, "exception_count": 12, "org_count": 4},
            ],
        })

    sql = """
        SELECT p.plan_id,
               p.compile_designator                               plan_name,
               DECODE(p.plan_type, 1,'MRP', 2,'MPS', 3,'DRP',
                      4,'MPS-MRP', 5,'SOP', TO_CHAR(p.plan_type)) plan_type,
               ROUND(SYSDATE - NVL(p.plan_completion_date,
                     p.data_completion_date), 1)                   days_since_run,
               (SELECT COUNT(*) FROM msc_exception_details e
                WHERE e.plan_id = p.plan_id
                  AND e.sr_instance_id = p.sr_instance_id)        exception_count,
               (SELECT COUNT(DISTINCT po.organization_id)
                FROM msc_plan_organizations po
                WHERE po.plan_id = p.plan_id
                  AND po.sr_instance_id = p.sr_instance_id)       org_count
        FROM   msc_plans p
        ORDER  BY NVL(p.plan_completion_date, p.data_completion_date) DESC NULLS LAST
        FETCH FIRST 200 ROWS ONLY
    """
    try:
        rows = oracle_db.execute_query(sql, max_rows=200)
        return jsonify({"demo_mode": False, "plans": rows})
    except Exception as exc:
        logger.warning("SCP plan list error: %s", exc)
        return jsonify({"demo_mode": False, "plans": [], "error": str(exc)})


@app.route("/api/scp/run", methods=["POST"])
def api_scp_run():
    """
    Execute the Supply Chain Planning analysis.
    Body: {"days_back": 90, "plan_id": <optional>}
    Returns KPIs, findings, and 15 query result sets.
    """
    from config.scp_app import (
        SCP_QUERIES, compute_kpis, compute_findings,
        DEMO_KPIS, DEMO_FINDINGS,
    )
    oracle_db, _, _, _ = get_singletons()

    body = request.get_json(silent=True) or {}
    plan_id = body.get("plan_id")  # optional — if not set, queries use MAX(plan_id)
    try:
        days_back = max(1, min(10000, int(body.get("days_back", 10000))))
    except (TypeError, ValueError):
        days_back = 10000

    demo_mode = (oracle_db is None) or oracle_db.demo_mode

    if demo_mode:
        return jsonify({
            "demo_mode": True,
            "days_back": days_back,
            "plan_id": plan_id or 1001,
            "plan_name": "MRP-DAILY",
            "execution_time_ms": 0,
            "kpis": DEMO_KPIS,
            "findings": DEMO_FINDINGS,
            "queries": {},
        })

    start = time.time()

    # Build plan_date: use the selected plan's completion date as the reference point
    # instead of SYSDATE, since plan data may be from years ago
    if plan_id:
        plan_date_expr = (f"(SELECT NVL(p.plan_completion_date, p.data_completion_date) "
                          f"FROM msc_plans p WHERE p.plan_id = {int(plan_id)})")
    else:
        plan_date_expr = ("(SELECT NVL(MAX(p.plan_completion_date), MAX(p.data_completion_date)) "
                          "FROM msc_plans p WHERE p.plan_completion_date IS NOT NULL "
                          "OR p.data_completion_date IS NOT NULL)")

    import re

    results = {}
    for qid, qdef in SCP_QUERIES.items():
        sql = qdef["sql"]
        sql = sql.replace("{days_back}", str(days_back))
        sql = sql.replace("{plan_date}", plan_date_expr)
        # Replace plan_id subqueries with the specific plan_id if provided
        if plan_id:
            sql = re.sub(
                r"\(SELECT MAX\(plan_id\) FROM msc_plans\s+WHERE [^)]+\)",
                str(int(plan_id)),
                sql,
            )
        q_start = time.time()
        try:
            rows = oracle_db.execute_query(sql, max_rows=200)
            q_ms = round((time.time() - q_start) * 1000)
            cols = list(rows[0].keys()) if rows else []
            results[qid] = {
                "rows": rows,
                "columns": cols,
                "row_count": len(rows),
                "execution_time_ms": q_ms,
            }
        except Exception as exc:
            logger.warning("SCP query %s error: %s", qid, exc)
            results[qid] = {
                "rows": [],
                "columns": [],
                "row_count": 0,
                "error": str(exc),
            }

    total_elapsed = round((time.time() - start) * 1000)
    kpis = compute_kpis(results)
    findings = compute_findings(kpis, results)

    return jsonify({
        "demo_mode": False,
        "days_back": days_back,
        "execution_time_ms": total_elapsed,
        "kpis": kpis,
        "findings": findings,
        "queries": results,
    })


@app.route("/api/scp/item_detail/<int:item_id>", methods=["GET"])
def api_scp_item_detail(item_id):
    """Drill-down: demand and supply timelines for a specific item."""
    oracle_db, _, _, _ = get_singletons()
    demo_mode = (oracle_db is None) or oracle_db.demo_mode

    if demo_mode:
        import random
        random.seed(item_id)
        now = time.time()
        demands = []
        for i in range(random.randint(3, 8)):
            days_out = random.randint(1, 60)
            demands.append({
                'demand_date': (datetime.now() + timedelta(days=days_out)).strftime('%Y-%m-%d'),
                'quantity': round(random.uniform(50, 500), 2),
                'demand_source': random.choice(['SALES_ORDER', 'FORECAST', 'MRP', 'INTERORG']),
                'order_number': f'SO-{random.randint(10000, 99999)}' if random.random() > 0.3 else None,
            })
        supplies = []
        for i in range(random.randint(2, 6)):
            days_out = random.randint(1, 45)
            supplies.append({
                'supply_date': (datetime.now() + timedelta(days=days_out)).strftime('%Y-%m-%d'),
                'quantity': round(random.uniform(100, 800), 2),
                'supply_type': random.choice(['PO', 'WO', 'PLANNED', 'INTRANSIT']),
                'supplier_name': random.choice(['Precision Parts Inc', 'TechComp Ltd', 'GlobalSupply Co', None]),
                'firm_status': random.choice([None, 'FIRM', None]),
            })
        return jsonify({
            'demo_mode': True,
            'item_id': item_id,
            'demands': sorted(demands, key=lambda x: x['demand_date']),
            'supplies': sorted(supplies, key=lambda x: x['supply_date']),
        })

    demand_sql = """
        SELECT d.using_assembly_demand_date                          demand_date,
               ROUND(d.using_requirement_quantity, 2)               quantity,
               DECODE(d.origination_type, 1,'MPS', 2,'MRP', 3,'FORECAST',
                      6,'SALES_ORDER', 7,'MANUAL', 8,'INTERORG',
                      TO_CHAR(d.origination_type))                  demand_source,
               d.order_number
        FROM   msc_demands d
        WHERE  d.inventory_item_id = :item_id
          AND  d.plan_id = (SELECT MAX(plan_id) FROM msc_plans
                            WHERE data_completion_date IS NOT NULL)
          AND  d.using_assembly_demand_date BETWEEN TRUNC(SYSDATE) AND TRUNC(SYSDATE) + 90
        ORDER  BY d.using_assembly_demand_date
        FETCH FIRST 50 ROWS ONLY
    """
    supply_sql = """
        SELECT s.new_schedule_date                                  supply_date,
               ROUND(s.new_order_quantity, 2)                       quantity,
               DECODE(s.order_type, 1,'PO', 3,'WO', 5,'PLANNED',
                      7,'INTRANSIT', TO_CHAR(s.order_type))         supply_type,
               tp.partner_name                                      supplier_name,
               s.disposition_status_type                             firm_status
        FROM   msc_supplies s
        LEFT JOIN msc_trading_partners tp
          ON   tp.partner_id = s.supplier_id
          AND  tp.sr_instance_id = s.sr_instance_id
        WHERE  s.inventory_item_id = :item_id
          AND  s.plan_id = (SELECT MAX(plan_id) FROM msc_plans
                            WHERE data_completion_date IS NOT NULL)
          AND  s.new_schedule_date BETWEEN TRUNC(SYSDATE) - 7 AND TRUNC(SYSDATE) + 90
        ORDER  BY s.new_schedule_date
        FETCH FIRST 50 ROWS ONLY
    """
    try:
        demands = oracle_db.execute_query(demand_sql, params={'item_id': item_id}, max_rows=50)
        supplies = oracle_db.execute_query(supply_sql, params={'item_id': item_id}, max_rows=50)
        return jsonify({
            'demo_mode': False, 'item_id': item_id,
            'demands': demands, 'supplies': supplies,
        })
    except Exception as exc:
        logger.warning("SCP item detail error (item_id=%s): %s", item_id, exc)
        return jsonify({'error': str(exc), 'demands': [], 'supplies': []}), 200


@app.route("/api/scp/plan_exceptions/<int:plan_id>", methods=["GET"])
def api_scp_plan_exceptions(plan_id):
    """All exceptions for a specific plan."""
    oracle_db, _, _, _ = get_singletons()
    demo_mode = (oracle_db is None) or oracle_db.demo_mode

    if demo_mode:
        import random
        random.seed(plan_id)
        types = [1, 2, 6, 7, 9, 14, 24]
        names = ['Shortage-reschedule in', 'Shortage-expedite', 'Excess-reschedule out',
                 'Excess-cancel', 'Late supply', 'Resource overload', 'Forecast deviation']
        items = ['Bearing Assembly BA-2040', 'PCB Board PCB-X100', 'Motor Housing MH-500',
                 'Hydraulic Pump HP-300', 'Control Valve CV-200']
        rows = []
        for i in range(random.randint(20, 50)):
            idx = i % len(types)
            rows.append({
                'exception_type': types[idx],
                'exception_name': names[idx],
                'item_name': items[i % len(items)],
                'planner_code': random.choice(['JSMITH', 'MLEE', 'RPATEL']),
                'make_buy': random.choice(['MAKE', 'BUY']),
                'quantity': round(random.uniform(10, 500), 2),
                'exception_date': (datetime.now() + timedelta(days=random.randint(-5, 30))).strftime('%Y-%m-%d'),
                'suggested_date': (datetime.now() + timedelta(days=random.randint(1, 45))).strftime('%Y-%m-%d'),
            })
        return jsonify({'demo_mode': True, 'plan_id': plan_id, 'rows': rows, 'row_count': len(rows)})

    sql = """
        SELECT e.exception_type,
               mle.meaning                                         exception_name,
               msi.item_name,
               msi.planner_code,
               DECODE(msi.planning_make_buy_code, 1,'MAKE', 2,'BUY') make_buy,
               e.quantity,
               e.date1                                             exception_date,
               e.date2                                             suggested_date,
               ROUND(e.date2 - e.date1, 0)                        days_delta
        FROM   msc_exception_details e
        JOIN   msc_system_items msi
          ON   msi.inventory_item_id = e.inventory_item_id
          AND  msi.plan_id           = e.plan_id
          AND  msi.sr_instance_id    = e.sr_instance_id
        LEFT JOIN mfg_lookups mle
          ON   mle.lookup_type = 'MSC_EXCEPTION_TYPE'
          AND  mle.lookup_code = e.exception_type
        WHERE  e.plan_id = :plan_id
        ORDER  BY e.exception_type, e.quantity DESC
        FETCH FIRST 200 ROWS ONLY
    """
    try:
        rows = oracle_db.execute_query(sql, params={'plan_id': plan_id}, max_rows=200)
        return jsonify({'demo_mode': False, 'plan_id': plan_id, 'rows': rows, 'row_count': len(rows)})
    except Exception as exc:
        logger.warning("SCP plan exceptions error (plan_id=%s): %s", plan_id, exc)
        return jsonify({'error': str(exc), 'rows': [], 'row_count': 0}), 200


@app.route("/api/scp/graph/<int:plan_id>")
def scp_graph(plan_id):
    """Return nodes and edges for supply chain network graph visualization."""
    import random as _rnd
    oracle_db, _, _, _ = get_singletons()
    demo_mode = (oracle_db is None) or oracle_db.demo_mode

    if demo_mode:
        # ── Generate realistic demo graph (~30 nodes, ~40 edges) ─────────
        _demo_items = [
            (10001, 'Bearing Assembly BA-2040', 'BUY'),
            (10002, 'PCB Board PCB-X100', 'BUY'),
            (10003, 'Motor Housing MH-500', 'MAKE'),
            (10004, 'Hydraulic Pump HP-300', 'MAKE'),
            (10005, 'Control Valve CV-200', 'BUY'),
            (10006, 'Gear Box GB-150', 'MAKE'),
            (10007, 'Sensor Module SM-400', 'BUY'),
            (10008, 'Steel Plate SP-1000', 'BUY'),
        ]
        _demo_suppliers = [
            'Precision Parts Inc', 'TechComp Ltd', 'GlobalSupply Co',
            'FastTrack Components', 'QualityFirst Mfg',
        ]
        _supply_types = ['PO', 'WO', 'PLANNED', 'INTRANSIT']
        _demand_sources = ['SALES_ORDER', 'FORECAST', 'MPS']
        _statuses = ['OK', 'OK', 'OK', 'TIGHT', 'LATE']  # weighted toward OK

        nodes = []
        edges = []
        node_ids = set()

        # Item nodes
        for iid, iname, mb in _demo_items:
            nid = f"item_{iid}"
            nodes.append({"id": nid, "label": iname, "group": "item", "make_buy": mb})
            node_ids.add(nid)

        # Supplier nodes
        for sup in _demo_suppliers:
            nid = f"supplier_{sup.replace(' ', '_')}"
            nodes.append({"id": nid, "label": sup, "group": "supplier"})
            node_ids.add(nid)

        late_count = 0
        tight_count = 0

        # Supply + demand nodes with edges
        for idx in range(14):
            item = _demo_items[idx % len(_demo_items)]
            iid, iname, mb = item
            item_nid = f"item_{iid}"

            sup_name = _demo_suppliers[idx % len(_demo_suppliers)]
            sup_nid = f"supplier_{sup_name.replace(' ', '_')}"

            stype = _rnd.choice(_supply_types)
            qty = _rnd.randint(100, 2000)
            status = _rnd.choice(_statuses)
            if status == 'LATE':
                late_count += 1
            elif status == 'TIGHT':
                tight_count += 1

            supply_nid = f"supply_{stype}_{idx}"
            nodes.append({
                "id": supply_nid,
                "label": f"{stype} ({qty} units)",
                "group": "supply",
                "status": status,
            })

            # Supplier -> Supply
            if mb == 'BUY':
                edges.append({"from": sup_nid, "to": supply_nid, "label": "supplies"})
            # Supply -> Item
            edges.append({"from": supply_nid, "to": item_nid, "label": f"{qty} units", "status": status})

            # Demand node
            dsrc = _rnd.choice(_demand_sources)
            dord = f"{'SO' if dsrc == 'SALES_ORDER' else 'FC'}-{1000 + idx}"
            dqty = _rnd.randint(50, qty)
            demand_nid = f"demand_{dord}"
            if demand_nid not in node_ids:
                nodes.append({
                    "id": demand_nid,
                    "label": f"{dord} ({dqty} units)",
                    "group": "demand",
                })
                node_ids.add(demand_nid)

            edges.append({"from": item_nid, "to": demand_nid, "label": f"pegged {dqty}", "status": status})

        return jsonify({
            "demo_mode": True,
            "plan_id": plan_id or 101,
            "nodes": nodes,
            "edges": edges,
            "stats": {
                "total_nodes": len(nodes),
                "late_count": late_count,
                "tight_count": tight_count,
            },
        })

    # ── Live mode — query MSC_FULL_PEGGING ───────────────────────────────
    sql = """
        SELECT DISTINCT
            msi.item_name,
            msi.inventory_item_id,
            DECODE(msi.planning_make_buy_code, 1,'MAKE', 2,'BUY') make_buy,
            DECODE(s.order_type, 1,'PO', 3,'WO', 5,'PLANNED', 7,'INTRANSIT', TO_CHAR(s.order_type)) supply_type,
            s.new_schedule_date supply_date,
            ROUND(fp.allocated_quantity, 2) pegged_qty,
            DECODE(d.origination_type, 1,'MPS', 2,'MRP', 3,'FORECAST', 6,'SALES_ORDER', 7,'MANUAL', TO_CHAR(d.origination_type)) demand_source,
            d.using_assembly_demand_date demand_date,
            d.order_number demand_order,
            CASE WHEN s.new_schedule_date > d.using_assembly_demand_date THEN 'LATE'
                 WHEN s.new_schedule_date > d.using_assembly_demand_date - 3 THEN 'TIGHT'
                 ELSE 'OK' END pegging_status,
            NVL(tp.partner_name, 'Internal') supplier_name
        FROM msc_full_pegging fp
        JOIN msc_supplies s ON s.transaction_id = fp.transaction_id AND s.plan_id = fp.plan_id AND s.sr_instance_id = fp.sr_instance_id
        JOIN msc_demands d ON d.demand_id = fp.demand_id AND d.plan_id = fp.plan_id AND d.sr_instance_id = fp.sr_instance_id
        JOIN msc_system_items msi ON msi.inventory_item_id = fp.inventory_item_id AND msi.plan_id = fp.plan_id AND msi.sr_instance_id = fp.sr_instance_id
        LEFT JOIN msc_trading_partners tp ON tp.partner_id = s.supplier_id AND tp.sr_instance_id = s.sr_instance_id
        WHERE fp.plan_id = :plan_id
        FETCH FIRST 500 ROWS ONLY
    """
    try:
        rows = oracle_db.execute_query(sql, params={'plan_id': plan_id}, max_rows=500)
    except Exception as exc:
        logger.warning("SCP graph query error (plan_id=%s): %s", plan_id, exc)
        return jsonify({'error': str(exc), 'nodes': [], 'edges': [], 'stats': {}})

    nodes = {}
    edges = []
    late_count = 0
    tight_count = 0

    for r in rows:
        item_id = r.get('inventory_item_id')
        item_name = r.get('item_name', f'Item-{item_id}')
        make_buy = r.get('make_buy', '')
        supply_type = r.get('supply_type', 'SUPPLY')
        pegged_qty = r.get('pegged_qty', 0)
        demand_source = r.get('demand_source', 'DEMAND')
        demand_order = r.get('demand_order', '')
        status = r.get('pegging_status', 'OK')
        supplier_name = r.get('supplier_name', 'Internal')

        if status == 'LATE':
            late_count += 1
        elif status == 'TIGHT':
            tight_count += 1

        # Item node
        item_nid = f"item_{item_id}"
        if item_nid not in nodes:
            nodes[item_nid] = {"id": item_nid, "label": item_name, "group": "item", "make_buy": make_buy}

        # Supplier node
        sup_nid = f"supplier_{supplier_name.replace(' ', '_')}"
        if sup_nid not in nodes:
            nodes[sup_nid] = {"id": sup_nid, "label": supplier_name, "group": "supplier"}

        # Supply node
        supply_nid = f"supply_{supply_type}_{item_id}_{hash(str(r)) % 100000}"
        nodes[supply_nid] = {
            "id": supply_nid,
            "label": f"{supply_type} ({pegged_qty} units)",
            "group": "supply",
            "status": status,
        }

        # Demand node
        demand_nid = f"demand_{demand_order or demand_source}"
        if demand_nid not in nodes:
            nodes[demand_nid] = {
                "id": demand_nid,
                "label": f"{demand_order or demand_source} ({pegged_qty} units)",
                "group": "demand",
            }

        # Edges
        if make_buy == 'BUY':
            edges.append({"from": sup_nid, "to": supply_nid, "label": "supplies"})
        edges.append({"from": supply_nid, "to": item_nid, "label": f"{pegged_qty} units", "status": status})
        edges.append({"from": item_nid, "to": demand_nid, "label": f"pegged {pegged_qty}", "status": status})

    return jsonify({
        "demo_mode": False,
        "plan_id": plan_id,
        "nodes": list(nodes.values()),
        "edges": edges,
        "stats": {
            "total_nodes": len(nodes),
            "late_count": late_count,
            "tight_count": tight_count,
        },
    })


# ─── Payables Agents (10 critical AP agents) + Observability ─────────────────

@app.route("/payables_agents")
def payables_agents_page():
    """Payables Agents workspace — 10 critical AP agents."""
    from agents.payables_agents import list_agents
    return render_template("payables_agents.html", agents=list_agents())


@app.route("/observability")
def observability_page():
    """Live execution flow of all Payables agents."""
    from agents.payables_agents import list_agents
    return render_template("observability.html", agents=list_agents())


@app.route("/api/payables_agents/list", methods=["GET"])
def api_payables_agents_list():
    from agents.payables_agents import list_agents
    return jsonify({"agents": list_agents()})


@app.route("/api/payables_agents/run/<agent_id>", methods=["POST"])
def api_payables_agents_run(agent_id):
    from agents.payables_agents import run_agent
    oracle_db, _, _, _ = get_singletons()
    body = request.get_json(silent=True) or {}
    try:
        days_back = max(1, min(365, int(body.get("days_back", 30))))
    except (TypeError, ValueError):
        days_back = 30
    source = body.get("source", "ui")
    result = run_agent(agent_id, days_back, oracle_db, source=source)
    return jsonify(result)


@app.route("/api/payables_agents/run_all", methods=["POST"])
def api_payables_agents_run_all():
    from agents.payables_agents import run_all
    oracle_db, _, _, _ = get_singletons()
    body = request.get_json(silent=True) or {}
    try:
        days_back = max(1, min(365, int(body.get("days_back", 30))))
    except (TypeError, ValueError):
        days_back = 30
    source = body.get("source", "ui_run_all")
    return jsonify(run_all(days_back, oracle_db, source=source))


@app.route("/api/observability/recent", methods=["GET"])
def api_observability_recent():
    from tools.observability import recent, agent_states, stats
    try:
        limit = max(1, min(500, int(request.args.get("limit", 200))))
    except (TypeError, ValueError):
        limit = 200
    agent_id = request.args.get("agent_id") or None
    return jsonify({
        "events": recent(limit=limit, agent_id=agent_id),
        "agents": agent_states(),
        "stats": stats(),
    })


@app.route("/api/observability/events")
def api_observability_events():
    """SSE endpoint streaming live agent events."""
    from tools.observability import subscribe, unsubscribe, sse_format, recent

    def stream():
        q = subscribe()
        try:
            # Replay recent buffer so a fresh tab has context immediately
            for ev in recent(limit=50):
                yield sse_format(ev)
            yield ": connected\n\n"
            while True:
                try:
                    ev = q.get(timeout=15)
                    yield sse_format(ev)
                except Exception:
                    # Heartbeat to keep proxies happy
                    yield ": ping\n\n"
        finally:
            unsubscribe(q)

    resp = Response(stream_with_context(stream()), mimetype="text/event-stream")
    resp.headers["Cache-Control"] = "no-cache"
    resp.headers["X-Accel-Buffering"] = "no"
    return resp


# ─── MCP server (REST surface + console) ──────────────────────────────────────

@app.route("/mcp")
def mcp_console_page():
    """Browse and invoke MCP tools, resources, and prompts."""
    from mcp_servers.ebs_p2p.registry import list_tools, RESOURCES, PROMPTS
    tools = list_tools()
    groups = sorted({t["group"] for t in tools})
    return render_template(
        "mcp_console.html",
        tools=tools,
        groups=groups,
        resources=RESOURCES,
        prompts=PROMPTS,
    )


@app.route("/api/mcp/tools", methods=["GET"])
def api_mcp_tools():
    from mcp_servers.ebs_p2p.registry import list_tools
    return jsonify({"tools": list_tools()})


@app.route("/api/mcp/call", methods=["POST"])
def api_mcp_call():
    from mcp_servers.ebs_p2p.registry import call_tool
    oracle_db, _, _, _ = get_singletons()
    body = request.get_json(silent=True) or {}
    name = body.get("name")
    args = body.get("arguments") or {}
    if not name:
        return jsonify({"error": "name is required"}), 400
    started = time.time()
    out = call_tool(name, args, oracle_db)
    return jsonify({
        "name": name, "arguments": args,
        "result": out,
        "execution_time_ms": int((time.time() - started) * 1000),
    })


@app.route("/api/mcp/resources", methods=["GET"])
def api_mcp_resources():
    from mcp_servers.ebs_p2p.registry import RESOURCES
    return jsonify({"resources": RESOURCES})


@app.route("/api/mcp/resource", methods=["GET"])
def api_mcp_resource():
    from mcp_servers.ebs_p2p.resources import read_resource
    uri = request.args.get("uri")
    if not uri:
        return jsonify({"error": "uri query param required"}), 400
    oracle_db, _, _, _ = get_singletons()
    return jsonify(read_resource(uri, oracle_db))


@app.route("/api/mcp/prompts", methods=["GET"])
def api_mcp_prompts():
    from mcp_servers.ebs_p2p.registry import PROMPTS
    return jsonify({"prompts": PROMPTS})


@app.route("/api/mcp/prompt", methods=["POST"])
def api_mcp_prompt():
    from mcp_servers.ebs_p2p.prompts import render_prompt
    body = request.get_json(silent=True) or {}
    return jsonify(render_prompt(body.get("name"), body.get("arguments") or {}))


# ─── Process Mining (Procurement + Payables) ─────────────────────────────────

@app.route("/process_mining")
def process_mining_page():
    """Process Mining workspace for P2P (Procurement + Payables)."""
    from config.process_mining import ACTIVITIES, REQUIRED_ACTIVITIES, HAPPY_PATH
    return render_template(
        "process_mining.html",
        activities=ACTIVITIES,
        required=REQUIRED_ACTIVITIES,
        happy=HAPPY_PATH,
    )


@app.route("/api/pm/analyze", methods=["POST"])
def api_pm_analyze():
    from agents.process_mining import analyze
    oracle_db, _, _, _ = get_singletons()
    body = request.get_json(silent=True) or {}
    filters = {
        "days_back":   body.get("days_back", 90),
        "vendor":      body.get("vendor"),
        "buyer":       body.get("buyer"),
        "min_amount":  body.get("min_amount"),
        "doc_type":    body.get("doc_type"),
    }
    return jsonify(analyze(filters, oracle_db))


@app.route("/api/pm/case/<path:case_id>", methods=["GET"])
def api_pm_case(case_id):
    from agents.process_mining import case_drill
    oracle_db, _, _, _ = get_singletons()
    return jsonify(case_drill(case_id, oracle_db))


@app.route("/api/pm/cases_for_variant", methods=["POST"])
def api_pm_cases_for_variant():
    from agents.process_mining import cases_for_variant
    oracle_db, _, _, _ = get_singletons()
    body = request.get_json(silent=True) or {}
    seq = body.get("sequence") or []
    limit = max(1, min(200, int(body.get("limit", 50))))
    return jsonify(cases_for_variant(seq, oracle_db, limit=limit))


@app.route("/api/pm/cases_for_edge", methods=["GET"])
def api_pm_cases_for_edge():
    from agents.process_mining import cases_for_edge
    oracle_db, _, _, _ = get_singletons()
    f = request.args.get("from")
    t = request.args.get("to")
    if not f or not t:
        return jsonify({"error": "from and to query params required"}), 400
    limit = max(1, min(200, int(request.args.get("limit", 50))))
    return jsonify(cases_for_edge(f, t, oracle_db, limit=limit))


# ─── JIRA Integration ────────────────────────────────────────────────────────

_jira_client = None


def _get_jira():
    global _jira_client
    if _jira_client is None:
        from tools.jira_client import JiraClient
        _jira_client = JiraClient()
    return _jira_client


@app.route("/jira")
def jira_page():
    """JIRA ticket search workspace."""
    jc = _get_jira()
    return render_template("jira.html",
                           jira_base_url=jc.base_url,
                           jira_configured=jc.is_configured())


@app.route("/api/jira/status", methods=["GET"])
def api_jira_status():
    from tools.jira_client import JiraError
    jc = _get_jira()
    if not jc.is_configured():
        return jsonify({"configured": False, "error": "JIRA credentials missing"}), 200
    try:
        me = jc.myself()
        return jsonify({
            "configured": True,
            "account_id": me.get("accountId"),
            "display_name": me.get("displayName"),
            "email": me.get("emailAddress"),
            "base_url": jc.base_url,
        })
    except JiraError as e:
        return jsonify({"configured": True, "error": str(e)}), 200


@app.route("/api/jira/metadata", methods=["GET"])
def api_jira_metadata():
    """One-shot fetch of reference data for filter dropdowns."""
    from tools.jira_client import JiraError
    jc = _get_jira()
    out: Dict[str, Any] = {}
    errors: List[str] = []
    for key, fn in [
        ("projects",    jc.projects),
        ("issue_types", jc.issue_types),
        ("statuses",    jc.statuses),
        ("priorities",  jc.priorities),
        ("resolutions", jc.resolutions),
    ]:
        try:
            out[key] = fn()
        except JiraError as e:
            out[key] = []
            errors.append(f"{key}: {e}")
    if errors:
        out["_errors"] = errors
    return jsonify(out)


@app.route("/api/jira/users", methods=["GET"])
def api_jira_users():
    from tools.jira_client import JiraError
    jc = _get_jira()
    q = request.args.get("q", "")
    try:
        return jsonify({"users": jc.users(query=q, max_results=30)})
    except JiraError as e:
        return jsonify({"users": [], "error": str(e)}), 200


@app.route("/api/jira/search", methods=["POST"])
def api_jira_search():
    from tools.jira_client import JiraError, JiraClient
    jc = _get_jira()
    body = request.get_json(silent=True) or {}
    filters = body.get("filters") or {}
    next_page_token = body.get("next_page_token") or None
    max_results = max(1, min(100, int(body.get("max_results", 50))))
    include_count = bool(body.get("include_count", True))

    jql = JiraClient.build_jql(filters)
    try:
        resp = jc.search(jql, next_page_token=next_page_token,
                         max_results=max_results)
    except JiraError as e:
        return jsonify({"error": str(e), "jql": jql}), 400

    issues = [JiraClient.shape_issue_row(i, jc.base_url)
              for i in resp.get("issues", [])]

    approx_total = None
    if include_count and not next_page_token:
        approx_total = jc.approximate_count(jql)

    return jsonify({
        "jql": jql,
        "issues": issues,
        "max_results": resp.get("maxResults", max_results),
        "next_page_token": resp.get("nextPageToken"),
        "is_last": resp.get("isLast", "nextPageToken" not in resp),
        "approximate_total": approx_total,
    })


@app.route("/api/jira/issue/<key>", methods=["GET"])
def api_jira_issue(key):
    from tools.jira_client import JiraError, JiraClient
    jc = _get_jira()
    try:
        raw = jc.issue(key)
    except JiraError as e:
        return jsonify({"error": str(e)}), 400

    f = raw.get("fields", {}) or {}

    def _adf_to_text(node):
        """Flatten Atlassian Document Format to readable plain text."""
        if not node:
            return ""
        if isinstance(node, str):
            return node
        if isinstance(node, list):
            return "\n".join(_adf_to_text(n) for n in node)
        if isinstance(node, dict):
            t = node.get("type")
            if t == "text":
                return node.get("text", "")
            if t == "hardBreak":
                return "\n"
            parts = [_adf_to_text(c) for c in (node.get("content") or [])]
            joined = "".join(parts)
            if t in ("paragraph", "heading", "listItem", "blockquote"):
                return joined + "\n"
            if t == "bulletList" or t == "orderedList":
                return joined + "\n"
            return joined
        return ""

    base = JiraClient.shape_issue_row(raw, jc.base_url)
    base["description"] = _adf_to_text(f.get("description")).strip()
    base["environment"] = _adf_to_text(f.get("environment")).strip()

    comments = ((f.get("comment") or {}).get("comments")) or []
    base["comments"] = [{
        "author": (c.get("author") or {}).get("displayName"),
        "created": c.get("created"),
        "body": _adf_to_text(c.get("body")).strip(),
    } for c in comments]

    base["attachments"] = [{
        "filename": a.get("filename"),
        "size": a.get("size"),
        "mime": a.get("mimeType"),
        "url": a.get("content"),
    } for a in (f.get("attachment") or [])]

    base["subtasks"] = [{
        "key": s.get("key"),
        "summary": (s.get("fields") or {}).get("summary"),
        "status": ((s.get("fields") or {}).get("status") or {}).get("name"),
    } for s in (f.get("subtasks") or [])]

    base["issuelinks"] = [{
        "type": (l.get("type") or {}).get("name"),
        "direction": "outward" if l.get("outwardIssue") else "inward",
        "key": (l.get("outwardIssue") or l.get("inwardIssue") or {}).get("key"),
        "summary": ((l.get("outwardIssue") or l.get("inwardIssue") or {})
                    .get("fields", {}).get("summary")),
    } for l in (f.get("issuelinks") or [])]

    return jsonify(base)


# ─── JIRA <-> EBS Bridge ─────────────────────────────────────────────────────

@app.route("/api/jira/scan_errors", methods=["POST"])
def api_jira_scan_errors():
    """Scan every EBS Agentic App and return ticketable findings."""
    from agents.jira_bridge import scan_fusion_errors
    body = request.get_json(silent=True) or {}
    try:
        days_back = max(1, min(365, int(body.get("days_back", 30))))
    except (TypeError, ValueError):
        days_back = 30
    oracle_db, _, _, _ = get_singletons()
    return jsonify(scan_fusion_errors(oracle_db, days_back=days_back))


@app.route("/api/jira/generate_ticket", methods=["POST"])
def api_jira_generate_ticket():
    """Ask Claude to draft a JIRA ticket from one scanned finding."""
    from agents.jira_bridge import generate_ticket_draft
    body = request.get_json(silent=True) or {}
    item = body.get("item") or {}
    if not item:
        return jsonify({"error": "item is required"}), 400
    return jsonify(generate_ticket_draft(item))


@app.route("/api/jira/create_ticket", methods=["POST"])
def api_jira_create_ticket():
    """Create a real JIRA ticket from a draft."""
    from tools.jira_client import JiraError
    jc = _get_jira()
    body = request.get_json(silent=True) or {}
    project = (body.get("project") or "").strip()
    summary = (body.get("summary") or "").strip()
    description = body.get("description") or ""
    issue_type = (body.get("issue_type") or "Task").strip()
    priority = (body.get("priority") or "").strip() or None
    labels = body.get("labels") or []

    if not project or not summary:
        return jsonify({"error": "project and summary are required"}), 400

    try:
        created = jc.create_issue(project_key=project, summary=summary,
                                  description=description,
                                  issue_type=issue_type,
                                  priority=priority,
                                  labels=labels)
    except JiraError as e:
        return jsonify({"error": str(e)}), 400

    key = created.get("key")
    return jsonify({
        "key": key,
        "id": created.get("id"),
        "url": f"{jc.base_url}/browse/{key}" if key else None,
        "self": created.get("self"),
    })


@app.route("/api/jira/troubleshoot/<key>", methods=["POST"])
def api_jira_troubleshoot(key: str):
    """Run EBS troubleshooting for a JIRA ticket, return report (no comment posted)."""
    from agents.jira_bridge import troubleshoot_ticket
    from tools.jira_client import JiraError
    jc = _get_jira()
    body = request.get_json(silent=True) or {}
    days_back = max(1, min(365, int(body.get("days_back", 30))))
    forced_apps = body.get("forced_apps") or None

    try:
        issue = jc.issue(key)
    except JiraError as e:
        return jsonify({"error": str(e)}), 400

    f = issue.get("fields", {}) or {}
    summary = f.get("summary") or ""

    def _adf(node):
        if not node: return ""
        if isinstance(node, str): return node
        if isinstance(node, list): return "\n".join(_adf(n) for n in node)
        if isinstance(node, dict):
            t = node.get("type")
            if t == "text": return node.get("text", "")
            if t == "hardBreak": return "\n"
            parts = [_adf(c) for c in (node.get("content") or [])]
            joined = "".join(parts)
            if t in ("paragraph", "heading", "listItem", "blockquote"):
                return joined + "\n"
            return joined
        return ""

    description = _adf(f.get("description")).strip()
    oracle_db, _, _, _ = get_singletons()
    result = troubleshoot_ticket(summary, description, oracle_db,
                                 days_back=days_back, forced_apps=forced_apps)
    result["ticket_key"] = key
    result["ticket_summary"] = summary
    return jsonify(result)


@app.route("/api/jira/issue/<key>/comment", methods=["POST"])
def api_jira_add_comment(key: str):
    """Post a comment to a JIRA ticket."""
    from tools.jira_client import JiraError
    jc = _get_jira()
    body = request.get_json(silent=True) or {}
    text = (body.get("body") or "").strip()
    if not text:
        return jsonify({"error": "body is required"}), 400
    try:
        resp = jc.add_comment(key, text)
    except JiraError as e:
        return jsonify({"error": str(e)}), 400
    return jsonify({
        "id": resp.get("id"),
        "created": resp.get("created"),
        "url": f"{jc.base_url}/browse/{key}",
    })


@app.errorhandler(500)
def server_error(e):
    logger.error("500 error on %s: %s", request.path, e)
    if request.path.startswith("/api/"):
        return jsonify({"error": str(e)}), 500
    return render_template("index.html", error=str(e)), 500


# ─── Entry Point ──────────────────────────────────────────────────────────────

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    debug = os.environ.get("FLASK_DEBUG", "false").lower() == "true"
    logger.info("Starting Oracle EBS Support Agent on port %d (debug=%s)", port, debug)
    app.run(host="0.0.0.0", port=port, debug=debug)
