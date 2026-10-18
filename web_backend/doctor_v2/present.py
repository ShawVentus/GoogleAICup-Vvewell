"""把检索结果整理成「英文在上、中文在下」的结构化卡片（给聊天 AI、MCP、前端共用）。
不含任何擅长原文：病种对口只给匹配到的关键词。"""
import re, json
from pathlib import Path

# Romanized display names, not verified official English names.
DOCTOR_NAMES_EN = json.loads((Path(__file__).parent / "data/doctor_names_en.json").read_text())

TITLE_EN = [  # (正则, 英文)，按顺序取第一个命中
    (r"主任中医师", "Chief TCM Physician"),
    (r"二级主任医师", "Chief Physician (Grade 2)"),
    (r"(?<!副)主任医师", "Chief Physician"),
    (r"副顾问", "Associate Consultant"),
    (r"顾问", "Consultant"),
    (r"高级医生", "Senior Doctor"),
    (r"专科医生", "Specialist Doctor"),
]
EVID_LEVEL_EN = {"国家级": "National key clinical specialty (China)", "省级": "Guangdong provincial key clinical specialty",
                 "三甲专科医院本专科（规则，Shaw 已确认）": "Core specialty of a Grade 3A specialty hospital",
                 "市级": "Shenzhen municipal key specialty", "区级": "District-level key specialty",
                 "国家级（待核实）": "National key clinical specialty (China, pending verification)"}
DIST_EN = {"福田区": "Futian", "罗湖区": "Luohu", "南山区": "Nanshan", "宝安区": "Bao'an", "龙岗区": "Longgang", "龙华区": "Longhua",
           "光明区": "Guangming", "坪山区": "Pingshan", "盐田区": "Yantian", "大鹏新区": "Dapeng"}


def title_en(title):
    for pat, en in TITLE_EN:
        if re.search(pat, title):
            return en
    return "Physician"


def district_en(d):
    d = re.sub(r"[（(].*?[）)]", "", d or "")
    names = [v for k, v in DIST_EN.items() if k in d]
    return " / ".join(names) + " District" if names else ""


def _clean_zh(text):
    """去掉内部备注（如「（Shaw 提供，来源链接待补）」），不给患者看"""
    return re.sub(r"（Shaw[^）]*）", "", text or "").strip()


def cards(results, parsed, hosp, std, feature, show_evid_levels):
    """results: recommender.retrieve_doctors 的第一个返回值。返回可直接 JSON 化的 dict。"""
    p = parsed["depts"]["primary"]
    fk_en = dict(zip(parsed.get("focus_keywords") or [], parsed.get("focus_keywords_en") or []))
    out_h = []
    for h in results:
        H = hosp[h["hospital_id"]]
        ft = feature.get(h["hospital_id"])
        ev = h.get("evidence")
        recog = None
        if ev:
            lvl = EVID_LEVEL_EN.get(ev["evidence_level"], "")
            recog = {"en": f"{std[ev['std_dept_id']]['name_en']}: {lvl}", "zh": _clean_zh(ev["evidence_detail"])}
        docs = []
        for c in h["doctors"]:
            d = c["doctor"]
            docs.append({
                "doctor_id": d["doctor_id"], "name_zh": d["name"],
                "name_en": DOCTOR_NAMES_EN.get(d["doctor_id"], "Physician"),
                "title": {"en": title_en(d["title"]), "zh": d["title"]},
                "dept": {"en": std[c["std"]]["name_en"], "zh": d["dept_local"]},
                "matched": [{"en": fk_en.get(k, ""), "zh": k} for k in c["hit"]],
            })
        dept_only = None
        if not h["doctors"]:
            dept_only = {"en": std[h["std"]]["name_en"], "zh": h.get("dept_local") or std[h["std"]]["name_zh"]}
        out_h.append({"hospital_id": h["hospital_id"], "name_en": H["name_en"], "name_zh": H["name_zh"],
                      "district_en": district_en(H["district"]),
                      "feature": {"en": ft["feature_en"], "zh": ft["feature_zh"]} if ft else None,
                      "recognition": recog, "dept_only": dept_only, "doctors": docs})
    alts = parsed["depts"]["acceptable"]
    return {"department": {"en": std[p]["name_en"], "zh": std[p]["name_zh"]},
            "also_consider": [{"en": std[a]["name_en"], "zh": std[a]["name_zh"]} for a in alts],
            "hospitals": out_h}


def to_text(card):
    """English display text; original Chinese remains in structured catalog fields."""
    lines = [f"This kind of concern is usually handled by {card['department']['en']}. This is not a diagnosis."]
    if card["also_consider"]:
        lines.append("It may also involve: " + ", ".join(a["en"] for a in card["also_consider"]) + ".")
    for i, h in enumerate(card["hospitals"], 1):
        lines += ["", f"{i}. {h['name_en']}", f"   {h['district_en']}, Shenzhen"]
        for field, label in (("feature", "About"), ("recognition", "Recognition")):
            if h[field] and h[field]["en"]:
                lines.append(f"   {label}: {h[field]['en']}")
        if h["dept_only"]:
            lines.append(f"   Register with: {h['dept_only']['en']} - no matching doctor in our list")
        for d in h["doctors"]:
            lines.append(f"   - {d['name_en']} · {d['title']['en']} · {d['dept']['en']}")
            matches = [m["en"] for m in d["matched"] if m["en"]]
            if matches:
                lines.append("     Related to your concern: " + ", ".join(matches))
    lines += ["", "For reference only; it does not replace a doctor. Your care coordinator will help arrange the visit.",
              "Physician names are romanized and may differ from their preferred English spelling."]
    return "\n".join(lines)
