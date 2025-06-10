#!/usr/bin/python3

import argparse
import base64
import json
from pathlib import Path
from typing import Any, Union

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import (
    ec, rsa,
    padding as rsa_padding,
    utils as asym_utils
)
from cryptography.hazmat.backends import default_backend


def canonicalize_json(obj: Any) -> bytes:
    return json.dumps(obj, separators=(",", ":"), sort_keys=True).encode("utf-8")


def load_private_key(path: Path) -> Union[rsa.RSAPrivateKey, ec.EllipticCurvePrivateKey]:
    with path.open("rb") as f:
        return serialization.load_pem_private_key(f.read(), password=None, backend=default_backend())


def load_public_key(path: Path) -> Union[rsa.RSAPublicKey, ec.EllipticCurvePublicKey]:
    with path.open("rb") as f:
        return serialization.load_pem_public_key(f.read(), backend=default_backend())


def sign_golden_measurement(golden_measurement: dict, private_key: Union[rsa.RSAPrivateKey, ec.EllipticCurvePrivateKey]) -> str:
    data = canonicalize_json(golden_measurement)

    if isinstance(private_key, rsa.RSAPrivateKey):
        signature = private_key.sign(
            data,
            rsa_padding.PKCS1v15(),
            hashes.SHA256(),
        )
    elif isinstance(private_key, ec.EllipticCurvePrivateKey):
        signature = private_key.sign(data, ec.ECDSA(hashes.SHA256()))
    else:
        raise TypeError("Unsupported private key type")

    return base64.b64encode(signature).decode("utf-8")


def verify_signature(
    golden_measurement: dict,
    signature_b64: str,
    public_key: Union[rsa.RSAPublicKey, ec.EllipticCurvePublicKey],
) -> bool:
    data = canonicalize_json(golden_measurement)
    signature = base64.b64decode(signature_b64)

    try:
        if isinstance(public_key, rsa.RSAPublicKey):
            public_key.verify(signature, data, rsa_padding.PKCS1v15(), hashes.SHA256())
        elif isinstance(public_key, ec.EllipticCurvePublicKey):
            public_key.verify(signature, data, ec.ECDSA(hashes.SHA256()))
        else:
            raise TypeError("Unsupported public key type")
        return True
    except Exception:
        return False


def sign_file(input_json: Path, private_key_path: Path, output_json: Path) -> None:
    with input_json.open() as f:
        data = json.load(f)

    if "golden_measurement" not in data:
        raise ValueError("Input JSON must contain a 'golden_measurement' field.")

    private_key = load_private_key(private_key_path)
    signature = sign_golden_measurement(data["golden_measurement"], private_key)
    data["signature"] = signature

    with output_json.open("w") as f:
        json.dump(data, f, indent=2)
    print(f"✅ Signed and saved to {output_json}")


def verify_file(signed_json: Path, public_key_path: Path) -> None:
    with signed_json.open() as f:
        data = json.load(f)

    if "golden_measurement" not in data or "signature" not in data:
        raise ValueError("Signed JSON must contain 'golden_measurement' and 'signature' fields.")

    public_key = load_public_key(public_key_path)
    result = verify_signature(data["golden_measurement"], data["signature"], public_key)
    print("✅ Verified" if result else "❌ Verification failed")


def main() -> None:
    parser = argparse.ArgumentParser(description="Sign or verify a JSON file using RSA or ECC keys.")
    parser.add_argument("mode", choices=["sign", "verify"], help="Operation mode")
    parser.add_argument("json_file", type=Path, help="Path to input JSON file")
    parser.add_argument("key_file", type=Path, help="Path to private (sign) or public (verify) key")
    parser.add_argument("-o", "--output", type=Path, help="Output path for signed JSON (sign mode only)")

    args = parser.parse_args()

    if args.mode == "sign":
        if not args.output:
            raise ValueError("Output path is required in sign mode.")
        sign_file(args.json_file, args.key_file, args.output)
    else:
        verify_file(args.json_file, args.key_file)


if __name__ == "__main__":
    main()

