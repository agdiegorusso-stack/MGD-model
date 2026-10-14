"""Select the original private signing key. Never create or publish a key.

MGD_KEYSTORE_BASE64 is supplied only by a GitHub Actions secret. An existing
MGD_STORE_FILE may be used locally. The former cache is a read-only recovery
source, not a place to save future private keys. A certificate alone is not a key.
"""
from __future__ import annotations
import base64
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

EXPECTED_SHA256 = "d4974611809f5def4c01e0d805a124be0a9471d7532b15c8eeb8d6ec30eb78e1"


def inspect_key(path: Path, alias: str, password: str) -> dict:
    """Return public metadata only; do not print tool errors or credentials."""
    env = dict(os.environ, MGD_INSPECT_PASSWORD=password)
    common = ["keytool", "-J-Duser.language=en", "-J-Duser.country=US"]
    args = ["-keystore", str(path), "-alias", alias,
            "-storepass:env", "MGD_INSPECT_PASSWORD"]
    try:
        info = subprocess.run(common + ["-list", "-v"] + args,
            env=env, capture_output=True, timeout=20, check=False)
        if info.returncode:
            return {"readable": False, "reason": "unreadable_key_or_alias"}
        private = "Entry type: PrivateKeyEntry" in info.stdout.decode(errors="replace")
        cert = subprocess.run(common + ["-exportcert"] + args,
            env=env, capture_output=True, timeout=20, check=False)
        if cert.returncode or not cert.stdout:
            return {"readable": False, "reason": "certificate_export_failed"}
        return {"readable": True, "private_key": private,
                "sha256": hashlib.sha256(cert.stdout).hexdigest()}
    except (OSError, subprocess.TimeoutExpired):
        return {"readable": False, "reason": "keytool_unavailable_or_timeout"}


def select_key(candidates: list[dict], expected: str = EXPECTED_SHA256):
    """Find a matching private-key entry; reject cert-only stores and mismatches."""
    report = {"expected_sha256": expected, "ready": False, "candidates": [],
              "reason": "original_private_signing_key_not_found",
              "private_key_created": False}
    selected = None
    for candidate in candidates:
        path = Path(candidate["path"])
        if not path.is_file():
            report["candidates"].append({"source": candidate["source"], "exists": False})
            continue
        row = {"source": candidate["source"], "exists": True,
               **inspect_key(path, candidate["alias"], candidate["password"])}
        row["matches_installed"] = row.get("sha256") == expected
        report["candidates"].append(row)
        if row.get("private_key") and row["matches_installed"] and selected is None:
            selected = candidate
    if selected:
        report.update(ready=True, reason="original_private_key_selected",
                      selected_source=selected["source"])
    return selected, report


def prepare_secret(encoded: str, directory: Path) -> Path:
    """Decode into a non-artifact runner directory with mode 0600."""
    raw = base64.b64decode(encoded, validate=True)
    if not raw or len(raw) > 1024 * 1024:
        raise ValueError("invalid_keystore_size")
    fd, name = tempfile.mkstemp(prefix="mgd-private-", suffix=".keystore", dir=directory)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "wb") as output:
            output.write(raw)
    except BaseException:
        Path(name).unlink(missing_ok=True)
        raise
    return Path(name)


def append_env(path: Path, values: dict[str, str]):
    if any("\n" in value or "\r" in value for value in values.values()):
        raise ValueError("multiline_signing_parameter_rejected")
    with path.open("a") as output:
        for key, value in values.items():
            output.write(f"{key}={value}\n")


def main() -> None:
    candidates = []
    preparation_error = None
    secret_path = None
    password = os.environ.get("MGD_STORE_PASSWORD") or "android"
    alias = os.environ.get("MGD_KEY_ALIAS") or "androiddebugkey"
    key_password = os.environ.get("MGD_KEY_PASSWORD") or password
    encoded = os.environ.get("MGD_KEYSTORE_BASE64", "").strip()
    if encoded:
        try:
            secret_path = prepare_secret(encoded, Path(os.environ.get("RUNNER_TEMP", tempfile.gettempdir())))
            candidates.append(dict(source="repository_secret", path=str(secret_path),
                                   password=password, alias=alias, key_password=key_password))
        except (ValueError, OSError):
            preparation_error = "invalid_keystore_secret"
    explicit = os.environ.get("MGD_STORE_FILE", "")
    if explicit:
        candidates.append(dict(source="explicit_store", path=str(Path(explicit).resolve()),
                               password=password, alias=alias, key_password=key_password))
    candidates.append(dict(source="legacy_cache", path=str(Path.home()/".android/debug.keystore"),
                           password="android", alias="androiddebugkey", key_password="android"))
    selected, report = select_key(candidates)
    if preparation_error:
        report["preparation_error"] = preparation_error
        selected = None
        report.update(ready=False, reason=preparation_error)
    if secret_path and (selected is None or selected["path"] != str(secret_path)):
        secret_path.unlink(missing_ok=True)
    if selected and os.environ.get("GITHUB_ENV"):
        append_env(Path(os.environ["GITHUB_ENV"]), {
            "MGD_STORE_FILE": selected["path"], "MGD_STORE_PASSWORD": selected["password"],
            "MGD_KEY_ALIAS": selected["alias"], "MGD_KEY_PASSWORD": selected["key_password"]})
    report_path = Path("mgd-neural-0421/tool/reports/signing-preflight0432.json")
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2))
    if os.environ.get("GITHUB_OUTPUT"):
        append_env(Path(os.environ["GITHUB_OUTPUT"]), {"ready": str(report["ready"]).lower()})
    print(json.dumps(report, indent=2))
    # Inspecting the key must not suppress independent model validation.
    # The final delivery step is responsible for failing a blocked release.
    if not report["ready"]:
        print("::warning::Original 0.43.1 signing key unavailable; APK publication is blocked. No replacement key was generated.")


if __name__ == "__main__":
    main()
