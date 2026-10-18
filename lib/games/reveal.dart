// lib/games/reveal.dart
//
// Self-contained "Reveal" mini-game engine, with two content modes:
// Guess the Country and Guess the City. Everything (data for both modes,
// scoring persistence, shared UI kit, and the mode-select + lobby + game
// screens) lives in this single file, same pattern as flag_guess.dart and
// which_is_farther.dart.
//
// The ONLY public symbol is [RevealModeScreen]; everything else is private
// to this library on purpose.
//
// DESIGN NOTES (things the spec didn't fully pin down, decided here):
//   - No difficulty tiers: the spec only described one scoring curve
//     (1000/700/400/100 by hint count), so each mode is a single flow.
//   - No per-round timer: "reveal" is a risk/reward choice (fewer hints =
//     more points), not a race against a clock like Flag Guess or Which Is
//     Farther — timing pressure would fight the core mechanic.
//   - A wrong guess does NOT end the run. It eliminates that choice and
//     (if any hints remain) auto-reveals the next one, so a round always
//     eventually resolves via elimination — there's no unwinnable dead end,
//     and no "Game Over" mid-run. A fixed-length run (20 rounds) ends in a
//     results screen instead, similar in spirit to the other games'
//     summary screen.
//   - "Combo" here means a streak of PERFECT guesses (solved on hint 1),
//     tracked the same way the other games track a correctness streak.
//   - Identity is tracked by NAME, not by the flag [code] — Guess the City
//     has several cities sharing one country (Rome/Venice/Naples/Florence
//     are all "IT"), so [code] alone can't tell entries apart. City names
//     are unique within their own pool, same as country names within
//     theirs, so name is the safe key.
//   - Guess the Country's hint 4 is that country's own flag. Guess the
//     City's hint 4 is the flag of the country the city is IN — a strong
//     clue, not a giveaway of the exact city (a country can have several
//     candidate cities), which is why the button copy differs by mode.
//   - Each mode keeps its own separate leaderboard.
//
// ADDING "Guess the Landmark" LATER:
//   Add a third _RevealMode + data pool the same way City was added below,
//   and a card for it in [RevealModeScreen]. Hint 4 doesn't have to be a
//   flag for that mode — e.g. a cropped photo — the round engine
//   (_RevealGameScreenState) doesn't care what hint 4 renders as, only that
//   _RevealEntry.flagEmoji returns *something* to show.

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:jidoapp/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// DATA
// ============================================================================

/// One guessable entry (a country, or a city): [name] is the answer text,
/// [code] is an ISO 3166-1 alpha-2 country code used only to render hint 4's
/// flag emoji (for Country mode it's the entry's own code; for City mode
/// it's the code of the country that city is in). [hints] holds exactly 3
/// authored clues, ordered vague -> specific:
///   [0] a historical/cultural fact
///   [1] a geographic fact
///   [2] a famous landmark or cultural icon
/// Hint 4 is always the flag emoji, derived from [code] — never authored.
class _RevealEntry {
  final String name;
  final String code;
  final List<String> hints; // exactly 3

  const _RevealEntry(this.name, this.code, this.hints);

  String get flagEmoji {
    final c = code.toUpperCase();
    final first = 0x1F1E6 + (c.codeUnitAt(0) - 0x41);
    final second = 0x1F1E6 + (c.codeUnitAt(1) - 0x41);
    return String.fromCharCode(first) + String.fromCharCode(second);
  }
}

