#!/usr/bin/env python3
"""Automated test runner for UniLib using x16emu testbench mode.

Drives the emulator headless, captures test output via the $9FBB debug
register, and reports pass/fail results.

Testbench protocol commands (init-phase, before RUN):
  Setup: RAM, ROM, STM, FLM, STA, STX, STY, SST, SSP
  Query: RQM (memory), RQA/RQX/RQY/RST/RSP (registers)
  Run:   RUN addr

Note: Testbench is init-phase only. After RUN, no commands can be sent
until the program terminates (STP). Mid-execution debugging must use the
debug I/O registers ($9FB0-$9FBF) from within the test program itself.
"""

import argparse
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


def find_sym_address(sym_path, label):
    """Parse ultest.sym for a label address. Returns int or None."""
    with open(sym_path) as f:
        for line in f:
            parts = line.split()
            if len(parts) == 3 and parts[0] == "al" and parts[2] == label:
                return int(parts[1], 16)
    return None


def list_test_labels(sym_path):
    """List all test entry point labels from the symbol file."""
    labels = []
    with open(sym_path) as f:
        for line in f:
            parts = line.split()
            if len(parts) == 3 and parts[0] == "al":
                name = parts[2]
                # Test labels start with .test_ (convention)
                if name.startswith(".test_"):
                    labels.append((name, int(parts[1], 16)))
    return labels


class TestbenchSession:
    """Manages a testbench session with the emulator."""

    def __init__(self, emu_path, prg_path=None, rom_path=None, cwd=None, verbose=False):
        self.verbose = verbose
        cmd = [emu_path, "-testbench"]
        if prg_path:
            cmd.extend(["-prg", prg_path])
        if rom_path:
            cmd.extend(["-rom", rom_path])
        self.proc = subprocess.Popen(
            cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            cwd=cwd,
        )
        self.timed_out = False
        self._wait_ready()

    def _wait_ready(self):
        """Wait for the initial RDY prompt."""
        while True:
            line = self.proc.stdout.readline()
            if not line:
                raise RuntimeError("Emulator closed before RDY")
            if line.strip() == "RDY":
                return

    def send_command(self, cmd):
        """Send a command and wait for RDY response. Returns response string."""
        if self.verbose:
            print(f"  >> {cmd}", file=sys.stderr)
        self.proc.stdin.write(cmd + "\n")
        self.proc.stdin.flush()
        resp = self.proc.stdout.readline()
        if not resp:
            raise RuntimeError(f"Emulator closed after '{cmd}'")
        resp = resp.strip()
        if self.verbose:
            print(f"  << {resp}", file=sys.stderr)
        if resp.startswith("ERR"):
            raise RuntimeError(f"Testbench error for '{cmd}': {resp}")
        return resp

    def query_memory(self, addr):
        """Read a memory byte. Returns int."""
        self.proc.stdin.write(f"RQM {addr:04X}\n")
        self.proc.stdin.flush()
        resp = self.proc.stdout.readline().strip()
        return int(resp, 16)

    def query_registers(self):
        """Read all registers. Returns dict."""
        regs = {}
        for name, cmd in [("A", "RQA"), ("X", "RQX"), ("Y", "RQY"),
                          ("S", "RST"), ("SP", "RSP")]:
            self.proc.stdin.write(cmd + "\n")
            self.proc.stdin.flush()
            resp = self.proc.stdout.readline().strip()
            regs[name] = int(resp, 16)
        return regs

    def set_ram_bank(self, bank):
        """Set RAM bank register."""
        self.send_command(f"RAM {bank:02X}")

    def set_memory(self, addr, value):
        """Write a byte to memory."""
        self.send_command(f"STM {addr:04X} {value:02X}")

    def fill_memory(self, start, end, value):
        """Fill memory range with a value."""
        self.send_command(f"FLM {start:04X} {end:04X} {value:02X}")

    def verify_memory(self, addr, expected, label=""):
        """Verify a memory byte matches expected value. Returns bool."""
        actual = self.query_memory(addr)
        if actual != expected:
            where = f" ({label})" if label else ""
            print(f"  VERIFY FAIL: ${addr:04X}{where} = ${actual:02X}, expected ${expected:02X}",
                  file=sys.stderr)
            return False
        return True

    def run(self, addr):
        """Start execution at addr. Does NOT wait for RDY."""
        cmd = f"RUN {addr:04X}"
        if self.verbose:
            print(f"  >> {cmd}", file=sys.stderr)
        self.proc.stdin.write(cmd + "\n")
        self.proc.stdin.flush()

    def collect_output(self, timeout=TIMEOUT_SECONDS):
        """Collect output lines until STP or timeout.
        Returns (completed, output_lines, debug_values).
        debug_values captures 'User debug N: $XX' output as a list of (reg, value) tuples.
        """
        output_lines = []
        debug_values = []
        timed_out = False

        def on_timeout(signum, frame):
            nonlocal timed_out
            timed_out = True
            self.proc.kill()

        old_handler = signal.signal(signal.SIGALRM, on_timeout)
        signal.alarm(timeout)

        try:
            while True:
                line = self.proc.stdout.readline()
                if not line:
                    break
                stripped = line.rstrip("\n").rstrip("\r")
                if stripped == "STP":
                    break
                if stripped:
                    output_lines.append(stripped)
                    # Parse debug register output
                    if stripped.startswith("User debug "):
                        try:
                            parts = stripped.split("$")
                            if len(parts) == 2:
                                val = int(parts[1], 16)
                                reg = int(stripped.split(":")[0][-1])
                                debug_values.append((reg, val))
                        except (ValueError, IndexError):
                            pass
        finally:
            signal.alarm(0)
            signal.signal(signal.SIGALRM, old_handler)

        if timed_out:
            return False, output_lines, debug_values
        return True, output_lines, debug_values

    def kill(self):
        """Terminate the emulator process."""
        try:
            self.proc.kill()
            self.proc.wait()
        except OSError:
            pass


