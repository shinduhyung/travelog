"""Read selected CSV/PDF members of public JRC ZIPs with HTTP range requests."""
import argparse
import concurrent.futures
import gzip
import io
from pathlib import Path
import urllib.request
import zipfile

OUT = Path(__file__).resolve().parents[1] / 'audit/city_statistics_ideas_sources'
BASE = ('https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GHSL/'
        'GHS_UCDB_GLOBE_R2024A/GHS_UCDB_THEME_GLOBE_R2024A/')


class RemoteZip(io.RawIOBase):
    def __init__(self, url):
        self.url, self.position = url, 0
        with urllib.request.urlopen(urllib.request.Request(url, headers={'Range': 'bytes=0-0'}), timeout=90) as r:
            if r.status != 206:
                raise ValueError('Server does not support range requests')
            self.length = int(r.headers['Content-Range'].split('/')[-1])

    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.position

    def seek(self, offset, whence=0):
        self.position = offset if whence == 0 else (self.position + offset if whence == 1 else self.length + offset)
        return self.position

    def read(self, size=-1):
        end = self.length - 1 if size < 0 else min(self.length - 1, self.position + size - 1)
        if end < self.position:
            return b''
        request = urllib.request.Request(self.url, headers={'Range': f'bytes={self.position}-{end}'})
        with urllib.request.urlopen(request, timeout=180) as response:
            if response.status != 206:
                raise ValueError('Expected partial content')
            raw = response.read()
        if len(raw) != end - self.position + 1:
            raise ValueError('Incomplete HTTP range response')
        self.position += len(raw)
        return raw


def fetch(theme):
    name = f'GHS_UCDB_THEME_{theme}_GLOBE_R2024A'
    url = f'{BASE}{name}/V1-2/{name}_V1_2.zip'
    with zipfile.ZipFile(RemoteZip(url)) as archive:
        saved = []
        for member in archive.namelist():
            if member.endswith('.csv'):
                dest = OUT / f'ghsl_{theme}.csv.gz'
                if not dest.exists():
                    dest.write_bytes(gzip.compress(archive.read(member)))
                saved.append((dest.name, dest.stat().st_size))
            elif member == name + '.pdf':
                dest = OUT / member
                if not dest.exists():
                    dest.write_bytes(archive.read(member))
                saved.append((dest.name, dest.stat().st_size))
    return theme, saved


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('themes', nargs='+')
    args = parser.parse_args()
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        for result in pool.map(fetch, args.themes):
            print(result, flush=True)
