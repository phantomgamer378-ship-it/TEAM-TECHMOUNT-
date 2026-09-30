# Phase 0: Dependency Audit

## 1. Backend (Python/FastAPI)
**Location:** `backend/requirements.txt`

### Core Frameworks
- `fastapi>=0.110`
- `uvicorn[standard]>=0.29`
- `pydantic>=2.6`

### ML & Audio Utilities
- `torch>=2.2`, `torchaudio>=2.2` (CPU currently assumed for inference API)
- `numpy>=1.26`
- `soundfile>=0.12.2`, `librosa>=0.10.2` (Audio preprocessing)
- `transformers>=4.40` (ASR/IndicConformer)
- `faster-whisper>=1.0` (ASR fallback)

### Missing / Required Upgrades (Future Phases)
- **Database:** `asyncpg`, `sqlalchemy` or `sqlmodel`, `alembic` (for Phase 11/12)
- **Redis:** `redis.asyncio` (for Phase 13)
- **Monitoring:** `prometheus-client`, `opentelemetry` (for Phase 15)

---

## 2. ML Training (vanirakshak-aasist)
**Location:** `vanirakshak-aasist/requirements-lock.txt`

### Core ML
- `torch==2.14.0`, `torchaudio==2.11.0`, `torchvision==0.29.0` (CUDA/MPS enabled for training)
- `numpy==2.4.6`, `pandas==3.0.6`

### Data Ingestion
- `pyarrow==25.0.1`, `datasets==5.0.1`, `huggingface_hub==1.33.0`

---

## 3. Frontend (Flutter)
**Location:** `frontend/flutter_app/pubspec.yaml` (Assuming standard structure)

### Expected Dependencies (Needs verification)
- HTTP/WebSocket clients (`http`, `web_socket_channel`)
- State management (Provider/Riverpod/Bloc)
- Audio recording plugins (`record`, `audioplayers`)

## 4. Operational / DevOps (Missing)
- **Docker:** No `Dockerfile` or `docker-compose.yml` found.
- **CI/CD:** No `.github/workflows` found.
