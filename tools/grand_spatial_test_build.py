"""Grand public entrypoint for the shared strict, guarded TEST build executor.

Requires --approval-json and --approval-sha256 from future independent review.
This wrapper creates no child; the existing executor owns every guarded phase.
"""
import sys
sys.dont_write_bytecode = True

from bar_spatial_test_build import main


if __name__ == "__main__":
    if any(value == "--environment" or value.startswith("--environment=") for value in sys.argv[1:]):
        raise SystemExit("Grand wrapper fixes --environment=grand_casino")
    raise SystemExit(main([*sys.argv[1:], "--environment", "grand_casino"]))
