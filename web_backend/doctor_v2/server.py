"""演示网页：python server.py [端口，默认 8080]。只依赖标准库。
GET /  → static/index.html；POST /api/recommend（JSON 表单）→ 推荐结果；
POST /api/chat（{"messages":[{"role","content"}]}）→ 对话 AI 回复 {reply, cards, type}（需要模型支持 tools）。
有 warning（降级为离线关键词、Gemini 失败）时不返回推荐内容，只返回错误提示。"""
import ipaddress, json, os, queue, sys, threading, time
from collections import defaultdict, deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from .recommender import recommend, HERE
from . import agent
from .countries import COUNTRY_NAMES

# 并发与限频（接口公开后防滥用；模型额度按调用计费）。可用环境变量调整
MAX_BODY = int(os.environ.get("WEWELL_MAX_BODY", 64 * 1024))        # 请求体上限（字节）
PER_MIN = int(os.environ.get("WEWELL_PER_MIN", 12))                 # 每个客户端 IP 每分钟最多次数
PER_DAY = int(os.environ.get("WEWELL_PER_DAY", 200))                # 每个客户端 IP 每天最多次数
MAX_INFLIGHT = int(os.environ.get("WEWELL_MAX_INFLIGHT", 4))        # 同时处理的请求数，超过返回 503
LOCK = threading.Semaphore(MAX_INFLIGHT)
MIME = {".html": "text/html; charset=utf-8", ".js": "text/javascript", ".mjs": "text/javascript", ".json": "application/json", ".css": "text/css",
        ".png": "image/png", ".jpg": "image/jpeg", ".svg": "image/svg+xml", ".ico": "image/x-icon", ".wasm": "application/wasm", ".ttf": "font/ttf",
        ".otf": "font/otf", ".woff": "font/woff", ".woff2": "font/woff2", ".txt": "text/plain; charset=utf-8", ".map": "application/json"}
_hits, _hits_lock = defaultdict(deque), threading.Lock()


def allow(ip, now=None):
    """滑动窗口限频。返回 (是否放行, 建议等待秒数)"""
    now = time.time() if now is None else now
    with _hits_lock:
        q = _hits[ip]
        while q and now - q[0] > 86400:
            q.popleft()
        recent = sum(1 for t in q if now - t <= 60)
        if len(q) >= PER_DAY:
            return False, 3600
        if recent >= PER_MIN:
            return False, 60
        q.append(now)
        if len(_hits) > 5000:   # 防止字典无限增长
            for k in [k for k, v in _hits.items() if not v or now - v[-1] > 86400][:1000]:
                _hits.pop(k, None)
        return True, 0


def client_ip(peer, xff):
    """只信任来自本机/内网（反向代理）的 X-Forwarded-For，且取最后一项（Google 前端会把真实客户端地址追加在末尾，前面的可能是伪造的）；否则一律用连接地址"""
    try:
        if xff and ipaddress.ip_address(peer).is_private:
            return xff.split(",")[-1].strip()
    except ValueError:
        pass
    return peer
REQUIRED = ("text", "age", "sex_at_birth", "current_country")

def clean(form):
    errs = []
    for k in REQUIRED:
        if form.get(k) in (None, ""): errs.append(k)
    try:
        form["age"] = int(form["age"])
        if not 0 <= form["age"] <= 120: errs.append("age")
    except (TypeError, ValueError, KeyError):
        errs.append("age")
    if form.get("sex_at_birth") not in ("M", "F", "unknown"): errs.append("sex_at_birth")
    form.pop("intent", None)  # v2 不再区分首诊/确诊
    form["text"] = str(form.get("text", ""))[:4000]
    form["reply_language"] = "zh" if form.get("reply_language") == "zh" else "en"
    form.setdefault("pregnant", "不适用")
    return list(dict.fromkeys(errs))

def validate_chat(body):
    if not isinstance(body, dict):
        raise ValueError("expected object")
    messages = body.get("messages")
    shown = body.get("shown_doctor_ids", [])
    country = body.get("current_country")
    age, sex = body.get("age"), body.get("sex_at_birth")
    if age is not None and (type(age) is not int or not 0 <= age <= 120):
        raise ValueError("invalid age")
    if sex is not None and sex not in ("M", "F", "unknown"):
        raise ValueError("invalid sex at birth")
    if country is not None and (not isinstance(country, str) or country not in COUNTRY_NAMES):
        raise ValueError("invalid current country")
    if (not isinstance(messages, list) or not 1 <= len(messages) <= 30 or
            any(not isinstance(m, dict) or m.get("role") not in ("user", "assistant") or
                not isinstance(m.get("content"), str) or not 0 < len(m["content"]) <= 4000 for m in messages)):
        raise ValueError("invalid messages")
    if (not isinstance(shown, list) or len(shown) > 100 or
            any(not isinstance(i, str) or len(i) > 128 for i in shown)):
        raise ValueError("invalid shown doctors")
    return messages, shown, country, age, sex


