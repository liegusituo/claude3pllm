#!/usr/bin/env python3
"""
DeepSeek Proxy — 统一代理 for Claude Desktop + Codex
========================================================

解决 Claude Desktop 升级后必须加 claude- 前缀导致模型路由错误的问题，
同时支持 Codex（OpenAI Responses API → DeepSeek Chat Completions API 协议翻译）。

原理：
  Claude Desktop → 本地代理(localhost:8787) → 剥掉 claude- 前缀 → DeepSeek Anthropic API
  Codex          → 本地代理(localhost:8787) → Responses→Chat 协议翻译 → DeepSeek Chat API

路径路由：
  POST /v1/messages  → Claude Desktop 链（原有逻辑，零改动）
  POST /v1/responses → Codex 链（新增协议翻译）
  GET  / /health     → 健康检查

使用方法：
  1. export DEEPSEEK_API_KEY=sk-xxxxxxxxxxxxxxxx
  2. python3 deepseek_proxy.py

  Claude Desktop 的 Base URL 设置为：http://127.0.0.1:8787
  Codex config.toml 中 model_provider 的 base_url 设置为：http://127.0.0.1:8787/v1
"""

import json
import os
import sys
import urllib.request
import urllib.error
from http.server import BaseHTTPRequestHandler, HTTPServer

# 强制禁用输出缓冲，确保 Swift 能实时获取日志
sys.stdout.reconfigure(line_buffering=True)
sys.stderr.reconfigure(line_buffering=True)

# ========== 配置区 ==========
PROXY_PORT = 9797

# --- Claude Desktop (Anthropic API) ---
DEEPSEEK_ANTHROPIC_URL = "https://api.deepseek.com/anthropic"

# --- Codex (OpenAI Chat Completions API) ---
DEEPSEEK_CHAT_URL = "https://api.deepseek.com/v1"

DEEPSEEK_API_KEY = os.environ.get("DEEPSEEK_API_KEY", "")
CODEX_DEEPSEEK_API_KEY = os.environ.get("CODEX_DEEPSEEK_API_KEY", "")
CLAUDE_DEEPSEEK_API_KEY = os.environ.get("CLAUDE_DEEPSEEK_API_KEY", "")


def get_api_key(for_claude=False):
    """获取 API Key。优先用专用 key，回退到通用 key。"""
    if for_claude and CLAUDE_DEEPSEEK_API_KEY:
        return CLAUDE_DEEPSEEK_API_KEY
    if not for_claude and CODEX_DEEPSEEK_API_KEY:
        return CODEX_DEEPSEEK_API_KEY
    return DEEPSEEK_API_KEY

# ---- Claude Desktop 模型名称映射 ----
# Claude Desktop 发来的 model ID → 真实 DeepSeek model ID
MODEL_MAP = {
    "claude-deepseek-v4-pro":   "deepseek-v4-pro",
    "claude-deepseek-v4-flash": "deepseek-v4-flash",
    # 兼容带 [1m] 后缀的写法
    "claude-deepseek-v4-pro[1m]":   "deepseek-v4-pro[1m]",
    "claude-deepseek-v4-flash[1m]": "deepseek-v4-flash[1m]",
}

# ---- Codex 模型名称映射 ----
# Codex 发来的 model ID → 真实 DeepSeek model ID
# Codex config.toml 中可指定任意 model 名，这里覆盖常见 GPT 模型名
CODEX_MODEL_MAP = {
    # 旗舰级 → deepseek-v4-pro（强推理，贵）
    "gpt-5.5": "deepseek-v4-pro",
    "gpt-5.2": "deepseek-v4-pro",
    "gpt-5.2-codex": "deepseek-v4-pro",
    "gpt-5.1": "deepseek-v4-pro",
    "gpt-5.1-codex": "deepseek-v4-pro",
    # 轻量级 → deepseek-v4-flash（快，便宜）
    "gpt-5.5-mini": "deepseek-v4-flash",
    "gpt-5.4-mini": "deepseek-v4-flash",
    "gpt-4o": "deepseek-v4-flash",
    # 直通
    "deepseek-chat": "deepseek-v4-flash",
    "deepseek-reasoner": "deepseek-v4-pro",
    "deepseek-v4-pro": "deepseek-v4-pro",
    "deepseek-v4-flash": "deepseek-v4-flash",
}
# ============================


