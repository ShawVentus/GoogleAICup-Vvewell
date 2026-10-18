"""
wewell 深圳第一版：患者描述 → 科室 → 医院 → 理由

流程：表单 + 原文 → ① 安全检查（关键词兜底）→ ② 解析（Gemini，或离线关键词兜底）
      → ③ 查库（标准科室精确匹配）→ ④ 排序（档位 + 证据 + 跨境 + 病情关键词）→ ⑤ 解释（模板，句句有出处）→ ⑥ 日志

只依赖 Python 标准库。Gemini 通过 HTTPS 直接调用，需要环境变量 GEMINI_API_KEY。
"""
import csv, json, os, re, time, uuid, urllib.request, urllib.error
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
VERSION = {"data": "sz-v1-2026-10-17", "prompt": "parse-v1", "rules": "rank-v1"}

# ---------------------------------------------------------------- 数据
def _csv(name):
    data_dir = os.path.join(HERE, "data")
    if not os.path.isdir(data_dir):
        data_dir = os.path.join(os.path.dirname(HERE), "3-数据")
    with open(os.path.join(data_dir, name), encoding="utf-8") as f:
        return list(csv.DictReader(f))

HOSP = {h["hospital_id"]: h for h in _csv("hospital.csv")}
DEPT_ROWS = _csv("hospital_dept.csv")
STD = {s["std_dept_id"]: s for s in _csv("std_dept.csv")}

ARCH_EN = {  # 类型字典：给美国患者的说法 + 固定注意文案
    "大学/教学综合医院": ("an academic / university teaching hospital", "China's \"Grade 3A\" rating is a government assessment of overall hospital capacity, not a quality ranking, and is not equivalent to U.S. CMS stars or accreditation."),
    "区域综合医院": ("a regional general hospital", "Being a general hospital does not mean every subspecialty has the same depth."),
    "妇幼保健院": ("a public maternal & children's hospital", "It also has public-health duties, so it is not identical to a U.S. women's hospital."),
    "儿童医院": ("a children's hospital", "Referral and age limits should be confirmed by department."),
    "肿瘤专科医院": ("a cancer specialty hospital", "This describes its clinical function only; it is not equivalent to an NCI-designated cancer center."),
    "心血管专科医院": ("a heart & vascular specialty hospital", "Comparable in function to a U.S. heart hospital; this is not a quality ranking."),
    "眼科专科医院": ("an eye hospital", "Inpatient and surgical scope cannot be inferred from the name alone."),
    "精神专科医院": ("a psychiatric hospital", "Mental-health law and privacy rules differ between China and the U.S."),
    "康复医院": ("a rehabilitation hospital", "Inpatient rehab and payment structures differ substantially."),
    "中医医院": ("a Traditional Chinese Medicine (TCM) hospital", "U.S. \"integrative care\" is not the same as a Chinese TCM hospital."),
    "私立妇产医院": ("a private women's & maternity hospital", "\"Built to Grade 3A standards\" is not the same as holding a Grade 3A rating."),
    "私立国际医院": ("a private international hospital", "Direct insurance billing must be confirmed case by case."),
}
EVID_EN = {"国家级": "national key clinical specialty (China)", "省级": "Guangdong provincial key clinical specialty",
           "三甲专科医院本专科（规则，Shaw 已确认）": "core specialty of a Grade 3A specialty hospital"}
DIST_EN = {"福田区": "Futian", "罗湖区": "Luohu", "南山区": "Nanshan", "宝安区": "Bao'an", "龙岗区": "Longgang", "龙华区": "Longhua",
           "光明区": "Guangming", "坪山区": "Pingshan", "盐田区": "Yantian", "大鹏新区": "Dapeng"}
def _dist_en(d):
    for k, v in DIST_EN.items():
        if d.startswith(k): return v + (" (multiple campuses)" if "多院区" in d else "")
    return d or "district to be confirmed"
CB_EN = {"E3": "has a dedicated international patient channel with published support services",
         "E2": "has at least one documented cross-border service",
         "E1": "offers standard registration only (no confirmed international channel)"}