class H(BaseHTTPRequestHandler):
    def _send(self, code, body, ctype="application/json; charset=utf-8"):
        b = body if isinstance(body, bytes) else json.dumps(body, ensure_ascii=False).encode()
        self.send_response(code); self.send_header("Access-Control-Allow-Origin", "*"); self.send_header("Content-Type", ctype); self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)
    def do_GET(self):
        path = self.path.split("?")[0]
        if path == "/healthz":   # Cloud Run / 监控用
            return self._send(200, {"ok": True})
        web = os.path.join(HERE, "static", "web")   # Flutter Web 构建产物（有就当演示页提供）
        if os.path.isdir(web):
            rel = os.path.normpath(path.lstrip("/"))
            full = os.path.realpath(os.path.join(web, rel))
            if not full.startswith(os.path.realpath(web) + os.sep) and full != os.path.realpath(web):
                return self._send(404, {"error": "not found"})   # 路径穿越
            if os.path.isfile(full):
                return self._send(200, open(full, "rb").read(), MIME.get(os.path.splitext(full)[1].lower(), "application/octet-stream"))
            if not path.startswith("/api/"):   # 单页应用：其余路径回到 index.html
                return self._send(200, open(os.path.join(web, "index.html"), "rb").read(), "text/html; charset=utf-8")
        elif path in ("/", "/index.html"):
            return self._send(200, open(os.path.join(HERE, "static", "index.html"), "rb").read(), "text/html; charset=utf-8")
        self._send(404, {"error": "not found"})
    def do_OPTIONS(self):   # 浏览器/Flutter Web 跨域预检
        self.send_response(204); self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type"); self.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS"); self.end_headers()
    def _guard(self):
        """限频 + 体积检查；不通过时已经发出响应并返回 False"""
        try:
            n = int(self.headers.get("Content-Length", 0) or 0)
        except ValueError:
            self._send(400, {"error": "invalid content length"}); return False
        if not 0 < n <= MAX_BODY:
            self._send(413, {"error": "request too large"}); return False
        ok, wait = allow(client_ip(self.client_address[0], self.headers.get("X-Forwarded-For")))
        if not ok:
            self._send(429, {"error": "too many requests, please slow down", "retry_after": wait}); return False
        return True
    def do_POST(self):
        if self.path in ("/api/chat", "/api/chat/stream", "/api/recommend") and not self._guard(): return
        if self.path == "/api/chat": return self._chat()
        if self.path == "/api/chat/stream": return self._chat_stream()
        if self.path != "/api/recommend": return self._send(404, {"error": "not found"})
        try:
            form = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0)) or 0))
            if not isinstance(form, dict): raise ValueError
        except ValueError:
            return self._send(400, {"error": "bad json"})
        errs = clean(form)
        if errs: return self._send(400, {"error": "missing or invalid fields", "fields": errs})
        out = self._run(lambda: recommend(form))
        if out is None: return
        if out.get("warning"):
            sys.stderr.write(f"blocked (warning): {out['warning']}\n")
            return self._send(503, {"error": "The analysis service is temporarily unavailable. Please try again in a minute."})
        self._send(200, {k: out.get(k) for k in ("type", "message", "intro", "urgent_notice", "question", "results", "meta", "cards") if k in out})
    def _run(self, fn):
        """限制同时处理的请求数；出错不把内部细节给用户。已发出错误响应时返回 None"""
        if not LOCK.acquire(timeout=5):
            self._send(503, {"error": "busy, try again shortly"}); return None
        try:
            return fn()
        except Exception as e:
            sys.stderr.write(f"request failed: {type(e).__name__}\n")
            self._send(500, {"error": "internal error"}); return None
        finally:
            LOCK.release()
    def _chat(self):
        try:
            body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0)) or 0))
            msgs, shown, country, age, sex = validate_chat(body)
        except ValueError:
            return self._send(400, {"error": "bad json: expected {\"messages\": [...]}"})
        out = self._run(lambda: agent.chat(msgs, shown_doctor_ids=shown, current_country=country, age=age, sex_at_birth=sex))
        if out is not None: self._send(200, out)
    def _chat_stream(self):
        """Server-Sent Events：先陆续推送进度（status），最后推送结果（result）；空闲时发注释行保活，避免代理断开"""
        try:
            body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0)) or 0))
            msgs, shown, country, age, sex = validate_chat(body)
        except ValueError:
            return self._send(400, {"error": "bad json: expected {\"messages\": [...]}"})
        if not LOCK.acquire(timeout=5):
            return self._send(503, {"error": "busy, try again shortly"})
        q = queue.Queue()
        def work():
            try:
                q.put(("result", agent.chat(msgs, progress=lambda t: q.put(("status", {"text": t})), shown_doctor_ids=shown, current_country=country, age=age, sex_at_birth=sex)))
            except Exception as e:
                sys.stderr.write(f"chat stream failed: {type(e).__name__}\n"); q.put(("error", {"error": "internal error"}))
            finally:
                LOCK.release(); q.put(("end", None))
        threading.Thread(target=work, daemon=True).start()
        self.send_response(200)
        for k, v in (("Access-Control-Allow-Origin", "*"), ("Content-Type", "text/event-stream; charset=utf-8"), ("Cache-Control", "no-cache"),
                     ("X-Accel-Buffering", "no"), ("Connection", "close")):
            self.send_header(k, v)
        self.end_headers()
        try:
            while True:
                try:
                    ev, data = q.get(timeout=10)
                except queue.Empty:
                    self.wfile.write(b": ping\n\n"); self.wfile.flush(); continue
                if ev == "end": break
                self.wfile.write(f"event: {ev}\ndata: {json.dumps(data, ensure_ascii=False)}\n\n".encode()); self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            pass   # 客户端走了；工作线程会自己结束并释放并发名额
    def log_message(self, *a): pass

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else int(os.environ.get("PORT", 8080))   # Cloud Run 通过 PORT 指定端口
    host = os.environ.get("WEWELL_HOST", "0.0.0.0")   # 部署时设为 Docker 网关地址，只让反向代理能访问
    print(f"http://{host}:{port}/")
    ThreadingHTTPServer((host, port), H).serve_forever()
