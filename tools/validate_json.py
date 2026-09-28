"""Check every JSON file under game/data (or --data-root)."""

from data_utils import run_cli


if __name__ == "__main__":
    raise SystemExit(run_cli("validate_json"))
