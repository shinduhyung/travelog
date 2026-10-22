"""Upload the catalogs build.py wrote to build/l10n/ to Firebase Storage.

  python tool/l10n/publish.py

Catalogs are gzip-encoded on upload and named after their content hash, so
they are cached forever. The manifest goes up last with no-cache, which makes
installed apps switch to the new files only once they all exist.
Needs `gcloud auth login` with write access to the bucket.
"""
import gzip
import json
import pathlib
import subprocess
import sys
import tempfile

from build import BUCKET, PUBLISH, STORAGE_PREFIX, load_json


def upload(path, name, cache_control):
    with tempfile.TemporaryDirectory() as tmp:
        packed = pathlib.Path(tmp) / path.name
        packed.write_bytes(gzip.compress(path.read_bytes(), 9))
        subprocess.run([
            'gcloud', 'storage', 'cp', str(packed), f'gs://{BUCKET}/{STORAGE_PREFIX}{name}',
            '--content-type=application/json; charset=utf-8',
            '--content-encoding=gzip',
            f'--cache-control={cache_control}',
        ], check=True, shell=sys.platform == 'win32')
        print(f'uploaded {STORAGE_PREFIX}{name} ({packed.stat().st_size} bytes gzipped)')


def exists(name):
    return subprocess.run(
        ['gcloud', 'storage', 'objects', 'describe', f'gs://{BUCKET}/{STORAGE_PREFIX}{name}'],
        capture_output=True, shell=sys.platform == 'win32').returncode == 0


def main():
    manifest = load_json(PUBLISH / 'languages.json')
    if manifest is None:
        sys.exit('Run tool/l10n/build.py first.')
    for language in manifest['languages']:
        if exists(language['file']):
            print(f'unchanged {STORAGE_PREFIX}{language["file"]}')
            continue
        upload(PUBLISH / language['file'], language['file'], 'public, max-age=31536000, immutable')
    upload(PUBLISH / 'languages.json', 'languages.json', 'no-cache')


if __name__ == '__main__':
    main()
