"""Reject embedded demo credentials and non-public environment secrets in web assets."""
import os
from pathlib import Path
root = Path(__file__).resolve().parent.parent
bundle = root / '.web-dist'
assert (bundle / 'index.html').is_file(), 'Build the web app first'
for path in bundle.rglob('*'):
    if path.is_file():
        assert 'demo_cloud_credentials' not in path.name and 'demo_ocr_credentials' not in path.name, 'Embedded credentials in web assets'
secrets = []
env_file = os.environ.get('ENV_FILE')
if env_file:
    for line in Path(env_file).read_text().splitlines():
        if '=' in line and not line.lstrip().startswith('#'):
            name, value = line.split('=', 1)
            value = value.strip().strip('"\'')
            if len(value) > 12 and any(s in name for s in ('SECRET', 'PASSWORD', 'TOKEN', 'SERVICE_ROLE', 'GEMINI_API', 'GOOGLE_API')):
                secrets.append(value.encode())
for path in bundle.rglob('*'):
    if path.is_file():
        data = path.read_bytes()
        assert not any(value in data for value in secrets), 'Secret found in web bundle'
print('Web asset credential scan passed')
