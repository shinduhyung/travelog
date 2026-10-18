"""Entity-name protection shared by catalog generation and editorial tooling."""
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
COMMON_WORDS = {
    'The', 'This', 'That', 'These', 'Those', 'Many', 'Most', 'One', 'Two',
    'First', 'Second', 'New', 'Old', 'Home', 'Here', 'Main', 'City', 'Town',
    'State', 'National', 'International', 'Independence', 'Landlocked',
    'Roman', 'Republic', 'Union', 'Ocean', 'Sea', 'River', 'Lake', 'Bay',
    'Mountain', 'Valley', 'Island', 'Park', 'Central', 'North', 'South',
    'East', 'West', 'Great', 'Grand', 'Modern', 'Ancient', 'Long', 'High',
    'Red', 'Blue', 'Green', 'White', 'Black', 'Golden', 'English', 'Nice',
    'Reading', 'Bath', 'Hope', 'Summer', 'Winter', 'Spring', 'Fall',
}

def walk(data):
    if isinstance(data, dict):
        yield data
        for value in data.values():
            yield from walk(value)
    elif isinstance(data, list):
        for value in data:
            yield from walk(value)

def names():
    result = {'Travelog', 'Jido', 'Google', 'Apple', 'Facebook', 'Instagram', 'YouTube', 'Trip.com', 'UNESCO', 'GaWC', 'IATA', 'GDP', 'USD', 'eSIM', 'Uber', 'Michelin', 'Roman Empire', 'British Empire', 'French Empire', 'Ottoman Empire', 'Mongol Empire', 'Inca Empire', 'Statue of Liberty', 'Top of the Rock'}
    for filename in ['cities.json', 'cities15000.json', 'all_landmarks.json', 'unesco_landmarks.json', 'airports.json', 'airlines.json', 'aircraft_models.json']:
        data = json.loads((ROOT / 'assets' / filename).read_text(encoding='utf-8'))
        for item in walk(data):
            for key in ['name', 'city', 'airline', 'model']:
                name = item.get(key)
                if isinstance(name, str) and len(name) > 2:
                    result.add(name)
    for path in (ROOT / 'lib').rglob('*.dart'):
        for match in re.finditer(r"(?:['\"](?:name|city|airline|airport|landmark)['\"]|\bname)\s*:\s*(['\"])([^'\"\n$]+)\1", path.read_text(encoding='utf-8')):
            result.add(match[2])
    return result

def trie(names):
    result = {}
    for name in names:
        cursor = result
        for char in name:
            cursor = cursor.setdefault(char, {})
        cursor[None] = True
    return result

def mask(text, tree):
    protected = []
    output = []
    index = 0
    while index < len(text):
        cursor = tree
        end = index
        best = None
        if index == 0 or not text[index-1].isascii() or not text[index-1].isalpha():
            while end < len(text) and text[end] in cursor:
                cursor = cursor[text[end]]
                end += 1
                if None in cursor and (end == len(text) or not text[end].isascii() or not text[end].isalpha()):
                    best = end
        if best is not None:
            protected.append(text[index:best])
            output.append(f'ZXQ{len(protected)-1:05d}ZXQ')
            index = best
        else:
            output.append(text[index])
            index += 1
    return ''.join(output), protected

def restore(text, protected):
    for index, original in enumerate(protected):
        text = text.replace(f'ZXQ{index:05d}ZXQ', original)
    return text
