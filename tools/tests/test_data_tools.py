"""Exercise real CLI tools: bad content must never receive a success exit code."""

import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "game/tests/fixtures/data"
TOOLS = ("validate_json", "validate_ids", "validate_references", "content_report")


class DataToolTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.data = Path(self.temp.name) / "data"
        shutil.copytree(FIXTURES / "valid", self.data)
        self.write("loot/loot.json", [{"type": "loot", "id": "loot_test", "rolls": 1,
                                      "entries": [{"item_id": "knife", "weight": 1}]}])

    def run_tool(self, name, root=None):
        result = subprocess.run(
            [sys.executable, str(ROOT / "tools" / (name + ".py")),
             "--data-root", str(root or self.data)],
            cwd=self.temp.name, capture_output=True, text=True, encoding="utf-8",
        )
        self.assertNotIn("Traceback", result.stderr)
        return result

    def write(self, relative, value):
        path = self.data / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value), encoding="utf-8")

    def test_valid_data_and_report_from_another_working_directory(self):
        for tool in TOOLS:
            with self.subTest(tool=tool):
                result = self.run_tool(tool)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        report = self.run_tool("content_report").stdout
        for expected in ("Materials: 2", "Items: 2", "Loot Groups: 1", "Loot Entries: 1", "misc: 1", "weapon: 1", "Total Definitions: 5"):
            self.assertIn(expected, report)

    def test_invalid_definitions_fail_with_source_and_reason(self):
        cases = json.loads((FIXTURES / "invalid_cases.json").read_text())
        for case in cases:
            relative = case["group"] + "/invalid.json"
            self.write(relative, case["entries"])
            try:
                for tool in TOOLS[1:]:
                    with self.subTest(case=case["name"], tool=tool):
                        result = self.run_tool(tool)
                        self.assertNotEqual(result.returncode, 0)
                        output = (result.stdout + result.stderr).lower()
                        self.assertIn("invalid.json", output)
                        self.assertIn(case["diagnostic"], output)
            finally:
                (self.data / relative).unlink()

    def test_malformed_json_fails_all_tools(self):
        shutil.copyfile(FIXTURES / "malformed.json", self.data / "items/broken.json")
        for tool in TOOLS:
            with self.subTest(tool=tool):
                result = self.run_tool(tool)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("broken.json", result.stdout + result.stderr)

    def test_json_boundaries_are_rejected(self):
        cases = json.loads((FIXTURES / "malformed_cases.json").read_text())
        for case in cases:
            (self.data / "items/boundary.json").write_text(case["text"], encoding="utf-8")
            # Overflow is legal JSON syntax but an invalid finite schema number.
            for tool in (TOOLS[1:] if case["name"] == "overflow_number" else TOOLS):
                with self.subTest(case=case["name"], tool=tool):
                    result = self.run_tool(tool)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("boundary.json", result.stdout + result.stderr)

    def test_syntax_scanner_checks_unloaded_directories(self):
        (self.data / "other").mkdir()
        shutil.copyfile(FIXTURES / "malformed.json", self.data / "other/broken.json")
        self.assertNotEqual(self.run_tool("validate_json").returncode, 0)

    def test_missing_root_and_group_are_errors(self):
        for tool in TOOLS:
            self.assertNotEqual(self.run_tool(tool, self.data / "missing").returncode, 0)
        shutil.rmtree(self.data / "materials")
        for tool in TOOLS[1:]:
            self.assertNotEqual(self.run_tool(tool).returncode, 0)

    def test_invalid_load_order_is_not_ignored(self):
        for groups in (["items", "materials"], ["materials"], ["materials", "materials"], ["../items"], None):
            self.write("core/load_order.json", {"groups": groups})
            for tool in TOOLS[1:]:
                with self.subTest(groups=groups, tool=tool):
                    self.assertNotEqual(self.run_tool(tool).returncode, 0)

    def test_single_object_nested_file_and_unknown_field(self):
        self.write("items/nested/extra.json", {"type": "item", "id": "extra", "name": "Extra",
                                               "category": "custom_category", "future_field": 1})
        result = self.run_tool("content_report")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("WARNING", result.stdout + result.stderr)
        self.assertIn("Items: 3", result.stdout)

    def test_one_hundred_items(self):
        self.write("items/items.json", [
            {"type": "item", "id": f"sample_{index}", "name": "Sample", "category": "misc", "materials": ["steel"]}
            for index in range(100)
        ])
        self.write("loot/loot.json", [{"type": "loot", "id": "loot_test", "rolls": 1,
                                      "entries": [{"item_id": "sample_0", "weight": 1}]}])
        result = self.run_tool("content_report")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Items: 100", result.stdout)

    def test_loot_references_validate_and_report_counts(self):
        result = self.run_tool("content_report")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Loot Groups: 1", result.stdout)
        self.assertIn("Loot Entries: 1", result.stdout)

    def test_unknown_loot_item_reference_fails(self):
        self.write("loot/loot.json", [{"type": "loot", "id": "unknown_ref", "rolls": 1,
                                       "entries": [{"item_id": "missing", "weight": 1}]}])
        result = self.run_tool("validate_references")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unknown item ID", (result.stdout + result.stderr))

    def test_fractional_loot_weight_and_entry_defaults_are_valid(self):
        self.write("loot/loot.json", [{"type": "loot", "id": "fractional_loot", "rolls": 2,
                                       "entries": [{"item_id": "knife", "weight": 0.25}]}])
        result = self.run_tool("validate_references")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_duplicate_and_invalid_loot_ids_fail(self):
        entries = [
            {"type": "loot", "id": "same", "rolls": 0, "entries": []},
            {"type": "loot", "id": "same", "rolls": 0, "entries": []},
        ]
        self.write("loot/duplicates.json", entries)
        result = self.run_tool("validate_ids")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("duplicate ID", (result.stdout + result.stderr))
        self.write("loot/invalid_id.json", {"type": "loot", "id": "Loot-Bad", "rolls": 0, "entries": []})
        result = self.run_tool("validate_ids")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("lowercase_snake_case", (result.stdout + result.stderr))


if __name__ == "__main__":
    unittest.main()
