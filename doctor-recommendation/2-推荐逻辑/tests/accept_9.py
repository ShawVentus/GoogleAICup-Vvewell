"""需求文档 v2 第 8 节 9 条验收。需要真实模型：LLM_URL / LLM_MODEL 等环境变量（见 recommender.py::_gateway）。
python tests/accept_9.py"""
import os, sys, json, re
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import recommender as R

def run(text, age, sex="unknown", lang="zh"):
    return R.recommend({"text": text, "age": age, "sex_at_birth": sex, "current_country": "US", "reply_language": lang},
                       log_path=os.path.join(R.HERE, "logs", "accept.jsonl"))

def docs(o):
    return [(h["hospital_id"], d) for h in o.get("results", []) for d in h["doctors"]]

BAD = re.compile(r"最好|顶级|保证|收费|费用|价格|\bbest\b|\btop\b|guarantee|\bfee|\bprice|\bcost", re.I)
res = []
def check(n, name, ok, detail=""):
    res.append(ok); print(("PASS" if ok else "FAIL"), n, name, detail)

o1 = run("38 岁，B 超查出子宫肌瘤", 38, "F")
d1 = docs(o1)
check(1, "妇科/3家/肌瘤医生在前", o1["type"] == "doctor_recommendation" and len(o1["results"]) == 3 and o1["meta"]["wanted"][0] == "GYN"
      and "子宫肌瘤" in o1["results"][0]["doctors"][0]["expertise"], str([h["hospital_id"] for h in o1["results"]]))
o2 = run("慢性咳嗽 3 个月，夜里喘", 45)
check(2, "呼吸科医生", o2["type"] == "doctor_recommendation" and "RESP" in o2["meta"]["wanted"], str(o2["meta"]["wanted"]))
o3 = run("最近焦虑失眠", 30)
check(3, "精神心理科医生", o3["type"] in ("doctor_recommendation", "department_fallback") and o3["meta"]["wanted"][0] == "PSY", f'{o3["type"]} {o3["meta"]["wanted"]} {[d["name"] for _, d in docs(o3)]}')
o4 = run("确诊肺腺癌，想要治疗方案", 60)
check(4, "肿瘤+胸外都可出现", o4["type"] == "doctor_recommendation", f'{o4["meta"]["wanted"]} {[(h, d["dept_local"]) for h, d in docs(o4)]}')
o5 = run("我最近膝关节疼，上下楼梯加重", 55)
check(5, "膝关节（科室级兜底或骨科医生，3家）", len(o5.get("results", [])) == 3, f'{o5["type"]} {o5["meta"]["wanted"]}')
o6 = run("父亲胸口压榨样疼、出汗、喘不上气", 70, "M")
check(6, "急症不推荐", o6["type"] == "emergency" and "results" not in o6)
o7 = run("我8岁的儿子视力越来越差，看黑板看不清", 8, "M")
check(7, "儿童：医院都收儿童、医生非成人专科", o7["type"] == "doctor_recommendation", f'{o7["meta"]["wanted"]} {[d["dept_local"] for _, d in docs(o7)]}')
o8 = run("38 岁，B 超查出子宫肌瘤", 38, "F")
check(8, "同一输入结果相同", json.dumps(o1["results"], sort_keys=True) == json.dumps(o8["results"], sort_keys=True))
bad = [(i, BAD.findall(o["message"])) for i, o in enumerate([o1, o2, o3, o4, o5, o7], 1) if BAD.search(o["message"])]
check(9, "全文无禁用词", not bad, str(bad))
print(f"\n{sum(res)}/{len(res)} PASS")