# ---------------------------------------------------------------- ① 安全检查（关键词兜底，模型检查之外的第二道）
RED_FLAGS = [
    (r"chest (pain|pressure).{0,40}(breath|sweat|arm|jaw)|chest tightness.{0,40}(sweat|arm|jaw)|crushing chest|胸(口|部)?(痛|闷|压).{0,15}(喘|呼吸|出汗|左臂)", "疑似心梗"),
    (r"face (droop|drooping)|slurred speech|sudden(ly)? (weak|numb).{0,20}(arm|leg|side)|口角歪斜|说话不清|突然.{0,6}(无力|麻木)", "疑似卒中"),
    (r"can'?t breathe|cannot breathe|struggling to breathe|喘不上气|呼吸困难", "呼吸困难"),
    (r"suicid|kill myself|end my life|self[- ]harm|不想活|自杀|自残", "自伤风险"),
    (r"(heavy|severe|uncontrolled) bleeding|大出血|血流不止", "大出血"),
    (r"seizure|convulsion|抽搐|癫痫发作", "抽搐"),
    (r"anaphyla|throat (is )?(swelling|closing)|喉咙肿|严重过敏", "严重过敏"),
    (r"pregnan.{0,30}bleed|孕.{0,10}出血", "孕期出血"),
    (r"worst headache|thunderclap|突发剧烈头痛|最剧烈的头痛", "突发剧烈头痛"),
    (r"(took|taken|swallowed|ingested|drank)\s+(an?\s+)?(overdose|too many|too much|a whole bottle|the whole bottle)|\b(i|he|she|they|we|(my|our) \w+)\s+(have\s+|had\s+|just\s+)?overdosed\b|swallowed (bleach|poison|detergent)|药物过量|过量服用|服毒|误服.{0,6}(药|农药|毒)", "服药过量或中毒"),
    (r"\\bunconscious\\b|passed out and|not waking|昏迷|意识不清", "意识改变"),
]
# 命中词附近出现这些「已知/已控制/经期」语境时不按急症拦截（交给模型判断）；出现 ACUTE 里的词则仍拦截
ACUTE = re.compile(r"(right now|just (had|started)|currently (having|seizing)|suddenly|sudden|minutes ago|ongoing|此刻|刚刚|突然|正在)", re.I)
BENIGN_CTX = {
    "抽搐": re.compile(r"(epilep|seizure[- ]free|without seizures|myoclonic|anticonvuls|seizure (medic|drug)|levetiracetam|癫痫|控制)", re.I),
    "大出血": re.compile(r"(period|menses|menstru|fibroid|月经|肌瘤)", re.I),
}
PAST = re.compile(r"(last (week|month|year)|years? ago|months? ago|已经好了|上周|去年|resolved|went away)", re.I)

FLAG_EN = {"疑似心梗": "possible heart attack", "疑似卒中": "possible stroke", "呼吸困难": "trouble breathing", "自伤风险": "risk of self-harm",
           "大出血": "heavy bleeding", "抽搐": "seizure", "严重过敏": "severe allergic reaction", "孕期出血": "bleeding in pregnancy",
           "突发剧烈头痛": "sudden severe headache", "意识改变": "altered consciousness", "服药过量或中毒": "possible overdose or poisoning"}

def safety_check(text):
    """只有「命中词附近」出现既往/已缓解的说法才放行（整段文字里有 last year 不算）；自伤风险永远拦截"""
    hits, live = [], []
    for rx, label in RED_FLAGS:
        for m in re.finditer(rx, text, re.I):
            hits.append(label)
            near = text[max(0, m.start() - 60): m.end() + 60]
            benign = BENIGN_CTX.get(label)
            if benign and benign.search(near) and not ACUTE.search(near):
                continue
            if label == "自伤风险" or not PAST.search(near):
                live.append(label)
    hits, live = list(dict.fromkeys(hits)), list(dict.fromkeys(live))
    if hits and not live:
        return {"flag": False, "rules": hits, "note": "命中危险词但描述为既往/已缓解，交给模型判断"}
    return {"flag": bool(live), "rules": live, "note": ""}

# ---------------------------------------------------------------- ①b 第二意见：独立的紧急程度判断（不同提示词、可换模型），失败则忽略
SECOND_SYSTEM = ("You are a triage nurse reviewing a message from a patient abroad. Decide how urgent the situation is RIGHT NOW, based only on the text. "
                 "Reply JSON only: {\"level\": \"emergency|urgent|none\", \"reason\": \"one sentence quoting the text\"}. "
                 "emergency = should call an ambulance / go to the emergency department now (e.g. chest pain with sweating or breathlessness, stroke signs, "
                 "loss of consciousness, seizure happening, severe bleeding, anaphylaxis, severe breathing difficulty, suicidal intent, sudden worst headache). "
                 "urgent = serious or could worsen, should see a doctor within 24-72 hours, but not an emergency this minute (e.g. spreading infection or abscess with swelling, "
                 "fever for days, new fast irregular heartbeat with symptoms, fainting episode already over, a seriously ill relative already in hospital). "
                 "none = routine, chronic, stable, past/resolved, or just information seeking. When unsure between two levels, choose the more urgent one.")
RANK = {"none": 0, "urgent": 1, "emergency": 2}

def _model_json(raw):
    if not isinstance(raw, str):
        raise ValueError("模型未返回文本")
    raw = raw.strip()
    # 代理可能把推理文字放在最终 JSON 前；只接受完整对象及空白/结束代码框。
    start = raw.find("{")
    if start < 0:
        raise ValueError("模型未返回 JSON 对象")
    value, end = json.JSONDecoder().raw_decode(raw[start:])
    if raw[start + end:].strip() not in ("", "```"):
        raise ValueError("模型返回了额外或不完整的数据")
    if not isinstance(value, dict):
        raise ValueError("模型返回的不是 JSON 对象")
    return value

