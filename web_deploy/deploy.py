"""Deploy the built web preview. Secret values are sent to Secret Manager on stdin."""
import argparse
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent
ap = argparse.ArgumentParser()
ap.add_argument('--project', required=True)
ap.add_argument('--env-file', required=True)
ap.add_argument('--gcloud', default='gcloud')
ap.add_argument('--region', default='asia-east1')
a = ap.parse_args()
values = {}
for line in Path(a.env_file).read_text().splitlines():
    if '=' in line and not line.lstrip().startswith('#'):
        name, value = line.split('=', 1)
        values[name.strip()] = value.strip().strip('"\'')
for name in ('GEMINI_API', 'GEMINI_URL', 'GOOGLE_API', 'SUPABASE_URL', 'SUPABASE_PUBLIC_KEY'):
    if not values.get(name):
        raise SystemExit(f'{name} is missing')


def run(args, **kwargs):
    return subprocess.run([a.gcloud, *args, '--project=' + a.project, '--quiet'],
                          cwd=ROOT, check=True, **kwargs)


service = 'vvewell-web-preview'
account = 'vvewell-web-runtime'
email = f'{account}@{a.project}.iam.gserviceaccount.com'
print('Checking runtime service account', flush=True)
exists = subprocess.run([a.gcloud, 'iam', 'service-accounts', 'describe', email, '--project=' + a.project],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
if not exists:
    run(['iam', 'service-accounts', 'create', account, '--display-name=Vvewell Web preview runtime'])
for variable, secret in [('GEMINI_API', 'vvewell-web-gemini-api'), ('GOOGLE_API', 'vvewell-web-google-api')]:
    exists = subprocess.run([a.gcloud, 'secrets', 'describe', secret, '--project=' + a.project],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
    if not exists:
        run(['secrets', 'create', secret, '--replication-policy=automatic'])
    print('Storing model credential in Secret Manager: ' + variable, flush=True)
    run(['secrets', 'versions', 'add', secret, '--data-file=-'], input=values[variable].encode())
    run(['secrets', 'add-iam-policy-binding', secret, '--member=serviceAccount:' + email,
         '--role=roles/secretmanager.secretAccessor'], stdout=subprocess.DEVNULL)
env = {'GEMINI_URL': values['GEMINI_URL'], 'GEMINI_MODEL': 'gemini-3.8-flash',
       'DOCTOR_GEMINI_MODEL': 'gemini-3.5-flash', 'WEWELL_LOG_REDACT': '1',
       'SUPABASE_URL': values['SUPABASE_URL'], 'SUPABASE_PUBLIC_KEY': values['SUPABASE_PUBLIC_KEY']}
assert all(',' not in value for value in env.values())
print('Building and deploying Cloud Run preview (maximum one instance)', flush=True)
run(['run', 'deploy', service, '--source=.', '--region=' + a.region,
     '--service-account=' + email, '--allow-unauthenticated', '--max-instances=1',
     '--min-instances=0', '--concurrency=4', '--memory=512Mi', '--cpu=1', '--timeout=300',
     '--update-secrets=GEMINI_API=vvewell-web-gemini-api:latest,GOOGLE_API=vvewell-web-google-api:latest',
     '--set-env-vars=' + ','.join(name + '=' + value for name, value in env.items())])
run(['run', 'services', 'update-traffic', service, '--region=' + a.region, '--to-latest'])
run(['run', 'services', 'describe', service, '--region=' + a.region, '--format=value(status.url)'])
