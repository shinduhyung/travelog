"""Interactive local key setup. Run in CMD; never prints or transmits the key."""
import getpass
from pathlib import Path
import re
import warnings

ENV_PATH = Path(__file__).resolve().parents[2] / '.env'


def update_env(text, key):
    if not key or any(c.isspace() for c in key) or any(c in key for c in '\'"#'):
        raise ValueError('Paste only the API key, without quotes, spaces or comments.')
    newline = '\r\n' if '\r\n' in text else '\n'
    lines = text.splitlines(keepends=True)
    result, replaced = [], False
    for line in lines:
        if re.match(r'^\s*TYPESAFE_API_KEY\s*=', line):
            if not replaced:
                result.append('TYPESAFE_API_KEY=' + key + newline)
                replaced = True
        else:
            result.append(line)
    if not replaced:
        if result and not result[-1].endswith(('\r', '\n')):
            result.append(newline)
        result.append('TYPESAFE_API_KEY=' + key + newline)
    return ''.join(result)


def main():
    warnings.simplefilter('error', getpass.GetPassWarning)
    try:
        key = getpass.getpass('Paste Jev API key (hidden), then press Enter: ').strip()
    except (getpass.GetPassWarning, EOFError):
        raise SystemExit('Hidden input unavailable. Run this command in a normal CMD window.') from None
    except KeyboardInterrupt:
        raise SystemExit('\nCancelled; no file changed.') from None
    if not key:
        raise SystemExit('Empty key; no file changed.')
    # Decode bytes directly so existing Windows line endings are preserved.
    original = ENV_PATH.read_bytes().decode('utf-8-sig') if ENV_PATH.exists() else ''
    try:
        updated = update_env(original, key)
    except ValueError as error:
        raise SystemExit(str(error)) from None
    ENV_PATH.write_bytes(updated.encode('utf8'))
    print('Saved TYPESAFE_API_KEY to the project .env. Other settings preserved.')
    print('No API request was sent.')


if __name__ == '__main__':
    main()
