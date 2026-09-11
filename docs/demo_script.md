# 🎤 Judge Demo Script — Voice Clone Shield (exact click-through)

> Total time: ~12 minutes. Every command is run from the repo root with the
> venv active (`source backend/.venv/bin/activate`). The server must be
> running: `uvicorn app.main:app --host 0.0.0.0 --port 8000` (from `backend/`).
>
> Golden rule: honesty wins. Every demo output is labelled REAL vs DEMO MODE,
> and the §Q&A answers below are rehearsed, not improvised.

## Pre-flight (night before — checklist)

- [ ] `python scripts/download_voice_model.py` && `python scripts/download_asr_model.py` (models cached — no venue Wi-Fi needed)
- [ ] Demo clips ready: `demo_data/tts_hindi_scam_long.mp3`, a REAL teammate recording `real_hindi_*.wav`, `normal_message.txt`
- [ ] Server started once and health-checked
- [ ] Backup: `--pure-demo` mode runs the whole demo with ZERO models — the ultimate fallback
- [ ] Browser tabs: `http://localhost:8000/docs` (API) — phone connected to same Wi-Fi for the LAN check

## The 12-minute sequence

### 1. The problem (1 min)
"AI voice cloning makes bank/police/relative scams convincing. We answer one
question: **can I trust this caller?** — with multiple independent signals,
not one detector."

### 2. The system is alive (1 min)
```bash
curl http://127.0.0.1:8000/api/health
```
Point at `voice_detector: loaded`, `asr_service: loaded`, `database: connected`,
`privacy_mode: true`. "Every service's state is visible; phone apps hit this
endpoint first."

### 3. The money moment — live analysis of a scam call (3 min)
```bash
python scripts/demo_pipeline.py demo_data/tts_hindi_scam_long.mp3 --lang hi
```
Walk the card top-down:
- **REAL AASIST-L** deepfake score (pretrained baseline — say so)
- **REAL Hindi transcript** appearing from actual speech
- **Real scam rules** → indicators → attack types
- **Risk timeline climbing** as the scam unfolds (81 → 85 CRITICAL)
- **Policy → liveness challenge**: "Blue Tiger 47"

### 4. Dynamic risk over WebSocket (2 min) — the "animated dashboard"
```bash
python scripts/ws_client.py demo_data/tts_hindi_scam_long.mp3
```
Risk updates stream in **one per second** with progress bars — the exact
protocol the Flutter Live-Risk screen consumes. Say: "simulated real-time
today; WebRTC/SIP ingestion is the next integration phase."

### 5. The control — a normal call (1 min)
```bash
python scripts/demo_pipeline.py demo_data/real_hindi_chat.wav --lang hi
```
LOW risk, no challenge. (Use a real teammate recording. If AASIST over-flags
TTS audio here, say why — that's roadmap phase A, measured in
`evaluation/results/`.)

### 6. Breadth — message + URL scanners (2 min)
```bash
curl -s -X POST localhost:8000/api/analyze/message \
  -H 'Content-Type: application/json' \
  -d "{\"text\": \"$(cat demo_data/scam_hindi.txt)\"}"
curl -s -X POST localhost:8000/api/analyze/url \
  -H 'Content-Type: application/json' \
  -d '{"url": "http://192.168.4.22/sbi/kyc/verify?otp=1"}'
```
CRITICAL message risk, HIGH URL risk with every reason listed — same
intelligence layer, explainable by construction.

### 7. Robustness + trust (1 min)
```bash
python scripts/demo_pipeline.py demo_data/test_too_short.wav
```
"Invalid audio is rejected gracefully — the system never crashes; failed
models fall back to labelled demo mode."

### 8. Close on the architecture (1 min)
Open `/docs`. "One frozen API contract drives everything — the Flutter app
consumes these same endpoints. The full roadmap is in `future.md` and
`docs/architecture.md`."

## Q&A — rehearsed answers (§26)

- **"How does it detect a voice-clone attack?"** → "We don't depend on a
  single detector. Audio is preprocessed and analyzed in parallel for
  synthetic-voice evidence and speech content; the speech is transcribed in
  Hindi/Marathi and analyzed for scam intent; independent signals are fused
  into a continuously updated risk score; crossing a policy threshold triggers
  an adaptive liveness challenge, and the user gets an explainable warning."
- **"Is the deepfake detector accurate for Hindi/Marathi?"** → "It's a
  pretrained baseline benchmarked on English speech, not yet fully evaluated
  on Indian-language speech — that evaluation is built (`evaluation/`) and
  fine-tuning is our first research milestone (`training/README.md`)."
- **"Does it work on real phone calls?"** → "Today it proves the intelligence
  pipeline on recordings; WebRTC/SIP ingestion is the next integration phase.
  Android can't access raw SIM-call audio anyway — that's a carrier problem."
- **"What if a model fails mid-demo?"** → "It falls back to labelled demo
  mode instead of crashing — reliability was a design constraint, and it's
  tested."
- **"Why trust the risk score?"** → "Don't blindly — the fusion weights are
  transparent placeholders, exposed in every response (`weights_used`); a
  calibrated model replaces them on the roadmap."
- **"Is my audio stored?"** → "No — privacy mode: audio is analysed in a temp
  file and deleted; only metadata, scores and evidence are persisted."
