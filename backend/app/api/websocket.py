"""
WS /ws/session/{session_id} (§12, §REAL-TIME LAYER) — streams Risk(t) updates
as they are computed, ONE MESSAGE PER AUDIO CHUNK, then the final canonical
response.

PROTOCOL (prototype, documented for the Flutter/web clients):
  client → {"type": "start", "lang": "hi"|"mr"}          (optional, default hi)
  client → {"type": "audio", "data": "<base64>", "fmt": "wav"}   (1+ messages, appended)
  client → {"type": "end"}                                (triggers analysis)
  server → {"type": "status", "message": "..."}           pipeline stage progress
  server → {"type": "risk_update", "t", "risk_score", "level",
            "voice_risk", "scam_risk"}                    one per chunk
  server → {"type": "final", "response": <canonical | fallback shape>}
  server → {"type": "error", "error": "..."}              protocol problems

PROTOTYPE honesty (§15): this SIMULATES real time — the client uploads a
recording and the server paces the risk_update messages (~0.25 s apart) to
look live. It is not streaming inference and not telephony (§2). The analysis
itself is the identical stream_analysis() used by HTTP and the demo card.

Implementation note: the pipeline is CPU-bound (~seconds), so it runs in a
worker thread and events are forwarded to the socket from the event loop —
health/other endpoints stay responsive while a stream is being analysed.
"""
import asyncio
import base64
import json
import logging
import os
import queue
import tempfile
import threading

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.database import database as db
from app.pipeline import stream_analysis

router = APIRouter(tags=["websocket"])

log = logging.getLogger(__name__)

_PACING_S = 0.25  # simulated real-time pacing between risk_update messages (§15)


@router.websocket("/ws/session/{session_id}")
async def ws_session(ws: WebSocket, session_id: str) -> None:
    await ws.accept()
    temp_path: str | None = None
    try:
        lang, parts, fmt = "hi", [], ".wav"
        ended = False
        while not ended:
            msg = await ws.receive_json()
            mtype = msg.get("type")
            if mtype == "start":
                if msg.get("lang") in ("hi", "mr"):
                    lang = msg["lang"]
            elif mtype == "audio":
                fmt = str(msg.get("fmt", "wav"))
                parts.append(str(msg.get("data", "")))
            elif mtype == "end":
                ended = True
            else:
                await ws.send_json({"type": "error", "error": f"unknown message type: {mtype}"})
                return

        if not parts or not any(parts):
            await ws.send_json({
                "type": "error",
                "error": "no audio received — send {type:'audio', data:<base64>} then {type:'end'}",
            })
            return

        raw = base64.b64decode("".join(parts), validate=False)
        if not raw:
            await ws.send_json({"type": "error", "error": "audio payload decoded to empty bytes"})
            return

        # PRIVACY-FIRST: audio lives in a temp file, deleted right after (§PRIVACY).
        tmp = tempfile.NamedTemporaryFile(delete=False, suffix=f".{fmt.lstrip('.')}")
        tmp.write(raw)
        tmp.close()
        temp_path = tmp.name

        events: queue.Queue = queue.Queue()

        def worker() -> None:
            try:
                for event in stream_analysis(
                    ws.app.state.services, temp_path, session_id, lang=lang
                ):
                    events.put(event)
            except Exception as exc:  # §20 — never kill the socket with a stack trace
                log.warning("WS stream failed: %s", exc)
                events.put(("final", {
                    "status": "partial", "error": f"pipeline error: {exc}",
                    "fallback_used": True,
                }, {}))
            events.put(None)  # sentinel

        threading.Thread(target=worker, daemon=True).start()
        loop = asyncio.get_running_loop()

        final_response = None
        while True:
            event = await loop.run_in_executor(None, events.get)
            if event is None:
                break
            kind = event[0]
            if kind == "stage":
                await ws.send_json({"type": "status", "message": f"[{event[1]}] {event[2]}: {event[3]}"})
            elif kind == "risk_update":
                await ws.send_json({"type": "risk_update", **event[1]})
                await asyncio.sleep(_PACING_S)  # §15 simulated real-time pacing
            elif kind == "final":
                final_response = event[1]
                await ws.send_json({"type": "final", "response": final_response})

        # Persist the result exactly like the HTTP route does (never the audio).
        if final_response and final_response.get("risk") is not None:
            db.create_session(session_id, source="ws")
            db.save_analysis_result(session_id, final_response)
            lv = final_response.get("liveness") or {}
            if lv.get("required") and lv.get("challenge"):
                db.save_liveness(session_id, lv["challenge"])

    except WebSocketDisconnect:
        log.info("WS session %s disconnected", session_id)
    except Exception as exc:  # §20 — report, never crash the socket handler
        log.warning("WS session %s error: %s", session_id, exc)
        try:
            await ws.send_json({"type": "error", "error": str(exc)})
        except Exception:
            pass
    finally:
        if temp_path:
            try:
                os.unlink(temp_path)  # PRIVACY-FIRST
            except OSError:
                pass
