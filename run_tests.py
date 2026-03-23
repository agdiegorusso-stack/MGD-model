import sys
import os
import subprocess

env = os.environ.copy()
env["PYTHONPATH"] = os.path.abspath(".")
result = subprocess.run([sys.executable, "-m", "pytest", "cortical_mgd/core/tests/test_mgd_metrics.py", "-v"], env=env, capture_output=True, text=True)
with open("test_full_log.txt", "w", encoding="utf-8") as f:
    f.write("STDOUT:\n")
    f.write(result.stdout)
    f.write("\nSTDERR:\n")
    f.write(result.stderr)
