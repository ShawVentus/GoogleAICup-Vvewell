"""推荐算法工具：聊天 AI（agent.py）和 MCP 服务（mcp_server.py）共用同一份定义与实现。"""
import json, re, sys
from . import recommender as R
from . import present

RECOMMEND = {
    "name": "recommend_hospitals_and_doctors",
    "description": (
        "Recommend suitable hospitals from the available catalog, each with matching doctors, for a patient. "
        "Call this ONLY after the patient has asked for help choosing a hospital or doctor AND you know their problem, age, "
        "sex at birth and country. The tool parses the problem into a medical department, applies safety rules, and returns "
        "English hospital and doctor cards. It may instead return an emergency warning or a "
        "follow-up question; relay those to the patient faithfully. Never invent hospitals or doctors that the tool did not return."),
    "inputSchema": {
        "type": "object",
        "properties": {
            "description": {"type": "string", "description": "The patient's problem in their own words (English or Chinese), including duration and key symptoms mentioned so far."},
            "age": {"type": "integer", "minimum": 0, "maximum": 120, "description": "Patient age in years."},
            "sex_at_birth": {"type": "string", "enum": ["M", "F", "unknown"]},
            "current_country": {"type": "string", "description": "Where the patient lives now (ISO code such as US, or a country name). Used for the emergency number."},
            "hospital_id": {"type": "string", "enum": list(R.HOSP), "description": "Restrict to this hospital ONLY if the patient asks for a specific hospital. IDs: " + "; ".join(k + " " + h["name_en"] + " " + h["name_zh"] for k, h in R.HOSP.items())},
            "more_doctors": {"type": "boolean", "description": "True ONLY when the patient explicitly asks for more or different doctors for the same concern; excludes previously shown doctors."},
            "followup_answers": {"type": "string", "description": "Answer to a previous follow-up question from this tool, if any."},
        },
        "required": ["description", "age", "sex_at_birth", "current_country"],
    },
}
LIST_HOSPITALS = {
    "name": "list_hospitals",
    "description": "List the hospitals currently in the recommendation library with their English names, district, features and doctor counts. Use it when the patient asks which hospitals are covered.",
    "inputSchema": {"type": "object", "properties": {}},
}
TOOLS = [RECOMMEND, LIST_HOSPITALS]


def _norm_args(args):
    """模型填参数常常不严格（age 给字符串、性别写 Female、国家写全名），先规整再校验"""
    age = args.get("age")
    if isinstance(age, str):
        m = re.search(r"\d+", age); age = int(m.group()) if m else None
    elif isinstance(age, float):
        age = int(age)
    sex = str(args.get("sex_at_birth") or "").strip().lower()
    sex = "F" if sex in ("f", "female", "woman", "girl", "女", "女性") else "M" if sex in ("m", "male", "man", "boy", "男", "男性") else "unknown"
    country = str(args.get("current_country") or "").strip()
    if re.search(r"china|中国|^cn$|prc", country, re.I) and not re.search(r"hong kong|macau|taiwan", country, re.I):
        country = "CN"
    elif re.search(r"united states|usa|u\.s|america|^us$|美国", country, re.I):
        country = "US"
    return dict(args, age=age, sex_at_birth=sex, current_country=country or "OTHER")


