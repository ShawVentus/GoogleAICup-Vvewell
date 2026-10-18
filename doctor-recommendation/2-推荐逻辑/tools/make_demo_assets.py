"""用真实医生库生成 Flutter 预览用的演示数据（不调模型，解析结果写死）：python tools/make_demo_assets.py"""
import json, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import recommender as R

CASES = [
    dict(id="fibroid", q="38 岁，B 超查出子宫肌瘤", match=["肌瘤", "子宫", "月经", "妇科"], age=38, p="GYN", acc=[], fk=["子宫肌瘤"]),
    dict(id="anxiety", q="最近焦虑、睡不着，持续几周了", match=["焦虑", "失眠", "睡不着", "抑郁", "心情"], age=30, p="PSY", acc=["NEURO"], fk=["焦虑", "失眠"]),
    dict(id="cough", q="慢性咳嗽 3 个月，夜里喘", match=["咳嗽", "喘", "哮喘", "气管"], age=45, p="RESP", acc=[], fk=["慢性咳嗽"]),
    dict(id="lung", q="确诊肺腺癌，想要治疗方案", match=["肺癌", "肺腺癌", "癌", "肿瘤"], age=60, p="ONC", acc=["CTS", "RESP"], fk=["肺癌"]),
    dict(id="kid_eye", q="8 岁孩子近视越来越深", match=["近视", "视力", "眼"], age=8, p="OPH", acc=["PED"], fk=["近视"]),
    dict(id="knee", q="膝盖疼，上下楼梯加重", match=["膝", "关节", "骨", "腰"], age=55, p="ORTHO", acc=[], fk=["膝"]),
]
out = {"scenarios": [], "emergency": {"match": ["胸口", "压榨", "喘不上气", "昏迷", "抽搐", "大出血", "自杀"],
       "text": "您描述的情况可能需要立即处理。请立即拨打急救电话（美国 911 / 中国 120），或前往最近的急诊。不要等待。"}}
for c in CASES:
    parsed = {"depts": {"primary": c["p"], "acceptable": c["acc"]}, "focus_keywords": c["fk"]}
    res, meta = R.retrieve_doctors({"age": c["age"]}, parsed)
    hs = []
    for h in res:
        H = R.HOSP[h["hospital_id"]]
        hs.append({"name": H["name_zh"], "name_en": H["name_en"], "district": H["district"],
                   "evidence": h["evidence"]["evidence_detail"] if h["evidence"] else "",
                   "dept_only": None if h["doctors"] else (h.get("dept_local") or R.STD[h["std"]]["name_zh"]),
                   "doctors": [{"name": x["doctor"]["name"], "title": x["doctor"]["title"], "dept": x["doctor"]["dept_local"],
                                "expertise": R._show(x["doctor"]["expertise"]), "hit": x["hit"], "url": x["doctor"]["source_url"]}
                               for x in h["doctors"]]})
    names = [R.STD[c["p"]]["name_zh"]] + [R.STD[a]["name_zh"] for a in c["acc"]]
    out["scenarios"].append({"id": c["id"], "question": c["q"], "match": c["match"], "age": c["age"],
                             "dept": names[0], "alt": names[1:], "hospitals": hs})
p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "wewell_app", "assets", "demo.json")
json.dump(out, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print({s["id"]: [len(h["doctors"]) for h in s["hospitals"]] for s in out["scenarios"]})
