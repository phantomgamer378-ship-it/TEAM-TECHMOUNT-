# Phase 0: Repository Current State

## 1. Project Locations
- **Frontend (Flutter)**: `frontend/flutter_app`
- **Backend (FastAPI)**: `backend/app`
- **ML & Training**: `vanirakshak-aasist`
- **Model Checkpoint**: `vanirakshak-aasist/artifacts/final/aasist_l_vanirakshak.pt`
- **Training Scripts**: `vanirakshak-aasist/scripts/train.py`, `create_splits.py`
- **Inference Scripts**: `vanirakshak-aasist/artifacts/final/inference.py`
- **Config Files**: `vanirakshak-aasist/configs/`
- **Environment Files**: `backend/.env`, `backend/.env.example`

## 2. Component Status

| Component | Status | Notes |
| :--- | :--- | :--- |
| **Model Checkpoint** | **DONE** | Fine-tuned AASIST-L on hi_in/IndicSynth exists at `artifacts/final/aasist_l_vanirakshak.pt` |
| **Database Configuration** | **MISSING** | No Postgres setup yet. Currently uses SQLite for local history. |
| **API Contracts** | **PARTIAL** | FastAPI routes exist (`/api/analyze/audio`) but are prototype-level. |
| **WebSocket Implementation** | **PARTIAL** | Basic simulation chunks implemented, but not true streaming inference. |
| **Flutter Routes** | **PARTIAL** | Basic IndexedStack routing exists in `app.dart`. Native Android bridge missing. |
| **Flutter State Management** | **PARTIAL** | Simple state exists. Needs robust architecture for real-time. |
| **Tests** | **PARTIAL** | 20+ tests exist in `backend/tests/` (pytest) but lack E2E coverage. |
| **Deployment Configuration** | **MISSING** | No Dockerfiles or deployment configs for AWS/GCP yet. |
| **CI/CD** | **MISSING** | No GitHub Actions or CI/CD pipelines defined. |

## 3. Risk Assessment
- **RISK**: Model checkpoint is currently stored locally inside the gitignored `artifacts/final/` folder. Needs formal model registry/storage (e.g. S3).
- **RISK**: Inference script `inference.py` is disconnected from FastAPI backend (backend currently imports a dummy/pretrained ML service).
- **RISK**: ASR uses `faster-whisper` but lacks Hindi/Marathi code-mixed specialized models.
- **RISK**: Liveness is a text-match stub, not a robust speaker verification system.
- **RISK**: Scam intelligence relies on keyword rules instead of NLP models.