const List<_RevealEntry> _kCountryEntries = [
  _RevealEntry('Hungary', 'HU', [
    "This nation's coronation regalia has been used in ceremonies for over 1,000 years.",
    "Europe's second-longest river flows right through its capital.",
    'Its neo-Gothic parliament building, one of the largest in Europe, stands beside that river.',
  ]),
  _RevealEntry('France', 'FR', [
    'A revolution here in 1789 helped reshape ideas of citizenship across Europe.',
    "It's bordered by the Pyrenees to the south and the Alps to the east.",
    'A 330-meter iron tower built for a World\'s Fair became its most famous landmark.',
  ]),
  _RevealEntry('Egypt', 'EG', [
    'Ancient pyramids built here over 4,500 years ago still stand today.',
    'The world\'s longest river flows north through this country into the Mediterranean.',
    'A great stone sphinx guards a plateau just outside its capital.',
  ]),
  _RevealEntry('Japan', 'JP', [
    "This nation's monarchy is considered the world's oldest continuous hereditary line.",
    "It's made up of over 6,800 islands along the Pacific Ring of Fire.",
    'A snow-capped, symmetrical volcano near its capital is a national icon.',
  ]),
  _RevealEntry('Peru', 'PE', [
    'This land was once the heart of the largest empire in pre-Columbian America.',
    'The world\'s longest mountain range runs through it, and the Amazon River begins here.',
    'A lost mountaintop citadel built by the Inca sits above a cloud forest.',
  ]),
  _RevealEntry('Italy', 'IT', [
    'An ancient empire based here once ruled most of Europe and the Mediterranean.',
    "It's a boot-shaped peninsula surrounded by four different seas.",
    'A leaning bell tower and an ancient amphitheater are among its most photographed sites.',
  ]),
  _RevealEntry('India', 'IN', [
    "This country's independence movement was led largely through nonviolent resistance.",
    'The world\'s highest mountain range forms much of its northern border.',
    'A white marble mausoleum was built here by an emperor for his late wife.',
  ]),
  _RevealEntry('Australia', 'AU', [
    'European settlers first used this land as a penal colony in the late 1700s.',
    "It's the only country that is also an entire continent.",
    'A white, sail-shaped performing arts building sits on the harbor of its largest city.',
  ]),
  _RevealEntry('Mexico', 'MX', [
    'An empire here built its capital on an island in a lake before Europeans arrived.',
    'It sits between two oceans and is crossed by the Tropic of Cancer.',
    'Ancient step-pyramids built by the Maya still rise from jungle in its south.',
  ]),
  _RevealEntry('Greece', 'GR', [
    'Democracy as a system of government is credited to city-states that once ruled here.',
    'It has thousands of islands scattered across the Aegean and Ionian seas.',
    'A marble temple dedicated to a goddess still crowns a hill above its capital.',
  ]),
  _RevealEntry('Brazil', 'BR', [
    "It's the only country in South America where Portuguese, not Spanish, is spoken.",
    "The world's largest rainforest covers most of its northern territory.",
    'A giant statue of a robed figure overlooks its most famous city from a mountaintop.',
  ]),
  _RevealEntry('China', 'CN', [
    "One of the world's longest structures was built here over centuries to guard its frontier.",
    'It shares land borders with more countries than almost any other nation on Earth.',
    "Thousands of life-sized clay soldiers were buried here to guard an emperor's tomb.",
  ]),
  _RevealEntry('Turkey', 'TR', [
    'This nation straddles two continents, split by a narrow strait running through its largest city.',
    "It's bordered by the Black Sea to the north and the Mediterranean to the south.",
    'A former cathedral-turned-mosque with a massive dome has stood there for over 1,400 years.',
  ]),
  _RevealEntry('Russia', 'RU', [
    'This is the largest country in the world by land area, spanning eleven time zones.',
    'It stretches across two continents, separated by the Ural Mountains.',
    'A colorful, onion-domed cathedral stands on a famous square in its capital.',
  ]),
  _RevealEntry('United Kingdom', 'GB', [
    "This nation's parliamentary system has influenced democracies around the world.",
    "It's made up of islands just off the northwest coast of mainland Europe.",
    'A clock tower nicknamed after its bell overlooks a river in its capital.',
  ]),
  _RevealEntry('Spain', 'ES', [
    'Explorers who set sail from here in 1492 reached the Americas for the first time.',
    'It shares the Iberian Peninsula with just one other country.',
    "An unfinished basilica designed by a famous architect has been under construction for over a century.",
  ]),
  _RevealEntry('Germany', 'DE', [
    "A wall once divided this country's capital for nearly three decades during the Cold War.",
    'It\'s crossed by the Rhine and Danube rivers and borders nine other countries.',
    'A fairytale-like castle in its south inspired a famous animation studio\'s logo.',
  ]),
  _RevealEntry('Canada', 'CA', [
    'It was formed by the confederation of British colonies in 1867.',
    'It has the longest coastline of any country in the world.',
    'A massive waterfall on its border with the US draws millions of visitors each year.',
  ]),
  _RevealEntry('South Korea', 'KR', [
    "This nation rebuilt itself into a global economic power after a war split its peninsula in the 1950s.",
    'It occupies the southern half of a peninsula bordered by two seas.',
    'A modern tower with a rotating restaurant overlooks its sprawling capital.',
  ]),
  _RevealEntry('Thailand', 'TH', [
    'This is the only country in Southeast Asia never colonized by a European power.',
    "It's shaped like an elephant's head on the map, bordering five other nations.",
    'Golden-spired temples and ornate royal palaces line the river through its capital.',
  ]),
  _RevealEntry('Kenya', 'KE', [
    'Fossils found here have made it central to the study of early human evolution.',
    'The Great Rift Valley cuts through it, and the equator crosses its territory.',
    "Vast herds of wildebeest cross its plains each year in one of nature's biggest migrations.",
  ]),
  _RevealEntry('Morocco', 'MA', [
    "This kingdom's old walled cities are known for their maze-like markets.",
    'It sits where the Atlantic Ocean meets the Mediterranean Sea, just south of Europe.',
    "A red-walled imperial city at the edge of the Sahara is famous for its old livestock market square.",
  ]),
  _RevealEntry('South Africa', 'ZA', [
    'A former political prisoner here became its first president elected in a fully democratic vote.',
    'Two oceans meet off its southern coastline.',
    'A flat-topped mountain overlooks its most visited city from above.',
  ]),
  _RevealEntry('Norway', 'NO', [
    'Seafaring raiders from here explored and settled parts of Europe over a thousand years ago.',
    'Deep, steep-sided inlets carved by glaciers cut into its western coastline.',
    "The sun doesn't set for weeks each summer above the Arctic Circle here.",
  ]),
  _RevealEntry('Netherlands', 'NL', [
    "Much of this country's land was reclaimed from the sea using an extensive system of dikes.",
    "It's famously flat, with roughly a quarter of its land below sea level.",
    'Windmills and tulip fields color its countryside every spring.',
  ]),
  _RevealEntry('Switzerland', 'CH', [
    'This country has stayed officially neutral through both World Wars.',
    "The Alps cover most of its territory, and it borders five countries without any coastline.",
    'A precise, world-famous style of timekeeping originated in its watchmaking towns.',
  ]),
  _RevealEntry('Sweden', 'SE', [
    'Flat-pack furniture from a company founded here is now sold worldwide.',
    'It\'s the largest country in Scandinavia, with thousands of islands off its coast.',
    'An annual prize for peace, science, and literature is awarded in its capital each December.',
  ]),
  _RevealEntry('Portugal', 'PT', [
    'Sailors from here launched an age of exploration that reached India and Brazil by sea.',
    'It occupies the western edge of the Iberian Peninsula, facing the Atlantic.',
    "A red bridge resembling San Francisco's famous one spans the river through its capital.",
  ]),
  _RevealEntry('Poland', 'PL', [
    "This nation's borders have shifted dramatically after being partitioned and redrawn in history.",
    "It's a flat plain bordered by the Baltic Sea to the north.",
    'A rebuilt medieval old town with a colorful market square sits at the heart of its capital.',
  ]),
  _RevealEntry('Austria', 'AT', [
    'A famous composer born here began performing for European royalty as a child prodigy.',
    'The eastern Alps cover much of this landlocked country.',
    "An ornate palace with hundreds of rooms once housed a sprawling European empire's rulers.",
  ]),
  _RevealEntry('Czech Republic', 'CZ', [
    'This nation split peacefully from its neighbor in 1993, without a single shot fired.',
    'It\'s landlocked in Central Europe, crossed by the Vltava river.',
    "An astronomical clock on its capital's old town hall has told time since the 1400s.",
  ]),
  _RevealEntry('Ireland', 'IE', [
    'Millions emigrated from this island nation during a devastating famine in the 1840s.',
    'It shares its island with a separate United Kingdom territory to the northeast.',
    'Dramatic sea cliffs rise from the Atlantic along its rugged west coast.',
  ]),
  _RevealEntry('Iceland', 'IS', [
    'This nation has no standing army and is powered almost entirely by renewable energy.',
    'It sits directly on the boundary between two tectonic plates in the North Atlantic.',
    'Geysers, hot springs, and the Northern Lights draw visitors to its volcanic landscape.',
  ]),
  _RevealEntry('Vietnam', 'VN', [
    'This nation was divided in two for two decades before reunifying in 1975.',
    'It has a long, S-shaped coastline along the South China Sea.',
    'Thousands of limestone islands rise from an emerald bay in its north.',
  ]),
  _RevealEntry('Indonesia', 'ID', [
    'This is the largest archipelago nation in the world, spanning over 17,000 islands.',
    'It straddles the equator between the Indian and Pacific Oceans.',
    'A massive ancient Buddhist temple complex, one of the world\'s largest, sits on one of its islands.',
  ]),
  _RevealEntry('Philippines', 'PH', [
    'This nation was named after a 16th-century Spanish king.',
    "It's an archipelago of over 7,000 islands in Southeast Asia.",
    "Centuries-old rice terraces carved into mountainsides are called a 'stairway to heaven' by locals.",
  ]),
  _RevealEntry('Argentina', 'AR', [
    "The tango dance originated in the working-class neighborhoods of this country's capital.",
    'It stretches from subtropical jungle in the north to glaciers in the south.',
    'A wide boulevard and an obelisk mark the heart of its capital city.',
  ]),
  _RevealEntry('Chile', 'CL', [
    'This is one of the longest, narrowest countries in the world, stretching along a coastline.',
    "It's squeezed between the Andes mountains and the Pacific Ocean.",
    'Giant stone statues carved by an isolated island civilization belong to its remote Pacific territory.',
  ]),
  _RevealEntry('Colombia', 'CO', [
    'This country is named after a famous explorer, though he never actually set foot here.',
    "It's the only South American country with coastlines on both the Pacific and Caribbean.",
    'A walled colonial port city on its Caribbean coast is known for its colorful balconies.',
  ]),
  _RevealEntry('Cuba', 'CU', [
    'A revolution here in 1959 led to decades of a communist government just off the US coast.',
    'It\'s the largest island in the Caribbean Sea.',
    'Vintage American cars from the 1950s still cruise the streets of its capital.',
  ]),
  _RevealEntry('Israel', 'IL', [
    'This nation was established in 1948 and considers itself a homeland for the Jewish people.',
    'It borders the Mediterranean Sea at the edge of the Middle East and Africa.',
    'A city considered holy by three major world religions lies at its heart.',
  ]),
  _RevealEntry('Saudi Arabia', 'SA', [
    'This kingdom is home to the two holiest cities in Islam.',
    'It covers most of the Arabian Peninsula and is largely desert.',
    'Millions of pilgrims travel here each year for an annual religious pilgrimage.',
  ]),
  _RevealEntry('United Arab Emirates', 'AE', [
    'This nation was formed in 1971 from a federation of seven small sheikhdoms.',
    'It sits on the Persian Gulf at the edge of the Arabian desert.',
    "The world's tallest building rises from the skyline of one of its cities.",
  ]),
  _RevealEntry('Iran', 'IR', [
    'This nation was known by another name, Persia, until the 1930s.',
    'Deserts and the Zagros mountains cover much of this Middle Eastern country.',
    'Ornate blue-tiled mosques and grand squares fill its ancient former capitals.',
  ]),
  _RevealEntry('New Zealand', 'NZ', [
    'This nation was one of the last major landmasses on Earth settled by humans, only about 700 years ago.',
    "It's made up of two main islands in the South Pacific, far from any other country.",
    'A film trilogy about a fictional ring was shot among its dramatic, otherworldly landscapes.',
  ]),
  _RevealEntry('Nigeria', 'NG', [
    'This is the most populous country in Africa.',
    'The river that gives the country its name flows through it into the Gulf of Guinea.',
    'A booming film industry here is nicknamed after a famous American one.',
  ]),
  _RevealEntry('Ethiopia', 'ET', [
    'This is one of the only African nations never colonized by a European power.',
    "It's a mountainous, landlocked country in the Horn of Africa.",
    'Churches carved directly out of solid rock, centuries ago, still stand in its north.',
  ]),
  _RevealEntry('Ghana', 'GH', [
    'This was the first sub-Saharan African nation to gain independence from colonial rule, in 1957.',
    'It sits on the Gulf of Guinea in West Africa.',
    'Centuries-old coastal forts here were once used in the transatlantic slave trade.',
  ]),
  _RevealEntry('Tanzania', 'TZ', [
    'This country formed in 1964 from the union of a mainland territory and an island.',
    "Africa's tallest peak rises within its borders, and a vast plain stretches across its north.",
    'A collapsed volcanic crater here shelters one of the densest concentrations of wildlife on Earth.',
  ]),
  _RevealEntry('Finland', 'FI', [
    'This nation is often ranked the happiest country in the world.',
    'It has thousands of lakes and shares a long border with Russia to the east.',
    'The Northern Lights dance over its Arctic region each winter.',
  ]),
  _RevealEntry('Denmark', 'DK', [
    'A famous children\'s storyteller from here wrote tales like The Little Mermaid.',
    'It\'s a small peninsula and set of islands between the North and Baltic Seas.',
    "A bronze statue of a mermaid sits on a rock in its capital's harbor.",
  ]),
  _RevealEntry('Belgium', 'BE', [
    "This country is headquarters to the European Union's main institutions.",
    'It\'s a small, low-lying nation wedged between France, Germany, and the Netherlands.',
    "A small bronze statue of a urinating boy has become an odd symbol of its capital.",
  ]),
  _RevealEntry('Croatia', 'HR', [
    'This nation\'s coastline was once part of the Roman Empire and later the Venetian Republic.',
    'Over a thousand islands line its Adriatic Sea coastline.',
    'A red-roofed walled old town, used as a filming location for a famous TV series, sits by the sea.',
  ]),
  _RevealEntry('Ukraine', 'UA', [
    "This nation's fertile black soil once made it known as the 'breadbasket' of Europe.",
    'It\'s the largest country entirely within Europe, bordering Russia to the east.',
    'A golden-domed cathedral has stood in its capital since the 11th century.',
  ]),
  _RevealEntry('Romania', 'RO', [
    'Legends of a blood-drinking count are loosely tied to a real medieval prince who ruled here.',
    'The Carpathian mountains form an arc through the middle of this country.',
    'A fortress associated with that vampire legend perches on a hilltop in its Transylvania region.',
  ]),
  _RevealEntry('Georgia', 'GE', [
    'This nation claims to be one of the first to adopt Christianity as a state religion, in the 4th century.',
    'It sits where Europe meets Asia, between the Black and Caspian Seas.',
    'Ancient stone watchtowers cluster in mountain villages in its remote highlands.',
  ]),
  _RevealEntry('Jordan', 'JO', [
    'This kingdom has remained a stable monarchy in a historically turbulent region.',
    'One of the saltiest bodies of water on Earth sits on its western border.',
    'An ancient city carved into rose-colored rock was hidden from the Western world until 1812.',
  ]),
  _RevealEntry('Lebanon', 'LB', [
    "This small nation's capital was once nicknamed the 'Paris of the Middle East.'",
    'It\'s a narrow, mountainous country on the eastern Mediterranean coast.',
    'Ancient cedar trees, once used to build Phoenician ships, still grow in its mountains.',
  ]),
  _RevealEntry('Sri Lanka', 'LK', [
    'This island nation was known as Ceylon until 1972.',
    "It sits in the Indian Ocean just off the southern tip of India, shaped like a teardrop.",
    'Ancient royal cities and a rock fortress painted with frescoes lie in its cultural heartland.',
  ]),
  _RevealEntry('Nepal', 'NP', [
    'This is the only country in the world with a non-rectangular national flag.',
    'It\'s a landlocked nation squeezed between two giants, with the Himalayas along its north.',
    "The world's tallest mountain sits on its border, drawing climbers from around the globe.",
  ]),
  _RevealEntry('Mongolia', 'MN', [
    'This nation was once the seat of the largest contiguous land empire in history.',
    'It\'s a landlocked country of vast steppe, wedged between two much larger neighbors.',
    'Nomadic herders still live in round felt tents scattered across its grasslands.',
  ]),
  _RevealEntry('Cambodia', 'KH', [
    'A powerful empire here built the largest religious monument complex on Earth.',
    'A major Southeast Asian river flows through this country.',
    'The towers of that ancient temple complex are so iconic they appear on its national flag.',
  ]),
  _RevealEntry('Myanmar', 'MM', [
    'This country was known as Burma until a military government renamed it in 1989.',
    'It\'s the largest country in mainland Southeast Asia, bordering both India and China.',
    'Thousands of ancient Buddhist temples and pagodas dot a plain in its center.',
  ]),
  _RevealEntry('Bolivia', 'BO', [
    'This is one of only two landlocked countries in South America.',
    "The world's largest salt flat stretches across its high Andean plateau.",
    "That mirror-like expanse of salt reflects the sky so perfectly it's called nature's largest mirror.",
  ]),
  _RevealEntry('Uruguay', 'UY', [
    'This is one of the smallest countries in South America, known for progressive social policies.',
    'It sits on the Atlantic coast between two much larger neighbors.',
    'A giant sculpture of a hand rises from the sand on one of its beaches.',
  ]),
  _RevealEntry('Panama', 'PA', [
    'A famous canal here connects two oceans, cutting weeks off ocean voyages.',
    'This narrow country forms the land bridge between North and South America.',
    'Massive ships still queue to pass through a set of locks that opened in 1914.',
  ]),
  _RevealEntry('Costa Rica', 'CR', [
    'This country abolished its military entirely in 1948.',
    'It\'s a Central American nation with coastlines on both the Pacific and Caribbean.',
    'Cloud forests here are home to the resplendent quetzal, a strikingly colorful bird.',
  ]),
  _RevealEntry('Qatar', 'QA', [
    'This tiny peninsula nation became one of the richest countries in the world through natural gas.',
    'It juts out into the Persian Gulf from the Arabian Peninsula.',
    'A futuristic skyline was built almost overnight ahead of hosting a World Cup.',
  ]),
  _RevealEntry('Singapore', 'SG', [
    'This nation transformed from a small port town into a global financial hub in just a few decades.',
    "It's a small island city-state at the tip of the Malay Peninsula.",
    'Giant tree-like structures covered in solar panels light up after dark in its famous gardens.',
  ]),
  _RevealEntry('Malaysia', 'MY', [
    'This nation is split between a peninsula and a portion of an island shared with two other countries.',
    "It straddles the South China Sea, part on the mainland and part on Borneo.",
    'Twin towers once the tallest buildings in the world rise from its capital\'s skyline.',
  ]),
];

