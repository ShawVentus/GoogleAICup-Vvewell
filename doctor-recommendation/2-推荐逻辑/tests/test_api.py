import json
import sys
import threading
import unittest
from pathlib import Path
from unittest.mock import patch
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from http.server import ThreadingHTTPServer
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import server


class ApiTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.httpd = ThreadingHTTPServer(('127.0.0.1', 0), server.H)
        cls.thread = threading.Thread(target=cls.httpd.serve_forever, daemon=True)
        cls.thread.start()
        cls.url = f'http://127.0.0.1:{cls.httpd.server_port}/api/recommend'

    @classmethod
    def tearDownClass(cls):
        cls.httpd.shutdown()
        cls.httpd.server_close()
        cls.thread.join()

    def post(self, form):
        request = Request(self.url, json.dumps(form).encode(), {'Content-Type': 'application/json'})
        try:
            with urlopen(request, timeout=5) as response:
                return response.status, json.load(response)
        except HTTPError as error:
            return error.code, json.load(error)

    def form(self, **extra):
        return dict(text='子宫肌瘤', age=38, sex_at_birth='F', current_country='CN', reply_language='zh', **extra)

    def test_invalid_profile_never_calls_model(self):
        with patch.object(server, 'recommend') as recommend:
            for age in [None, True, -1, 121, 'not-a-number']:
                form = self.form(); form['age'] = age
                self.assertEqual(self.post(form)[0], 400)
            recommend.assert_not_called()

    def test_model_failure_has_no_results(self):
        with patch.object(server, 'recommend', return_value={'warning': 'offline fallback'}):
            status, data = self.post(self.form())
        self.assertEqual(status, 503)
        self.assertNotIn('results', data)

    def test_followup_contract(self):
        with patch.object(server, 'recommend', return_value={'type': 'followup', 'question': '持续多久？'}) as recommend:
            status, data = self.post(self.form(followup_answers='三个月'))
        self.assertEqual(status, 200)
        self.assertEqual(data['question'], '持续多久？')
        self.assertEqual(recommend.call_args.args[0]['followup_answers'], '三个月')

    def test_emergency_does_not_wait_for_age_or_model_lock(self):
        form = self.form(); form.update(text='胸口压榨样疼、出汗、喘不上气', age=None)
        server.LOCK.acquire()
        try:
            with patch.object(server, 'recommend', return_value={'type': 'emergency', 'message': '请拨打120'}):
                status, data = self.post(form)
        finally:
            server.LOCK.release()
        self.assertEqual(status, 200)
        self.assertEqual(data['type'], 'emergency')

    def test_present_uses_actual_hospital_and_doctor_fields(self):
        import recommender as R
        parsed = {'depts': {'primary': 'GYN', 'acceptable': []}, 'focus_keywords': ['子宫肌瘤']}
        rows, meta = R.retrieve_doctors({'age': 38}, parsed)
        out = {'type': 'doctor_recommendation', 'meta': meta, 'results': [{
            'hospital_id': h['hospital_id'], 'std': h['std'], 'evidence': None,
            'doctors': [{'doctor_id': d['doctor']['doctor_id'], 'name': d['doctor']['name'], 'title': d['doctor']['title'],
                'dept_local': d['doctor']['dept_local'], 'expertise': d['doctor']['expertise'],
                'matched_keywords': d['hit']} for d in h['doctors']],
        } for h in rows]}
        result = server.present(out)
        self.assertEqual(result['department'], '妇科')
        self.assertTrue(result['results'][0]['doctors'][0]['expertise'])
        self.assertEqual(result['results'][0]['name'], R.HOSP[rows[0]['hospital_id']]['name_zh'])


if __name__ == '__main__':
    unittest.main()
