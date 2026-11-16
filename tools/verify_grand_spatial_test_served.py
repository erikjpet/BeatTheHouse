"""Grand public served-byte proof, using the unchanged guarded TLS/stream flow."""
import sys
sys.dont_write_bytecode = True

from verify_bar_spatial_test_served import main


if __name__ == "__main__":
    if any(value == "--environment" or value.startswith("--environment=") for value in sys.argv[1:]):
        raise SystemExit("Grand wrapper fixes --environment=grand_casino")
    raise SystemExit(main([*sys.argv[1:], "--environment", "grand_casino"]))
