import json
import re
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import recommender as R
import server


class EnglishPresentationTest(unittest.TestCase):
    def test_english_card_fields_have_no_chinese_or_expertise(self):
        doctor = next(d for d in R.DOCTORS if d['name'] == '屈园')
        out = {'type': 'doctor_recommendation', 'message': '中文原文', 'meta': {'wanted': ['ONC']},
            'results': [{'hospital_id': 'SZ003', 'std': 'ONC', 'evidence': '中文科室证据',
              'doctors': [{'doctor_id': doctor['doctor_id'], 'name': doctor['name'],
                'title': doctor['title'], 'dept_local': doctor['dept_local'],
                'expertise': doctor['expertise'], 'matched_keywords': ['肺癌']}]}]}
        result = server.present(out, 'en')
        self.assertNotRegex(json.dumps(result, ensure_ascii=False), r'[\u3400-\u9fff]')
        hospital = result['results'][0]
        self.assertEqual(hospital['name'], 'The University of Hong Kong-Shenzhen Hospital')
        self.assertEqual(hospital['district'], 'Futian')
        card = hospital['doctors'][0]
        self.assertEqual(card['name'], 'Qu Yuan')
        self.assertEqual(card['title'], 'Senior Physician')
        self.assertNotIn('expertise', card)
        self.assertNotIn('hit', card)

    def test_all_hospitals_and_doctors_have_english_display_data(self):
        for hid, hospital in R.HOSP.items():
            self.assertTrue(hospital['name_en'] or server.HOSPITAL_NAMES_EN[hid])
            self.assertIn(hospital['district'], server.DISTRICTS_EN)
        for doctor in R.DOCTORS:
            self.assertTrue(server.DOCTOR_NAMES_EN[doctor['doctor_id']])
            self.assertNotRegex(server.DOCTOR_NAMES_EN[doctor['doctor_id']], r'[\u3400-\u9fff]')

    def test_english_profile_values_are_accepted(self):
        form = dict(text='Knee pain', age=55, sex_at_birth='M', current_country='CN',
            pregnant='not_applicable', reply_language='en')
        self.assertEqual(server.clean(form), [])
        self.assertEqual(form['reply_language'], 'en')


if __name__ == '__main__':
    unittest.main()
