#!/usr/bin/env python3
"""Automated test runner for UniLib using x16emu testbench mode.

Drives the emulator headless, captures test output via the $9FBB debug
register, and reports pass/fail results.
"""

import os
import signal
import subprocess
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
RUN_DIR = os.path.join(PROJECT_DIR, "run")
SYM_FILE = os.path.join(PROJECT_DIR, "ultest.sym")
PRG_FILE = os.path.join(RUN_DIR, "ULTEST.PRG")

DEFAULT_EMU = os.path.expanduser("~/dev/x16/x16-emulator/build/x16emu")
TIMEOUT_SECONDS = 60


def find_start_address(sym_path):
    """Parse ultest.sym for the .start label address."""
    with open(sym_path) as f:
        for line in f:
            parts = line.split()
            if len(parts) == 3 and parts[0] == "al" and parts[2] == ".start":
                return int(parts[1], 16)
    return None


def run_tests():
    emu = os.environ.get("X16EMU", DEFAULT_EMU)
    if not os.path.isfile(emu):
        print(f"ERROR: emulator not found: {emu}", file=sys.stderr)
        return 2

    if not os.path.isfile(PRG_FILE):
        print(f"ERROR: test binary not found: {PRG_FILE}", file=sys.stderr)
        return 2

    start_addr = find_start_address(SYM_FILE)
    if start_addr is None:
        print(f"ERROR: .start label not found in {SYM_FILE}", file=sys.stderr)
        return 2

    cmd = [emu, "-testbench", "-prg", PRG_FILE]
    proc = subprocess.Popen(
        cmd,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        cwd=RUN_DIR,
    )

    timed_out = False

    def on_timeout(signum, frame):
        nonlocal timed_out
        timed_out = True
        proc.kill()

    signal.signal(signal.SIGALRM, on_timeout)
    signal.alarm(TIMEOUT_SECONDS)

    try:
        # Wait for RDY
        while True:
            line = proc.stdout.readline()
            if not line:
                break
            if line.strip() == "RDY":
                break

        if timed_out:
            print("TIMEOUT waiting for RDY", file=sys.stderr)
            return 3

        # Send RUN command
        run_cmd = f"RUN {start_addr:04X}\n"
        proc.stdin.write(run_cmd)
        proc.stdin.flush()

        # Collect output until STP
        output_lines = []
        while True:
            line = proc.stdout.readline()
            if not line:
                break
            stripped = line.rstrip("\n").rstrip("\r")
            if stripped == "STP":
                break
            if stripped:
                output_lines.append(stripped)

        signal.alarm(0)
    except Exception as e:
        signal.alarm(0)
        print(f"ERROR: {e}", file=sys.stderr)
        proc.kill()
        proc.wait()
        return 2

    if timed_out:
        print("TIMEOUT waiting for test completion", file=sys.stderr)
        proc.wait()
        return 3

    # Kill emulator
    proc.kill()
    proc.wait()

    # Parse results
    passed = 0
    failed = 0
    for line in output_lines:
        print(line)
        if line.endswith(" OK"):
            passed += 1
        elif line.endswith(" FAIL"):
            failed += 1

    print()
    if failed == 0 and passed > 0:
        print(f"ALL {passed} TESTS PASSED")
        return 0
    elif failed > 0:
        print(f"FAILED: {failed} of {passed + failed} tests")
        return 1
    else:
        print("WARNING: no test results found in output")
        return 2


if __name__ == "__main__":
    sys.exit(run_tests())
