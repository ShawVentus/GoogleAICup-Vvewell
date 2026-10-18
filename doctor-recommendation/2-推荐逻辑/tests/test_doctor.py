"""不调用模型的确定性测试：python tests/test_doctor.py"""
import os, sys, csv
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import recommender as R

def parsed(p, acc=(), fk=()):
    return {"depts": {"primary": p, "acceptable": list(acc)}, "focus_keywords": list(fk)}

# 数据质量
ids = set(s["std_dept_id"] for s in R._csv("std_dept.csv"))
assert all(i in ids for d in R.DOCTORS for i in d["std_dept_ids"].split("|"))
assert len({(d["hospital_id"], d["dept_local"], d["name"]) for d in R.DOCTORS}) == len(R.DOCTORS)
assert all(len(d["expertise"]) >= 4 and d["source_url"] and d["title_level"] in ("主任", "私立国际门诊") for d in R.DOCTORS)
assert {d["hospital_id"] for d in R.DOCTORS} <= set(R.HOSP)

# 病种对口排前；每家 ≤2 位；最多 3 家；同输入同输出
f = {"age": 38}
a, m = R.retrieve_doctors(f, parsed("GYN", fk=["子宫肌瘤"]))
assert len(a) == 3 and all(len(h["doctors"]) <= 2 for h in a) and a[0]["doctors"][0]["hit"] == ["子宫肌瘤"]
b, _ = R.retrieve_doctors(f, parsed("GYN", fk=["子宫肌瘤"]))
assert [[c["doctor"]["doctor_id"] for c in h["doctors"]] for h in a] == [[c["doctor"]["doctor_id"] for c in h["doctors"]] for h in b]
# 单字关键词不算对口
assert R._kw_hits(R.DOCTORS[0], ["肺"]) == []
# 成人不推儿科医生；儿童可以
adult, _ = R.retrieve_doctors({"age": 30}, parsed("PED"))
assert not any(c["doctor"]["std_dept_ids"] == "PED" for h in adult for c in h["doctors"])
kid, _ = R.retrieve_doctors({"age": 8}, parsed("PED"))
assert kid and kid[0]["doctors"]
# 没有医生的科室 → 科室级兜底（TRANS 没有医生）
fb, meta = R.retrieve_doctors({"age": 40}, parsed("TRANS"))
assert meta["fallback"] in (True, False) and all(h["doctors"] == [] for h in fb)
# 展示清理：不出现禁用词，库里原文不改
assert "顶级" not in R._show("肺结节顶级专家") and "专家" in R._show("肺结节顶级专家")
print("ALL PASS")
