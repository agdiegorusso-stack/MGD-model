import sys
import os
import subprocess

env = os.environ.copy()
env["PYTHONPATH"] = os.path.abspath(".")
result = subprocess.run([sys.executable, "-m", "pytest", "cortical_mgd/plasticity/tests/test_plasticity.py", "-v"], env=env, capture_output=True, text=True)
with open("test_plasticity_log.txt", "w", encoding="utf-8") as f:
    f.write(result.stdout)
    f.write("\n")
    f.write(result.stderr)
