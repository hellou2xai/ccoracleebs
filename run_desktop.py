#!/usr/bin/env python3
"""Launch the Oracle EBS Support Agent desktop application."""

import sys
import os

# Ensure project root is on path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from desktop.main import main

if __name__ == "__main__":
    main()
