"""入库脚本：5 家医院原始名单 → data/doctor.csv（+ 剔除清单、质量报告）。
python tools/build_doctors.py
规则见 docs/需求文档-医生级推荐MVP-v2.md 第 2、4 节；用户 2026-10-18 补充：
擅长原文为空/未列的不收；归不了类的不收；港大收「顾问」「明写主任医师」「高级医生」。"""
import csv, os, re, collections as C

HERE = os.path.dirname(os.path.abspath(__file__))
D = os.path.join(HERE, "..", "data")
HID = {"深圳市人民医院": "SZ001", "北京大学深圳医院": "SZ002", "香港大学深圳医院": "SZ003",
       "深圳市第二人民医院": "SZ004", "南方医科大学深圳医院": "SZ005",
       "中国医学科学院肿瘤医院深圳医院": "SZ020", "中国医学科学院阜外医院深圳医院": "SZ021", "深圳市眼科医院": "SZ022", "深圳新风和睦家医院": "SZ030"}
PRIVATE = {r["hospital_id"] for r in csv.DictReader(open(os.path.join(D, "hospital.csv"), encoding="utf-8")) if r["ownership"] in ("私立", "民营")}
STD_IDS = [r["std_dept_id"] for r in csv.DictReader(open(os.path.join(D, "std_dept.csv"), encoding="utf-8"))]

# 科室名 → 标准科室。按顺序取第一条命中；None 表示明确不可推荐（麻醉、影像、急诊等），直接剔除
DEPT_RULES = [
    (r"呼吸", ["RESP"]),  # 先于「重症」规则：呼吸与危重症医学科要保留
    (r"麻醉|病理|超声|影像|核医学|介入|急诊|急危重症|重症|日间手术|外科内镜", None),
    (r"冠心病|心律|高血压|心衰|心肌病|结构性心脏|先天性心脏|肺血管|心脏康复", ["CARD"]),
    (r"成人外科中心", ["CTS"]),
    (r"CCU|术后恢复", None),
    (r"眼|视网膜|青光|白内障|角膜|斜视|视光|屈光|近视|视觉", ["OPH"]),   # 先于儿科/整形/肿瘤：小儿眼科、眼整形、眼肿瘤都归眼科
    (r"新生儿|儿科|儿童|小儿", ["PED"]),
    (r"生殖", ["REPRO"]),
    (r"妇产", ["GYN", "OB"]),
    (r"产前诊断|产科", ["OB"]),
    (r"妇科", ["GYN"]),
    (r"肿瘤|放疗|血液病", ["ONC"]),
    (r"神外|神经外科", ["NSURG"]),
    (r"神经内科|神经医学中心/神经内科|睡眠与脑", ["NEURO"]),
    (r"疼痛", ["PAIN"]),
    (r"心脏大血管外科|心血管外科|胸心外|胸外科", ["CTS"]),
    (r"心血管内科|心血管病|心律失常|心血管综合内科", ["CARD"]),
    (r"消化内科", ["GI"]),
    (r"肾内科|肾病", ["NEPH"]),
    (r"内分泌", ["ENDO"]),
    (r"血液内科", ["HEME"]),
    (r"感染", ["INF"]),
    (r"风湿", ["RHEUM"]),
    (r"老年", ["GERI"]),
    (r"全科|健康管理|体检|保健科$", ["GP"]),
    (r"泌尿", ["URO"]),
    (r"整形|烧伤|美容|手足显微|创面", ["PLAST"]),
    (r"骨|脊柱|足踝|手外科|运动医学|创伤", ["ORTHO"]),
    (r"肝胆|胃肠|结直肠|肛肠|甲状腺|乳腺|甲乳|血管外科|外科", ["GS"]),
    (r"耳鼻咽喉|耳鼻喉", ["ENT"]),
    (r"口腔", ["DENT"]),
    (r"皮肤", ["DERM"]),
    (r"精神|心理", ["PSY"]),
    (r"康复", ["REHAB"]),
    (r"中医|针灸|推拿|治未病|中西医", ["TCM"]),
]
# 科室名看不出看什么病（特诊、国际部、营养等）→ 按擅长原文关键词归类
EXP_RULES = [
    ("CARD", r"冠心病|心律失常|高血压|心力衰竭|心衰|心肌|心绞痛|房颤|心血管"),
    ("RESP", r"哮喘|慢阻肺|肺炎|慢性咳嗽|肺部疾病|呼吸"),
    ("GI", r"胃炎|胃肠|消化|肝病|肝炎|肠镜|胃镜|胰腺炎"),
    ("NEPH", r"肾炎|肾病|蛋白尿|透析"),
    ("ENDO", r"糖尿病|甲状腺|内分泌|骨质疏松|肥胖|代谢"),
    ("HEME", r"贫血|白血病|淋巴瘤|血小板|血液"),
    ("NEURO", r"癫痫|帕金森|头痛|头晕|脑血管|卒中|痴呆|神经"),
    ("RHEUM", r"风湿|红斑狼疮|类风湿|痛风|强直性脊柱炎"),
    ("GERI", r"老年"),
    ("PSY", r"心理|抑郁|焦虑|失眠|精神"),
    ("GYN", r"妇科|子宫|卵巢|宫颈|月经"),
    ("OB", r"产科|妊娠|孕"),
    ("REPRO", r"不孕|试管|辅助生殖"),
    ("PED", r"儿童|小儿|新生儿"),
    ("ORTHO", r"骨折|关节|脊柱|骨科|运动损伤"),
    ("URO", r"泌尿|前列腺|结石"),
    ("DERM", r"皮肤|湿疹|银屑病"),
    ("OPH", r"眼"),
    ("ENT", r"鼻|咽喉|耳鸣|听力"),
    ("DENT", r"口腔|牙"),
    ("TCM", r"中医|针灸"),
    ("REHAB", r"康复"),
    ("PAIN", r"疼痛"),
    ("GS", r"普外|胃肠外科|肝胆|疝"),
    ("INF", r"感染|肝炎|结核|艾滋"),
]
ONC_RE = re.compile(r"癌|恶性|肿瘤")  # 单独出现「化疗后呕吐」之类不算
PSY_RE = re.compile(r"抑郁|焦虑|心理(治疗|咨询|障碍|疾病|诊疗)|精神(障碍|疾病)")  # 用户 2026-10-18 确认：擅长写抑郁焦虑的同时归入 PSY
CHIEF = re.compile(r"(?<!副)(主任医师|主任中医师)|二级主任医师")   # 「副主任医师」不算
SPECIAL = re.compile(r"香港|客座|客席|特聘|名誉临床")
LOW = re.compile(r"主治|住院|治疗师|视光|营养")
EMPTY_EXP = re.compile(r"^(官方简介未列|未列|未公开|待补|暂无|待核|无)")


