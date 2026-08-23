#!/usr/bin/env python3
"""
tool/generate_which_is_farther_questions.py

Regenerates assets/data/which_is_farther_questions.json for the
"Which Is Farther?" mini-game.

Usage:
    python3 generate_which_is_farther_questions.py
    (writes the output JSON next to wherever you run it from --
     copy/move the result into assets/data/ in the Flutter project)

To add more cities, extend the CITIES list below (name, ISO 3166-1
alpha-2 country code, latitude, longitude). To change how questions are
bucketed by difficulty, edit DIFF_BANDS. To change how many questions are
kept per (origin city, difficulty) pair, edit CAP_PER_ORIGIN_DIFF.
"""

import json, math, random, itertools
from collections import defaultdict

random.seed(42)

# name, ISO 3166-1 alpha-2 country code, lat, lon
CITIES = [
    # East Asia
    ("Seoul","KR",37.5665,126.9780), ("Busan","KR",35.1796,129.0756),
    ("Tokyo","JP",35.6762,139.6503), ("Osaka","JP",34.6937,135.5023),
    ("Beijing","CN",39.9042,116.4074), ("Shanghai","CN",31.2304,121.4737),
    ("Hong Kong","HK",22.3193,114.1694), ("Taipei","TW",25.0330,121.5654),
    ("Pyongyang","KP",39.0392,125.7625), ("Ulaanbaatar","MN",47.8864,106.9057),
    # Southeast Asia
    ("Bangkok","TH",13.7563,100.5018), ("Hanoi","VN",21.0285,105.8542),
    ("Ho Chi Minh City","VN",10.8231,106.6297), ("Manila","PH",14.5995,120.9842),
    ("Jakarta","ID",-6.2088,106.8456), ("Kuala Lumpur","MY",3.1390,101.6869),
    ("Singapore","SG",1.3521,103.8198), ("Phnom Penh","KH",11.5564,104.9282),
    ("Vientiane","LA",17.9757,102.6331), ("Yangon","MM",16.8661,96.1951),
    ("Bandar Seri Begawan","BN",4.9031,114.9398), ("Dili","TL",-8.5569,125.5603),
    # South Asia
    ("New Delhi","IN",28.6139,77.2090), ("Mumbai","IN",19.0760,72.8777),
    ("Kolkata","IN",22.5726,88.3639), ("Karachi","PK",24.8607,67.0011),
    ("Islamabad","PK",33.6844,73.0479), ("Dhaka","BD",23.8103,90.4125),
    ("Colombo","LK",6.9271,79.8612), ("Kathmandu","NP",27.7172,85.3240),
    ("Thimphu","BT",27.4728,89.6390), ("Male","MV",4.1755,73.5093),
    ("Kabul","AF",34.5553,69.2075),
    # Central Asia
    ("Astana","KZ",51.1605,71.4704), ("Almaty","KZ",43.2220,76.8512),
    ("Tashkent","UZ",41.2995,69.2401), ("Bishkek","KG",42.8746,74.5698),
    ("Dushanbe","TJ",38.5598,68.7870), ("Ashgabat","TM",37.9601,58.3261),
    # Middle East
    ("Tehran","IR",35.6892,51.3890), ("Baghdad","IQ",33.3152,44.3661),
    ("Damascus","SY",33.5138,36.2765), ("Beirut","LB",33.8938,35.5018),
    ("Amman","JO",31.9454,35.9284), ("Tel Aviv","IL",32.0853,34.7818),
    ("Riyadh","SA",24.7136,46.6753), ("Jeddah","SA",21.4858,39.1925),
    ("Abu Dhabi","AE",24.4539,54.3773), ("Dubai","AE",25.2048,55.2708),
    ("Doha","QA",25.2854,51.5310), ("Kuwait City","KW",29.3759,47.9774),
    ("Manama","BH",26.2285,50.5860), ("Muscat","OM",23.5880,58.3829),
    ("Sanaa","YE",15.3694,44.1910), ("Ankara","TR",39.9334,32.8597),
    ("Istanbul","TR",41.0082,28.9784),
    # Africa
    ("Cairo","EG",30.0444,31.2357), ("Tripoli","LY",32.8872,13.1913),
    ("Tunis","TN",36.8065,10.1815), ("Algiers","DZ",36.7538,3.0588),
    ("Rabat","MA",34.0209,-6.8416), ("Marrakech","MA",31.6295,-7.9811),
    ("Nouakchott","MR",18.0735,-15.9582), ("Dakar","SN",14.7167,-17.4677),
    ("Bamako","ML",12.6392,-8.0029), ("Accra","GH",5.6037,-0.1870),
    ("Abidjan","CI",5.3600,-4.0083), ("Lagos","NG",6.5244,3.3792),
    ("Abuja","NG",9.0765,7.3986), ("Niamey","NE",13.5127,2.1128),
    ("Ndjamena","TD",12.1348,15.0557), ("Khartoum","SD",15.5007,32.5599),
    ("Addis Ababa","ET",9.1450,40.4897), ("Nairobi","KE",-1.2864,36.8172),
    ("Kampala","UG",0.3476,32.5825), ("Kigali","RW",-1.9403,29.8739),
    ("Dar es Salaam","TZ",-6.7924,39.2083), ("Lusaka","ZM",-15.3875,28.3228),
    ("Harare","ZW",-17.8252,31.0335), ("Gaborone","BW",-24.6282,25.9231),
    ("Windhoek","NA",-22.5609,17.0658), ("Cape Town","ZA",-33.9249,18.4241),
    ("Johannesburg","ZA",-26.2041,28.0473), ("Maputo","MZ",-25.9692,32.5732),
    ("Antananarivo","MG",-18.8792,47.5079), ("Kinshasa","CD",-4.4419,15.2663),
    ("Brazzaville","CG",-4.2634,15.2429), ("Libreville","GA",0.4162,9.4673),
    ("Yaounde","CM",3.8480,11.5021), ("Luanda","AO",-8.8390,13.2894),
    ("Freetown","SL",8.4657,-13.2317), ("Monrovia","LR",6.3004,-10.7969),
    ("Conakry","GN",9.6412,-13.5784), ("Lome","TG",6.1319,1.2228),
    ("Cotonou","BJ",6.3703,2.3912), ("Ouagadougou","BF",12.3714,-1.5197),
    ("Mogadishu","SO",2.0469,45.3182), ("Asmara","ER",15.3229,38.9251),
    ("Djibouti City","DJ",11.8251,42.5903), ("Juba","SS",4.8517,31.5825),
    ("Bangui","CF",4.3947,18.5582), ("Malabo","GQ",3.7523,8.7742),
    ("Sao Tome","ST",0.3302,6.7333), ("Praia","CV",14.9330,-23.5133),
    ("Banjul","GM",13.4549,-16.5790), ("Bissau","GW",11.8636,-15.5977),
    ("Lilongwe","MW",-13.9626,33.7741), ("Mbabane","SZ",-26.3054,31.1367),
    ("Maseru","LS",-29.3151,27.4869), ("Port Louis","MU",-20.1609,57.5012),
    ("Victoria","SC",-4.6191,55.4513), ("Moroni","KM",-11.7022,43.2551),
    # Europe
    ("London","GB",51.5074,-0.1278), ("Paris","FR",48.8566,2.3522),
    ("Berlin","DE",52.5200,13.4050), ("Madrid","ES",40.4168,-3.7038),
    ("Rome","IT",41.9028,12.4964), ("Lisbon","PT",38.7223,-9.1393),
    ("Amsterdam","NL",52.3676,4.9041), ("Brussels","BE",50.8503,4.3517),
    ("Bern","CH",46.9480,7.4474), ("Vienna","AT",48.2082,16.3738),
    ("Warsaw","PL",52.2297,21.0122), ("Prague","CZ",50.0755,14.4378),
    ("Budapest","HU",47.4979,19.0402), ("Bucharest","RO",44.4268,26.1025),
    ("Sofia","BG",42.6977,23.3219), ("Athens","GR",37.9838,23.7275),
    ("Stockholm","SE",59.3293,18.0686), ("Oslo","NO",59.9139,10.7522),
    ("Copenhagen","DK",55.6761,12.5683), ("Helsinki","FI",60.1699,24.9384),
    ("Reykjavik","IS",64.1466,-21.9426), ("Dublin","IE",53.3498,-6.2603),
    ("Moscow","RU",55.7558,37.6173), ("Kyiv","UA",50.4501,30.5234),
    ("Minsk","BY",53.9006,27.5590), ("Chisinau","MD",47.0105,28.8638),
    ("Vilnius","LT",54.6872,25.2797), ("Riga","LV",56.9496,24.1052),
    ("Tallinn","EE",59.4370,24.7536), ("Zagreb","HR",45.8150,15.9819),
    ("Belgrade","RS",44.7866,20.4489), ("Sarajevo","BA",43.8563,18.4131),
    ("Ljubljana","SI",46.0569,14.5058), ("Bratislava","SK",48.1486,17.1077),
    ("Skopje","MK",41.9973,21.4280), ("Podgorica","ME",42.4304,19.2594),
    ("Tirana","AL",41.3275,19.8187), ("Nicosia","CY",35.1856,33.3823),
    ("Valletta","MT",35.8989,14.5146), ("Luxembourg City","LU",49.6116,6.1319),
    ("Monaco","MC",43.7384,7.4246), ("Tbilisi","GE",41.7151,44.7830),
    ("Yerevan","AM",40.1792,44.4991), ("Baku","AZ",40.4093,49.8671),
    # Americas
    ("Washington DC","US",38.9072,-77.0369), ("New York","US",40.7128,-74.0060),
    ("Los Angeles","US",34.0522,-118.2437), ("Chicago","US",41.8781,-87.6298),
    ("Miami","US",25.7617,-80.1918), ("Honolulu","US",21.3069,-157.8583),
    ("Toronto","CA",43.6532,-79.3832), ("Ottawa","CA",45.4215,-75.6972),
    ("Vancouver","CA",49.2827,-123.1207), ("Mexico City","MX",19.4326,-99.1332),
    ("Guatemala City","GT",14.6349,-90.5069), ("San Salvador","SV",13.6929,-89.2182),
    ("Tegucigalpa","HN",14.0723,-87.1921), ("Managua","NI",12.1364,-86.2514),
    ("San Jose","CR",9.9281,-84.0907), ("Panama City","PA",8.9824,-79.5199),
    ("Havana","CU",23.1136,-82.3666), ("Kingston","JM",17.9714,-76.7931),
    ("Port-au-Prince","HT",18.5944,-72.3074), ("Santo Domingo","DO",18.4861,-69.9312),
    ("Nassau","BS",25.0343,-77.3963), ("Bridgetown","BB",13.1939,-59.5432),
    ("Port of Spain","TT",10.6549,-61.5019), ("Bogota","CO",4.7110,-74.0721),
    ("Caracas","VE",10.4806,-66.9036), ("Quito","EC",-0.1807,-78.4678),
    ("Lima","PE",-12.0464,-77.0428), ("La Paz","BO",-16.4897,-68.1193),
    ("Santiago","CL",-33.4489,-70.6693), ("Buenos Aires","AR",-34.6037,-58.3816),
    ("Montevideo","UY",-34.9011,-56.1645), ("Asuncion","PY",-25.2637,-57.5759),
    ("Georgetown","GY",6.8013,-58.1551), ("Paramaribo","SR",5.8520,-55.2038),
    ("Brasilia","BR",-15.8267,-47.9218), ("Sao Paulo","BR",-23.5505,-46.6333),
    ("Rio de Janeiro","BR",-22.9068,-43.1729),
    # Oceania
    ("Canberra","AU",-35.2809,149.1300), ("Sydney","AU",-33.8688,151.2093),
    ("Melbourne","AU",-37.8136,144.9631), ("Wellington","NZ",-41.2865,174.7762),
    ("Auckland","NZ",-36.8485,174.7633), ("Suva","FJ",-18.1416,178.4419),
    ("Port Moresby","PG",-9.4438,147.1803),
]