def danger_second_opinion(form):
    url, key, _m = _gateway()
    if not key or os.environ.get("DANGER_SECOND_OPINION", "1") == "0":
        return None
    model = os.environ.get("DANGER_MODEL_2") or (_m if os.environ.get("GEMINI_URL") else "gpt-5.6-terra" if os.environ.get("LLM_URL") else "google/gemini-2.5-flash-lite")
    user = json.dumps({"text": form["text"], "age": form.get("age"), "followup_answers": form.get("followup_answers"), "conversation": form.get("conversation", [])}, ensure_ascii=False)
    for attempt in range(2):
        try:
            out = _post_json(url, {"model": model, "temperature": 0, "max_tokens": 8192, "reasoning_effort": "low", "response_format": {"type": "json_object"},
                                   "messages": [{"role": "system", "content": SECOND_SYSTEM}, {"role": "user", "content": user}]},
                             {"Authorization": "Bearer " + key})
            r = _model_json(out["choices"][0]["message"]["content"])
            if isinstance(r, dict) and r.get("level") in RANK:
                return {"level": r["level"], "reason": str(r.get("reason", ""))[:300], "model": model}
            return None
        except (urllib.error.URLError, OSError, KeyError, IndexError, TypeError, ValueError) as e:
            if attempt == 1:
                return None
            if "HTTP 429" in str(e):
                m = re.search(r"[Rr]etry after (\d+)s", str(e)); time.sleep(min(int(m.group(1)) + 1, 5) if m else 5)
            elif "HTTP 4" in str(e):
                return None
            else:
                time.sleep(2)
    return None

URGENT_EN = "Based on what you described, we recommend seeing a doctor in the next 1–3 days (sooner if it gets worse). If your condition changes suddenly, call {num} or go to the nearest emergency department. The hospitals below are for follow-up care in Shenzhen."
URGENT_ZH = "根据您的描述，建议在未来 1–3 天内就医（加重请更早）。如果情况突然变化，请立即拨打 {num} 或去最近的急诊。下面的医院是在深圳的后续就诊选择。"
def urgent_notice(form, lang):
    in_cn = (form.get("current_country") or "US").upper() in ("CN", "CHINA")
    return (URGENT_EN if lang == "en" else URGENT_ZH).format(num="120" if in_cn else "911")

# ---------------------------------------------------------------- ② 解析
def _std_table():
    return "\n".join(f"{s['std_dept_id']} {s['name_zh']}：包含 {s['includes']}；不包含 → {s['excludes_to']}" for s in STD.values())

def _load_env():
    """读 .env（容忍等号两边有空格）；不覆盖已有环境变量"""
    paths = [os.path.join(d, ".env") for d in (os.getcwd(), HERE, os.path.dirname(HERE))]
    if os.environ.get("ENV_FILE"):
        paths.insert(0, os.environ["ENV_FILE"])
    for path in paths:
        if not os.path.isfile(path):
            continue
        for line in open(path, encoding="utf-8"):
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip().strip("\"'"))
_load_env()

def _post_json(url, body, headers):
    req = urllib.request.Request(url, data=json.dumps(body).encode(), headers={"Content-Type": "application/json", **headers})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:  # 把服务端的错误原因带出来（如免费档 403），不含 key
        detail = e.read().decode("utf-8", "replace")[:400]
        raise OSError(f"HTTP {e.code}: {detail}")

def _gateway():
    """(url, key, 默认模型)。设了 LLM_URL 就走自定义 OpenAI 兼容服务（key 取 LLM_API_KEY 或 API_KEY，模型取 LLM_MODEL）；否则走 Vercel AI Gateway"""
    if os.environ.get("LLM_URL"):
        return (os.environ["LLM_URL"], os.environ.get("LLM_API_KEY") or os.environ.get("API_KEY"), os.environ.get("LLM_MODEL", "gpt-5.6-luna"))
    if os.environ.get("GEMINI_URL") and os.environ.get("GEMINI_API"):
        return (os.environ["GEMINI_URL"].rstrip("/") + "/v1/chat/completions", os.environ["GEMINI_API"], os.environ.get("GEMINI_MODEL", "gemini-3.8-flash"))
    return (os.environ.get("AI_GATEWAY_URL", "https://ai-gateway.vercel.sh/v1/chat/completions"), os.environ.get("AI_GATEWAY_API_KEY"), "google/gemini-2.5-flash")