# ============================================================
#  Claude Desktop 模型解析（原有逻辑，不改）
# ============================================================
def resolve_model(model_id: str) -> str:
    """把 claude-xxx 前缀剥掉，还原为真实的 DeepSeek model ID。"""
    if model_id in MODEL_MAP:
        return MODEL_MAP[model_id]
    if model_id.startswith("claude-deepseek-"):
        return model_id[len("claude-"):]
    if model_id.startswith("claude-") and "deepseek" in model_id:
        return model_id[len("claude-"):]
    return model_id


def resolve_codex_model(model_id: str) -> str:
    """把 Codex 发来的 model ID 映射为 DeepSeek model ID。"""
    if model_id in CODEX_MODEL_MAP:
        return CODEX_MODEL_MAP[model_id]
    if model_id.startswith("gpt-"):
        return "deepseek-v4-flash"
    if "deepseek" in model_id.lower():
        return model_id
    return "deepseek-v4-flash"


# ============================================================
#  Codex 协议翻译器（新增）
# ============================================================
class CodexTranslator:

    @staticmethod
    def translate_request(payload: dict) -> dict:
        """将 Codex 发来的 Responses API 请求转换为 DeepSeek Chat API 请求。"""
        chat_req = {}

        original_model = payload.get("model", "gpt-5.1")
        reasoning_effort = payload.get("reasoning", {}).get("effort", "") or payload.get("reasoning_effort", "")
        chat_req["model"] = resolve_codex_model(original_model)
        
        print(f"[Codex] 模型映射: {original_model!r} -> {chat_req['model']!r}")
        
        if reasoning_effort in ("high", "xhigh"):
            chat_req["model"] = "deepseek-v4-pro"
            print(f"[Codex] 高推理等级升级: {reasoning_effort} -> deepseek-v4-pro")

        chat_req["messages"] = CodexTranslator._convert_input_to_messages(
            payload.get("input", "")
        )

        if "tools" in payload and payload["tools"]:
            chat_req["tools"] = CodexTranslator._convert_tools_to_chat(payload["tools"])
            tool_choice = payload.get("tool_choice", "auto")
            if tool_choice:
                chat_req["tool_choice"] = tool_choice

        if "temperature" in payload:
            chat_req["temperature"] = payload["temperature"]
        if "max_output_tokens" in payload:
            chat_req["max_tokens"] = payload["max_output_tokens"]
        if "top_p" in payload:
            chat_req["top_p"] = payload["top_p"]

        chat_req["stream"] = payload.get("stream", False)
        
        # 只在有 reasoning_effort 时设置 thinking，并且根据 effort 选择正确的类型
        if reasoning_effort:
            if reasoning_effort in ("high", "xhigh"):
                # 高推理等级用 v4-pro，启用 thinking
                chat_req["thinking"] = {"type": "enabled", "budget_tokens": 16000}
            else:
                # low/medium: 不要设置 thinking（避免冲突）
                # 或者设置为自动模式（需要验证 API）
                pass
        # 如果没有 reasoning_effort，也不要设置 thinking

        print(f"[Codex] 请求: messages={len(chat_req['messages'])}, tools={len(chat_req.get('tools', []))}, stream={chat_req['stream']}, reasoning={reasoning_effort!r}")

        return chat_req

    _output_counter = 0

    @classmethod
    def _next_output_id(cls) -> str:
        cls._output_counter += 1
        return f"msg_{cls._output_counter:04d}"

    @staticmethod
    def translate_response(chat_resp: dict) -> dict:
        """将 DeepSeek Chat API 响应转换为 Codex Responses API 格式。"""
        import time
        resp = {}

        resp["id"] = chat_resp.get("id", "")
        resp["object"] = "response"
        resp["created_at"] = chat_resp.get("created", int(time.time()))
        resp["model"] = chat_resp.get("model", "deepseek-v4-flash")

        choices = chat_resp.get("choices", [])
        output = []
        if choices:
            choice = choices[0]
            message = choice.get("message", {})

            reasoning_content = message.get("reasoning_content", "")
            if reasoning_content:
                output.append({
                    "id": CodexTranslator._next_output_id(),
                    "type": "reasoning",
                    "status": "completed",
                    "summary": [{"type": "summary_text", "text": reasoning_content}],
                })

            text_content = message.get("content") or ""
            if text_content:
                output.append({
                    "id": CodexTranslator._next_output_id(),
                    "type": "message",
                    "status": "completed",
                    "role": "assistant",
                    "content": [{
                        "type": "output_text",
                        "text": text_content,
                        "annotations": [],
                    }],
                })

            tool_calls = message.get("tool_calls")
            if tool_calls:
                for tc in tool_calls:
                    func = tc.get("function", {})
                    output.append({
                        "id": CodexTranslator._next_output_id(),
                        "type": "function_call",
                        "status": "completed",
                        "call_id": tc.get("id", ""),
                        "name": func.get("name", ""),
                        "arguments": func.get("arguments", ""),
                    })

        if not output:
            output.append({
                "id": CodexTranslator._next_output_id(),
                "type": "message",
                "status": "completed",
                "role": "assistant",
                "content": [{
                    "type": "output_text",
                    "text": "",
                    "annotations": [],
                }],
            })

        resp["output"] = output

        finish_reason = choices[0].get("finish_reason", "stop") if choices else "stop"
        resp["status"] = "completed" if finish_reason == "stop" else finish_reason

        usage = chat_resp.get("usage", {})
        resp["usage"] = {
            "input_tokens": usage.get("prompt_tokens", 0),
            "output_tokens": usage.get("completion_tokens", 0),
            "total_tokens": usage.get("total_tokens", 0),
            "input_tokens_details": {
                "cached_tokens": usage.get("prompt_tokens_details", {}).get("cached_tokens", 0),
            },
            "output_tokens_details": {
                "reasoning_tokens": usage.get("completion_tokens_details", {}).get("reasoning_tokens", 0),
            },
        }

        return resp

    @staticmethod
    def _convert_input_to_messages(input_val):
        if isinstance(input_val, str):
            return [{"role": "user", "content": input_val}]

        if isinstance(input_val, list):
            messages = []
            for item in input_val:
                if not isinstance(item, dict):
                    continue

                item_type = item.get("type", "")

                if item_type == "reasoning":
                    summary = item.get("summary", [])
                    reasoning_text = ""
                    for s in summary:
                        if isinstance(s, dict) and s.get("type") == "summary_text":
                            reasoning_text = s.get("text", "")
                            break
                    if messages and messages[-1].get("role") == "assistant":
                        messages[-1]["reasoning_content"] = reasoning_text
                    continue

                if item_type == "function_call":
                    tc = {
                        "id": item.get("call_id", ""),
                        "type": "function",
                        "function": {
                            "name": item.get("name", ""),
                            "arguments": item.get("arguments", ""),
                        }
                    }
                    if (messages and messages[-1].get("role") == "assistant"
                            and "tool_calls" in messages[-1]):
                        messages[-1]["tool_calls"].append(tc)
                    else:
                        messages.append({
                            "role": "assistant",
                            "content": "",
                            "tool_calls": [tc],
                        })
                    continue

                if item_type == "function_call_output":
                    messages.append({
                        "role": "tool",
                        "tool_call_id": item.get("call_id", ""),
                        "content": item.get("output", ""),
                    })
                    continue

                role = item.get("role", "user")
                if role == "developer":
                    role = "system"
                content = item.get("content") or ""

                if isinstance(content, list):
                    text_parts = []
                    for part in content:
                        if isinstance(part, dict):
                            if part.get("type") in ("input_text", "output_text"):
                                text_parts.append(part.get("text", ""))
                    content = "\n".join(text_parts) if text_parts else ""

                messages.append({"role": role, "content": content})

            return messages if messages else [{"role": "user", "content": ""}]

        return [{"role": "user", "content": str(input_val)}]

    @staticmethod
    def _convert_tools_to_chat(tools: list) -> list:
        chat_tools = []
        for tool in tools:
            if not isinstance(tool, dict):
                continue
            if tool.get("type") == "function":
                chat_tool = {
                    "type": "function",
                    "function": {
                        "name": tool.get("name", ""),
                        "description": tool.get("description", ""),
                    }
                }
                if "parameters" in tool and tool["parameters"]:
                    chat_tool["function"]["parameters"] = tool["parameters"]
                if "strict" in tool:
                    chat_tool["function"]["strict"] = tool["strict"]
                chat_tools.append(chat_tool)
        return chat_tools


