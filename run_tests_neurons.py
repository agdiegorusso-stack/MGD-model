import sys
import os
import subprocess

env = os.environ.copy()
env["PYTHONPATH"] = os.path.abspath(".")
result = subprocess.run([sys.executable, "-m", "pytest", "cortical_mgd/neurons/tests/test_neurons.py", "-v"], env=env, capture_output=True, text=True)
with open("test_neurons_log.txt", "w", encoding="utf-8") as f:
    f.write(result.stdout)
    f.write("\n")
    f.write(result.stderr)
