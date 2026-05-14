"""
JIRA Cloud REST API v3 client.

Provides a small, focused wrapper around Atlassian Cloud's JIRA REST API
for fetching projects, issue types, statuses, priorities, users, and for
running JQL searches with rich filter support.

Credentials are read from environment variables:
  JIRA_BASE_URL   e.g. https://u2xai.atlassian.net
  JIRA_EMAIL      Atlassian account email
  JIRA_API_TOKEN  API token from id.atlassian.com
"""

import os
import logging
from typing import Any, Dict, List, Optional
from urllib.parse import quote

import requests
from requests.auth import HTTPBasicAuth

logger = logging.getLogger(__name__)


class JiraError(Exception):
    pass


class JiraClient:
    def __init__(
        self,
        base_url: Optional[str] = None,
        email: Optional[str] = None,
        api_token: Optional[str] = None,
        timeout: int = 30,
    ):
        self.base_url = (base_url or os.environ.get("JIRA_BASE_URL", "")).rstrip("/")
        self.email = email or os.environ.get("JIRA_EMAIL", "")
        self.api_token = api_token or os.environ.get("JIRA_API_TOKEN", "")
        self.timeout = timeout

        if not self.base_url or not self.email or not self.api_token:
            logger.warning("JIRA credentials missing — set JIRA_BASE_URL, JIRA_EMAIL, JIRA_API_TOKEN")

        self._auth = HTTPBasicAuth(self.email, self.api_token)
        self._headers = {"Accept": "application/json", "Content-Type": "application/json"}

    # ─── internal ─────────────────────────────────────────────────────────
    def _get(self, path: str, params: Optional[Dict[str, Any]] = None) -> Any:
        url = f"{self.base_url}{path}"
        try:
            r = requests.get(url, auth=self._auth, headers=self._headers,
                             params=params, timeout=self.timeout)
        except requests.RequestException as e:
            raise JiraError(f"Network error calling {path}: {e}") from e
        if r.status_code >= 400:
            raise JiraError(f"JIRA {r.status_code} on {path}: {r.text[:400]}")
        return r.json()

    def _post(self, path: str, body: Dict[str, Any]) -> Any:
        url = f"{self.base_url}{path}"
        try:
            r = requests.post(url, auth=self._auth, headers=self._headers,
                              json=body, timeout=self.timeout)
        except requests.RequestException as e:
            raise JiraError(f"Network error calling {path}: {e}") from e
        if r.status_code >= 400:
            raise JiraError(f"JIRA {r.status_code} on {path}: {r.text[:400]}")
        return r.json()

    # ─── connectivity ─────────────────────────────────────────────────────
    def myself(self) -> Dict[str, Any]:
        return self._get("/rest/api/3/myself")

    def server_info(self) -> Dict[str, Any]:
        return self._get("/rest/api/3/serverInfo")

    def is_configured(self) -> bool:
        return bool(self.base_url and self.email and self.api_token)

    # ─── reference data (for filter dropdowns) ────────────────────────────
    def projects(self) -> List[Dict[str, Any]]:
        out: List[Dict[str, Any]] = []
        start_at = 0
        while True:
            page = self._get("/rest/api/3/project/search",
                             params={"startAt": start_at, "maxResults": 50})
            out.extend(page.get("values", []))
            if page.get("isLast", True) or not page.get("values"):
                break
            start_at += len(page["values"])
            if start_at > 500:
                break
        return [{"id": p.get("id"), "key": p.get("key"), "name": p.get("name")}
                for p in out]

    def issue_types(self) -> List[Dict[str, Any]]:
        data = self._get("/rest/api/3/issuetype")
        seen = {}
        for it in data:
            name = it.get("name")
            if name and name not in seen:
                seen[name] = {"id": it.get("id"), "name": name,
                              "iconUrl": it.get("iconUrl"),
                              "subtask": it.get("subtask", False)}
        return list(seen.values())

    def statuses(self) -> List[Dict[str, Any]]:
        data = self._get("/rest/api/3/status")
        seen = {}
        for s in data:
            name = s.get("name")
            if name and name not in seen:
                cat = (s.get("statusCategory") or {}).get("name")
                seen[name] = {"id": s.get("id"), "name": name, "category": cat}
        return list(seen.values())

    def priorities(self) -> List[Dict[str, Any]]:
        data = self._get("/rest/api/3/priority")
        return [{"id": p.get("id"), "name": p.get("name"),
                 "iconUrl": p.get("iconUrl")} for p in data]

    def resolutions(self) -> List[Dict[str, Any]]:
        data = self._get("/rest/api/3/resolution")
        return [{"id": r.get("id"), "name": r.get("name")} for r in data]

    def labels(self, max_results: int = 200) -> List[str]:
        try:
            data = self._get("/rest/api/3/label",
                             params={"maxResults": max_results})
            return data.get("values", [])
        except JiraError:
            return []

    def users(self, query: str = "", max_results: int = 50) -> List[Dict[str, Any]]:
        try:
            data = self._get("/rest/api/3/users/search",
                             params={"query": query, "maxResults": max_results})
        except JiraError:
            data = []
        return [{"accountId": u.get("accountId"),
                 "displayName": u.get("displayName"),
                 "emailAddress": u.get("emailAddress"),
                 "avatarUrl": (u.get("avatarUrls") or {}).get("24x24")}
                for u in data if u.get("accountType") == "atlassian"]

    # ─── JQL building + search ────────────────────────────────────────────
    @staticmethod
    def build_jql(filters: Dict[str, Any]) -> str:
        """Translate the filter dict from the UI into a JQL string."""
        clauses: List[str] = []

        def quote_val(v: str) -> str:
            return '"' + str(v).replace('"', '\\"') + '"'

        def in_clause(field: str, values: List[Any]) -> Optional[str]:
            vals = [v for v in (values or []) if v not in (None, "", "Any")]
            if not vals:
                return None
            if len(vals) == 1:
                return f'{field} = {quote_val(vals[0])}'
            return f'{field} in ({", ".join(quote_val(v) for v in vals)})'

        if c := in_clause("issuekey", filters.get("issue_keys")):
            clauses.append(c)
        if c := in_clause("project", filters.get("projects")):
            clauses.append(c)
        if c := in_clause("issuetype", filters.get("issue_types")):
            clauses.append(c)
        if c := in_clause("status", filters.get("statuses")):
            clauses.append(c)
        if c := in_clause("priority", filters.get("priorities")):
            clauses.append(c)
        if c := in_clause("resolution", filters.get("resolutions")):
            clauses.append(c)
        if c := in_clause("labels", filters.get("labels")):
            clauses.append(c)
        if c := in_clause("component", filters.get("components")):
            clauses.append(c)
        if c := in_clause("fixVersion", filters.get("fix_versions")):
            clauses.append(c)

        # Assignee / Reporter (special "currentUser()" or "unassigned" sentinels allowed)
        for field, key in [("assignee", "assignee"), ("reporter", "reporter")]:
            val = filters.get(key)
            if val:
                if val == "currentUser":
                    clauses.append(f"{field} = currentUser()")
                elif val == "unassigned" and field == "assignee":
                    clauses.append("assignee is EMPTY")
                else:
                    clauses.append(f"{field} = {quote_val(val)}")

        # Date ranges (created / updated / resolved / due)
        for prefix, jql_field in [
            ("created", "created"),
            ("updated", "updated"),
            ("resolved", "resolutiondate"),
            ("due", "duedate"),
        ]:
            frm = filters.get(f"{prefix}_from")
            to  = filters.get(f"{prefix}_to")
            if frm:
                clauses.append(f'{jql_field} >= "{frm}"')
            if to:
                clauses.append(f'{jql_field} <= "{to}"')

        # Text search across summary/description/comments
        text = (filters.get("text") or "").strip()
        if text:
            clauses.append(f'text ~ {quote_val(text)}')

        # Sprint name (free-text)
        sprint = (filters.get("sprint") or "").strip()
        if sprint:
            clauses.append(f'sprint = {quote_val(sprint)}')

        # Epic link / parent
        epic = (filters.get("epic") or "").strip()
        if epic:
            clauses.append(f'parent = {quote_val(epic)}')

        # Raw JQL override / extension
        raw = (filters.get("raw_jql") or "").strip()
        if raw:
            clauses.append(f"({raw})")

        # JIRA Cloud requires a bounded query — if no clauses, default to last 52 weeks
        if not clauses:
            clauses.append("updated >= -52w")

        jql = " AND ".join(clauses)
        order = filters.get("order_by") or "updated DESC"
        return f"{jql} ORDER BY {order}"

    def search(self, jql: str, next_page_token: Optional[str] = None,
               max_results: int = 50,
               fields: Optional[List[str]] = None) -> Dict[str, Any]:
        """Cursor-paginated search (new JIRA Cloud API).

        Returns dict with: issues, nextPageToken (optional), isLast.
        """
        params: Dict[str, Any] = {
            "jql": jql,
            "maxResults": max(1, min(100, max_results)),
            "fields": ",".join(fields or [
                "summary", "status", "priority", "issuetype",
                "assignee", "reporter", "created", "updated",
                "resolutiondate", "duedate", "labels", "components",
                "fixVersions", "project", "resolution",
            ]),
        }
        if next_page_token:
            params["nextPageToken"] = next_page_token
        return self._get("/rest/api/3/search/jql", params=params)

    def approximate_count(self, jql: str) -> int:
        try:
            data = self._post("/rest/api/3/search/approximate-count", {"jql": jql})
            return int(data.get("count", 0) or 0)
        except JiraError as e:
            logger.warning("approximate_count failed: %s", e)
            return -1

    def issue(self, key_or_id: str) -> Dict[str, Any]:
        return self._get(f"/rest/api/3/issue/{quote(key_or_id)}")

    # ─── writes ───────────────────────────────────────────────────────────
    @staticmethod
    def _sanitize(text: str) -> str:
        """Strip dashes that violate the project's writing rules."""
        if not text:
            return text
        for s in (" — ", " – "):
            text = text.replace(s, ". ")
        text = text.replace("—", ". ").replace("–", ". ")
        return text

    @staticmethod
    def _inline_to_adf(text: str) -> List[Dict[str, Any]]:
        """Convert inline markdown (**bold**, *italic*, `code`) into ADF text nodes."""
        import re
        text = JiraClient._sanitize(text)
        nodes: List[Dict[str, Any]] = []
        # Pattern matches **bold**, *italic*, `code` (in that priority order)
        pattern = re.compile(
            r"(\*\*([^*\n]+)\*\*)"      # 1,2: **bold**
            r"|(`([^`\n]+)`)"            # 3,4: `code`
            r"|(\*([^*\n]+)\*)"          # 5,6: *italic*
        )
        pos = 0
        for m in pattern.finditer(text):
            if m.start() > pos:
                nodes.append({"type": "text", "text": text[pos:m.start()]})
            if m.group(1):
                nodes.append({"type": "text", "text": m.group(2),
                              "marks": [{"type": "strong"}]})
            elif m.group(3):
                nodes.append({"type": "text", "text": m.group(4),
                              "marks": [{"type": "code"}]})
            elif m.group(5):
                nodes.append({"type": "text", "text": m.group(6),
                              "marks": [{"type": "em"}]})
            pos = m.end()
        if pos < len(text):
            nodes.append({"type": "text", "text": text[pos:]})
        if not nodes:
            nodes.append({"type": "text", "text": text})
        return nodes

    @staticmethod
    def _paragraph(text: str) -> Dict[str, Any]:
        # Handle hardBreaks inside a paragraph (single newline)
        import re
        chunks = re.split(r"\n", text)
        content: List[Dict[str, Any]] = []
        for i, ch in enumerate(chunks):
            if i > 0:
                content.append({"type": "hardBreak"})
            content.extend(JiraClient._inline_to_adf(ch))
        return {"type": "paragraph", "content": content}

    @staticmethod
    def text_to_adf(text: str) -> Dict[str, Any]:
        """Markdown to Atlassian Document Format.

        Supports: ## / ### headings, **bold**, *italic*, `inline code`,
        ```fenced code blocks```, bullet lists (- or *),
        ordered lists (1. 2. 3.), block quotes (> ...), horizontal rule (---).
        Falls back to a single paragraph for unknown lines.
        """
        import re
        if not text:
            text = ""
        text = JiraClient._sanitize(text)

        lines = text.split("\n")
        i = 0
        blocks: List[Dict[str, Any]] = []

        def flush_paragraph(buf: List[str]) -> None:
            if not buf:
                return
            joined = "\n".join(buf).strip("\n")
            if joined.strip():
                blocks.append(JiraClient._paragraph(joined))

        para_buf: List[str] = []

        while i < len(lines):
            line = lines[i]
            stripped = line.strip()

            # Fenced code block ```lang ... ```
            fence_m = re.match(r"^```(\w+)?\s*$", line)
            if fence_m:
                flush_paragraph(para_buf); para_buf = []
                lang = fence_m.group(1) or ""
                code_lines: List[str] = []
                i += 1
                while i < len(lines) and not re.match(r"^```\s*$", lines[i]):
                    code_lines.append(lines[i])
                    i += 1
                attrs = {"language": lang} if lang else {}
                blocks.append({
                    "type": "codeBlock",
                    "attrs": attrs,
                    "content": [{"type": "text", "text": "\n".join(code_lines)}]
                    if code_lines else [],
                })
                i += 1
                continue

            # Heading: ## or ###
            h_m = re.match(r"^(#{1,6})\s+(.*)$", line)
            if h_m:
                flush_paragraph(para_buf); para_buf = []
                level = min(6, len(h_m.group(1)))
                blocks.append({
                    "type": "heading",
                    "attrs": {"level": level},
                    "content": JiraClient._inline_to_adf(h_m.group(2)),
                })
                i += 1
                continue

            # Horizontal rule
            if re.match(r"^-{3,}\s*$", line) or re.match(r"^\*{3,}\s*$", line):
                flush_paragraph(para_buf); para_buf = []
                blocks.append({"type": "rule"})
                i += 1
                continue

            # Block quote
            if stripped.startswith("> "):
                flush_paragraph(para_buf); para_buf = []
                quote_lines: List[str] = []
                while i < len(lines) and lines[i].strip().startswith("> "):
                    quote_lines.append(lines[i].strip()[2:])
                    i += 1
                blocks.append({
                    "type": "blockquote",
                    "content": [JiraClient._paragraph("\n".join(quote_lines))],
                })
                continue

            # Bullet list
            if re.match(r"^\s*[-*]\s+", line):
                flush_paragraph(para_buf); para_buf = []
                items: List[Dict[str, Any]] = []
                while i < len(lines) and re.match(r"^\s*[-*]\s+", lines[i]):
                    item_text = re.sub(r"^\s*[-*]\s+", "", lines[i])
                    items.append({
                        "type": "listItem",
                        "content": [JiraClient._paragraph(item_text)],
                    })
                    i += 1
                blocks.append({"type": "bulletList", "content": items})
                continue

            # Ordered list
            if re.match(r"^\s*\d+\.\s+", line):
                flush_paragraph(para_buf); para_buf = []
                items = []
                while i < len(lines) and re.match(r"^\s*\d+\.\s+", lines[i]):
                    item_text = re.sub(r"^\s*\d+\.\s+", "", lines[i])
                    items.append({
                        "type": "listItem",
                        "content": [JiraClient._paragraph(item_text)],
                    })
                    i += 1
                blocks.append({"type": "orderedList", "content": items})
                continue

            # Blank line separates paragraphs
            if not stripped:
                flush_paragraph(para_buf)
                para_buf = []
                i += 1
                continue

            # Regular paragraph line
            para_buf.append(line)
            i += 1

        flush_paragraph(para_buf)

        if not blocks:
            blocks.append({"type": "paragraph",
                           "content": [{"type": "text", "text": ""}]})
        return {"type": "doc", "version": 1, "content": blocks}

    def create_issue(self, project_key: str, summary: str, description: str,
                     issue_type: str = "Task",
                     priority: Optional[str] = None,
                     labels: Optional[List[str]] = None) -> Dict[str, Any]:
        fields: Dict[str, Any] = {
            "project": {"key": project_key},
            "summary": summary[:250],
            "issuetype": {"name": issue_type},
            "description": self.text_to_adf(description),
        }
        if priority:
            fields["priority"] = {"name": priority}
        if labels:
            fields["labels"] = [l.replace(" ", "-") for l in labels]
        return self._post("/rest/api/3/issue", {"fields": fields})

    def add_comment(self, key: str, body: str) -> Dict[str, Any]:
        return self._post(f"/rest/api/3/issue/{quote(key)}/comment",
                          {"body": self.text_to_adf(body)})

    def _put(self, path: str, body: Dict[str, Any]) -> Any:
        url = f"{self.base_url}{path}"
        try:
            r = requests.put(url, auth=self._auth, headers=self._headers,
                             json=body, timeout=self.timeout)
        except requests.RequestException as e:
            raise JiraError(f"Network error calling {path}: {e}") from e
        if r.status_code >= 400:
            raise JiraError(f"JIRA {r.status_code} on {path}: {r.text[:400]}")
        # PUT returns 204 No Content on success
        if not r.text:
            return {"ok": True}
        return r.json()

    def update_issue(self, key: str,
                     summary: Optional[str] = None,
                     description: Optional[str] = None,
                     priority: Optional[str] = None,
                     labels: Optional[List[str]] = None) -> Dict[str, Any]:
        fields: Dict[str, Any] = {}
        if summary is not None:
            fields["summary"] = summary[:240]
        if description is not None:
            fields["description"] = self.text_to_adf(description)
        if priority is not None:
            fields["priority"] = {"name": priority}
        if labels is not None:
            fields["labels"] = [l.replace(" ", "-") for l in labels]
        if not fields:
            return {"ok": True, "skipped": True}
        return self._put(f"/rest/api/3/issue/{quote(key)}", {"fields": fields})

    # ─── shaping helpers ──────────────────────────────────────────────────
    @staticmethod
    def shape_issue_row(issue: Dict[str, Any], base_url: str = "") -> Dict[str, Any]:
        f = issue.get("fields", {}) or {}
        st = f.get("status") or {}
        pr = f.get("priority") or {}
        it = f.get("issuetype") or {}
        asg = f.get("assignee") or {}
        rep = f.get("reporter") or {}
        prj = f.get("project") or {}
        res = f.get("resolution") or {}
        return {
            "key": issue.get("key"),
            "id": issue.get("id"),
            "url": f"{base_url}/browse/{issue.get('key')}" if base_url else None,
            "summary": f.get("summary"),
            "status": st.get("name"),
            "status_category": (st.get("statusCategory") or {}).get("name"),
            "priority": pr.get("name"),
            "priority_icon": pr.get("iconUrl"),
            "issuetype": it.get("name"),
            "issuetype_icon": it.get("iconUrl"),
            "assignee": asg.get("displayName"),
            "assignee_avatar": (asg.get("avatarUrls") or {}).get("24x24"),
            "reporter": rep.get("displayName"),
            "project_key": prj.get("key"),
            "project_name": prj.get("name"),
            "created": f.get("created"),
            "updated": f.get("updated"),
            "resolved": f.get("resolutiondate"),
            "due": f.get("duedate"),
            "resolution": res.get("name"),
            "labels": f.get("labels") or [],
            "components": [c.get("name") for c in (f.get("components") or [])],
            "fix_versions": [v.get("name") for v in (f.get("fixVersions") or [])],
        }
