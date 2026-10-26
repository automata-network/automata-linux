#!/usr/bin/env python3
"""Verify a downloaded Automata Linux release against an independently trusted key.

Requires Python 3.11+ and OpenSSL. Checks release files, signatures, archive
bindings, and metadata consistency. Does not attest a running VM.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def der_integer(raw):
    raw = raw.lstrip(b'\x00') or b'\x00'
    if raw[0] & 0x80:
        raw = b'\x00' + raw
    return b'\x02' + bytes([len(raw)]) + raw


def verify_signature(body, raw_signature, public_key, scratch):
    require(len(raw_signature) == 64, 'signature must contain 64 bytes (r || s)')
    require(len(public_key) == 65 and public_key[0] == 4,
            'publisher key must be an uncompressed 65-byte secp256k1 key')
    integers = der_integer(raw_signature[:32]) + der_integer(raw_signature[32:])
    signature = b'\x30' + bytes([len(integers)]) + integers
    # SubjectPublicKeyInfo: id-ecPublicKey, secp256k1, uncompressed SEC1 key.
    spki = bytes.fromhex('3056301006072a8648ce3d020106052b8104000a034200') + public_key
    with tempfile.TemporaryDirectory(prefix='automata-release-', dir=scratch) as temporary:
        directory = Path(temporary)
        (directory / 'key.der').write_bytes(spki)
        (directory / 'signature.der').write_bytes(signature)
        (directory / 'pack.json').write_bytes(body)
        result = subprocess.run([
            'openssl', 'dgst', '-sha256', '-verify', str(directory / 'key.der'),
            '-keyform', 'DER', '-signature', str(directory / 'signature.der'),
            str(directory / 'pack.json'),
        ], capture_output=True, text=True)
    require(result.returncode == 0, 'measurement-pack signature verification failed')


def verify(directory, expected_key, scratch):
    repository = Path(__file__).resolve().parents[1]
    provenance_bytes = (directory / 'release-provenance.json').read_bytes()
    require(provenance_bytes == (repository / 'provenance.json').read_bytes(),
            'provenance differs from the checked-out release documentation')
    require((directory / 'RELEASE-NOTES.md').read_bytes() ==
            (repository / 'RELEASE_NOTES.md').read_bytes(),
            'release notes differ from the checked-out release documentation')
    provenance = json.loads(provenance_bytes)
    release = provenance['release']
    prefix = 'automata-linux-' + release
    platforms = ['all', 'aws', 'azure', 'gcp', 'qemu']
    expected = {'RELEASE-NOTES.md', 'release-provenance.json', 'SHA256SUMS'}
    for platform in platforms:
        stem = f'{prefix}-{platform}'
        expected.add(stem + '.atabi')
        expected.update(stem + '.measurement-pack.' + suffix
                        for suffix in ['json', 'sig', 'pubkey'])
    require(set(provenance['release_assets']) == expected, 'provenance asset inventory differs')
    actual = {path.name for path in directory.iterdir()}
    require(actual == expected,
            f'release inventory differs: missing={sorted(expected - actual)}, extra={sorted(actual - expected)}')
    for name in expected:
        path = directory / name
        require(path.is_file() and not path.is_symlink(), f'not a regular release file: {name}')
    checksums = {}
    for line in (directory / 'SHA256SUMS').read_text().splitlines():
        sha, separator, name = line.partition('  ')
        require(separator and len(sha) == 64 and all(c in '0123456789abcdef' for c in sha),
                'invalid SHA256SUMS line')
        require(name in expected - {'SHA256SUMS'} and name not in checksums,
                'unexpected or duplicate checksum filename')
        checksums[name] = sha
    require(set(checksums) == expected - {'SHA256SUMS'}, 'checksum inventory differs')
    for name, sha in checksums.items():
        require(digest(directory / name) == sha, f'checksum mismatch: {name}')
    expected_pack_files = {name for name in expected if '.measurement-pack.' in name}
    require(set(provenance['measurement_pack_sha256']) == expected_pack_files,
            'measurement-pack digest inventory differs')
    for name, sha in provenance['measurement_pack_sha256'].items():
        require(digest(directory / name) == sha, f'pack differs from release provenance: {name}')
    profiles = None
    for platform in platforms:
        stem = f'{prefix}-{platform}'
        archive_name = stem + '.atabi'
        body = (directory / (stem + '.measurement-pack.json')).read_bytes()
        signature = (directory / (stem + '.measurement-pack.sig')).read_bytes()
        key_text = (directory / (stem + '.measurement-pack.pubkey')).read_text().strip()
        key = bytes.fromhex(key_text.removeprefix('0x'))
        require(key == expected_key, f'unexpected publisher key: {stem}')
        verify_signature(body, signature, expected_key, scratch)
        pack = json.loads(body)
        canonical = json.dumps(pack, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode()
        require(canonical == body, f'noncanonical measurement pack: {stem}')
        require(pack['schema'] == 'atakit.base_image_measurement_pack.v4', 'unsupported pack schema')
        require(pack['revision'] == provenance['measurement_pack_revision'], 'pack revision differs')
        subject = pack['subject']
        require(subject['publisher'] == provenance['publisher_fingerprint'], 'publisher fingerprint differs')
        require(subject['id'] == provenance['base_image_id'], 'base-image ID differs')
        require(subject['name'] == 'automata-linux' and subject['version'] == release, 'pack subject differs')
        archive_hash = digest(directory / archive_name)
        require(subject['archive_sha256'] == '0x' + archive_hash, f'signed archive hash differs: {stem}')
        require(provenance['archive_sha256'][archive_name] == archive_hash, 'provenance archive hash differs')
        expected_uri = f'https://github.com/automata-network/automata-linux/releases/download/{release}/{archive_name}'
        require(subject['uri'] == expected_uri, 'archive URI differs')
        current = pack['measurements']['profiles']
        require(len({p['id'] for p in current}) == len(current), 'duplicate profile identifier')
        for profile in current:
            require(len({v['id'] for v in profile['variants']}) == len(profile['variants']),
                    'duplicate variant identifier')
        names = {p['name']: sorted(v['name'] for v in p['variants']) for p in current}
        require(names == provenance['measurement_profiles'], 'profile and variant inventory differs')
        if profiles is not None:
            require(current == profiles, 'archive packs contain different measurement policies')
        profiles = current
    require(len(expected) == 23, 'unexpected total asset count')
    print(f'{release}: verified 23 files, 5 publisher signatures, and 5 signed archive hashes')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path, help='directory containing all 23 downloaded release assets')
    parser.add_argument('--publisher-key', required=True,
                        help='independently trusted uncompressed secp256k1 public key (0x04...)')
    parser.add_argument('--scratch-dir', type=Path, help='parent directory for temporary verification files')
    args = parser.parse_args()
    try:
        key = bytes.fromhex(args.publisher_key.removeprefix('0x'))
        verify(args.directory, key, args.scratch_dir)
    except (ValueError, KeyError, TypeError, OSError, json.JSONDecodeError) as error:
        print(f'Verification failed: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