def title_level(hosp, r):
    """返回 (title_level, 备注)；title_level 为空表示不收"""
    t, pos = r["title"], r.get("pos", "")
    r = dict(r, hid=HID[hosp])
    if hosp == "香港大学深圳医院":
        if t == "主任医师" or re.search(r"(?<!副)顾问", pos) or pos == "高级医生":
            return "主任", ""
        return "", "港大：非顾问/主任医师/高级医生"
    if r["hid"] in PRIVATE and SPECIAL.search(t) and not LOW.search(t):   # 用户确认：收回有擅长的香港/特聘医生
        return "私立国际门诊", "香港/特聘医生，内地职称未单列"
    if CHIEF.search(t):
        note = "职称待核" if ("；" in t or r.get("check", "").startswith("需核对")) else ""
        return ("私立国际门诊" if r["hid"] in PRIVATE else "主任"), note
    return "", "公立医院：非主任医师（%s）" % t


def classify(dept_local, expertise):
    """返回 (std_ids, 方式)；std_ids 为 None 表示科室明确不可推荐，[] 表示归不了类"""
    ids = []
    for seg in re.split(r"[；;]", dept_local):
        for pat, tgt in DEPT_RULES:
            if re.search(pat, seg):
                if tgt is None:
                    ids = ids if ids else None
                else:
                    ids += [x for x in tgt if x not in (ids or [])]
                break
    method = "科室名"
    if ids is None:
        return None, "科室不可推荐"
    if not ids:
        method = "擅长原文"
        hits = sorted(((len(re.findall(p, expertise)), k) for k, p in EXP_RULES), reverse=True)
        ids = [k for n, k in hits if n > 0][:2]
    if ONC_RE.search(expertise) and "ONC" not in ids:
        ids.append("ONC")
    if PSY_RE.search(expertise) and "PSY" not in ids:
        ids.append("PSY")
    return ids, method


