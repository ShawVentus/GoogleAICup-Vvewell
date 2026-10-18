import json
import re
import unittest

from web_backend.doctor_v2 import present, recommender as R, tools


class EnglishDisplayTest(unittest.TestCase):
    def test_every_catalog_doctor_has_romanized_display_name(self):
        self.assertEqual(len(R.DOCTORS), 878)
        for doctor in R.DOCTORS:
            name = present.DOCTOR_NAMES_EN[doctor['doctor_id']]
            self.assertTrue(name.strip())
            self.assertIsNone(re.search(r'[\u4e00-\u9fff]', name))

    def test_recommendation_text_and_model_brief_are_english(self):
        result = tools.run('recommend_hospitals_and_doctors', dict(
            description='uterine fibroids', age=38, sex_at_birth='F', current_country='GB'), offline=True)
        self.assertEqual(result['type'], 'doctor_recommendation')
        self.assertIsNone(re.search(r'[\u4e00-\u9fff]', result['text']))
        self.assertIsNone(re.search(r'[\u4e00-\u9fff]', tools.brief(result)))
        self.assertIn('romanized', result['text'])
        for hospital in result['cards']['hospitals']:
            for doctor in hospital['doctors']:
                self.assertTrue(doctor['name_en'])
                self.assertTrue(doctor['name_zh'])

    def test_english_emergency_uses_selected_country(self):
        for country, number in [('JP', '119'), ('GB', '999'), ('CN', '120'), ('OTHER', 'local emergency number')]:
            message = R._emergency({'current_country': country}, ['自伤风险'], 'en')
            self.assertIn(number, message)
            self.assertNotIn('988', message)
            self.assertIsNone(re.search(r'[\u4e00-\u9fff]', message))

    def test_urgent_notice_uses_selected_country(self):
        self.assertIn('119', R.urgent_notice({'current_country': 'JP'}, 'en'))
        self.assertNotIn('911', R.urgent_notice({'current_country': 'OTHER'}, 'en'))
        self.assertIn('local emergency number', R.urgent_notice({}, 'en'))

    def test_hospital_list_display_is_english(self):
        result = tools.run('list_hospitals', {})
        self.assertIsNone(re.search(r'[\u4e00-\u9fff]', tools.brief(result)))
        self.assertIsNone(re.search(r'[\u4e00-\u9fff]', result['text']))
