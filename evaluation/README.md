# 📊 Evaluation — measure before you fine-tune (roadmap Phase A)

> §EVALUATION / §22 discipline: **small and honest, never exhaustive. Record
> prediction/score/expected label per sample; compute EER only if you actually
> compute it; never state an accuracy number you didn't measure.**

Fine-tuning starts here: you cannot improve (or claim to improve) a model you
have not measured. This directory holds the evaluation harness and its results.

## The harness

`scripts/evaluate_voice_detector.py` evaluates the **VoiceDetector** (the
fine-tuning target) over a folder of labelled clips:

- Naming convention IS the label — no separate labels file needed:
  - genuine speech → filenames starting `real_`, `genuine_` or `bonafide_`
  - synthetic speech → filenames starting `fake_`, `tts_`, `synth_` or `clone_`
  - anything else is **skipped with a warning** (no guessing)
- Runs the exact production pipeline (AudioProcessor → VoiceDetector) so
  measured numbers match deployed behaviour.
- Outputs per sample: file, expected label, spoof score, prediction at the
  0.5 prototype threshold, correct/incorrect.
- Metrics: accuracy per class, and **EER** — computed honestly (sorted-score
  sweep with interpolation) and only reported when BOTH classes are present.

```bash
# from the repo root, venv active
python scripts/evaluate_voice_detector.py --dir demo_data
python scripts/evaluate_voice_detector.py --dir my_eval_set --out evaluation/results
```

Results are written to `evaluation/results/` as JSON + a human-readable
Markdown table. Commit the results with the sample list so every number in
your README/slides is traceable.

## What a good evaluation set contains (build it in this order)

1. **Genuine Hindi + Marathi** — 2–3 team members reading the demo scripts and
   some casual speech, phone recordings (`real_hindi_*.wav`, `real_marathi_*.wav`).
2. **Synthetic Hindi + Marathi** — gTTS/TTS samples we already generate
   (`tts_*.mp3`), plus a second TTS system later (different generator!).
3. **Hard cases, added gradually** — noisy speech, compressed/telephony-like
   audio, short clips, code-mixed speech.

## Reading the numbers honestly

- A set of only `tts_*` samples gives a **detection rate, not EER** (EER needs
  both classes) — the harness says so explicitly instead of inventing a number.
- Scores on TTS-only fakes do NOT generalize to voice conversion or unseen
  generators — say "evaluated on N clips incl. M genuine, EER = x" or say
  nothing.
- These are PROTOTYPE measurements on a tiny set — never benchmark claims.

## Where this leads

`training/README.md` — the fine-tuning learning path. The baseline numbers
from this harness are what your future fine-tuned model must beat, measured
the same way, on the same splits.