def load():
    rows = []
    for r in csv.DictReader(open(os.path.join(D, "raw", "four_hospitals.csv"), encoding="utf-8-sig")):
        if r["医院"] == "深圳市第二人民医院":
            continue   # 二院用 2026-10-18 新调研名单（sz004.csv）覆盖
        rows.append(dict(hosp=r["医院"], dept=r["科室"], name=r["姓名"].strip(), title=r["职称"], pos=r["官网职务或岗位"],
                         exp=r["擅长病种及诊疗技术"].strip(), url=r["医生官方链接"], date=r["检索日期"], check=""))
    for r in csv.DictReader(open(os.path.join(D, "raw", "pkuszh.csv"), encoding="utf-8-sig")):
        rows.append(dict(hosp="北京大学深圳医院", dept=r["department"], name=r["name"].strip(), title=r["title"], pos="",
                         exp=r["specialty"].strip(), url=r["source"], date=r["review_date"], check=r["title_check"]))
    # 二院新名单里 148 人「未公开」擅长，但旧候选库（官方个人页）有原文：按姓名回填，其余不动
    old = {r["姓名"].strip(): r for r in csv.DictReader(open(os.path.join(D, "raw", "four_hospitals.csv"), encoding="utf-8-sig"))
           if r["医院"] == "深圳市第二人民医院" and len(r["擅长病种及诊疗技术"].strip()) >= 4}
    for fn in ("sz004", "sz021", "sz030"):
        for r in csv.DictReader(open(os.path.join(D, "raw", fn + ".csv"), encoding="utf-8-sig")):
            dept = r["科室（官网原文）"]
            if fn == "sz030":   # 新风和睦家目录科室很粗（内科/外科），科室名后附官网头衔一起判断
                dept = dept + "｜" + re.sub(r"[、，,]", " ", r["职称（原文）"])
            exp, url = r["擅长（原文）"].strip(), r["介绍页URL"]
            if fn == "sz004" and EMPTY_EXP.match(exp) and r["医生姓名"].strip() in old:
                o = old[r["医生姓名"].strip()]
                exp, url = o["擅长病种及诊疗技术"].strip(), o["医生官方链接"] or url
            rows.append(dict(hosp=r["医院"], dept=dept, name=r["医生姓名"].strip(), title=r["职称（原文）"], pos="",
                             exp=exp, url=url, date=r["采集日期"], check=""))
    for r in csv.DictReader(open(os.path.join(D, "raw", "sz020_sz022.csv"), encoding="utf-8-sig")):
        exp = "；".join(x for x in (r["擅长疾病/情况"].strip(), r["擅长诊疗方向"].strip()) if x and x != "未公开")
        rows.append(dict(hosp=r["医院名称"], dept=r["官网科室栏目"], name=r["医生姓名"].strip(), title=r["职称"], pos="",
                         exp=exp, url=r["个人官网URL"], date=r["检索日期"], check=""))
    return rows


def main():
    kept, dropped, seen = [], [], set()
    for r in load():
        why = None
        tl, note = title_level(r["hosp"], r)
        if not tl:
            why = note
        elif len(r["exp"]) < 4 or EMPTY_EXP.match(r["exp"]):
            why = "无擅长原文"
        else:
            ids, method = classify(r["dept"], r["exp"])
            if ids is None:
                why = "科室不可推荐（麻醉/影像/急诊/重症等）"
            elif not ids:
                why = "归不了类"
            else:
                key = (r["hosp"], r["dept"], r["name"])
                if key in seen:
                    why = "重复"
                seen.add(key)
        if why:
            dropped.append((r["hosp"], r["dept"], r["name"], r["title"], r["pos"], why))
            continue
        kept.append(dict(hospital_id=HID[r["hosp"]], dept_local=r["dept"], name=r["name"],
                         title=r["title"] if (r["title"] == "主任医师" or r["hosp"] != "香港大学深圳医院") else r["pos"],
                         title_level=tl, std_dept_ids="|".join(ids), expertise=r["exp"], source_url=r["url"],
                         collected_date=r["date"], map_method=method, note=note))
    kept.sort(key=lambda d: (d["hospital_id"], d["dept_local"], d["name"]))
    n = C.Counter()
    for d in kept:
        n[d["hospital_id"]] += 1
        d["doctor_id"] = "%s-D%04d" % (d["hospital_id"], n[d["hospital_id"]])
    cols = ["doctor_id", "hospital_id", "dept_local", "name", "title", "title_level", "std_dept_ids", "expertise",
            "source_url", "collected_date", "map_method", "note"]
    with open(os.path.join(D, "doctor.csv"), "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, cols); w.writeheader(); w.writerows(kept)
    with open(os.path.join(D, "doctor_dropped.csv"), "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f); w.writerow(["医院", "科室", "姓名", "职称", "岗位", "剔除原因"]); w.writerows(dropped)
    # 质量报告
    assert all(i in STD_IDS for d in kept for i in d["std_dept_ids"].split("|"))
    rep = ["# 医生入库质量报告", ""]
    names = {v: k for k, v in HID.items()}
    rep += ["| 医院 | 原始 | 入库 | 剔除 |", "|---|---:|---:|---:|"]
    raw = C.Counter(r["hosp"] for r in load())
    for h, i in HID.items():
        rep.append("| %s | %d | %d | %d |" % (h, raw[h], n[i], raw[h] - n[i]))
    rep += ["", "合计入库 %d 人（擅长覆盖率 100%%）" % len(kept), "", "## 剔除原因", ""]
    for k, v in C.Counter((d[0], d[5]) for d in dropped).most_common():
        rep.append("- %s：%s × %d" % (k[0], k[1], v))
    rep += ["", "## 归类方式", ""] + ["- %s：%d" % kv for kv in C.Counter(d["map_method"] for d in kept).items()]
    rep += ["", "## 各标准科室医生数", ""]
    cnt = C.Counter(i for d in kept for i in d["std_dept_ids"].split("|"))
    rep += ["- %s：%d（覆盖医院 %d 家）" % (k, v, len({d["hospital_id"] for d in kept if k in d["std_dept_ids"].split("|")}))
            for k, v in sorted(cnt.items())]
    rep += ["", "没有医生的标准科室：" + "、".join(s for s in STD_IDS if s not in cnt) , ""]
    open(os.path.join(HERE, "..", "docs", "入库质量报告.md"), "w", encoding="utf-8").write("\n".join(rep))
    print("\n".join(rep))


if __name__ == "__main__":
    main()
