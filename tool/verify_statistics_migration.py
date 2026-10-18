"""Frozen legacy fingerprints prove migration preserves every field/value/order.

The fixture was captured from Git HEAD before the JSON migration. A deliberate
future data update should update its fingerprint as part of that reviewed change.
"""
import hashlib
import json
import struct
from pathlib import Path
from statistics_schema import DATASETS, decode_statistics

ROOT = Path(__file__).resolve().parents[1]


def fingerprint(value):
    h = hashlib.sha256()

    def emit(v):
        if v is None:
            h.update(b'n')
        elif isinstance(v, bool):
            h.update(b't' if v else b'f')
        elif isinstance(v, int):
            h.update(b'i' + str(v).encode('ascii') + b';')
        elif isinstance(v, float):
            h.update(b'd' + struct.pack('>d', v))
        elif isinstance(v, str):
            b = v.encode('utf8')
            h.update(b's' + str(len(b)).encode('ascii') + b':' + b)
        elif isinstance(v, list):
            h.update(b'[')
            for item in v:
                emit(item)
            h.update(b']')
        elif isinstance(v, dict):
            h.update(b'{')
            for key in sorted(v):
                emit(key)
                emit(v[key])
            h.update(b'}')
        else:
            raise TypeError(type(v))
    emit(value)
    return h.hexdigest()


def main():
    baseline = json.loads((ROOT / 'test/fixtures/statistics_legacy_fingerprints.json').read_text(encoding='utf8'))
    if set(baseline) != {f'assets/{n}.json' for n in DATASETS}:
        raise ValueError('Baseline/registry coverage mismatch')
    for path, expected in baseline.items():
        current = json.loads((ROOT / path).read_text(encoding='utf8'))
        if fingerprint(decode_statistics(current)) != expected:
            raise ValueError(f'Migration changed content: {path}')
    print(f'All {len(baseline)} datasets preserve every legacy field, value, type and row order')


if __name__ == '__main__':
    main()