def parse_gemini(form, model=None, api_key=None):
    """优先走 Vercel AI Gateway（AI_GATEWAY_API_KEY，OpenAI 兼容）；没有时回退 Google 原生接口（GEMINI_API_KEY）"""
    gw_url, gw_key, gw_model = _gateway()
    gw_key = api_key or gw_key
    g_key = os.environ.get("GEMINI_API_KEY")
    if not gw_key and not g_key:
        raise RuntimeError("没有 AI_GATEWAY_API_KEY 或 GEMINI_API_KEY")
    default_model = gw_model if gw_key else "gemini-2.5-flash"
    model = model or (os.environ.get("LLM_MODEL") if os.environ.get("LLM_URL") else os.environ.get("GEMINI_MODEL")) or default_model
    with open(os.path.join(HERE, "prompts", "parse_system.txt"), encoding="utf-8") as prompt:
        system = prompt.read().replace("{STD_TABLE}", _std_table())
    system += "\n【医院编号】\n" + "\n".join(f"{hid}: {h['name_zh']} ({h['name_en']})" for hid, h in HOSP.items())
    user = json.dumps({k: form.get(k) for k in ("text", "age", "sex_at_birth", "pregnant", "followup_answers", "conversation")}, ensure_ascii=False)
    if form.get("reply_language"):  # 网页传入；评测用例不带，提示词保持不变
        system += "\n\n【输出语言】reason、danger.reason 和 followup_question 必须用「" + ("English" if form["reply_language"] == "en" else "中文") + "」书写。"
    last = None
    use_rf = True  # 回复为空时，下一次去掉 response_format 再试（个别服务在 JSON 模式下会返回空）
    for attempt in range(2):
        try:
            if gw_key:
                url = gw_url
                body = {"model": model, "temperature": 0, "max_tokens": 8192, "reasoning_effort": "low",
                        "messages": [{"role": "system", "content": system}, {"role": "user", "content": user}]}
                if use_rf: body["response_format"] = {"type": "json_object"}
                out = _post_json(url, body, {"Authorization": "Bearer " + gw_key})
                raw = out["choices"][0]["message"]["content"]
            else:
                body = {"systemInstruction": {"parts": [{"text": system}]},
                        "contents": [{"role": "user", "parts": [{"text": user}]}],
                        "generationConfig": {"temperature": 0, "responseMimeType": "application/json"}}
                out = _post_json(f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent", body, {"x-goog-api-key": g_key})
                raw = out["candidates"][0]["content"]["parts"][0]["text"]
            if not (raw or "").strip():
                use_rf = False
            parsed = _model_json(raw)
            return parsed, {"engine": "gemini", "model": model, "raw": raw}
        except (urllib.error.URLError, OSError, KeyError, IndexError, TypeError, ValueError) as e:  # 含读超时、被安全策略拦截（无 candidates）
            last = e
            if attempt == 1:
                break
            if "HTTP 429" in str(e):  # 限制退避时间，避免后端重试超过前端等待窗口
                m = re.search(r"[Rr]etry after (\d+)s", str(e))
                time.sleep(min(int(m.group(1)) + 1, 5) if m else 5)
            elif "HTTP 4" in str(e):
                break  # 其他 4xx（如 403 免费档不可用）重试没有意义
            else:
                time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"Gemini 调用失败：{last}")

# 离线兜底：只用于没有 API 时演示流水线，准确度远低于大模型
KW = [
    ("ONC", r"cancer|tumou?r.{0,10}malignan|carcinoma|lymphoma|leukemia|metasta|chemo|radiotherapy|癌|恶性|淋巴瘤|白血病|化疗|放疗|转移"),
    ("OB", r"pregnan|prenatal|weeks pregnant|怀孕|孕\d|产检|孕期"),
    ("REPRO", r"infertil|ivf|can'?t (get|become) pregnant|egg freez|不孕|试管|冻卵|备孕"),
    ("GYN", r"\bperiods?\b|menstru|uterine|fibroid|ovar|cervi|menopaus|pelvic floor|月经|子宫|肌瘤|卵巢|宫颈|更年期|白带"),
    ("PSY", r"anxiety|depress|insomnia|panic|bipolar|adhd|焦虑|抑郁|失眠|双相|多动"),
    ("OPH", r"\beyes?\b|vision|cataract|glaucoma|retina|myopi|nearsight|short-?sight|glasses|眼|视力|白内障|青光眼|近视"),
    ("DENT", r"tooth|teeth|dental|gum|implant|orthodont|牙|口腔|种植|正畸"),
    ("ENT", r"\bears?\b|hearing|tinnitus|\bsinus|\bnose\b|\bthroat\b|snor|耳|听力|鼻|咽|打鼾"),
    ("DERM", r"\brash|eczema|acne|psoria|skin|mole|皮疹|湿疹|痘|银屑|皮肤|痣"),
    ("CTS", r"bypass|valve (replacement|surgery)|lung surgery|thoracic surg|搭桥|瓣膜|胸外"),
    ("CARD", r"palpitat|arrhythm|hypertension|high blood pressure|\bheart\b(?!burn)|chest (pain|tight)|心悸|心律|高血压|心脏|胸闷|胸痛"),
    ("RESP", r"\bcough|asthma|copd|lung nodule|wheez|咳|哮喘|慢阻肺|肺结节|气喘"),
    ("GI", r"stomach|acid reflux|heartburn|diarrh|constipat|colonoscop|bloat|胃|反酸|腹泻|便秘|肠镜|胃镜|腹胀"),
    ("GS", r"hernia|gallstone|gallbladder|appendi|thyroid nodule|breast lump|hemorrhoid|疝|胆结石|胆囊|阑尾|甲状腺结节|乳腺|痔"),
    ("URO", r"kidney stone|prostat|urinat|erectile|肾结石|前列腺|尿频|尿急|阳痿"),
    ("NEPH", r"kidney (function|disease)|protein in urine|dialysis|肾功能|蛋白尿|透析|肾炎"),
    ("ENDO", r"diabet|thyroid|blood sugar|osteopor|糖尿病|甲状腺|血糖|骨质疏松"),
    ("NSURG", r"brain tumou?r|aneurysm|hydroceph|脑瘤|动脉瘤|脑积水"),
    ("NEURO", r"headache|migraine|dizz|parkinson|memory|numbness|tremor|头痛|偏头痛|头晕|帕金森|记忆|手抖"),
    ("ORTHO", r"knee|\bhip\b|back pain|spine|scoliosis|fracture|shoulder|joint|herniated disc|膝|髋|腰痛|脊柱|侧弯|骨折|肩|关节|腰椎间盘|颈椎"),
    ("RHEUM", r"lupus|rheumatoid|gout|ankylos|红斑狼疮|类风湿|痛风|强直"),
    ("INF", r"hepatitis|tubercul|\bhiv\b|fever of unknown|肝炎|乙肝|结核|艾滋"),
    ("HEME", r"anemi|platelet|bleeding disorder|贫血|血小板"),
    ("REHAB", r"rehab|after stroke recovery|physical therapy|康复"),
    ("TCM", r"acupunct|traditional chinese|\btcm\b|herbal|针灸|中医|推拿"),
    ("PAIN", r"chronic pain|neuralgia|shingles pain|慢性疼痛|神经痛"),
]
FOCUS_KW = r"(子宫肌瘤|白内障|青光眼|脊柱侧弯|肺结节|甲状腺结节|乳腺|胃肠|肝|卒中|近视|不孕|fibroid|cataract|glaucoma|scoliosis|lung nodule|thyroid nodule|breast|stroke|infertility)"
FOCUS_ZH = {"fibroid": "子宫肌瘤", "cataract": "白内障", "glaucoma": "青光眼", "scoliosis": "脊柱侧弯", "lung nodule": "肺结节",
            "thyroid nodule": "甲状腺", "breast": "乳腺", "stroke": "卒中", "infertility": "不孕"}