// ── Guess the City ──────────────────────────────────────────────────────────
const List<_RevealEntry> _kCityEntries = [
  _RevealEntry('Budapest', 'HU', [
    'This city once served as the co-capital of a sprawling European empire.',
    'Europe\'s second-longest river splits this city into hilly and flat halves.',
    'Its neo-Gothic parliament building, one of the largest in Europe, sits right on the riverbank.',
  ]),
  _RevealEntry('Paris', 'FR', [
    'This city was the epicenter of a revolution that began in 1789.',
    'A river winds through its heart, lined with world-famous art museums.',
    'A 330-meter iron tower built for a World\'s Fair overlooks its skyline.',
  ]),
  _RevealEntry('Rome', 'IT', [
    'This city was the capital of an empire that once ruled most of the Western world.',
    'It\'s built across seven hills beside a river in central Italy.',
    'A massive ancient amphitheater here once hosted gladiator battles.',
  ]),
  _RevealEntry('Cairo', 'EG', [
    'This city has stood near some of the oldest wonders of the ancient world.',
    'It sits on the banks of the world\'s longest river, near its delta.',
    'Massive stone pyramids and a great stone sphinx lie just outside the city.',
  ]),
  _RevealEntry('Istanbul', 'TR', [
    'This city has been the capital of three different empires throughout history.',
    'It\'s the only city in the world that sits on two continents, split by a strait.',
    'A domed former cathedral-turned-mosque has towered over its skyline for 1,400 years.',
  ]),
  _RevealEntry('Kyoto', 'JP', [
    'For over a thousand years, this city was the imperial capital before power moved elsewhere.',
    'It sits in a valley surrounded by mountains on three sides.',
    'Thousands of vermillion gates wind up a hillside shrine here.',
  ]),
  _RevealEntry('Athens', 'GR', [
    'This city is considered the birthplace of Western democracy.',
    'It sits on a plain surrounded by mountains, near the Aegean coast.',
    'A marble temple to a goddess crowns a rocky hill above the city.',
  ]),
  _RevealEntry('Marrakech', 'MA', [
    'Founded over 900 years ago, this city was once the capital of a powerful Berber empire.',
    'It sits at the foot of a mountain range, on the edge of the desert.',
    'Its old walled quarter is famous for a bustling square filled with food stalls at night.',
  ]),
  _RevealEntry('Venice', 'IT', [
    'For centuries, this city-state was one of the wealthiest trading powers in the Mediterranean.',
    'It\'s built across more than 100 small islands in a lagoon.',
    'Boats ferry visitors along its canals instead of cars, since none exist here.',
  ]),
  _RevealEntry('Amsterdam', 'NL', [
    'This city grew wealthy during a 17th-century \'Golden Age\' of global trade.',
    'It\'s built below sea level, laced with concentric rings of canals.',
    'Narrow, gabled townhouses line its canal rings, many leaning slightly with age.',
  ]),
  _RevealEntry('Berlin', 'DE', [
    'A wall once split this city in two for nearly three decades during the Cold War.',
    'It sits on a river in the flat northeastern plains of its country.',
    'A neoclassical gate, once stranded in no-man\'s land by that wall, is now a symbol of reunification.',
  ]),
  _RevealEntry('Prague', 'CZ', [
    'Legend says a clockmaker was blinded here so he could never recreate his masterpiece.',
    'A river winds beneath a centuries-old stone bridge lined with statues here.',
    'An astronomical clock on its old town hall has told time since the 1400s.',
  ]),
  _RevealEntry('Vienna', 'AT', [
    'A young musical prodigy performed for European royalty here as a child in the 1760s.',
    'It sits on the Danube at the edge of the Alps.',
    'A palace with over 1,400 rooms once housed the rulers of a sprawling empire here.',
  ]),
  _RevealEntry('Moscow', 'RU', [
    'This city was rebuilt as a capital after a devastating fire during a 19th-century invasion.',
    'It sits on a river in the middle of a vast plain.',
    'A colorful, onion-domed cathedral stands on its famous Red Square.',
  ]),
  _RevealEntry('Beijing', 'CN', [
    'This city has served as the seat of power for dynasties and governments for over 800 years.',
    'It sits on a plain near mountains that once marked its empire\'s northern frontier.',
    'A vast palace complex, once forbidden to commoners, sits at its very center.',
  ]),
  _RevealEntry('Bangkok', 'TH', [
    'This city became a royal capital in 1782 after the fall of a previous capital upriver.',
    'It\'s built on a delta, laced with canals branching off a major river.',
    'Golden-spired temples and a royal palace sit along the riverbank here.',
  ]),
  _RevealEntry('Delhi', 'IN', [
    'This city was designed and built as a new imperial capital in the early 20th century.',
    'It sits on the plains near the banks of a sacred river\'s tributary.',
    'A towering sandstone minaret, one of the tallest brick minarets in the world, rises from its old quarter.',
  ]),
  _RevealEntry('Jerusalem', 'IL', [
    'This city is considered holy by three major world religions.',
    'It sits on a plateau in the hill country, between a sea and a desert.',
    'A golden-domed shrine sits atop a hill sacred to Jews, Christians, and Muslims alike.',
  ]),
  _RevealEntry('Havana', 'CU', [
    'A 1959 revolution here brought decades of communist rule to this Caribbean island.',
    'It sits on a natural harbor on the island\'s northern coast.',
    'Vintage American cars from the 1950s still cruise its colorful streets.',
  ]),
  _RevealEntry('Rio de Janeiro', 'BR', [
    'This city served as the capital of a South American nation for nearly two centuries.',
    'It sits between granite mountains and the sea, wrapped around a famous bay.',
    'A giant statue of a robed figure watches over the city from a mountaintop.',
  ]),
  _RevealEntry('Buenos Aires', 'AR', [
    'The tango dance was born in this city\'s working-class immigrant neighborhoods.',
    'It sits on the banks of one of the widest estuaries in the world.',
    'A towering white obelisk marks the center of its widest avenue.',
  ]),
  _RevealEntry('Cusco', 'PE', [
    'This city was once the capital of the largest empire in pre-Columbian America.',
    'It sits high in the Andes, over 3,400 meters above sea level.',
    'Massive, precisely-cut stone walls built without mortar still form the base of many buildings.',
  ]),
  _RevealEntry('Mexico City', 'MX', [
    'This city was built atop the ruins of an Aztec capital that once stood on an island in a lake.',
    'It sits in a high mountain valley, ringed by volcanoes.',
    'The remains of a great Aztec temple were rediscovered beneath its historic center in the 1970s.',
  ]),
  _RevealEntry('New York City', 'US', [
    'This city was briefly the first capital of its country after independence.',
    'It\'s built around one of the world\'s largest natural harbors, split across several islands.',
    'A green statue holding a torch has welcomed arriving ships to its harbor since 1886.',
  ]),
  _RevealEntry('London', 'GB', [
    'This city\'s parliament grew out of a medieval great council that slowly gained power from the monarchy.',
    'It straddles a river that once marked the edge of a Roman settlement here.',
    'A famous clock tower nicknamed after its bell overlooks the river here.',
  ]),
  _RevealEntry('Dublin', 'IE', [
    'This city\'s Georgian architecture boomed in the 18th century under British rule.',
    'It sits at the mouth of a river flowing into the Irish Sea.',
    'One of the world\'s oldest breweries has operated at the edge of the city since 1759.',
  ]),
  _RevealEntry('Edinburgh', 'GB', [
    'This city\'s medieval old town grew up along the path leading to a hilltop castle.',
    'It\'s built across extinct volcanic hills near the Scottish coast.',
    'A castle perched on a rocky crag has dominated its skyline for centuries.',
  ]),
  _RevealEntry('Barcelona', 'ES', [
    'This city hosted the Summer Olympics in 1992, transforming its waterfront.',
    'It sits on the Mediterranean coast, backed by a mountain range.',
    'An unfinished basilica designed by a visionary architect has been under construction here since 1882.',
  ]),
  _RevealEntry('Lisbon', 'PT', [
    'A massive earthquake and tsunami devastated this city on a holiday morning in 1755.',
    'It\'s built across seven hills along a wide river estuary near the Atlantic.',
    'A red suspension bridge resembling San Francisco\'s famous one spans the water here.',
  ]),
  _RevealEntry('Reykjavik', 'IS', [
    'Norse settlers are said to have founded this city over 1,100 years ago.',
    'It sits on a volcanic island just south of the Arctic Circle.',
    'Geothermal heat warms nearly every building in this city, drawn from beneath the earth.',
  ]),
  _RevealEntry('Stockholm', 'SE', [
    'This city grew around a fortress built to guard a waterway into a lake in the 13th century.',
    'It\'s spread across 14 islands connected by more than 50 bridges.',
    'A warship that sank on its maiden voyage in 1628 was recovered centuries later and now sits in its own museum.',
  ]),
  _RevealEntry('Helsinki', 'FI', [
    'This city was moved to its current location by royal decree in the 16th century.',
    'It sits on a peninsula jutting into an archipelago on the Baltic Sea.',
    'A striking church, blasted directly into solid granite, sits in one of its neighborhoods.',
  ]),
  _RevealEntry('Warsaw', 'PL', [
    'This city was almost entirely leveled in World War II and rebuilt from old paintings and photographs.',
    'It sits on a river roughly in the center of its country.',
    'Its meticulously reconstructed old town square looks much as it did centuries ago.',
  ]),
  _RevealEntry('Krakow', 'PL', [
    'This city served as its country\'s royal capital for over 500 years.',
    'It sits on a river in the country\'s south, near a mountain range.',
    'A dragon legend is tied to a cave beneath the hill where its royal castle stands.',
  ]),
  _RevealEntry('Seville', 'ES', [
    'A famous explorer\'s remains are said to be interred in this city\'s massive cathedral.',
    'It sits on a navigable river in the south of its country.',
    'A giant wooden structure resembling waffles or mushrooms now shades a plaza in its old quarter.',
  ]),
  _RevealEntry('Naples', 'IT', [
    'This city has lived for centuries in the shadow of one of the few active volcanoes on mainland Europe.',
    'It sits on a bay in the south of its country, facing the Tyrrhenian Sea.',
    'The ruins of a Roman town buried by that volcano\'s eruption in 79 AD lie just outside the city.',
  ]),
  _RevealEntry('Florence', 'IT', [
    'This city was the beating heart of a cultural rebirth that reshaped European art in the 14th-16th centuries.',
    'It sits on a river in the hills of central Italy.',
    'A massive red-tiled dome, an engineering marvel when completed in 1436, crowns its cathedral.',
  ]),
  _RevealEntry('Cape Town', 'ZA', [
    'This city was founded in 1652 as a supply station for ships rounding the tip of Africa.',
    'Two oceans meet just off its coastline.',
    'A flat-topped mountain looms directly over the city center.',
  ]),
  _RevealEntry('Nairobi', 'KE', [
    'This city grew from a small rail depot into East Africa\'s largest metropolis in just over a century.',
    'It sits on a plateau near the edge of the Great Rift Valley.',
    'A national park sits right at its edge, where lions and giraffes roam within sight of skyscrapers.',
  ]),
  _RevealEntry('Timbuktu', 'ML', [
    'This city was once a legendary center of Islamic scholarship, said to be paved with gold in medieval tales.',
    'It sits at the edge of the Sahara, near a bend in a great West African river.',
    'Centuries-old mud-brick mosques, rebuilt by hand each year, still stand here.',
  ]),
  _RevealEntry('Stone Town', 'TZ', [
    'This old quarter was once the center of a major spice and slave trade in East Africa.',
    'It sits on an island just off the East African coast, in the Indian Ocean.',
    'Elaborately carved wooden doors decorate the old stone buildings of its historic quarter.',
  ]),
  _RevealEntry('Hanoi', 'VN', [
    'This city has served as its country\'s capital, on and off, for over a thousand years.',
    'It sits beside a major river in the country\'s north.',
    'A scenic lake with a small pagoda-topped island sits at the heart of its old quarter.',
  ]),
  _RevealEntry('Hong Kong', 'CN', [
    'This city grew from a small fishing settlement into a global financial hub under 150 years of colonial rule.',
    'It\'s built on a hilly island and a peninsula facing a deep natural harbor.',
    'A dramatic skyline of skyscrapers lights up in a nightly show over its harbor.',
  ]),
  _RevealEntry('Singapore', 'SG', [
    'This city transformed from a small port town into a global financial hub in just a few decades after independence.',
    'It sits at the southern tip of a peninsula, just north of the equator.',
    'Giant tree-like structures covered in solar panels light up after dark in its famous gardens.',
  ]),
  _RevealEntry('Dubai', 'AE', [
    'This city transformed from a small pearling and fishing town into a global hub in just a few decades.',
    'It sits on the Persian Gulf coast, surrounded by desert.',
    'The world\'s tallest building rises from its skyline.',
  ]),
  _RevealEntry('Kathmandu', 'NP', [
    'This city\'s valley was once home to three rival medieval kingdoms, each leaving behind its own royal square.',
    'It lies in a bowl-shaped valley in the foothills of the Himalayas.',
    'A stupa with painted eyes watching in all four directions crowns a hill on its western edge.',
  ]),
  _RevealEntry('Ulaanbaatar', 'MN', [
    'This city began as a nomadic Buddhist monastic center that relocated dozens of times before settling permanently.',
    'It\'s one of the coldest capital cities in the world, sitting on a high steppe plateau.',
    'Round felt tents still cluster in neighborhoods on the edges of this otherwise modern skyline.',
  ]),
  _RevealEntry('Sydney', 'AU', [
    'This city grew from a penal colony established by British ships in 1788.',
    'It\'s built around one of the world\'s largest natural harbors.',
    'A white, sail-shaped performing arts building sits right on that harbor\'s edge.',
  ]),
];

