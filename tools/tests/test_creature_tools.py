import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "game/tests/fixtures/data"


class CreatureToolTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.data = Path(self.temp.name) / "data"
        shutil.copytree(FIXTURES / "valid", self.data)
        self.write("core/load_order.json", {"groups": ["materials", "items", "loot", "consumables", "creatures"]})
        self.write("consumables/consumables.json", [])
        self.write("creatures/creatures.json", [])

    def run_tool(self, name):
        result = subprocess.run(
            [sys.executable, str(ROOT / "tools" / (name + ".py")), "--data-root", str(self.data)],
            cwd=self.temp.name, capture_output=True, text=True, encoding="utf-8",
        )
        self.assertNotIn("Traceback", result.stderr)
        return result

    def write(self, relative, value):
        path = self.data / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value), encoding="utf-8")

    def test_creature_content_and_report(self):
        self.write("core/load_order.json", {"groups": ["materials", "items", "loot", "consumables", "creatures"]})
        self.write("creatures/creatures.json", [{"type": "creature", "id": "zombie_basic", "name": "Basic Zombie",
                    "move_speed": 70.0, "vision_range": 320.0, "attack_range": 38.0, "attack_interval": 1.2}])
        result = self.run_tool("content_report")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Creatures: 1", result.stdout)
        self.assertIn("Total Definitions: 11", result.stdout)
        for tool in ("validate_json", "validate_ids", "validate_references"):
            with self.subTest(tool=tool):
                validated = self.run_tool(tool)
                self.assertEqual(validated.returncode, 0, validated.stdout + validated.stderr)

    def test_creature_schema_errors(self):
        self.write("core/load_order.json", {"groups": ["materials", "items", "loot", "consumables", "creatures"]})
        self.write("creatures/creatures.json", [])
        cases = json.loads((ROOT / "game/tests/fixtures/creatures/invalid_cases.json").read_text(encoding="utf-8"))
        for case in cases:
            with self.subTest(case=case["name"]):
                self.write("creatures/invalid.json", case["entries"])
                for tool in ("validate_ids", "validate_references"):
                    with self.subTest(tool=tool):
                        result = self.run_tool(tool)
                        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                        self.assertIn(case["diagnostic"], result.stdout + result.stderr)
                (self.data / "creatures/invalid.json").unlink()

    def test_creature_overflow_number_is_rejected(self):
        path = self.data / "creatures/invalid.json"
        path.write_text('[{"type":"creature","id":"overflow","name":"Overflow","move_speed":1e999,"vision_range":320,"attack_range":38,"attack_interval":1.2}]', encoding="utf-8")
        result = self.run_tool("validate_ids")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("move_speed", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
