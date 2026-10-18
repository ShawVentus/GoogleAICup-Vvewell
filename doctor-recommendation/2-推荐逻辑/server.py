"""Local Flutter preview and doctor recommendation API (standard library only)."""
import json
import os
import sys
import threading
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from recommender import DOCTORS, HOSP, STD, _gateway, _show, recommend, safety_check

LOCK = threading.Lock()
WEB_ROOT = Path(__file__).resolve().parent.parent / '1-前端代码' / 'build' / 'web'

# Pinyin display names; regenerate this file when doctor.csv changes.
DOCTOR_NAMES_EN = json.loads(Path(__file__).with_name('doctor_names_en.json').read_text())
DOCTOR_BY_ID = {d['doctor_id']: d for d in DOCTORS}
DISTRICTS_EN = {'罗湖区': 'Luohu', '福田区': 'Futian', '宝安区': "Bao'an", '光明区': 'Guangming',
    '龙岗区': 'Longgang', '南山区': 'Nanshan', '福田区（多院区）': 'Futian · Multiple campuses',
    '罗湖区（多院区）': 'Luohu · Multiple campuses', '': 'Shenzhen'}
HOSPITAL_NAMES_EN = {
    'SZ005': 'Shenzhen Hospital of Southern Medical University',
    'SZ006': 'The Seventh Affiliated Hospital of Sun Yat-sen University (Shenzhen)',
    'SZ016': "Shenzhen Children's Hospital",
    'SZ020': 'Cancer Hospital, Chinese Academy of Medical Sciences, Shenzhen Center',
    'SZ021': 'Fuwai Hospital, Chinese Academy of Medical Sciences, Shenzhen',
    'SZ026': 'Shenzhen Far East Maternity Hospital',
    'SZ029': 'Shenzhen Amcare Women and Children Hospital',
    'SZ030': 'Shenzhen New Frontier United Family Hospital',
}


def title_en(title):
    if '高级顾问' in title or '资深顾问' in title:
        return 'Senior Consultant'
    if '顾问' in title:
        return 'Consultant'
    if '主任中医师' in title:
        return 'Chief TCM Physician'
    if '主任医师' in title:
        return 'Chief Physician'
    if '高级医生' in title:
        return 'Senior Physician'
    return 'Specialist'


def clean(form):
    errors = []
    text = form.get('text')
    if not isinstance(text, str) or not text.strip() or len(text) > 4000:
        errors.append('text')
    else:
        form['text'] = text.strip()
    urgent = isinstance(text, str) and safety_check(text)['flag']
    age = form.get('age')
    if age is None and urgent:
        pass  # Emergency guidance must not wait for a completed age field.
    elif type(age) is not int or not 0 <= age <= 120:
        errors.append('age')
    if form.get('sex_at_birth') not in ('M', 'F', 'unknown'):
        errors.append('sex_at_birth')
    if form.get('current_country') not in ('CN', 'US'):
        errors.append('current_country')
    if form.get('pregnant', '不确定') not in ('是', '否', '不确定', '不适用', 'yes', 'no', 'unsure', 'not_applicable'):
        errors.append('pregnant')
    followup = form.get('followup_answers', '')
    if not isinstance(followup, str) or len(followup) > 4000:
        errors.append('followup_answers')
    conversation = form.get('conversation', [])
    if not isinstance(conversation, list) or len(conversation) > 8 or any(
        not isinstance(turn, dict) or turn.get('role') not in ('user', 'assistant') or
        not isinstance(turn.get('content'), str) or len(turn['content']) > 3000
        for turn in conversation
    ):
        errors.append('conversation')
    shown = form.get('shown_doctor_ids', [])
    if not isinstance(shown, list) or len(shown) > 100 or any(
        not isinstance(i, str) or len(i) > 128 for i in shown
    ):
        errors.append('shown_doctor_ids')
    form['reply_language'] = 'zh' if form.get('reply_language') == 'zh' else 'en'
    form.setdefault('pregnant', '不确定')
    form['pregnant'] = {'是': 'yes', '否': 'no', '不确定': 'unsure', 'not_applicable': '不适用'}.get(form['pregnant'], form['pregnant'])
    form.pop('intent', None)
    return errors


