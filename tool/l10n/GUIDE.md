# Translation guide (for translators and translation agents)

You translate English display text of a travel/geography app into one target
language. Read this file and the language's `tool/l10n/<lang>/style.md` (if
present) before starting.

## Input and output

- Input chunk: `tool/l10n/<lang>/work/in/NNN.json`, a JSON array of
  `{"id": int, "en": "<English>", "landmark": "<name / city>"?}`.
  `landmark` is context only. Do not put it in the output.
  Short labels may carry `ref_ko`, the reviewed Korean translation. Use it
  only to tell which meaning is intended ("Met" → 충족 means a requirement
  was met). Always translate from the English.
- Output: `tool/l10n/<lang>/work/out/NNN.json`, one JSON object mapping every
  id (as a string) to its translation: `{"0": "...", "1": "..."}`.
  Every input id must appear exactly once.

## Rules

- Write fluent, natural text as a native editor would for a travel guide.
  Restructure sentences rather than translating word for word.
- Keep placeholders such as `{0}` and `{1}` exactly. Word order may move them.
  Exception: a placeholder glued to an English word (`hop{1}`, `Day{1}`) is
  the English plural "s". Drop it unless your language uses that suffix.
- Keep the same number of `\n` line breaks. "Highlights" texts are one item
  per line, often `Name: description`. Keep the lines in order, drop the
  leading space after `\n`, and translate the item names too.
- Short labels and titles stay short noun phrases.
- Proper nouns: use the established name in the target language. Otherwise
  transliterate following the language's standard convention. Leave no
  English words, except acronyms, codes and brands normally written in Latin
  script (UNESCO, NASA, IATA codes, ISO currency codes, km, m).
- Keep personal-name initials (J. Paul Getty, L.F. Wade). Do not drop them.
- Do not add, drop or editorialize information. Do not convert units.
- English "billion" is 10^9 and "trillion" is 10^12. Use the word your
  language has for that value, not its look-alike ("$1.2 trillion" is
  "1.200 miliardi di dollari" in Italian, "1.2万亿美元" in Chinese).
- Log or debug strings (`[AdService] ...`) still get translated, with code
  identifiers and placeholders kept as is.

## Procedure

1. Read the chunk.
2. Write the output with the Write tool, in 2–3 part files if it is long,
   then merge them. Use absolute paths. Name any helper files after your
   chunk number. Other translators share the folder.
3. Validate with Python (`PYTHONIOENCODING=utf-8`, `encoding='utf-8'`):
   the output parses as JSON, its keys equal the input ids, and no value is
   empty. Line breaks and placeholders must match the source, and no stray
   English words may remain.
4. Report only the chunk numbers and item counts.
