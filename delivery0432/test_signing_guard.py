"""Signing regression tests, using throw-away keys unrelated to the app."""
import base64
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import signing_guard as guard


class SigningTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.folder = Path(cls.temp.name)
        cls.key = cls.folder / "temporary-test.jks"
        subprocess.run(["keytool", "-genkeypair", "-noprompt", "-alias", "test",
            "-keystore", str(cls.key), "-storepass", "test-password",
            "-keypass", "test-password", "-keyalg", "RSA", "-keysize", "2048",
            "-validity", "1", "-dname", "CN=Throwaway signing test"],
            check=True, capture_output=True, timeout=30)
        cls.cert = cls.folder / "certificate.der"
        subprocess.run(["keytool", "-exportcert", "-alias", "test", "-keystore", str(cls.key),
            "-storepass", "test-password", "-file", str(cls.cert)],
            check=True, capture_output=True, timeout=20)
        cls.cert_only = cls.folder / "certificate-only.jks"
        subprocess.run(["keytool", "-importcert", "-noprompt", "-alias", "test", "-keystore", str(cls.cert_only),
            "-storepass", "test-password", "-file", str(cls.cert)],
            check=True, capture_output=True, timeout=20)
        import hashlib
        cls.fingerprint = hashlib.sha256(cls.cert.read_bytes()).hexdigest()

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def candidate(self, path=None):
        return dict(source="test", path=str(path or self.key), alias="test", password="test-password")

    def test_01_wrong_certificate_does_not_pass(self):
        selected, result = guard.select_key([self.candidate()])
        self.assertIsNone(selected)
        self.assertFalse(result["ready"])
        self.assertEqual(result["candidates"][0]["sha256"], self.fingerprint)

    def test_02_original_private_entry_selects_exact_path(self):
        selected, result = guard.select_key([self.candidate()], self.fingerprint)
        self.assertTrue(result["ready"])
        self.assertEqual(selected["path"], str(self.key))

    def test_03_public_certificate_alone_is_not_a_signer(self):
        selected, result = guard.select_key([self.candidate(self.cert_only)], self.fingerprint)
        self.assertIsNone(selected)
        self.assertTrue(result["candidates"][0]["matches_installed"])
        self.assertFalse(result["candidates"][0]["private_key"])

    def test_04_missing_key_is_not_generated(self):
        path = self.folder / "absent.jks"
        selected, result = guard.select_key([self.candidate(path)])
        self.assertFalse(path.exists())
        self.assertFalse(result["private_key_created"])

    def test_05_wrong_password_is_sanitized(self):
        candidate = self.candidate(); candidate["password"] = "not-the-password"
        _, report = guard.select_key([candidate])
        self.assertFalse(report["candidates"][0]["readable"])
        self.assertNotIn("not-the-password", json.dumps(report))

    def test_06_secret_file_is_private_and_exact(self):
        encoded = base64.b64encode(self.key.read_bytes()).decode()
        path = guard.prepare_secret(encoded, self.folder)
        self.assertEqual(path.read_bytes(), self.key.read_bytes())
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        path.unlink()

    def test_07_malformed_secret_is_rejected(self):
        for value in ("!!!!", "", "  "):
            with self.assertRaises(ValueError):
                guard.prepare_secret(value, self.folder)

    def test_08_environment_line_injection_is_rejected_atomically(self):
        path = self.folder / "github-env"
        path.write_text("PREVIOUS=yes\n")
        with self.assertRaises(ValueError):
            guard.append_env(path, {"MGD_KEY_ALIAS": "alias\nUNEXPECTED=yes"})
        self.assertEqual(path.read_text(), "PREVIOUS=yes\n")

    def test_09_diagnostic_never_contains_password_or_encoded_private_key(self):
        _, report = guard.select_key([self.candidate()], self.fingerprint)
        text = json.dumps(report)
        self.assertNotIn("test-password", text)
        self.assertNotIn(base64.b64encode(self.key.read_bytes()).decode(), text)

    def test_10_real_certificate_pin_cannot_silently_change(self):
        self.assertEqual(guard.EXPECTED_SHA256,
            "d4974611809f5def4c01e0d805a124be0a9471d7532b15c8eeb8d6ec30eb78e1")


if __name__ == "__main__":
    unittest.main()
