from pathlib import Path
import subprocess
import re

env = {}
for line in Path('.env').read_text().splitlines():
    if '=' in line and not line.strip().startswith('#'):
        k, v = line.split('=', 1)
        env[k] = v

url = env['SUPABASE_URL'].rstrip('/')
key = env['SUPABASE_ANON_KEY']

def redact(text: str) -> str:
    text = text.replace(key, '[REDACTED_ANON_KEY]')
    text = re.sub(r'eyJ[A-Za-z0-9._-]+', '[REDACTED_JWT]', text)
    return text

for fn, payload in [
    ('parent-summary', '{}'),
    ('vocabulary-explanation', '{"word":"moon","reading_level":"beginner"}'),
]:
    cmd = [
        'curl', '-sS', '-i', '-X', 'POST', f'{url}/functions/v1/{fn}',
        '-H', ': '.join(['Authorization', 'Bearer']) + ' ' + key,
        '-H', 'apikey: ' + key,
        '-H', 'Content-Type: application/json',
        '--data', payload,
    ]
    out = subprocess.run(cmd, text=True, capture_output=True, timeout=60).stdout
    print(f'--- {fn} ---')
    print(redact(out[:1200]))
