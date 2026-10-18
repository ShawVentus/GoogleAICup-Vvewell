import json
import sys
import unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import recommender as R


class ModelResponseTest(unittest.TestCase):
    def test_plain_and_fenced_json(self):
        for raw in ['{"level":"none"}', '```json\n{"level":"none"}\n```', '```\n{"level":"none"}\n```', 'Reasoning text\n\n{"level":"none"}']:
            self.assertEqual(R._model_json(raw), {'level': 'none'})

    def test_invalid_output_is_not_guessed(self):
        for raw in ['', None, '{"level":"none"} trailing text', '{"a":1} {"b":2}', '[]', '```json\n{invalid}\n```']:
            with self.assertRaises(ValueError):
                R._model_json(raw)

    def test_parser_stops_after_two_attempts(self):
        with patch.object(R, '_gateway', return_value=('https://example.test', 'test-key', 'test-model')), \
             patch.object(R, '_post_json', return_value={'choices': [{'message': {'content': ''}}]}) as post, \
             patch.object(R.time, 'sleep'):
            with self.assertRaises(RuntimeError):
                R.parse_gemini({'text': 'test'})
        self.assertEqual(post.call_count, 2)
        self.assertEqual(post.call_args.args[1]['reasoning_effort'], 'low')
        self.assertEqual(post.call_args.args[1]['max_tokens'], 8192)

    def test_secondary_safety_check_accepts_fenced_json(self):
        out = {'choices': [{'message': {'content': '```json\n{"level":"urgent","reason":"test"}\n```'}}]}
        with patch.object(R, '_gateway', return_value=('https://example.test', 'test-key', 'test-model')), \
             patch.object(R, '_post_json', return_value=out):
            self.assertEqual(R.danger_second_opinion({'text': 'test'})['level'], 'urgent')


if __name__ == '__main__':
    unittest.main()