def parse_offline(form):
    t = form["text"]
    hits = []
    for sid, rx in KW:
        if re.search(rx, t, re.I) and sid not in hits:
            hits.append(sid)
    age = form.get("age")
    if "ONC" in hits:  # 方案 C：肿瘤首选 ONC，器官科室放也合理
        hits = ["ONC"] + [h for h in hits if h != "ONC"]
    if age is not None and age < 14:
        organ = {"OPH", "DENT", "DERM", "PSY"}
        if hits and hits[0] in organ:
            hits = [hits[0], "PED"] + hits[1:]
        else:
            hits = ["PED"] + hits
    if form.get("sex_at_birth") == "M":
        hits = [h for h in hits if h not in ("GYN", "OB")]
    if not hits:
        hits = ["GP"]
    fk = [FOCUS_ZH.get(m.lower(), m) for m in re.findall(FOCUS_KW, t, re.I)]
    return ({"danger": {"flag": False, "evidence": "", "reason": "离线模式只用关键词规则"},
             "symptoms": [], "depts": {"primary": hits[0], "acceptable": hits[1:3]},
             "focus_keywords": list(dict.fromkeys(fk)), "confidence": "low",
             "need_followup": hits == ["GP"], "followup_question": "", "reason": "离线关键词匹配（仅演示用）"},
            {"engine": "offline-keywords"})

def validate(parsed):
    d = parsed.get("depts") if isinstance(parsed.get("depts"), dict) else {}
    p = d.get("primary")
    acc = [a for a in (d.get("acceptable") or []) if isinstance(a, str) and a in STD and a != p][:2]
    if p not in STD:
        p = acc.pop(0) if acc else None
    parsed["depts"] = {"primary": p, "acceptable": acc}
    dg = parsed.get("danger") if isinstance(parsed.get("danger"), dict) else {}
    lvl = dg.get("level") if dg.get("level") in ("emergency", "urgent", "none") else ("emergency" if dg.get("flag") else "none")
    dg["level"] = lvl; dg["flag"] = lvl == "emergency"  # flag 只表示「此刻急症、要拦截」
    parsed["danger"] = dg
    hospital_id = parsed.get("hospital_id")
    if hospital_id is not None and hospital_id not in HOSP:
        raise ValueError("模型返回未知医院编号")
    if type(parsed.get("more_doctors", False)) is not bool:
        raise ValueError("更多医生字段格式错误")
    return parsed

# ---------------------------------------------------------------- ③④ 查库 + 排序
def _age_mismatch(local, age):
    """按年龄排除不对口的官网科室：1 岁以上不给新生儿科；18 岁以上不给儿科类科室"""
    if age is None:
        return False
    if age >= 1 and "新生儿" in local:
        return True
    return age >= 18 and bool(re.search(r"儿少|小儿|儿童|儿科|儿外|儿保|儿内", local))

