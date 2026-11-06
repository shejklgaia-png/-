#!/usr/bin/env python3
"""Current v46 step self-check. Run from any working directory."""
from pathlib import Path
import runpy
runpy.run_path(str(Path(__file__).with_name('v46_orbit_self_check.py')),run_name='__main__')