print("city count:", len(CITIES))
assert len(set(c[0] for c in CITIES)) == len(CITIES), "duplicate city name"

def haversine(lat1, lon1, lat2, lon2):
    R = 6371.0088  # mean Earth radius, km
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi/2)**2 + math.cos(p1)*math.cos(p2)*math.sin(dlambda/2)**2
    return 2 * R * math.asin(math.sqrt(a))

DIFF_BANDS = [
    ("expert", 0.003, 0.03),
    ("hard",   0.03,  0.08),
    ("medium", 0.08,  0.20),
    ("easy",   0.20,  0.50),
]

def bucket_for(ratio):
    for name, lo, hi in DIFF_BANDS:
        if lo <= ratio < hi:
            return name
    return None

candidates = defaultdict(list)  # (origin_idx, difficulty) -> [candidate dict]

n = len(CITIES)
for oi, origin in enumerate(CITIES):
    others = [i for i in range(n) if i != oi]
    for ai, bi in itertools.combinations(others, 2):
        a, b = CITIES[ai], CITIES[bi]
        dA = haversine(origin[2], origin[3], a[2], a[3])
        dB = haversine(origin[2], origin[3], b[2], b[3])
        if dA == dB:
            continue
        lo, hi = min(dA, dB), max(dA, dB)
        ratio = (hi - lo) / lo
        diff = bucket_for(ratio)
        if diff is None:
            continue
        farther_is_a = dA > dB
        # Randomize which slot (a/b) the farther city lands in.
        if random.random() < 0.5:
            slot_a, slot_b = a, b
            distA, distB = dA, dB
        else:
            slot_a, slot_b = b, a
            distA, distB = dB, dA
        answer = "a" if distA > distB else "b"
        candidates[(oi, diff)].append({
            "origin": {"name": origin[0], "cc": origin[1]},
            "a": {"name": slot_a[0], "cc": slot_a[1], "km": round(distA)},
            "b": {"name": slot_b[0], "cc": slot_b[1], "km": round(distB)},
            "answer": answer,
            "difficulty": diff,
        })

CAP_PER_ORIGIN_DIFF = 12
final = []
for (oi, diff), items in candidates.items():
    random.shuffle(items)
    final.extend(items[:CAP_PER_ORIGIN_DIFF])

random.shuffle(final)
for i, q in enumerate(final):
    q["id"] = f"q{i:06d}"

counts = defaultdict(int)
for q in final:
    counts[q["difficulty"]] += 1

print("total questions:", len(final))
for k in ["easy","medium","hard","expert"]:
    print(f"  {k}: {counts[k]}")

with open("which_is_farther_questions.json", "w", encoding="utf-8") as f:
    json.dump(final, f, ensure_ascii=False, separators=(",", ":"))

import os
print("file size (KB):", round(os.path.getsize("which_is_farther_questions.json")/1024, 1))
