"""
WebSocket live-risk client — the 'animated dashboard' in a terminal (§12).

Connects to ws://<host>/ws/session/<id>, uploads an audio file, and prints
each Risk(t) update AS THE SERVER COMPUTES IT — the dynamic-risk demo moment.

Usage (from the repo root, venv active, server running):
    python scripts/ws_client.py demo_data/tts_hindi_scam_long.mp3
    python scripts/ws_client.py my_call.mp3 --lang mr --host ws://192.168.43.73:8000

This is exactly what the Flutter Live Risk screen will consume (same protocol).
"""
import argparse
import asyncio
import base64
import json
from pathlib import Path

import websockets


def _fmt(v):
    return f"{v:.2f}" if isinstance(v, (int, float)) else "  — "


async def run(args) -> None:
    uri = f"{args.host}/ws/session/{args.session_id}"
    audio = Path(args.audio)
    print(f"Connecting {uri}")
    print(f"Streaming  {audio.name}  (lang={args.lang})")
    print("-" * 60)

    async with websockets.connect(uri) as ws:
        await ws.send(json.dumps({"type": "start", "lang": args.lang}))
        await ws.send(json.dumps({
            "type": "audio",
            "data": base64.b64encode(audio.read_bytes()).decode(),
            "fmt": audio.suffix.lstrip("."),
        }))
        await ws.send(json.dumps({"type": "end"}))

        while True:
            msg = json.loads(await ws.recv())
            mtype = msg.get("type")
            if mtype == "status":
                print(f"  … {msg['message']}")
            elif mtype == "risk_update":
                bar = "█" * int(msg["risk_score"] / 5)
                print(f"  t={msg['t']:>4.0f}s  risk {msg['risk_score']:>3} "
                      f"{msg['level']:<8} |{bar:<20}| "
                      f"(voice {_fmt(msg.get('voice_risk'))}, scam {_fmt(msg.get('scam_risk'))})")
            elif mtype == "final":
                r = msg["response"]
                print("-" * 60)
                if r.get("fallback_used") and "risk" not in r:
                    print(f"  FALLBACK: {r.get('error')}")
                else:
                    print(f"  FINAL   : {r['risk']['score']}/100 — {r['risk']['level']}"
                          f"  ({r['scam_analysis']['category']})")
                    print(f"  Policy  : {r['explanation'][-1]}")
                    print(f"  Action  : {r['recommendation'][:70]}")
                break
            elif mtype == "error":
                print(f"  ERROR   : {msg['error']}")
                break
    print("-" * 60)


def main() -> int:
    p = argparse.ArgumentParser(description="Voice Clone Shield WS live-risk client")
    p.add_argument("audio", help="audio file to stream (WAV/MP3/FLAC/OGG)")
    p.add_argument("--lang", choices=["hi", "mr"], default="hi")
    p.add_argument("--host", default="ws://127.0.0.1:8000")
    p.add_argument("--session-id", default="ws-demo-001")
    args = p.parse_args()
    asyncio.run(run(args))
    return 0


if __name__ == "__main__":
    sys_exit = main()
    raise SystemExit(sys_exit)