// ============================================================================
// MODE DESCRIPTORS
// ============================================================================

/// Bundles everything a lobby/game screen needs for one content mode, so the
/// engine below is written once and reused for both Country and City.
class _RevealMode {
  final String title;
  final String heroSubtitle;
  final String finalHintLabel;
  final String storageKey;
  final List<_RevealEntry> pool;

  const _RevealMode({
    required this.title,
    required this.heroSubtitle,
    required this.finalHintLabel,
    required this.storageKey,
    required this.pool,
  });
}

const _RevealMode _kCountryMode = _RevealMode(
  title: 'Guess the Country',
  heroSubtitle: 'Fewer hints, more points. 1000 → 700 → 400 → 100.',
  finalHintLabel: 'Reveal the flag',
  storageKey: 'reveal_country_scores',
  pool: _kCountryEntries,
);

const _RevealMode _kCityMode = _RevealMode(
  title: 'Guess the City',
  heroSubtitle: 'Fewer hints, more points. 1000 → 700 → 400 → 100.',
  finalHintLabel: "Reveal the country's flag",
  storageKey: 'reveal_city_scores',
  pool: _kCityEntries,
);

// ============================================================================
// SCORE PERSISTENCE
// ============================================================================

class _RevealScoreRecord {
  final int score;
  final int roundsCompleted;
  final int maxRounds;
  final int bestCombo; // best perfect-guess (hint-1) streak
  final DateTime playedAt;