def _age_ok(h, age):
    if age is None:
        return True
    mn = int(h["min_age"] or 0); mx = int(h["max_age"]) if h["max_age"] else 200
    return mn <= age <= mx

# ---------------------------------------------------------------- ④ 医生级检索与排序（需求文档 v2 第 5 节）
DOCTORS = _csv("doctor.csv")
DOC_STD = {d["doctor_id"]: d["std_dept_ids"].split("|") for d in DOCTORS}
VERSION["data"] = "sz-doctor-v1-2026-10-18"; VERSION["rules"] = "doctor-rank-v1"
TOP_EVID = ("国家级", "省级")        # 排序第 3 级：国家级、省级认定优先，其余其次
SHOW_EVID = ("国家级", "省级", "市级", "区级", "国家级（待核实）")
N_HOSP, N_DOC = 3, 2
CHILD_ONLY = re.compile(r"儿")

def _evidence(hid, std):
    """该院某标准科室的最高科室认定；没有则 None"""
    best = None
    for r in DEPT_ROWS:
        if r["hospital_id"] == hid and r["std_dept_id"] == std and r["evidence_level"] in SHOW_EVID:
            if best is None or (r["evidence_level"] in TOP_EVID and best["evidence_level"] not in TOP_EVID):
                best = r
    return best

def _doctor_age_ok(d, age):
    if age is None:
        return True
    if age >= 18 and d["std_dept_ids"] == "PED":   # 成人不推只看儿科的医生
        return False
    return not _age_mismatch(d["dept_local"], age)

def _kw_hits(d, fks):
    text = d["expertise"] + "|" + d["dept_local"]
    return [f for f in fks if len(f) >= 2 and f in text]   # 单字（如「肺」）太泛，不算病种对口

def retrieve_doctors(form, parsed):
    p = parsed["depts"]["primary"]; acc = parsed["depts"]["acceptable"]
    wanted = ([p] if p else []) + acc
    fks = parsed.get("focus_keywords") or []
    age = form.get("age")
    hospital_id = parsed.get("hospital_id")
    more = parsed.get("more_doctors", False)
    excluded = set(form.get("shown_doctor_ids", [])) if more else set()
    cands = []
    for d in DOCTORS:
        if (hospital_id and d["hospital_id"] != hospital_id) or d["doctor_id"] in excluded:
            continue
        ids = DOC_STD[d["doctor_id"]]
        if not set(ids) & set(wanted):
            continue
        if not _age_ok(HOSP[d["hospital_id"]], age) or not _doctor_age_ok(d, age):
            continue
        hit = _kw_hits(d, fks)
        use = p if p in ids else next(i for i in ids if i in wanted)   # 用来查科室认定的标准科室
        ev = _evidence(d["hospital_id"], use)
        key = (-len(hit), 0 if ids[0] == p else 1 if p in ids else 2,   # 科室名直接归到首选科室 > 仅擅长里提到（如附加的肿瘤科）> 也合理科室
                0 if ev and ev["evidence_level"] in TOP_EVID else 1, d["doctor_id"])
        cands.append({"doctor": d, "key": key, "hit": hit, "std": use, "evidence": ev})
    cands.sort(key=lambda c: c["key"])
    groups = {}
    for c in cands:                       # 医院名次 = 它最靠前那位医生的名次
        groups.setdefault(c["doctor"]["hospital_id"], []).append(c)
    hosp = [{"hospital_id": hid, "doctors": cs[:6 if more else N_DOC], "evidence": cs[0]["evidence"], "std": cs[0]["std"]}
            for hid, cs in groups.items()][:N_HOSP]
    meta = {"wanted": wanted, "n_candidates": len(cands), "fallback": False}
    # 兜底：没有医生，或医院不足 3 家 → 补科室级推荐（只有挂号科室，没有医生）
    if len(hosp) < N_HOSP and not hospital_id and not more:
        meta["fallback"] = not hosp
        have = {h["hospital_id"] for h in hosp}
        rows = {}
        for r in DEPT_ROWS:
            h = r["hospital_id"]
            if h in have or r["std_dept_id"] not in wanted or h not in {x["hospital_id"] for x in DOCTORS}:
                continue
            if not _age_ok(HOSP[h], age) or _age_mismatch(r["local_dept_name"], age):
                continue
            sc = (0 if r["std_dept_id"] == p else 1, 0 if r["evidence_level"] in TOP_EVID else 1, h)
            if h not in rows or sc < rows[h][0]:
                rows[h] = (sc, r)
        for h, (sc, r) in sorted(rows.items(), key=lambda x: x[1][0]):
            if len(hosp) >= N_HOSP:
                break
            hosp.append({"hospital_id": h, "doctors": [], "evidence": _evidence(h, r["std_dept_id"]), "std": r["std_dept_id"],
                         "dept_local": r["local_dept_name"]})
    return hosp, meta

