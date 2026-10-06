import json
import os
import subprocess
import sys
import tempfile
import unittest


ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SCRIPT = os.path.join(ROOT, "tools", "dump_report.py")


class DumpReportTests(unittest.TestCase):
    def run_report(self, dump):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "dump.json")
            with open(path, "w") as f:
                json.dump(dump, f)
            result = subprocess.run([sys.executable, SCRIPT, path], text=True, capture_output=True)
            return path, result

    def test_report_lists_tier_techs_and_recipes(self):
        dump = {"technology": {
            "sushi-packer": {"prerequisites": [], "unit": {"count": 30, "ingredients": [["automation-science-pack", 1]]}},
            "fast-sushi-packer": {"prerequisites": ["logistics-2", "basic-electronics"], "unit": {"count": 75, "ingredients": [["automation-science-pack", 1], ["logistic-science-pack", 1]]}}},
            "recipe": {"fast-sushi-packer": {"ingredients": [["fast-splitter", 1], ["advanced-circuit", 5]]}}}
        _, result = self.run_report(dump)
        self.assertEqual(result.returncode, 0, result.stderr)
        lines = result.stdout.splitlines()
        self.assertIn("TECH fast-sushi-packer prereq=logistics-2,basic-electronics packs=automation-science-pack,logistic-science-pack count=75", lines)
        self.assertIn("TECH sushi-packer prereq= packs=automation-science-pack count=30", lines)
        self.assertIn("RECIPE fast-sushi-packer fast-splitter:1,advanced-circuit:5", lines)

    def test_report_ignores_other_techs(self):
        dump = {"technology": {"logistics-2": {}, "sushi-packer": {}},
                "recipe": {"fast-sushi-packer-pyvoid": {"ingredients": []}}}
        _, result = self.run_report(dump)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("logistics-2", result.stdout)
        self.assertNotIn("fast-sushi-packer-pyvoid", result.stdout)

    def test_report_last_line_names_dump(self):
        path, result = self.run_report({"technology": {}, "recipe": {}})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines()[-1], "dump-report-ok " + path)


if __name__ == "__main__":
    unittest.main()