  const _RevealScoreRecord({
    required this.score,
    required this.roundsCompleted,
    required this.maxRounds,
    required this.bestCombo,
    required this.playedAt,
  });

  Map<String, dynamic> toJson() => {
    'score': score,
    'roundsCompleted': roundsCompleted,
    'maxRounds': maxRounds,
    'bestCombo': bestCombo,
    'playedAt': playedAt.toIso8601String(),
  };

  factory _RevealScoreRecord.fromJson(Map<String, dynamic> json) => _RevealScoreRecord(
    score: json['score'] as int,
    roundsCompleted: json['roundsCompleted'] as int,
    maxRounds: json['maxRounds'] as int,
    bestCombo: json['bestCombo'] as int,
    playedAt: DateTime.tryParse(json['playedAt'] as String? ?? '') ?? DateTime.now(),
  );
}

class _RevealScoreService {
  static const int maxStoredRecords = 20;

  /// [storageKey] comes from the active [_RevealMode] so Country and City
  /// keep separate leaderboards.
  Future<List<_RevealScoreRecord>> loadRecords(String storageKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      final records =
      decoded.map((e) => _RevealScoreRecord.fromJson(e as Map<String, dynamic>)).toList();
      records.sort((a, b) => b.score.compareTo(a.score));
      return records;
    } catch (_) {
      return [];
    }
  }

  Future<void> addRecord(String storageKey, _RevealScoreRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadRecords(storageKey);
    final updated = [...existing, record]..sort((a, b) => b.score.compareTo(a.score));
    final trimmed = updated.take(maxStoredRecords).toList();
    await prefs.setString(storageKey, jsonEncode(trimmed.map((r) => r.toJson()).toList()));
  }
}