# ---------------------------------------------------------------- ⑤ 解释（模板：每句话都来自库里的字段；禁止评价医生好坏、承诺约到、提收费）
SHOW_SUB = [("顶级专家", "专家"), ("顶级", ""), ("保证", "确保"), ("最佳", "优质"), ("最好", "较好"), ("收费", "收取"), ("费用", "开支")]
def _show(text):
    """展示时的措辞清理（库里的擅长原文不改）：医生自称「顶级」等词不转述，需求第 6 节禁止评价医生好坏"""
    for a, b in SHOW_SUB:
        text = text.replace(a, b)
    return text

def explain(form, parsed, results, meta, lang="en"):
    p = parsed["depts"]["primary"]; acc = parsed["depts"]["acceptable"]
    zh = lang != "en"
    if not results:
        return "深圳的医院库里暂时没有找到合适的医生，顾问会跟进。" if zh else "We could not find a suitable doctor in our Shenzhen list for this need yet. A care coordinator will follow up with you."
    names_zh = "、".join(STD[x]["name_zh"] for x in [p] + acc)
    if zh:
        lines = [f"根据您的描述，这类情况一般看{STD[p]['name_zh']}" + (f"（也可能涉及{'、'.join(STD[a]['name_zh'] for a in acc)}）" if acc else "") + "。这不是诊断。\n"]
    else:
        alt = "".join(f" (it may also involve {STD[a]['name_en']})" for a in acc[:1])
        lines = [f"Based on what you described, this is usually handled by {STD[p]['name_en']} ({STD[p]['name_zh']}){alt}. This is not a diagnosis.\n"]
    for i, h in enumerate(results, 1):
        H = HOSP[h["hospital_id"]]
        name = H["name_zh"] + (f" ({H['name_en']})" if H["name_en"] else "")
        ev = h["evidence"]
        evtxt = ev["evidence_detail"] if ev and ev["evidence_detail"] else ""
        lines.append(f"{i}. {name}" + (f" — {_dist_en(H['district'])}, Shenzhen" if not zh else f"（深圳{H['district']}）"))
        if evtxt:
            lines.append(("   · 科室认定：" if zh else "   • Department recognition: ") + evtxt)
        if not h["doctors"]:
            dept = h.get("dept_local") or STD[h["std"]]["name_zh"]
            lines.append((f"   · 挂号科室：{dept}（本次库里没有与您情况对口的医生，仅给科室）" if zh else
                          f"   • Register with: {dept} ({STD[h['std']]['name_en']}) — no matching doctor in our list; department only."))
        for c in h["doctors"]:
            d = c["doctor"]
            lines.append(f"   {'·' if zh else '•'} {d['name']}｜{d['title'].split('｜')[0]}｜{d['dept_local']}")
            lines.append(("      擅长：" if zh else "      Expertise (as published): ") + _show(d["expertise"]))
            if c["hit"]:
                lines.append(("      与您的情况相关：" if zh else "      Related to your concern: ") + "、".join(c["hit"]))
    num = "120" if zh and (form.get("current_country") or "").upper() in ("CN", "CHINA") else "911"
    lines.append("\n仅供参考，不能代替医生；顾问会协助安排就诊。如出现急症，在美国请拨 911，在中国内地请拨 120。" if zh else
                 "\nFor reference only; it does not replace a doctor. Your care coordinator will help arrange the visit. "
                 "If this becomes an emergency, call 911 (in the U.S.) or 120 (in mainland China).")
    return "\n".join(lines)

