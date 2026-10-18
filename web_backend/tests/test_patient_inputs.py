import json
import unittest
from web_backend.doctor_v2 import agent, countries, server

class PatientInputsTest(unittest.TestCase):
    def test_sorted_practical_country_list(self):
        names = [v for k, v in countries.COUNTRY_NAMES.items() if k != 'OTHER']
        self.assertEqual(len(names), 30)
        self.assertEqual(names, sorted(names, key=str.casefold))
        self.assertEqual(list(countries.COUNTRY_NAMES)[-1], 'OTHER')
        self.assertTrue({'NZ','BR','MX','NL','AE','TH','VN'} <= countries.COUNTRY_NAMES.keys())

    def test_patient_fields_validated(self):
        body = {'messages': [{'role':'user', 'content':'hello'}]}
        self.assertEqual(server.validate_chat(dict(body, age=38, sex_at_birth='F'))[3:], (38,'F'))
        for age in [-1, 121, True, '38', []]:
            with self.assertRaises(ValueError): server.validate_chat(dict(body, age=age))
        for sex in ['female', 12, [], {}]:
            with self.assertRaises(ValueError): server.validate_chat(dict(body, sex_at_birth=sex))

    def test_selected_details_reach_tool_without_reasking(self):
        received = []
        def llm(messages, spec):
            self.assertIn('Patient age entered in the interface: 38', messages[0]['content'])
            self.assertIn('Sex at birth selected in the interface: F', messages[0]['content'])
            if messages[-1]['role']=='user':
                return {'tool_calls':[{'id':'c1','function':{'name':'recommend_hospitals_and_doctors', 'arguments':json.dumps({'age':99,'sex_at_birth':'M','current_country':'US'})}}]}
            return {'content':'Here are suitable options.'}
        def runner(name,args):
            received.append(args)
            return {'type':'chat','text':'OK'}
        agent.chat([{'role':'user','content':'Find doctors for fibroids'}], llm=llm, tool_runner=runner, age=38, sex_at_birth='F', current_country='NZ')
        self.assertEqual((received[0]['age'],received[0]['sex_at_birth'],received[0]['current_country']),(38,'F','NZ'))