// ============================================================================
// SHARED UI KIT
// ============================================================================

const Color _kInk = Color(0xFF1A1B23);
const Color _kMuted = Color(0xFF8E8E9B);
const Color _kFaint = Color(0xFFC7C7D1);
const Color _kSurface = Color(0xFFFAFAFC);
const Color _kAccent = Color(0xFFE8A33D); // warm "spotlight" gold, distinct from the other games

class _SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? borderColor;

  const _SoftCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 22,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: borderColor != null ? Border.all(color: borderColor!, width: 1.4) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: child,
    );
  }
}

class _GradientButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final VoidCallback onPressed;
  final bool outlined;

  const _GradientButton({
    required this.label,
    required this.color,
    required this.onPressed,
    this.icon,
    this.outlined = false,
  });

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final fg = widget.outlined ? widget.color : Colors.white;
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) => setState(() => _scale = 1),
      onTapCancel: () => setState(() => _scale = 1),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 17),
          decoration: BoxDecoration(
            gradient: widget.outlined
                ? null
                : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [widget.color, Color.lerp(widget.color, Colors.black, 0.18)!],
            ),
            color: widget.outlined ? Colors.white : null,
            border: widget.outlined ? Border.all(color: widget.color.withOpacity(0.35), width: 1.4) : null,
            borderRadius: BorderRadius.circular(18),
            boxShadow: widget.outlined
                ? null
                : [
              BoxShadow(
                  color: widget.color.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: fg, size: 20),
                const SizedBox(width: 8),
              ],
              Text(tr(widget.label),
                  style: TextStyle(color: fg, fontSize: 15.5, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScreenBackground extends StatelessWidget {
  final Widget child;

  const _ScreenBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x1FE8A33D), _kSurface],
          stops: [0.0, 0.4],
        ),
      ),
      child: child,
    );
  }
}

