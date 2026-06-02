#!/usr/bin/env python
"""CLI entry point script for Django ORM Analyzer."""

import json
import sys

from django_orm_analyzer.parser import run_cli

if __name__ == "__main__":
    try:
        run_cli()
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}), flush=True)
        sys.exit(1)