def present(out, lang="zh"):
    payload = {k: out[k] for k in ('type', 'message', 'intro', 'urgent_notice', 'question', 'meta') if k in out}
    english = lang == 'en'
    name_field = 'name_en' if english else 'name_zh'
    if english and out.get('type') in ('doctor_recommendation', 'department_fallback'):
        payload.pop('message', None)
    wanted = out.get('meta', {}).get('wanted', [])
    payload['department'] = STD[wanted[0]][name_field] if wanted else ''
    payload['alternatives'] = [STD[s][name_field] for s in wanted[1:]]
    payload['results'] = []
    for h in out.get('results', []):
        hospital = HOSP[h['hospital_id']]
        english_name = hospital['name_en'] or HOSPITAL_NAMES_EN[h['hospital_id']]
        payload['results'].append({
            'name': english_name if english else hospital['name_zh'], 'name_en': english_name,
            'district': DISTRICTS_EN[hospital['district']] if english else hospital['district'],
            'evidence': '' if english else h['evidence'] or '',
            'dept_only': STD[h['std']][name_field] if not h['doctors'] else None,
            'doctors': [{
                'doctor_id': d['doctor_id'],
                'name': DOCTOR_NAMES_EN.get(d['doctor_id'], 'Doctor') if english else d['name'],
                'title': title_en(d['title']) if english else d['title'],
                'dept': ' / '.join(STD[i]['name_en'] for i in DOCTOR_BY_ID[d['doctor_id']]['std_dept_ids'].split('|')) if english else d['dept_local'],
                **({} if english else {'expertise': _show(d['expertise']), 'hit': d['matched_keywords']}),
            } for d in h['doctors']],
        })
    return payload


class H(SimpleHTTPRequestHandler):
    def _send(self, code, body):
        data = json.dumps(body, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == '/api/health':
            _, key, model = _gateway()
            return self._send(200, {'status': 'ok', 'model_configured': bool(key), 'model': model})
        if self.path.startswith('/api/'):
            return self._send(404, {'error': 'Endpoint not found'})
        return super().do_GET()

    def do_POST(self):
        if self.path != '/api/recommend':
            return self._send(404, {'error': 'Endpoint not found'})
        try:
            length = int(self.headers.get('Content-Length', '0'))
            if not 0 < length <= 131072:
                return self._send(413, {'error': 'The request is empty or too large.'})
            form = json.loads(self.rfile.read(length))
            if not isinstance(form, dict):
                raise ValueError()
        except (ValueError, UnicodeDecodeError):
            return self._send(400, {'error': 'Invalid request format.'})
        errors = clean(form)
        if errors:
            return self._send(400, {'error': 'Please enter your concern, a valid age (0–120), sex at birth, and current location.', 'fields': errors})
        if safety_check(form['text'] + '\n' + form.get('followup_answers', ''))['flag']:
            return self._send(200, present(recommend(form), form['reply_language']))
        # Do not queue behind a slow model request; allow the caller to retry.
        if not LOCK.acquire(blocking=False):
            return self._send(503, {'error': 'The service is busy. Please try again shortly.'})
        try:
            out = recommend(form)
            if out.get('warning'):
                return self._send(503, {'error': 'The recommendation service is temporarily unavailable. Please try again.'})
            payload = present(out, form['reply_language'])
        except Exception as error:
            # Upstream errors may include credentials or patient content.
            sys.stderr.write(f'recommend failed: {type(error).__name__}\n')
            return self._send(500, {'error': 'Unable to complete the recommendation. Please try again.'})
        finally:
            LOCK.release()
        self._send(200, payload)

    def log_message(self, *args):
        pass


if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 4186
    print(f'http://127.0.0.1:{port}/', flush=True)
    ThreadingHTTPServer(('127.0.0.1', port), partial(H, directory=str(WEB_ROOT))).serve_forever()
