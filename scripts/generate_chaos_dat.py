#!/usr/bin/env python3
"""
Generate chaos.dat — gate file for debug key functionality.
The file contains the key string followed by cipher-text padding to exactly 8192 bytes.
The DLL validates the file via SHA-256 hash before enabling debug keys.

Run once to generate; check in the .dat file (NOT this script) alongside the DLL.
"""

import hashlib
import os
import secrets

TARGET_SIZE = 8192  # 8 KB exactly
KEY_STRING = b"HADES_ACCESSIBILITY_DEBUG_KEY_GATE_FILE_VALIDATION_v001"

def generate():
    # Key string at the start
    data = bytearray(KEY_STRING)

    # Fill remaining bytes with cryptographically random data (cipher text)
    remaining = TARGET_SIZE - len(data)
    if remaining <= 0:
        raise ValueError(f"Key string ({len(data)} bytes) exceeds target size ({TARGET_SIZE} bytes)")

    cipher_bytes = secrets.token_bytes(remaining)
    data.extend(cipher_bytes)

    assert len(data) == TARGET_SIZE, f"Expected {TARGET_SIZE} bytes, got {len(data)}"

    # Write the file
    out_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "hades", "chaos.dat")
    with open(out_path, "wb") as f:
        f.write(data)

    # Compute SHA-256
    sha256 = hashlib.sha256(data).hexdigest()

    print(f"Generated: {out_path}")
    print(f"Size: {len(data)} bytes")
    print(f"Key string: {len(KEY_STRING)} bytes")
    print(f"Cipher padding: {remaining} bytes")
    print(f"SHA-256: {sha256}")
    print()
    print("// Paste this into debug.cpp:")
    print(f'static const char* CHAOS_HASH = "{sha256}";')

    # Also output as byte array for C++ (alternative approach)
    hash_bytes = hashlib.sha256(data).digest()
    hex_arr = ", ".join(f"0x{b:02x}" for b in hash_bytes)
    print()
    print("// Or as byte array:")
    print(f"static const uint8_t CHAOS_HASH_BYTES[] = {{ {hex_arr} }};")

if __name__ == "__main__":
    generate()