def run(name, args, offline=False, log_path=None, progress=None):
    """返回 dict：{type, text, cards?, question?}。永远不抛异常给调用方（出错时 type='error'）。"""
    try:
        if name == "list_hospitals":
            cnt = {}
            for d in R.DOCTORS:
                cnt[d["hospital_id"]] = cnt.get(d["hospital_id"], 0) + 1
            hs = []
            for hid, n in sorted(cnt.items()):
                H = R.HOSP[hid]; ft = R.FEATURE.get(hid)
                hs.append({"name_en": H["name_en"], "name_zh": H["name_zh"], "district_en": present.district_en(H["district"]),
                           "feature_en": ft["feature_en"] if ft else None, "doctors_in_library": n})
            return {"type": "hospital_list", "hospitals": hs, "text": "\n".join(f"- {h['name_en']}, {h['district_en']}, {h['doctors_in_library']} doctors" for h in hs)}
        if name != RECOMMEND["name"]:
            return {"type": "error", "text": f"Unknown tool: {name}"}
        args = _norm_args(args)
        form = {"text": str(args.get("description", ""))[:4000], "age": args.get("age"), "sex_at_birth": args.get("sex_at_birth") or "unknown",
                "current_country": args.get("current_country") or "OTHER", "reply_language": "en"}
        hospital = args.get("hospital_id")
        if hospital and hospital not in R.HOSP:
            return {"type": "error", "text": "Unknown hospital. Ask the patient which hospital they mean."}
        form["hospital_id"] = hospital
        form["more_doctors"] = args.get("more_doctors") is True
        form["shown_doctor_ids"] = args.get("shown_doctor_ids", [])
        if args.get("followup_answers"):
            form["followup_answers"] = args["followup_answers"]
        if not form["text"].strip() or type(form["age"]) is not int or not 0 <= form["age"] <= 120:
            return {"type": "error", "text": "Invalid arguments: description must be non-empty and age must be an integer between 0 and 120. Ask the patient for the missing information."}
        kw = {"offline": offline, "intro": False, "progress": progress}
        if log_path:
            kw["log_path"] = log_path
        out = R.recommend(form, **kw)
        if out.get("warning") and not offline:   # 解析失败（模型超时/空回复）：再试一次
            out = R.recommend(form, **kw)
        if out.get("warning") and not offline:   # 离线关键词模式只用于测试，线上不给患者看
            sys.stderr.write("tool warning: upstream analysis unavailable\n")
            return {"type": "error", "text": "The analysis service is temporarily unavailable. Please try again shortly."}
        t = out["type"]
        if t == "emergency":
            return {"type": "emergency", "text": out["message"]}
        if t == "followup":
            return {"type": "followup", "question": out["question"], "text": out["question"]}
        if t in ("doctor_recommendation", "department_fallback") and not out["cards"]["hospitals"]:
            return {"type": "no_results", "text": "No additional matching doctors were found for these filters. Do not repeat previously shown doctors; ask whether to consider another hospital."}
        if t in ("doctor_recommendation", "department_fallback"):
            res = {"type": t, "cards": out["cards"], "text": out["message"]}
            if out.get("urgent_notice"):
                res["urgent_notice"] = out["urgent_notice"]
            return res
        return {"type": t, "text": out.get("message", "")}
    except Exception as e:  # 内部错误不泄露给患者
        return {"type": "error", "text": "The tool failed unexpectedly.", "detail": repr(e)[:200]}


def brief(res):
    """给聊天模型看的精简版（名字、科室、特色；不含长文本），防止模型编造或复述过多"""
    if res["type"] in ("doctor_recommendation", "department_fallback"):
        c = res["cards"]
        return json.dumps({
            "type": res["type"], "department": c["department"]["en"], "also_consider": [a["en"] for a in c["also_consider"]],
            "urgent_notice": res.get("urgent_notice"),
            "hospitals": [{"name_en": h["name_en"], "district": h["district_en"],
                           "feature": h["feature"]["en"] if h["feature"] else None,
                           "recognition": h["recognition"]["en"] if h["recognition"] else None,
                           "doctors": [{"name": d["name_en"], "title": d["title"]["en"], "department": d["dept"]["en"],
                                        "related_to_concern": [m["en"] for m in d["matched"] if m["en"]]} for d in h["doctors"]],
                           "department_only": h["dept_only"]["en"] if h["dept_only"] else None} for h in c["hospitals"]],
            "note": "The patient's screen already shows full hospital and doctor cards; summarize briefly, do not repeat every doctor."}, ensure_ascii=False)
    if res["type"] == "hospital_list":
        return json.dumps({"type": res["type"], "text": res["text"], "hospitals": [
            {k: v for k, v in h.items() if k != "name_zh"} for h in res["hospitals"]]}, ensure_ascii=False)
    return json.dumps({k: v for k, v in res.items() if k in ("type", "text", "question")}, ensure_ascii=False)
