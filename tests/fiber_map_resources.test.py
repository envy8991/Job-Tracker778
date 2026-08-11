import hashlib
import re
import subprocess
import unittest
from pathlib import Path
ROOT = Path(__file__).parents[1]
WEB = ROOT / "Job Tracker/Resources/WebMaps"
class FiberMapResourcesTest(unittest.TestCase):
    def test_resources_are_local_and_runtime_initializes_offline(self):
        html = (WEB / "FiberMap.html").read_text()
        refs = [ref for ref in re.findall(r'(?:src|href)="([^"]+)"', html) if '${' not in ref]
        framework_refs = [ref for ref in refs if not ref.startswith(("https://tile.openstreetmap.org/", "https://www.openstreetmap.org/copyright"))]
        self.assertFalse([ref for ref in framework_refs if ref.startswith(("http://", "https://", "//"))])
        for ref in framework_refs:
            self.assertTrue((WEB / ref).is_file(), ref)
        for entry in (WEB / "resource-integrity.sha256").read_text().splitlines():
            expected, relative = entry.split(maxsplit=1)
            actual = hashlib.sha256((WEB / relative).read_bytes()).hexdigest()
            self.assertEqual(expected, actual, relative)
        completed = subprocess.run(["node", str(ROOT / "tests/fiber_map_resource_smoke.js")], check=True, capture_output=True, text=True)
        self.assertIn("passed", completed.stdout)
if __name__ == "__main__": unittest.main()