# ---------------------------------------------------------------- 总入口 + ⑥ 日志
def recommend(form, offline=False, log_path=os.path.join(HERE, "logs", "runs.jsonl")):
    rid = uuid.uuid4().hex[:12]
    rec = {"id": rid, "time": time.strftime("%Y-%m-%dT%H:%M:%S"), "version": VERSION, "form": form}
    lang = form.get("reply_language", "en")
    safe = safety_check(form["text"] + "\n" + form.get("followup_answers", ""))
    rec["safety_rules"] = safe
    if safe["flag"]:
        out = {"type": "emergency", "message": _emergency(form, safe["rules"], lang)}
    else:
        second = None
        try:
            if offline:
                parsed, eng = parse_offline(form)
            else:  # 主解析与第二意见并行
                with ThreadPoolExecutor(2) as ex:
                    f2 = ex.submit(danger_second_opinion, form)
                    try:
                        parsed, eng = parse_gemini(form)
                    finally:
                        second = f2.result()
        except RuntimeError as e:
            parsed, eng = parse_offline(form); eng["fallback_reason"] = str(e)
        parsed = validate(parsed)
        rec["parse"] = parsed; rec["engine"] = eng; rec["second_opinion"] = second
        level = parsed["danger"]["level"]
        if second and RANK[second["level"]] > RANK[level]:
            level = second["level"]
        rec["danger_level"] = level
        if level == "emergency":
            why = parsed["danger"].get("reason") if parsed["danger"]["level"] == "emergency" else second["reason"]
            out = {"type": "emergency", "message": _emergency(form, [why or ""], lang)}
        elif parsed.get("need_followup") and parsed.get("followup_question") and not form.get("followup_answers"):
            out = {"type": "followup", "question": parsed["followup_question"]}
        elif not parsed["depts"]["primary"]:
            out = {"type": "no_department", "message": parsed.get("reason", "")}
        else:
            results, meta = retrieve_doctors(form, parsed)
            rec["rank_meta"] = meta
            rec["results"] = [{"hospital_id": h["hospital_id"], "std": h["std"], "evidence": h["evidence"]["evidence_detail"] if h["evidence"] else None,
                               "doctors": [{"doctor_id": c["doctor"]["doctor_id"], "name": c["doctor"]["name"], "title": c["doctor"]["title"].split("｜")[0],
                                            "dept_local": c["doctor"]["dept_local"], "expertise": c["doctor"]["expertise"], "matched_keywords": c["hit"]}
                                           for c in h["doctors"]]} for h in results]
            out = {"type": "department_fallback" if meta["fallback"] else "doctor_recommendation", "results": rec["results"], "meta": meta,
                   "message": explain(form, parsed, results, meta, lang)}
            if not results:
                name = HOSP[parsed["hospital_id"]]["name_zh"] if parsed.get("hospital_id") else "当前医生库"
                message = f"{name}中暂无符合本次情况的医生。"
                if parsed.get("more_doctors"):
                    message = f"{name}中暂无更多符合本次情况的医生。已展示过的医生不会重复推荐。"
                if lang == 'en':
                    name = HOSP[parsed['hospital_id']]['name_en'] if parsed.get('hospital_id') else 'Our doctor directory'
                    message = f"No {'additional ' if parsed.get('more_doctors') else ''}matching doctors were found{' at ' + name if name else ' at this hospital'}."
                out.update(type="no_results", message=message)
    if rec.get("danger_level") == "urgent" and out["type"] in ("doctor_recommendation", "department_fallback", "followup", "no_department", "no_results"):
        out["urgent_notice"] = urgent_notice(form, lang)
    eng = rec.get("engine", {})
    out["engine"] = eng.get("engine", "rules-only")
    if eng.get("fallback_reason"):
        out["warning"] = f"Gemini 未调用成功（{eng['fallback_reason']}），本次用离线关键词兜底，准确度低，不要给患者看"
    elif eng.get("engine") == "offline-keywords":
        out["warning"] = "离线关键词模式（仅演示），准确度低，不要给患者看"
    rec["output_type"] = out["type"]
    rec["n_candidates"] = (rec.get("rank_meta") or {}).get("n_candidates")
    if log_path is not None:
        os.makedirs(os.path.dirname(log_path), exist_ok=True)
        with open(log_path, "a", encoding="utf-8") as f:
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")
    out["id"] = rid
    if log_path is not None:
        _review_pool(rec, out, log_path)
    return out

def _review_pool(rec, out, log_path):
    """待标注池：值得人再看一眼的请求。以后由医生/AI 标注后并入评测集（见 export_pool.py）"""
    p = rec.get("parse") or {}
    why = []
    if p.get("confidence") == "low": why.append("低置信度")
    if out["type"] == "followup": why.append("触发追问")
    if out["type"] == "no_department": why.append("无法判断科室")
    if rec.get("danger_level") == "urgent": why.append("二级紧急")
    if (rec.get("rank_meta") or {}).get("uncertain"): why.append("多科室并列")
    sec = rec.get("second_opinion")
    if sec and p and sec["level"] != p.get("danger", {}).get("level"): why.append(f"两次紧急判断不一致({p['danger']['level']}/{sec['level']})")
    if rec.get("safety_rules", {}).get("rules") and not rec["safety_rules"]["flag"]: why.append("命中危险词但被放行")
    if out.get("warning"): why.append("降级为离线解析")
    if not why:
        return
    with open(os.path.join(os.path.dirname(log_path), "review_pool.jsonl"), "a", encoding="utf-8") as f:
        f.write(json.dumps({"id": rec["id"], "time": rec["time"], "text": rec["form"]["text"], "followup_answers": rec["form"].get("followup_answers"),
                            "reasons": why, "model_primary": (p.get("depts") or {}).get("primary"), "danger_level": rec.get("danger_level")}, ensure_ascii=False) + "\n")

def _emergency(form, rules, lang):
    in_cn = (form.get("current_country") or "US").upper() in ("CN", "CHINA")
    num = "120" if in_cn else "911"
    rules_en = [FLAG_EN.get(r, r) for r in rules if r]
    crisis = (not in_cn) and "自伤风险" in rules
    extra_en = " If you are thinking about harming yourself, you can also call or text 988 (Suicide & Crisis Lifeline) right now." if crisis else ""
    extra_zh = " 如果您有伤害自己的想法，也可以立即拨打或发短信到 988（美国自杀与危机热线）。" if crisis else ""
    return (f"Your description includes warning signs ({', '.join(rules_en)}). Please call {num} or go to the nearest emergency department now. "
            "Do not wait to travel for treatment." + extra_en if lang == "en"
            else f"您的描述中有需要立即就医的信号（{'、'.join(r for r in rules if r)}）。请立即拨打 {num} 或前往最近的急诊，不要等待出行。" + extra_zh)
