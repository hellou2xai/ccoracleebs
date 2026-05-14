"""Capture screenshots of EBS Support Agent for the demo deck."""
from pathlib import Path
from playwright.sync_api import sync_playwright
import time

OUT = Path(__file__).parent / "screens"
OUT.mkdir(exist_ok=True)
BASE = "http://localhost:8000"

SHOTS = [
    ("chat",      "/",         2500),
    ("dashboard", "/dashboard", 3500),
    ("fusion",    "/fusion",    3500),
    ("scp",       "/scp",       3500),
    ("payables",  "/payables",  3500),
]

def grab():
    with sync_playwright() as p:
        browser = p.chromium.launch()
        ctx = browser.new_context(viewport={"width": 1600, "height": 1000}, device_scale_factor=2)
        page = ctx.new_page()
        for name, path, wait in SHOTS:
            try:
                page.goto(BASE + path, wait_until="networkidle", timeout=15000)
            except Exception as e:
                print(f"goto {path} warn: {e}")
            page.wait_for_timeout(wait)
            # try to dismiss any overlay modals
            try:
                page.keyboard.press("Escape")
            except Exception:
                pass
            page.screenshot(path=str(OUT / f"{name}.png"), full_page=False)
            print(f"captured {name}")
        # Try running a fusion app to get a results drawer
        try:
            page.goto(BASE + "/fusion", wait_until="networkidle", timeout=15000)
            page.wait_for_timeout(2000)
            btn = page.locator("button:has-text('Run Now')").first
            if btn.count():
                btn.click()
                page.wait_for_timeout(5000)
                page.screenshot(path=str(OUT / "fusion_drawer.png"), full_page=False)
                print("captured fusion_drawer")
        except Exception as e:
            print(f"drawer err: {e}")
        # SCP with analysis run
        try:
            page.goto(BASE + "/scp", wait_until="networkidle", timeout=15000)
            page.wait_for_timeout(2000)
            btn = page.locator("button:has-text('Run')").first
            if btn.count():
                btn.click()
                page.wait_for_timeout(6000)
                page.screenshot(path=str(OUT / "scp_results.png"), full_page=False)
                print("captured scp_results")
        except Exception as e:
            print(f"scp run err: {e}")
        browser.close()

if __name__ == "__main__":
    grab()
