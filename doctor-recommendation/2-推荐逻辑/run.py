"""命令行：python run.py --text "..." --age 45 --sex F [--intent confirmed_dx] [--lang zh] [--offline]"""
import argparse, json
from recommender import recommend
ap = argparse.ArgumentParser()
ap.add_argument("--text", required=True)
ap.add_argument("--age", type=int)
ap.add_argument("--sex", default="unknown", choices=["M", "F", "unknown"])
ap.add_argument("--pregnant", default="不适用")
ap.add_argument("--intent", default="undecided", choices=["undecided", "confirmed_dx", "other"])
ap.add_argument("--country", default="US")
ap.add_argument("--lang", default="en", choices=["en", "zh"])
ap.add_argument("--followup", default="")
ap.add_argument("--offline", action="store_true", help="不调 Gemini，用关键词兜底（仅演示）")
ap.add_argument("--json", action="store_true")
a = ap.parse_args()
form = dict(text=a.text, age=a.age, sex_at_birth=a.sex, pregnant=a.pregnant, intent=a.intent,
            current_country=a.country, reply_language=a.lang, followup_answers=a.followup)
out = recommend(form, offline=a.offline)
if out.get("warning"): print("⚠️ " + out["warning"] + "\n")
print(json.dumps(out, ensure_ascii=False, indent=2) if a.json else out.get("message") or out.get("question"))
