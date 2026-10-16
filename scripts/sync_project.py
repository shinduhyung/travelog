#!/usr/bin/env python3
"""Update this checkout without overwriting work or creating a merge."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def git(*args, capture=False):
    return subprocess.run(
        ['git', *args], cwd=ROOT, check=True, text=True,
        stdout=subprocess.PIPE if capture else None,
    )


def main():
    if len(sys.argv) != 1:
        raise SystemExit('Usage: python3 scripts/sync_project.py')
    if git('status', '--porcelain', capture=True).stdout.strip():
        raise SystemExit('Local changes exist. Commit or stash them before syncing.')
    branch = git('branch', '--show-current', capture=True).stdout.strip()
    if not branch:
        raise SystemExit('Detached HEAD or rebase in progress. Finish it before syncing.')
    upstream = git('rev-parse', '--abbrev-ref', '@{upstream}', capture=True).stdout.strip()
    git('fetch', '--prune')
    git('merge', '--ff-only', upstream)
    print(f'Synced {branch} with {upstream}. Run flutter pub get before building.')


if __name__ == '__main__':
    try:
        main()
    except subprocess.CalledProcessError as exc:
        raise SystemExit(exc.returncode)
