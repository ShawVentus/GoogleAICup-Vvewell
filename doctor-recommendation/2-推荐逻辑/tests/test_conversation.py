import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import recommender as R
import server


class ConversationTest(unittest.TestCase):
    def parsed(self, **extra):
        return dict(depts={'primary': 'ONC', 'acceptable': []}, focus_keywords=['肺癌'], **extra)

    def test_more_from_named_hospital_excludes_previous_doctors(self):
        first, _ = R.retrieve_doctors({'age': 60}, self.parsed(hospital_id='SZ003'))
        shown = [c['doctor']['doctor_id'] for h in first for c in h['doctors']]
        self.assertTrue(shown)
        more, _ = R.retrieve_doctors({'age': 60, 'shown_doctor_ids': shown},
            self.parsed(hospital_id='SZ003', more_doctors=True))
        self.assertTrue(more)
        self.assertTrue(all(h['hospital_id'] == 'SZ003' for h in more))
        self.assertTrue(all(c['doctor']['doctor_id'] not in shown for h in more for c in h['doctors']))
        self.assertLessEqual(len(more[0]['doctors']), 6)

    def test_exhausted_named_hospital_never_fills_other_hospitals(self):
        shown = [d['doctor_id'] for d in R.DOCTORS if d['hospital_id'] == 'SZ003']
        rows, _ = R.retrieve_doctors({'age': 60, 'shown_doctor_ids': shown},
            self.parsed(hospital_id='SZ003', more_doctors=True))
        self.assertEqual(rows, [])

    def test_rejects_invalid_conversation(self):
        form = dict(text='更多', age=60, sex_at_birth='M', current_country='CN',
            conversation=[{'role': 'system', 'content': 'bad'}])
        self.assertIn('conversation', server.clean(form))

    def test_rejects_unknown_model_hospital(self):
        with self.assertRaises(ValueError):
            R.validate(self.parsed(hospital_id='not-in-database'))


if __name__ == '__main__':
    unittest.main()