// ============================================================================
// MODE SELECT SCREEN (entry point — the only public symbol in this file)
// ============================================================================

/// Pick Country or City, then go straight to that mode's lobby.
class RevealModeScreen extends StatelessWidget {
  const RevealModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Scaffold(
      backgroundColor: _kSurface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title:  Text(tr('Reveal'),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _kInk)),
        iconTheme: const IconThemeData(color: _kInk),
      ),
      body: _ScreenBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 100, 20, 32),
            children: [
               Text(tr('CHOOSE A MODE'),
                  style: TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: _kMuted)),
              const SizedBox(height: 16),
              _ModeCard(
                mode: _kCountryMode,
                icon: Icons.public_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const _RevealLobbyScreen(mode: _kCountryMode)),
                ),
              ),
              const SizedBox(height: 14),
              _ModeCard(
                mode: _kCityMode,
                icon: Icons.location_city_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const _RevealLobbyScreen(mode: _kCityMode)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final _RevealMode mode;
  final IconData icon;
  final VoidCallback onTap;

  const _ModeCard({required this.mode, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return GestureDetector(
      onTap: onTap,
      child: _SoftCard(
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_kAccent.withOpacity(0.85), _kAccent],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: _kAccent.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6)),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr(mode.title),
                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: _kInk)),
                  const SizedBox(height: 4),
                  Text(tr(mode.heroSubtitle),
                      style: const TextStyle(fontSize: 12.5, color: _kMuted, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 22, color: _kFaint),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// LOBBY SCREEN
// ============================================================================

/// Leaderboard + start button for one [_RevealMode].
class _RevealLobbyScreen extends StatefulWidget {
  final _RevealMode mode;

  const _RevealLobbyScreen({required this.mode});

  @override
  State<_RevealLobbyScreen> createState() => _RevealLobbyScreenState();
}

class _RevealLobbyScreenState extends State<_RevealLobbyScreen> {
  final _service = _RevealScoreService();
  late Future<List<_RevealScoreRecord>> _recordsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _recordsFuture = _service.loadRecords(widget.mode.storageKey);
    });
  }

  Future<void> _startGame() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _RevealGameScreen(mode: widget.mode)),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Scaffold(
      backgroundColor: _kSurface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(tr('Reveal · ${widget.mode.title}'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _kInk)),
        iconTheme: const IconThemeData(color: _kInk),
      ),
      body: _ScreenBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 92, 20, 20),
            child: Column(
              children: [
                _SoftCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: _kAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.lightbulb_rounded, color: _kAccent, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          tr(widget.mode.heroSubtitle),
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _kMuted),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(child: _buildHistory()),
                const SizedBox(height: 18),
                _GradientButton(
                  label: 'Start Game',
                  icon: Icons.play_arrow_rounded,
                  color: _kAccent,
                  onPressed: _startGame,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistory() {
    return FutureBuilder<List<_RevealScoreRecord>>(
      future: _recordsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final records = snapshot.data!;
        if (records.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events_outlined, size: 46, color: _kFaint),
                const SizedBox(height: 12),
                 Text(tr('No runs yet'),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kInk)),
                const SizedBox(height: 4),
                 Text(tr('Play a round to start your leaderboard'),
                    style: TextStyle(fontSize: 12.5, color: _kMuted)),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 Text(tr('LEADERBOARD'),
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: _kMuted)),
                Text(tr('${records.length} run${records.length == 1 ? '' : 's'}'),
                    style: const TextStyle(fontSize: 12, color: _kFaint, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: records.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _RecordTile(rank: i + 1, record: records[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RecordTile extends StatelessWidget {
  final int rank;
  final _RevealScoreRecord record;

  const _RecordTile({required this.rank, required this.record});

  static const _medalColors = {1: Color(0xFFFFC93C), 2: Color(0xFFB8C1CC), 3: Color(0xFFD08A5B)};

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final sameDay = d.year == now.year && d.month == now.month && d.day == now.day;
    if (sameDay) {
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    final medal = _medalColors[rank];
    return _SoftCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderColor: medal?.withOpacity(0.5),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (medal ?? _kFaint).withOpacity(medal != null ? 0.18 : 0.12),
              shape: BoxShape.circle,
            ),
            child: medal != null
                ? Icon(Icons.emoji_events_rounded, size: 16, color: medal)
                : Text(tr('$rank'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _kMuted)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('${record.score}'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _kInk)),
                const SizedBox(height: 2),
                Text(
                  tr('${record.roundsCompleted}/${record.maxRounds} rounds · best streak ${record.bestCombo} · ${_formatDate(record.playedAt)}'),
                  style: const TextStyle(fontSize: 11.5, color: _kMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// GAME SCREEN
// ============================================================================

enum _RoundPhase { playing, revealed, complete }

class _RevealGameScreen extends StatefulWidget {
  final _RevealMode mode;

  const _RevealGameScreen({required this.mode});

  @override
  State<_RevealGameScreen> createState() => _RevealGameScreenState();
}

class _RevealGameScreenState extends State<_RevealGameScreen> {
  static const int _maxRoundsCap = 20;
  static const int _choicesPerRound = 6;
  static const List<int> _scoreByHintLevel = [0, 1000, 700, 400, 100]; // index by hintLevel (1..4)

  late final List<_RevealEntry> _rounds;
  late final int _maxRounds;

  int _roundIndex = 0;
  int _totalScore = 0;
  int _bestRoundScore = 0;
  int _perfectStreak = 0;
  int _bestPerfectStreak = 0;

  _RoundPhase _phase = _RoundPhase.playing;
  int _hintLevel = 1;
  final Set<String> _wrongNames = {};
  late List<_RevealEntry> _choices;
  int? _lastRoundScore;
  bool _recorded = false;

  _RevealEntry get _current => _rounds[_roundIndex];

  @override
  void initState() {
    super.initState();
    final pool = List<_RevealEntry>.from(widget.mode.pool)..shuffle();
    _maxRounds = min(_maxRoundsCap, pool.length);
    _rounds = pool.take(_maxRounds).toList();
    _choices = [];
    _startRound();
  }

  void _startRound() {
    final others = widget.mode.pool.where((c) => c.name != _current.name).toList()..shuffle();
    final choices = [_current, ...others.take(_choicesPerRound - 1)]..shuffle();
    setState(() {
      _hintLevel = 1;
      _wrongNames.clear();
      _choices = choices;
      _lastRoundScore = null;
      _phase = _RoundPhase.playing;
    });
  }

  void _revealNextHint() {
    if (_hintLevel >= 4) return;
    setState(() => _hintLevel++);
  }

  void _onGuess(_RevealEntry entry) {
    if (_phase != _RoundPhase.playing) return;
    if (entry.name == _current.name) {
      final score = _scoreByHintLevel[_hintLevel];
      setState(() {
        _totalScore += score;
        _lastRoundScore = score;
        if (score > _bestRoundScore) _bestRoundScore = score;
        if (_hintLevel == 1) {
          _perfectStreak++;
          if (_perfectStreak > _bestPerfectStreak) _bestPerfectStreak = _perfectStreak;
        } else {
          _perfectStreak = 0;
        }
        _phase = _RoundPhase.revealed;
      });
      Future.delayed(const Duration(milliseconds: 1300), () {
        if (!mounted) return;
        if (_roundIndex + 1 >= _maxRounds) {
          _finishGame();
        } else {
          setState(() => _roundIndex++);
          _startRound();
        }
      });
    } else {
      setState(() {
        _wrongNames.add(entry.name);
        if (_hintLevel < 4) _hintLevel++;
      });
    }
  }

  void _finishGame() {
    setState(() => _phase = _RoundPhase.complete);
    _saveRecord();
  }

  Future<void> _saveRecord() async {
    if (_recorded) return;
    _recorded = true;
    try {
      await _RevealScoreService().addRecord(widget.mode.storageKey, _RevealScoreRecord(
        score: _totalScore,
        roundsCompleted: _maxRounds,
        maxRounds: _maxRounds,
        bestCombo: _bestPerfectStreak,
        playedAt: DateTime.now(),
      ));
    } catch (_) {
      // Local-storage hiccups shouldn't block showing the result screen.
    }
  }

  void _retry() {
    setState(() {
      _roundIndex = 0;
      _totalScore = 0;
      _bestRoundScore = 0;
      _perfectStreak = 0;
      _bestPerfectStreak = 0;
      _recorded = false;
      _phase = _RoundPhase.playing;
      _rounds.shuffle();
    });
    _startRound();
  }

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Scaffold(
      backgroundColor: _kSurface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(tr(widget.mode.title),
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _kInk)),
        iconTheme: const IconThemeData(color: _kInk),
        actions: _phase == _RoundPhase.complete
            ? null
            : [_ScoreBadge(total: _totalScore, best: _bestRoundScore)],
      ),
      body: _ScreenBackground(
        child: SafeArea(
          child: _phase == _RoundPhase.complete ? _buildComplete() : _buildRound(),
        ),
      ),
    );
  }

  Widget _buildRound() {
    final revealed = _phase == _RoundPhase.revealed;
    final nextScore = _hintLevel < 4 ? _scoreByHintLevel[_hintLevel + 1] : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr('ROUND ${_roundIndex + 1} / $_maxRounds'),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: _kMuted)),
              if (_perfectStreak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _kAccent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.bolt_rounded, size: 15, color: _kAccent),
                    const SizedBox(width: 3),
                    Text(tr('$_perfectStreak'),
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _kAccent)),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (revealed)
            _buildResultBanner()
          else
            Column(
              children: [
                for (int level = 1; level <= _hintLevel; level++) ...[
                  _buildHintCard(level),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.4,
              children: _choices.map(_buildChoiceButton).toList(),
            ),
          ),
          const SizedBox(height: 8),
          if (!revealed)
            _hintLevel < 4
                ? GestureDetector(
              onTap: _revealNextHint,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kAccent.withOpacity(0.35), width: 1.3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.visibility_rounded, size: 18, color: _kAccent),
                    const SizedBox(width: 8),
                    Text(
                      tr(_hintLevel == 3 ? widget.mode.finalHintLabel : 'Reveal another clue'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _kAccent),
                    ),
                    if (nextScore != null) ...[
                      const SizedBox(width: 6),
                      Text(tr('(worth $nextScore now)'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kMuted)),
                    ],
                  ],
                ),
              ),
            )
                : Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              child:  Text(tr('Final clue — guess below'),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _kMuted)),
            ),
        ],
      ),
    );
  }

  Widget _buildHintCard(int level) {
    final isFlag = level == 4;
    return _SoftCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: _kAccent.withOpacity(0.12), shape: BoxShape.circle),
            child: Text(tr('$level'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _kAccent)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: isFlag
                ? Text(tr(_current.flagEmoji), style: const TextStyle(fontSize: 28))
                : Text(tr(_current.hints[level - 1]),
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _kInk, height: 1.35)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultBanner() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF2FBE73),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: const Color(0xFF2FBE73).withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_current.flagEmoji} ${widget.mode == _kCountryMode ? AppLocale.instance.countryName(_current.name) : _current.name} +${_lastRoundScore ?? 0}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
                  Text(tr(_hintLevel == 1 ? 'Perfect — solved on the first clue!' : 'Solved with $_hintLevel hints'),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceButton(_RevealEntry entry) {
    final isWrong = _wrongNames.contains(entry.name);
    final isRevealedCorrect = _phase == _RoundPhase.revealed && entry.name == _current.name;

    Color bg = Colors.white;
    Color fg = _kInk;
    Color border = Colors.black.withOpacity(0.04);

    if (isRevealedCorrect) {
      bg = const Color(0xFF2FBE73);
      border = const Color(0xFF2FBE73);
      fg = Colors.white;
    } else if (isWrong) {
      bg = const Color(0xFFFF5A5F).withOpacity(0.1);
      border = const Color(0xFFFF5A5F).withOpacity(0.4);
      fg = const Color(0xFFC62828);
    }

    return GestureDetector(
      onTap: isWrong ? null : () => _onGuess(entry),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 1.4),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isWrong) const Padding(
              padding: EdgeInsets.only(right: 5),
              child: Icon(Icons.close_rounded, size: 14, color: Color(0xFFC62828)),
            ),
            Flexible(
              child: Text(widget.mode == _kCountryMode ? AppLocale.instance.countryName(entry.name) : entry.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: fg)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplete() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_kAccent.withOpacity(0.85), _kAccent]),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: _kAccent.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: const Icon(Icons.emoji_events_rounded, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 18),
             Text(tr('Run Complete!'),
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _kInk)),
            const SizedBox(height: 26),
            _SoftCard(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 26),
              child: Column(children: [
                Text(tr('$_totalScore'),
                    style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: _kAccent)),
                 Text(tr('TOTAL SCORE'),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: _kMuted)),
                const SizedBox(height: 18),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _StatChip(label: 'Rounds', value: '$_maxRounds'),
                  const SizedBox(width: 10),
                  _StatChip(label: 'Best', value: '$_bestRoundScore'),
                  const SizedBox(width: 10),
                  _StatChip(label: 'Streak', value: '$_bestPerfectStreak'),
                ]),
              ]),
            ),
            const SizedBox(height: 26),
            _GradientButton(label: 'Play Again', color: _kAccent, onPressed: _retry),
            const SizedBox(height: 10),
            _GradientButton(
              label: 'Back to Lobby',
              color: _kAccent,
              outlined: true,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final int total;
  final int best;

  const _ScoreBadge({required this.total, required this.best});

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Padding(
      padding: const EdgeInsets.only(right: 16, top: 4, bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(tr('$total'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _kAccent)),
            Text(tr('best $best'),
                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: _kMuted)),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    Localizations.maybeLocaleOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: _kSurface, borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Text(tr(value), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _kInk)),
        const SizedBox(height: 2),
        Text(tr(label.toUpperCase()),
            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: _kMuted)),
      ]),
    );
  }
}