# ============================================================
#  HTTP 代理处理器
# ============================================================
class ProxyHandler(BaseHTTPRequestHandler):

    def log_message(self, fmt, *args):
        """自定义日志格式。"""
        print(f"[Proxy] {fmt % args}")
    
    def log_client(self):
        """记录客户端连接信息。"""
        client_ip = self.client_address[0] if self.client_address else "unknown"
        client_port = self.client_address[1] if self.client_address else 0
        print(f"[Client] {client_ip}:{client_port} -> {self.path}")

    def do_POST(self):
        """根据 URL 路径分发到 Claude 链或 Codex 链。"""
        self.log_client()
        
        if "/v1/responses" in self.path:
            self._handle_codex()
        elif "/v1/messages" in self.path:
            self._handle_claude()
        else:
            length = int(self.headers.get("Content-Length", 0))
            if length == 0:
                self._send_error(400, "Empty request body")
                return
            body = self.rfile.read(length)
            try:
                payload = json.loads(body)
            except json.JSONDecodeError:
                self._send_error(400, "Invalid JSON")
                return

            if "messages" in payload and "model" in payload:
                self._handle_claude_with_body(body, payload)
            elif "input" in payload and "model" in payload:
                self._handle_codex_with_body(body, payload)
            else:
                print(f"[Proxy] 未知请求格式，路径: {self.path}")
                self._send_error(400, f"Unknown request format for path: {self.path}")

    def _handle_claude(self):
        """处理 Claude Desktop 请求（Anthropic Messages API → DeepSeek Anthropic API）。"""
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length)

        try:
            payload = json.loads(body)
        except json.JSONDecodeError:
            payload = {}

        original_model = payload.get("model", "(unknown)")
        resolved_model = resolve_model(original_model)
        
        print(f"[Claude] 模型: {original_model!r}")
        if original_model != resolved_model:
            payload["model"] = resolved_model
            print(f"[Claude] 模型转换: {original_model!r} -> {resolved_model!r}")

        # 只有在原请求没有 thinking 参数时才设置，避免冲突
        if "thinking" not in payload:
            # 也检查是否有 reasoning_effort，如果有就不设置 thinking
            if "reasoning_effort" not in payload and "reasoning" not in payload:
                if resolved_model and "pro" in resolved_model.lower():
                    payload["thinking"] = {"type": "enabled", "budget_tokens": 16000}
                else:
                    payload["thinking"] = {"type": "disabled"}
            else:
                print(f"[Claude] 检测到 reasoning 参数，跳过 thinking 设置")

        api_key = get_api_key(for_claude=True)
        if not api_key:
            auth = self.headers.get("Authorization", "")
            if auth.startswith("Bearer "):
                api_key = auth[7:]
            x_api = self.headers.get("x-api-key", "")
            if x_api:
                api_key = x_api

        if not api_key:
            self._send_error(401, "未找到 API Key，请设置环境变量 DEEPSEEK_API_KEY")
            return

        target_url = DEEPSEEK_ANTHROPIC_URL + self.path
        new_body = json.dumps(payload).encode("utf-8")

        req = urllib.request.Request(
            target_url,
            data=new_body,
            method="POST",
        )
        req.add_header("Content-Type", "application/json")
        req.add_header("Authorization", f"Bearer {api_key}")
        req.add_header("anthropic-version",
                       self.headers.get("anthropic-version", "2023-06-01"))

        for key, val in self.headers.items():
            if key.lower().startswith("anthropic-") and key.lower() != "anthropic-version":
                req.add_header(key, val)

        self._forward_request(req)

    def _handle_claude_with_body(self, body: bytes, payload: dict):
        """处理兜底检测到的 Claude Desktop 请求。"""
        original_model = payload.get("model", "(unknown)")
        resolved_model = resolve_model(original_model)
        
        print(f"[Claude] 模型: {original_model!r}")
        if original_model != resolved_model:
            payload["model"] = resolved_model
            print(f"[Claude] 模型转换: {original_model!r} -> {resolved_model!r}")

        # 只有在原请求没有 thinking 参数时才设置，避免冲突
        if "thinking" not in payload:
            # 也检查是否有 reasoning_effort，如果有就不设置 thinking
            if "reasoning_effort" not in payload and "reasoning" not in payload:
                if resolved_model and "pro" in resolved_model.lower():
                    payload["thinking"] = {"type": "enabled", "budget_tokens": 16000}
                else:
                    payload["thinking"] = {"type": "disabled"}
            else:
                print(f"[Claude] 检测到 reasoning 参数，跳过 thinking 设置")

        api_key = get_api_key(for_claude=True)
        if not api_key:
            auth = self.headers.get("Authorization", "")
            if auth.startswith("Bearer "):
                api_key = auth[7:]
            x_api = self.headers.get("x-api-key", "")
            if x_api:
                api_key = x_api

        if not api_key:
            self._send_error(401, "未找到 API Key，请设置 CLAUDE_DEEPSEEK_API_KEY 或 DEEPSEEK_API_KEY")
            return

        target_url = DEEPSEEK_ANTHROPIC_URL + self.path
        new_body = json.dumps(payload).encode("utf-8")

        req = urllib.request.Request(target_url, data=new_body, method="POST")
        req.add_header("Content-Type", "application/json")
        req.add_header("Authorization", f"Bearer {api_key}")
        req.add_header("anthropic-version",
                       self.headers.get("anthropic-version", "2023-06-01"))

        for key, val in self.headers.items():
            if key.lower().startswith("anthropic-") and key.lower() != "anthropic-version":
                req.add_header(key, val)

        self._forward_request(req)

    def _handle_codex(self):
        """处理 Codex 请求（Responses API → DeepSeek Chat API）。"""
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length)

        try:
            payload = json.loads(body)
        except json.JSONDecodeError:
            self._send_error(400, "Invalid JSON in Codex request")
            return

        self._process_codex_request(payload)

    def _handle_codex_with_body(self, body: bytes, payload: dict):
        """处理兜底检测到的 Codex 请求。"""
        self._process_codex_request(payload)

    def _process_codex_request(self, payload: dict):
        """Codex 请求的处理核心：协议翻译 + 转发。"""
        api_key = get_api_key(for_claude=False)
        if not api_key:
            auth = self.headers.get("Authorization", "")
            if auth.startswith("Bearer "):
                api_key = auth[7:]
            x_api = self.headers.get("x-api-key", "")
            if x_api:
                api_key = x_api

        if not api_key:
            self._send_error(401, "未找到 API Key，请设置 CODEX_DEEPSEEK_API_KEY 或 DEEPSEEK_API_KEY")
            return

        try:
            chat_req = CodexTranslator.translate_request(payload)
        except Exception as e:
            print(f"[Codex] 请求翻译失败: {e}")
            self._send_error(400, f"Request translation error: {e}")
            return

        target_url = f"{DEEPSEEK_CHAT_URL}/chat/completions"
        new_body = json.dumps(chat_req).encode("utf-8")

        req = urllib.request.Request(target_url, data=new_body, method="POST")
        req.add_header("Content-Type", "application/json")
        req.add_header("Authorization", f"Bearer {api_key}")

        is_stream = chat_req.get("stream", False)
        if is_stream:
            chat_req["stream"] = False
            new_body = json.dumps(chat_req).encode("utf-8")
            req = urllib.request.Request(target_url, data=new_body, method="POST")
            req.add_header("Content-Type", "application/json")
            req.add_header("Authorization", f"Bearer {api_key}")

        try:
            with urllib.request.urlopen(req, timeout=600) as resp:
                resp_body = resp.read()
                chat_response = json.loads(resp_body)
                codex_response = CodexTranslator.translate_response(chat_response)

                if is_stream:
                    self._send_codex_sse(codex_response)
                else:
                    response_json = json.dumps(codex_response, ensure_ascii=False).encode("utf-8")
                    self.send_response(200)
                    self.send_header("Content-Type", "application/json")
                    self.send_header("Content-Length", str(len(response_json)))
                    self.end_headers()
                    self.wfile.write(response_json)

        except urllib.error.HTTPError as e:
            err_body = e.read()
            print(f"[Codex] DeepSeek Chat API 返回错误 {e.code}: {err_body.decode(errors='replace')}")
            try:
                err_payload = json.loads(err_body)
                error_msg = err_payload.get("error", {}).get("message", str(err_body))
            except (json.JSONDecodeError, AttributeError):
                error_msg = err_body.decode(errors='replace')
            self._send_error(e.code, error_msg)
        except Exception as e:
            print(f"[Codex] 转发失败: {e}")
            self._send_error(502, str(e))

    def _forward_request(self, req: urllib.request.Request):
        """通用 HTTP 转发（用于 Claude Desktop 链路）。"""
        try:
            with urllib.request.urlopen(req, timeout=600) as resp:
                resp_body = resp.read()
                try:
                    resp_json = json.loads(resp_body)
                    content = resp_json.get("content", [])
                    has_thinking = any(
                        isinstance(b, dict) and b.get("type") == "thinking"
                        for b in content
                    )
                    print(f"[Claude] 响应: thinking={'✅' if has_thinking else '❌'}, content_blocks={len(content)}")
                except (json.JSONDecodeError, Exception):
                    pass
                self.send_response(resp.status)
                for key, val in resp.headers.items():
                    if key.lower() not in ("transfer-encoding", "connection"):
                        self.send_header(key, val)
                self.end_headers()
                self.wfile.write(resp_body)
        except urllib.error.HTTPError as e:
            err_body = e.read()
            print(f"[Proxy] DeepSeek 返回错误 {e.code}: {err_body.decode(errors='replace')}")
            self.send_response(e.code)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(err_body)
        except BrokenPipeError:
            pass
        except Exception as e:
            print(f"[Proxy] 转发失败: {e}")
            try:
                self._send_error(502, str(e))
            except (BrokenPipeError, ConnectionResetError):
                pass

    def do_HEAD(self):
        """HEAD 请求：用于健康探测。"""
        if self.path in ("/", "/health"):
            self.send_response(200)
            self.end_headers()
        elif "/v1/models" in self.path:
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

    def do_GET(self):
        """健康检查 / 模型列表 / 状态接口。"""
        if self.path in ("/", "/health"):
            self._send_json_safe(200, {
                "status": "running",
                "port": PROXY_PORT,
                "targets": {
                    "claude": DEEPSEEK_ANTHROPIC_URL,
                    "codex": f"{DEEPSEEK_CHAT_URL}/chat/completions",
                },
                "claude_model_map": MODEL_MAP,
                "codex_model_map": CODEX_MODEL_MAP,
                "features": {
                    "claude_desktop": "支持（Anthropic Messages API 透传）",
                    "codex": "支持（Responses API to Chat API 协议翻译）",
                    "streaming": "支持（SSE 流式响应）",
                },
            })
        elif "/v1/models" in self.path:
            models = []
            for codex_name, real_name in CODEX_MODEL_MAP.items():
                models.append({
                    "id": codex_name,
                    "object": "model",
                    "owned_by": "deepseek",
                })
            self._send_json_safe(200, {
                "object": "list",
                "data": models,
            })
        else:
            self._send_error_safe(404, "Not Found")

    def _send_codex_sse(self, codex_response: dict):
        """将完整的 Responses API 响应以 SSE 流式格式返回给 Codex。"""
        try:
            self._send_codex_sse_inner(codex_response)
        except BrokenPipeError:
            pass

    def _send_codex_sse_inner(self, codex_response: dict):
        import time, uuid

        response_id = codex_response.get("id", f"resp_{uuid.uuid4().hex[:12]}")
        output = codex_response.get("output", [])

        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        self.end_headers()

        seq = 0

        seq += 1
        self._write_sse_event("response.created", {
            "type": "response.created",
            "sequence_number": seq,
            "response": codex_response,
        })

        seq += 1
        self._write_sse_event("response.in_progress", {
            "type": "response.in_progress",
            "sequence_number": seq,
            "response_id": response_id,
        })

        for idx, item in enumerate(output):
            if item.get("type") == "message":
                seq += 1
                self._write_sse_event("response.output_item.added", {
                    "type": "response.output_item.added",
                    "sequence_number": seq,
                    "response_id": response_id,
                    "output_index": idx,
                    "item": item,
                })

                content_list = item.get("content", [])
                for cidx, content in enumerate(content_list):
                    if content.get("type") == "output_text":
                        seq += 1
                        self._write_sse_event("response.content_part.added", {
                            "type": "response.content_part.added",
                            "sequence_number": seq,
                            "response_id": response_id,
                            "item_id": item.get("id", ""),
                            "output_index": idx,
                            "content_index": cidx,
                            "part": content,
                        })

                        text = content.get("text", "")
                        if text:
                            seq += 1
                            self._write_sse_event("response.output_text.delta", {
                                "type": "response.output_text.delta",
                                "sequence_number": seq,
                                "response_id": response_id,
                                "item_id": item.get("id", ""),
                                "output_index": idx,
                                "content_index": cidx,
                                "delta": text,
                            })

                        seq += 1
                        self._write_sse_event("response.content_part.done", {
                            "type": "response.content_part.done",
                            "sequence_number": seq,
                            "response_id": response_id,
                            "item_id": item.get("id", ""),
                            "output_index": idx,
                            "content_index": cidx,
                        })

                seq += 1
                self._write_sse_event("response.output_item.done", {
                    "type": "response.output_item.done",
                    "sequence_number": seq,
                    "response_id": response_id,
                    "output_index": idx,
                    "item": item,
                })

            elif item.get("type") == "function_call":
                seq += 1
                self._write_sse_event("response.output_item.added", {
                    "type": "response.output_item.added",
                    "sequence_number": seq,
                    "response_id": response_id,
                    "output_index": idx,
                    "item": item,
                })

                seq += 1
                self._write_sse_event("response.function_call_arguments.delta", {
                    "type": "response.function_call_arguments.delta",
                    "sequence_number": seq,
                    "response_id": response_id,
                    "item_id": item.get("id", ""),
                    "output_index": idx,
                    "call_id": item.get("call_id", ""),
                    "name": item.get("name", ""),
                    "delta": item.get("arguments", ""),
                })

                seq += 1
                self._write_sse_event("response.function_call_arguments.done", {
                    "type": "response.function_call_arguments.done",
                    "sequence_number": seq,
                    "response_id": response_id,
                    "item_id": item.get("id", ""),
                    "output_index": idx,
                })

                seq += 1
                self._write_sse_event("response.output_item.done", {
                    "type": "response.output_item.done",
                    "sequence_number": seq,
                    "response_id": response_id,
                    "output_index": idx,
                    "item": item,
                })

        seq += 1
        self._write_sse_event("response.completed", {
            "type": "response.completed",
            "sequence_number": seq,
            "response_id": response_id,
            "response": codex_response,
        })

    def _write_sse_event(self, event: str, data: dict):
        """发送单个 SSE event。"""
        payload = json.dumps(data, ensure_ascii=False)
        self._write_sse(f"event: {event}\ndata: {payload}\n\n")

    def _write_sse(self, raw: str):
        """写入原始 SSE 字符串并立即 flush。"""
        self.wfile.write(raw.encode("utf-8"))
        self.wfile.flush()

    def _send_json_safe(self, code, data):
        try:
            self._send_json(code, data)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def _send_error_safe(self, code, msg):
        try:
            self._send_json(code, {"error": msg})
        except (BrokenPipeError, ConnectionResetError):
            pass

    def _send_json(self, code, data):
        body = json.dumps(data, ensure_ascii=False, indent=2).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_error(self, code, msg):
        self._send_json(code, {"error": msg})


