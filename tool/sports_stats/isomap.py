"""Country-name -> ISO3 resolver built from assets/custom.geo.json (Natural Earth)."""
import json
import re
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def norm(s):
    s = unicodedata.normalize('NFKD', str(s))
    s = ''.join(c for c in s if not unicodedata.combining(c))
    s = re.sub(r'\[[^\]]*\]|\([^)]*\)', ' ', s)
    s = s.lower().replace('&', 'and')
    s = re.sub(r'[^a-z0-9]+', ' ', s).strip()
    return re.sub(r'^the ', '', s)


# Names (as written by Wikipedia/FIFA/MLB) that Natural Earth spells differently.
ALIASES = {
    'united states': 'USA', 'usa': 'USA', 'south korea': 'KOR', 'korea republic': 'KOR',
    'north korea': 'PRK', 'korea dpr': 'PRK', 'russia': 'RUS', 'soviet union': 'RUS',
    'czech republic': 'CZE', 'czechia': 'CZE', 'czechoslovakia': 'CZE',
    'ivory coast': 'CIV', 'cote d ivoire': 'CIV', 'dr congo': 'COD', 'congo dr': 'COD',
    'democratic republic of the congo': 'COD', 'zaire': 'COD', 'congo': 'COG',
    'republic of the congo': 'COG', 'north macedonia': 'MKD', 'macedonia': 'MKD',
    'eswatini': 'SWZ', 'swaziland': 'SWZ', 'cape verde': 'CPV', 'cabo verde': 'CPV',
    'turkey': 'TUR', 'turkiye': 'TUR', 'england': 'GBR', 'scotland': 'GBR', 'wales': 'GBR',
    'northern ireland': 'GBR', 'great britain': 'GBR', 'united kingdom': 'GBR',
    'germany': 'DEU', 'west germany': 'DEU', 'east germany': 'DEU',
    'serbia': 'SRB', 'yugoslavia': 'SRB', 'serbia and montenegro': 'SRB', 'fr yugoslavia': 'SRB',
    'chinese taipei': 'TWN', 'taiwan': 'TWN', 'hong kong': 'HKG', 'china pr': 'CHN',
    'china': 'CHN', 'macau': 'MAC', 'macao': 'MAC', 'iran': 'IRN', 'ir iran': 'IRN',
    'vietnam': 'VNM', 'viet nam': 'VNM', 'syria': 'SYR', 'laos': 'LAO', 'brunei': 'BRN',
    'palestine': 'PSE', 'state of palestine': 'PSE', 'kyrgyz republic': 'KGZ', 'kyrgyzstan': 'KGZ',
    'timor leste': 'TLS', 'east timor': 'TLS', 'myanmar': 'MMR', 'burma': 'MMR',
    'gambia': 'GMB', 'the gambia': 'GMB', 'bahamas': 'BHS', 'curacao': 'CUW',
    'saint kitts and nevis': 'KNA', 'st kitts and nevis': 'KNA', 'saint lucia': 'LCA', 'st lucia': 'LCA',
    'saint vincent and the grenadines': 'VCT', 'st vincent and the grenadines': 'VCT',
    'antigua and barbuda': 'ATG', 'trinidad and tobago': 'TTO', 'bosnia and herzegovina': 'BIH',
    'bosnia herzegovina': 'BIH', 'sao tome and principe': 'STP', 'micronesia': 'FSM',
    'federated states of micronesia': 'FSM', 'dominican republic': 'DOM', 'netherlands': 'NLD',
    'dutch east indies': 'IDN', 'puerto rico': 'PRI', 'guam': 'GUM', 'american samoa': 'ASM',
    'us virgin islands': 'VIR', 'united states virgin islands': 'VIR', 'british virgin islands': 'VGB',
    'virgin islands': 'VIR', 'cayman islands': 'CYM', 'faroe islands': 'FRO', 'new caledonia': 'NCL',
    'tahiti': 'PYF', 'french polynesia': 'PYF', 'cook islands': 'COK', 'bermuda': 'BMU',
    'aruba': 'ABW', 'refugee olympic team': None, 'republic of ireland': 'IRL', 'ireland': 'IRL', 'australasia': None, 'bohemia': None, 'macau china': 'MAC', 'hong kong china': 'HKG', 'st vincent grenadines': 'VCT', 'dpr korea': 'PRK', 'st kitts and nevis': 'KNA', 'korea republic': 'KOR', 'ir iran': 'IRN', 'cote d ivoire': 'CIV', 'turkiye': 'TUR', 'congo dr': 'COD', 'curacao': 'CUW', 'cabo verde': 'CPV',
}


class IsoResolver:
    def __init__(self):
        geo = json.loads((ROOT / 'assets/custom.geo.json').read_text(encoding='utf8'))
        self.index = {}
        self.codes = set()
        feats = []
        for f in geo['features']:
            p = f['properties']
            iso = p.get('iso_a3_eh') or p.get('iso_a3')
            if iso and iso != '-99':
                self.codes.add(iso)
                feats.append((iso, p))
        # Own names first; the sovereign's name only fills gaps (France != Saint Martin).
        for keys in (('name', 'admin', 'brk_name', 'formal_en', 'name_long', 'name_en'), ('geounit', 'sovereignt')):
            for iso, p in feats:
                for k in keys:
                    v = p.get(k)
                    if v:
                        self.index.setdefault(norm(v), iso)
        self.unresolved = set()

    def resolve(self, name):
        n = norm(name)
        iso = ALIASES.get(n)
        if iso is None and n in ALIASES:
            return None
        if iso is None:
            iso = self.index.get(n)
        if iso is None:
            self.unresolved.add(str(name))
            return None
        if iso not in self.codes:
            self.unresolved.add(f'{name}->{iso}')
            return None
        return iso
