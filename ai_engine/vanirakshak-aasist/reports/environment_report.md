# Environment Report

- **Audit date:** 2026-09-28
- **Scope:** Phase 0 only. No packages were installed, datasets accessed, or model/training commands run.

## System

| Check | Result |
| --- | --- |
| Hardware | Apple MacBook Air, Apple M2, 8 CPU cores |
| Architecture | `arm64` |
| macOS | 26.5.2 (build 25F84) |
| RAM | 16 GiB |
| Available disk | 30 GiB on a 228 GiB volume (86% used) |
| Git | 2.53.0; executable available |
| Project environment | Existing isolated `.venv` at the project root |

## Python And Packages

Python was checked from the project `.venv`, not the global interpreter.

| Package | Installed version |
| --- | --- |
| Python | 3.11.9 |
| PyTorch | 2.14.0 |
| torchaudio | 2.11.0 |
| torchvision | 0.29.0 |
| NumPy | 2.4.6 |
| datasets | 5.0.1 |
| soundfile | 0.14.0 |
| librosa | 0.11.0 |
| pandas | 3.0.6 |
| scikit-learn | 1.9.1 |
| matplotlib | 3.11.2 |
| tqdm | 4.70.1 |

Validation: `python -m pip check` reported no broken requirements, and all listed packages imported successfully.

## Acceleration

- `torch.backends.mps.is_built()`: `True`
- `torch.backends.mps.is_available()`: `True`
- MPS smoke operation: created a tensor on `mps:0`; sum was `2.0`
- CUDA: unavailable (expected on this Mac)
- Selected device for this machine: **MPS**

No fallback was enabled. The audit did not run model-specific operations, so it does not establish that every AASIST-L operation is supported by MPS.

## Findings And Risks

- Phase 0 device acceptance is met: MPS is available and completed a basic tensor operation.
- `torch` and `torchaudio` have different version numbers (`2.14.0` and `2.11.0`). Imports and dependency checks pass, but their compatibility with the project's actual audio/model path must be verified in Phase 1 before training.
- Disk headroom is approximately 30 GiB. This is not sufficient reason to download either full dataset; continue with metadata inspection and a bounded pilot as specified.
- No package installation or dataset download was performed as part of this audit.

## Phase 0 Result

**Passed with a compatibility item to verify in Phase 1.** The machine is Apple Silicon, the isolated Python environment is available, Git is installed, and MPS is usable. This is an environment audit only; it does not verify the AASIST-L checkpoint, audio decoding/resampling, training, or evaluation.

## Next Commands

After approval to begin Phase 1:

```bash
cd "/Users/vishalchauhan/Documents/SIH Project/voice-clone-shield/vanirakshak-aasist"
./.venv/bin/python scripts/smoke_test.py
```

The existing smoke-test script checks both CPU and MPS and writes `reports/model_audit.md`. This command is a proposed next step only; it was not run during Phase 0.