# ============================================================
#  启动入口
# ============================================================
def main():
    if not DEEPSEEK_API_KEY and not CODEX_DEEPSEEK_API_KEY and not CLAUDE_DEEPSEEK_API_KEY:
        print("⚠️  警告：未检测到任何 API Key 环境变量。")
        print("   请至少设置以下之一：")
        print("   export DEEPSEEK_API_KEY=sk-xxxxxxxxxxxxxxxx")
        print("   export CODEX_DEEPSEEK_API_KEY=sk-xxxxxxxxxxxxxxxx")
        print("   export CLAUDE_DEEPSEEK_API_KEY=xxxxxxxxxxxx\n")

    server = HTTPServer(("127.0.0.1", PROXY_PORT), ProxyHandler)
    print("=" * 58)
    print("  DeepSeek 统一代理 v2 — Claude Desktop + Codex")
    print("=" * 58)
    print(f"  监听地址：http://127.0.0.1:{PROXY_PORT}")
    print()
    print("  🔑 API Key 状态：")
    if DEEPSEEK_API_KEY:
        print(f"     通用 key (DEEPSEEK_API_KEY): ✅ 已设置")
    else:
        print(f"     通用 key (DEEPSEEK_API_KEY): ❌ 未设置")
    if CODEX_DEEPSEEK_API_KEY:
        print(f"     Codex 专用 (CODEX_DEEPSEEK_API_KEY): ✅ 已设置")
    else:
        print(f"     Codex 专用 (CODEX_DEEPSEEK_API_KEY): ⬜ 未设置")
    if CLAUDE_DEEPSEEK_API_KEY:
        print(f"     Claude 专用 (CLAUDE_DEEPSEEK_API_KEY): ✅ 已设置")
    else:
        print(f"     Claude 专用 (CLAUDE_DEEPSEEK_API_KEY): ⬜ 未设置")
    print()
    print("  📌 Claude Desktop 配置：")
    print(f"     Base URL → http://127.0.0.1:{PROXY_PORT}")
    print("  📌 Codex config.toml 配置：")
    print(f"     base_url = \"http://127.0.0.1:{PROXY_PORT}/v1\"")
    print(f"     wire_api = \"responses\"")
    print(f"     env_key = \"CODEX_DEEPSEEK_API_KEY\"")
    print()
    print("  📌 路由规则：")
    print("     POST /v1/messages  → Claude Desktop（Anthropic 透传）")
    print("     POST /v1/responses → Codex（Responses→Chat 翻译）")
    print(f"  📌 模型映射(Codex): {CODEX_MODEL_MAP}")
    print()
    print("  按 Ctrl+C 停止代理\n")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[Proxy] 已停止。")
        server.server_close()


if __name__ == "__main__":
    main()
