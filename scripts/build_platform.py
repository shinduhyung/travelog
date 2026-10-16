#!/usr/bin/env python3
"""Build shared source using the selected store's version and build number."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('platform', choices=['android', 'ios'])
    parser.add_argument('--build-name', help='Override the configured store version')
    parser.add_argument('--build-number', help='Override the configured store build number')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    if args.platform == 'ios' and sys.platform != 'darwin' and not args.dry_run:
        parser.error('iOS builds require macOS and Xcode.')
    versions = json.loads((ROOT / 'platform_versions.json').read_text())[args.platform]
    command = [
        'flutter', 'build', 'appbundle' if args.platform == 'android' else 'ipa',
        '--release',
        f'--build-name={args.build_name or versions["build_name"]}',
        f'--build-number={args.build_number or versions["build_number"]}',
    ]
    print(' '.join(command), flush=True)
    if not args.dry_run:
        subprocess.run(command, cwd=ROOT, check=True)


if __name__ == '__main__':
    try:
        main()
    except subprocess.CalledProcessError as exc:
        raise SystemExit(exc.returncode)
