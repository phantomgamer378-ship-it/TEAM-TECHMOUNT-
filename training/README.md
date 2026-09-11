# 🎓 Fine-Tuning Learning Path — from pretrained baseline to Hindi/Marathi Shield

> This is the post-SIH research track (roadmap phases A–C of the master
> prompt). The prototype deliberately does NOT train models — it *measures*
> the baseline (`evaluation/`) and keeps the architecture swap-ready. This
> document teaches the fine-tuning journey end-to-end, tied to OUR codebase.
>
> Standing rules (never break these): no fake metrics · never claim 100%
> detection · evaluate before and after · speaker-disjoint and
> generator-disjoint splits · say "pretrained baseline, evaluated on N clips"
> or say nothing.

---

## 1. THE MODEL: `AASIST-L` — the one already in production

We fine-tune **the exact AASIST-L architecture that already runs in our
backend** (`backend/app/ml/aasist.py` + the pretrained LA checkpoint).

**Why this model and not something bigger/shinier:**

| Reason | Detail |
|---|---|
| Already integrated | It sits behind our `VoiceDetector` interface; a fine-tuned checkpoint swaps in via `MODEL_PATH` with zero code changes |
| Tiny | ~110K parameters → trainable on a **free Colab GPU** in hours, not days |
| Strong baseline | ~1% EER on ASVspoof2019-LA (its home benchmark) — a solid starting point to *preserve* while adding Indian-language robustness |
| We measured the gap | Our evaluation harness shows clean Hindi/Marathi TTS scores 0.89–1.0 spoof (correct), but we have **no genuine Indian speech measured yet** — that unknown is exactly what Phase A→C fixes |
| Research headroom | The master prompt's regional architecture = **shared encoder + per-language calibration heads** — a natural second stage on top of the same backbone |

**What "fine-tuning" means here, concretely:** load the pretrained LA
checkpoint, then continue training with a small learning rate on Indian
real/fake pairs, so the model keeps its general anti-spoofing knowledge while
learning Indian-language acoustics (phonemes, mics, TTS systems, telephone
channels). Later stages can freeze the backbone and train only a small
calibration head per language — cheaper and less catastrophic-forgetting.