def run_tests(emu, verbose=False, verify_load=False, timeout=TIMEOUT_SECONDS,
              prg_file=None, sym_file=None, rom_path=None):
    """Run the full test suite. Returns exit code."""
    prg = os.path.abspath(prg_file) if prg_file else PRG_FILE
    sym = os.path.abspath(sym_file) if sym_file else SYM_FILE
    if rom_path:
        rom_path = os.path.abspath(rom_path)

    if not os.path.isfile(emu):
        print(f"ERROR: emulator not found: {emu}", file=sys.stderr)
        return 2

    if not os.path.isfile(prg):
        print(f"ERROR: test binary not found: {prg}", file=sys.stderr)
        return 2

    start_addr = find_sym_address(sym, ".start")
    if start_addr is None:
        print(f"ERROR: .start label not found in {sym}", file=sys.stderr)
        return 2

    if verbose:
        print(f"Emulator: {emu}", file=sys.stderr)
        print(f"PRG: {prg}", file=sys.stderr)
        print(f"Start address: ${start_addr:04X}", file=sys.stderr)
        print(file=sys.stderr)

    try:
        session = TestbenchSession(emu, prg, rom_path=rom_path, cwd=RUN_DIR, verbose=verbose)
    except RuntimeError as e:
        print(f"ERROR: Failed to start testbench: {e}", file=sys.stderr)
        return 2

    try:
        # Optional: verify PRG loaded correctly by checking a few bytes
        if verify_load:
            # Read PRG file header (2-byte load address)
            with open(prg, "rb") as f:
                load_lo = f.read(1)[0]
                load_hi = f.read(1)[0]
                load_addr = load_lo | (load_hi << 8)
                first_bytes = f.read(4)

            if verbose:
                print(f"PRG load address: ${load_addr:04X}", file=sys.stderr)
                print(f"First 4 bytes: {' '.join(f'${b:02X}' for b in first_bytes)}", file=sys.stderr)

            ok = True
            for i, expected in enumerate(first_bytes):
                if not session.verify_memory(load_addr + i, expected, f"PRG+{i}"):
                    ok = False
            if not ok:
                print("ERROR: PRG file not loaded correctly", file=sys.stderr)
                session.kill()
                return 2
            if verbose:
                print("PRG load verified OK", file=sys.stderr)
                print(file=sys.stderr)

        # Run tests
        session.run(start_addr)
        completed, output_lines, debug_values = session.collect_output(timeout)

    finally:
        session.kill()

    if not completed:
        # On timeout, still print any output we captured
        for line in output_lines:
            print(line)
        print()
        print("TIMEOUT waiting for test completion", file=sys.stderr)
        return 3

    # Parse results
    passed = 0
    failed = 0
    failed_tests = []
    for line in output_lines:
        print(line)
        if line.endswith(" OK"):
            passed += 1
        elif line.endswith(" FAIL"):
            failed += 1
            failed_tests.append(line)

    print()
    if failed == 0 and passed > 0:
        print(f"ALL {passed} TESTS PASSED")
        return 0
    elif failed > 0:
        print(f"FAILED: {failed} of {passed + failed} tests")
        if verbose and failed_tests:
            print("\nFailing tests:", file=sys.stderr)
            for t in failed_tests:
                print(f"  {t}", file=sys.stderr)
        return 1
    else:
        print("WARNING: no test results found in output")
        if verbose and output_lines:
            print("\nRaw output:", file=sys.stderr)
            for line in output_lines:
                print(f"  {line}", file=sys.stderr)
        return 2


def main():
    parser = argparse.ArgumentParser(
        description="UniLib automated test runner using x16emu testbench mode."
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Verbose output: show testbench commands, debug info"
    )
    parser.add_argument(
        "--verify-load",
        action="store_true",
        help="Verify PRG loaded correctly before running tests"
    )
    parser.add_argument(
        "--emu",
        default=None,
        help="Path to x16emu (overrides X16EMU env var)"
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=TIMEOUT_SECONDS,
        help=f"Timeout in seconds (default: {TIMEOUT_SECONDS})"
    )
    parser.add_argument(
        "--prg",
        default=None,
        help="Path to test PRG file (default: run/ULTEST.PRG)"
    )
    parser.add_argument(
        "--sym",
        default=None,
        help="Path to symbol file (default: ultest.sym)"
    )
    parser.add_argument(
        "--rom",
        default=None,
        help="Path to custom ROM image (passed as -rom to emulator)"
    )

    args = parser.parse_args()

    timeout = args.timeout
    emu = args.emu or os.environ.get("X16EMU", DEFAULT_EMU)
    sys.exit(run_tests(emu, verbose=args.verbose, verify_load=args.verify_load,
                       timeout=timeout, prg_file=args.prg, sym_file=args.sym,
                       rom_path=args.rom))


if __name__ == "__main__":
    main()
