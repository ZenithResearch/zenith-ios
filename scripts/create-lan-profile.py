#!/usr/bin/env python3
"""Export public LAN setup from the receiver's approved authority policy and TLS cert.

Does not configure a server, grant access, install trust, or read private keys.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import ssl
from urllib.parse import urlsplit


def profile(policy, certificate, name):
    origin = policy["receiver"]
    parsed = urlsplit(origin)
    if (parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password
            or parsed.query or parsed.fragment or parsed.path or len(origin) > 2048
            or not name.strip() or len(name) > 80 or policy["audience"] != "devgraph"
            or not re.fullmatch(r"[0-9a-f]{64}", policy["public_key"])
            or not 1 <= len(policy["issuer"]) <= 256 or not 1 <= len(policy["key_id"]) <= 256
            or (parsed.port is not None and not 1 <= parsed.port <= 65535)):
        raise ValueError("Invalid public receiver settings")
    der = ssl.PEM_cert_to_DER_cert(certificate)
    return {"name": name, "receiver": origin, "issuer": policy["issuer"],
            "authority": {key: policy[key] for key in
                          ("issuer", "key_id", "public_key", "receiver", "audience")},
            "network": "lan", "tls_certificate_sha256": hashlib.sha256(der).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--authority-policy", required=True, type=Path)
    parser.add_argument("--certificate", required=True, type=Path)
    parser.add_argument("--name", default="Work on Wi-Fi")
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    value = profile(json.loads(args.authority_policy.read_text()), args.certificate.read_text(), args.name)
    fd = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w") as file:
        json.dump(value, file, indent=2)
        file.write("\n")
        file.flush()
        os.fsync(file.fileno())
    print("Public LAN connection file created. Review before sharing with the phone.")


if __name__ == "__main__":
    main()
