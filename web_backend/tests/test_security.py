import base64
from functools import partial
from http.server import ThreadingHTTPServer
import importlib.util
import json
from pathlib import Path
import tempfile
import threading
import unittest
from urllib.error import HTTPError
from urllib.request import urlopen, Request
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('web_server', ROOT / 'web_backend/server.py')
web = importlib.util.module_from_spec(spec)
spec.loader.exec_module(web)


class WebSecurityTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.folder = tempfile.TemporaryDirectory()
        Path(cls.folder.name, 'index.html').write_text('preview')
        cls.httpd = ThreadingHTTPServer(('127.0.0.1', 0), partial(web.Handler, directory=cls.folder.name))
        cls.thread = threading.Thread(target=cls.httpd.serve_forever, daemon=True)
        cls.thread.start()
        cls.base = f'http://127.0.0.1:{cls.httpd.server_port}'

    @classmethod
    def tearDownClass(cls):
        cls.httpd.shutdown(); cls.httpd.server_close(); cls.thread.join(); cls.folder.cleanup()

    def test_anonymous_personal_data_is_rejected(self):
        with self.assertRaises(HTTPError) as error:
            urlopen(self.base + '/api/cloud/profiles')
        self.assertEqual(error.exception.code, 401)

    def test_public_ai_preview_uses_backend_without_exposing_credentials(self):
        form = dict(text='test', age=40, sex_at_birth='M', current_country='CN', reply_language='en')
        with patch.object(web.doctor_server, 'recommend', return_value={'type': 'no_department', 'message': 'Please describe your concern.'}) as model:
            with urlopen(Request(self.base + '/api/recommend', json.dumps(form).encode(), {'Content-Type': 'application/json'})) as response:
                result = json.load(response)
        self.assertEqual(result['type'], 'no_department')
        model.assert_called_once()


    def test_ai_preview_has_a_request_limit(self):
        from collections import deque
        import time
        with patch.object(web, 'AI_TIMES', deque([time.monotonic()] * 20)):
            with self.assertRaises(HTTPError) as error:
                urlopen(Request(self.base + '/api/consult', b'{"question":"test"}'))
        self.assertEqual(error.exception.code, 429)

    def test_public_config_has_only_publishable_values(self):
        with patch.object(web, 'SUPABASE_URL', 'https://example.supabase.co'), patch.object(web, 'PUBLIC_KEY', 'sb_publishable_test'):
            with urlopen(self.base + '/api/config') as response:
                data = json.load(response)
        self.assertEqual(set(data), {'supabase_url', 'supabase_public_key'})

    def test_service_role_key_cannot_be_used_as_public_configuration(self):
        payload = base64.urlsafe_b64encode(json.dumps({'role': 'service_role'}).encode()).decode().rstrip('=')
        with self.assertRaises(ValueError):
            web.validate_public_key('header.' + payload + '.signature')

    def test_source_and_private_configuration_are_not_served(self):
        for path in ('/.env', '/web_backend/server.py', '/../.env'):
            with self.assertRaises(HTTPError) as error:
                urlopen(self.base + path)
            self.assertEqual(error.exception.code, 404)


if __name__ == '__main__':
    unittest.main()
