"""Login to Grafana and screenshot the SRE Golden Signals dashboard."""
import sys
from pathlib import Path

from playwright.sync_api import sync_playwright

GRAFANA_URL = "http://localhost:30030"
USER = "admin"
PASSWORD = "sre-final-admin"
DASHBOARD_PATH = "/d/ecom-api-sre/ecom-api-sre-golden-signals"
DASHBOARD_QUERY = "?orgId=1&from=now-30m&to=now&kiosk=tv&refresh=10s"

OUT = Path(__file__).resolve().parents[1] / "docs" / "images" / "05-grafana-dashboard.png"

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    context = browser.new_context(viewport={"width": 1920, "height": 1200})
    page = context.new_page()

    # 1) login
    print(f"-> navigating to login")
    page.goto(f"{GRAFANA_URL}/login", wait_until="networkidle", timeout=30000)
    page.fill('input[name="user"]', USER)
    page.fill('input[name="password"]', PASSWORD)
    page.click('button[type="submit"]')

    # 2) Grafana may prompt to change password — skip if so
    try:
        page.wait_for_url(f"{GRAFANA_URL}/?orgId=1", timeout=10000)
    except Exception:
        # Could be on the /profile/password change screen — skip
        skip = page.query_selector("text=Skip")
        if skip:
            skip.click()
            page.wait_for_load_state("networkidle", timeout=15000)

    # 3) navigate to the dashboard with kiosk mode
    print(f"-> opening dashboard")
    page.goto(f"{GRAFANA_URL}{DASHBOARD_PATH}{DASHBOARD_QUERY}",
              wait_until="networkidle", timeout=45000)

    # Let panels finish loading
    page.wait_for_timeout(6000)

    # 4) screenshot
    OUT.parent.mkdir(parents=True, exist_ok=True)
    print(f"-> capturing to {OUT}")
    page.screenshot(path=str(OUT), full_page=True)

    browser.close()

print(f"OK saved {OUT}  ({OUT.stat().st_size/1024:.1f} KB)")
