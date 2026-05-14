"""
Playwright conftest — allow Chromium to connect to port 6000
(Chromium blocks several port numbers as "unsafe" by default; 6000 is one of them).
"""

import pytest


@pytest.fixture(scope="session")
def browser_type_launch_args():
    """Pass --explicitly-allowed-ports=6000 so Chromium won't block our dev server."""
    return {"args": ["--explicitly-allowed-ports=8000"]}
