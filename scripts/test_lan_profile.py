import importlib.util
from pathlib import Path
import ssl
import unittest

spec = importlib.util.spec_from_file_location("lan_profile", Path(__file__).with_name("create-lan-profile.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class LANProfileTests(unittest.TestCase):
    def setUp(self):
        self.policy = {"issuer": "example", "key_id": "example-key",
                       "public_key": "12" * 32, "receiver": "https://work.example.local:9444",
                       "audience": "devgraph", "permissions": [{"operation": "example"}],
                       "private_key": "must-never-be-copied"}
        cert = Path(__file__).parent.parent / "Tests/ZenithKitTests/Fixtures/lan-server.der"
        self.certificate = ssl.DER_cert_to_PEM_cert(cert.read_bytes())

    def test_public_export_does_not_copy_authority_or_secrets(self):
        result = module.profile(self.policy, self.certificate, "Example LAN")
        self.assertEqual(set(result), {"name", "receiver", "issuer", "authority", "network", "tls_certificate_sha256"})
        self.assertEqual(set(result["authority"]), {"issuer", "key_id", "public_key", "receiver", "audience"})
        self.assertNotIn("must-never-be-copied", str(result))
        self.assertEqual(result["authority"]["receiver"], result["receiver"])

    def test_rejects_unsafe_origin_and_malformed_certificate(self):
        for address in ["http://work.local", "https://secret@work.local", "https://work.local/path",
                        "https://work.local?secret=value", "https://work.local:65536"]:
            with self.assertRaises(ValueError):
                module.profile({**self.policy, "receiver": address}, self.certificate, "LAN")
        with self.assertRaises(ValueError):
            module.profile(self.policy, "not a certificate", "LAN")


if __name__ == "__main__":
    unittest.main()
