"""Interactive local key setup. Run in CMD; never prints or transmits the key."""
import getpass
from pathlib import Path
import re
import warnings

ENV_PATH = Path(__file__).resolve().parents[2] / '.env.jev'


def migrate_legacy_key():
    """Move the offline-only key out of Flutter's bundled .env without printing it."""
    legacy = ENV_PATH.parent / '.env'
    if not legacy.exists():
        return 0
    original = legacy.read_bytes().decode('utf-8-sig')
    def key_from(text):
        values = {}
        for line in text.splitlines():
            key,sep,value = line.partition('=')
            if sep and key.strip() in ('TYPESAFE_API_KEY','JEV_API_KEY'):
                values[key.strip()] = value.strip().strip('"\'')
        return values.get('TYPESAFE_API_KEY') or values.get('JEV_API_KEY')
    current = ENV_PATH.read_bytes().decode('utf-8-sig') if ENV_PATH.exists() else ''
    key = key_from(current) or key_from(original)
    kept = [line for line in original.splitlines(keepends=True)
            if not re.match(r'^\s*(?:export\s+)?(?:TYPESAFE_API_KEY|JEV_API_KEY)\s*=',line)]
    removed = len(original.splitlines(keepends=True))-len(kept)
    if removed:
        if not key:
            raise ValueError('Could not preserve local key; legacy file unchanged')
        ENV_PATH.write_bytes(update_env(current,key).encode('utf8'))
        legacy.write_bytes(''.join(kept).encode('utf8'))
    return removed


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
    migrate_legacy_key()
    print('Saved TYPESAFE_API_KEY to .env.jev (local tooling only). Other settings preserved.')
    print('No API request was sent.')


if __name__ == '__main__':
    main()