**Later models (do NOT start here):** a Whisper-encoder feature branch fused
with AASIST (master prompt's research extension), wav2vec2/WavLM front ends,
and a LoRA fine-tune of IndicConformer for the ASR track. Each is a separate
project after AASIST-L works.

## 2. THE DATA: a two-stage plan (start small, then public corpora)

### Stage 1 — the starter set you build yourself (this is where you begin)

Fully license-clean, fully understood, splits you control. Target: **200–500
clips per class** to validate the whole loop before scaling.

| Class | Source | Notes |
|---|---|---|
| **Genuine** | Team + friends reading scripts & chatting, Hindi/Marathi, phone mic (16 kHz where possible) | `real_hindi_*.wav` — aim for ≥5 speakers; record a manifest (speaker, device, language) |
| **Fake (TTS)** | **Multiple generators**: gTTS, edge-tts, AI4Bharat Indic-TTS, and one cloning system (XTTS-v2) | `fake_hindi_tts1_*.wav` — generator diversity is THE point; a model trained on one TTS system learns to detect that system, not "fakeness" |
| **Noise/telephony** (later) | Augment both classes: add noise, MP3-ify, band-limit to 300–3400 Hz (phone channel) | Augmentations are applied at training time, not stored |

**The one beginner trap to internalize: leakage.** If the same speaker appears
in both train and test (even across real/fake pairs), or the same TTS
generator produces both train and test fakes, your EER will be fiction.
Splits must be **speaker-disjoint** AND **generator-disjoint**.

### Stage 2 — public corpora (verified availability, September 2026)

| Dataset | What | Access (verified on HF) |
|---|---|---|
| **IndicVoices** (`ai4bharat/IndicVoices`) | Genuine Indian speech, 22 languages incl. **hi, mr** — 11,200+ hrs transcribed | **HF `gated: auto`** — request access, approved instantly; **CC-BY-4.0** |
| **IndicVoices-R** (`ai4bharat/indicvoices_r`) | Read speech variant — controlled content, easier anti-spoof pairing | HF, `gated: auto` |
| **IndicSynth** | Indian **synthetic** speech (TTS + voice conversion) for deepfake research — the master prompt names it for exactly this | **NOT on Hugging Face** — request via the AI4Bharat website (research-use constraints apply). An unofficial HF mirror exists (`vdivyasharma/IndicSynth`) — verify authenticity/license before using |
| **ASVspoof2019 LA** | English, the checkpoint's home benchmark | Download per protocol — used to **validate your training loop** (below) |

**Common Voice note:** Mozilla moved distribution to "Mozilla Data Collective"
(Oct 2025) — more friction now; IndicVoices is the better path.

### The pipeline-validation trick (do this first)

Before trusting any Indian-data run: **fine-tune on ASVspoof2019 LA itself**
(the checkpoint's home data) and confirm you reproduce sane behavior (EER in
the ~1–3% neighborhood on its eval set). If your loop can't reproduce the
benchmark, the loop is broken — not the data. This is the cheapest debugging
tool you will ever use.

## 3. THE METHOD (beginner → practitioner)

1. **Transfer learning, concretely:** `model = Model(AASIST_L_CONFIG); model.load_state_dict(pretrained)` → train with **lr 1e-4 → 1e-5** (10–100× smaller than pretraining), 20–50 epochs, batch 16–32.
2. **Loss:** weighted cross-entropy (same as the official repo); keep class balance roughly even.
3. **Preprocessing = OUR pipeline:** 16 kHz mono peak-normalized — the SAME `AudioProcessor` path at train and inference time. A train/serve mismatch here is the #1 silent killer of anti-spoof fine-tunes.
4. **Augmentation at train time:** random gain, noise (SNR 5–20 dB), MP3 re-encode, 300–3400 Hz band-limit. `torchaudio` does all of it.
5. **Windowing:** fixed ~4 s windows (64600 samples) — the model's native input; random crop per epoch.
6. **Metrics:** **EER** is the anti-spoofing metric (the point where miss-rate = false-alarm-rate). Our `scripts/evaluate_voice_detector.py` already computes it honestly — reuse that sweep logic in training to select the best epoch on a **dev** set, and touch the test set ONCE at the end.
7. **Calibration (roadmap Phase C end):** after training, pick the operating threshold on dev data (our current 0.5 is uncalibrated); optionally per-language heads. Report EER *and* the chosen threshold.
8. **Unseen-generator evaluation (Phase E):** hold out one TTS system entirely from training; report EER on it separately. That number is the honest "does it generalize?" answer.

## 4. THE TRAINING SKELETON (Phase C starting point — Colab-ready shape)

> Marked FUTURE: this is the loop you'll run once Stage-1 data exists. It
> plugs into OUR architecture — nothing here invents new interfaces.

```python
# training/train_aasist.py (FUTURE — Phase C; skeleton for learning)
# Run on Colab GPU. Validate on ASVspoof2019 LA first (§2 pipeline-validation trick).

import torch, torch.nn as nn
from torch.utils.data import Dataset, DataLoader
from app.ml.aasist import Model, AASIST_L_CONFIG   # OUR ported architecture

class ClipDataset(Dataset):
    """real_*/fake_* files → 64600-sample windows + label (bonafide=1, spoof=0)."""
    # __getitem__: AudioProcessor.preprocess → random 4s crop → torch.float32

def evaluate_eer(model, loader, device):
    """Reuse the sorted-score EER sweep from scripts/evaluate_voice_detector.py."""

model = Model(AASIST_L_CONFIG)
model.load_state_dict(torch.load("models/AASIST-L.pth", map_location="cpu"))
model.to(device)

loss_fn = nn.CrossEntropyLoss(weight=torch.tensor([1.0, 1.0]).to(device))
optim = torch.optim.Adam(model.parameters(), lr=1e-4, weight_decay=1e-4)

best_eer = 1.0
for epoch in range(30):
    model.train()
    for wav, label in train_loader:            # speaker-disjoint train split
        out = model(wav.to(device))[1]         # (B, 2) logits — official contract
        loss = loss_fn(out, label.to(device))
        optim.zero_grad(); loss.backward(); optim.step()

    model.eval()
    eer = evaluate_eer(model, dev_loader, device)   # generator-disjoint dev split
    print(f"epoch {epoch}: dev EER = {eer}")
    if eer < best_eer:
        best_eer = eer
        torch.save(model.state_dict(), "models/checkpoints/regional_best.pth")

# NEVER touch the test split until the end. Report EER on held-out speakers
# AND on a held-out TTS generator separately.
```

**Deployment:** the best checkpoint goes to `backend/models/` and loads through
the existing `VoiceDetector` (`VOICE_MODEL_PATH` in `.env`) — the master
prompt's `FutureRegionalVoiceDetector` swap, one env var, zero code changes.
Then re-run `scripts/evaluate_voice_detector.py` and report before/after EER
on the SAME set.

## 5. MILESTONES (each one is a real, reportable result)

- [ ] **A1** — genuine recordings collected (≥5 speakers × hi/mr) → first EER with both classes (today the harness honestly reports "not computable")
- [ ] **A2** — evaluation table committed (`evaluation/results/`) — the pretrained baseline, measured
- [ ] **B1** — starter set: ≥200 genuine + ≥200 fake, ≥3 TTS generators, manifest written
- [ ] **B2** — splits: speaker-disjoint + generator-disjoint, documented in `data/metadata/`
- [ ] **C1** — training loop reproduces ASVspoof2019 LA sanity numbers
- [ ] **C2** — fine-tuned model beats the baseline EER on the Indian test set (report BOTH numbers)
- [ ] **D1** — threshold calibrated on dev; per-language breakdown published
- [ ] **E1** — unseen-generator EER reported honestly (this number will be worse — say so)

## 6. COMPUTE REALITY CHECK

| Task | Feasible on |
|---|---|
| AASIST-L fine-tune (200–500 clips × 30 epochs) | **Free Colab GPU** — the model is ~110K params; minutes per epoch |
| IndicVoices-scale training (1000s of hrs) | Colab Pro / one rented GPU — only if you scale up deliberately |
| IndicConformer ASR LoRA (600M) | Colab Pro with QLoRA/PEFT — separate track, do NOT start before AASIST-L works |
| Whisper-feature fusion research | Post-doc-level; document, don't build |
