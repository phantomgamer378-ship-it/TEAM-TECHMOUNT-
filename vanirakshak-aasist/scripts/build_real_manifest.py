"""
VANIRAKSHAK AASIST-L — Real Data Manifest Builder  (Phase 11-12)
=================================================================
Builds a balanced bonafide/spoof manifest from:

  BONAFIDE (real speech):
    • google/fleurs  hi_in  (Apache-2.0, ~2800 clips, pure parquet, no gating)
    • google/fleurs  mr_in  (Marathi)

  SPOOF (synthetic speech):
    • ksmashhero/IndicSynth  Hindi  (public, pure parquet, no loading script)
    • ksmashhero/IndicSynth  Marathi

Audio decoding:
    soundfile + io.BytesIO — NO torchcodec, NO trust_remote_code.

Usage:
    python scripts/build_real_manifest.py --lang hi --count 200
    python scripts/build_real_manifest.py --lang mr --count 200
    python scripts/build_real_manifest.py --lang hi --count 200 --force

Options:
    --lang    hi | mr
    --count   Max clips per class (default: 200)
    --out     Custom manifest output path
    --force   Overwrite existing manifest (default: resume / skip)
"""

import os
import io
import csv
import sys
import time
import argparse
import traceback
from pathlib import Path

import numpy as np
import soundfile as sf
import librosa

TARGET_SR = 16000
NUM_SAMPLES = 64600   # AASIST-L input length

# ─── Dataset registry ────────────────────────────────────────────────────────
#
# Each entry defines:
#   hf_path       : HuggingFace dataset repo id
#   config        : dataset config/subset name (None = default)
#   split         : HF split
#   audio_col     : column name containing audio (dict with 'array'+'sampling_rate')
#   speaker_col   : column for speaker id (optional)
#   generator_col : column for TTS model id (optional, spoof only)
#
LANG_MAP = {
    "hi": {
        "bonafide": {
            "hf_path": "google/fleurs",
            "config": "hi_in",
            "split": "train+validation+test",   # merge all splits for more data
            "audio_col": "audio",
            "speaker_col": "id",
        },
        "spoof": {
            "hf_path": "ksmashhero/IndicSynth",
            "config": "Hindi",
            "split": "train",
            "audio_col": "audio",
            "speaker_col": "Source Speaker_ID",
            "generator_col": "Generative Model",
        },
    },
    "mr": {
        "bonafide": {
            "hf_path": "google/fleurs",
            "config": "mr_in",
            "split": "train+validation+test",
            "audio_col": "audio",
            "speaker_col": "id",
        },
        "spoof": {
            "hf_path": "ksmashhero/IndicSynth",
            "config": "Marathi",
            "split": "train",
            "audio_col": "audio",
            "speaker_col": "Source Speaker_ID",
            "generator_col": "Generative Model",
        },
    },
}


# ─── Audio helpers ────────────────────────────────────────────────────────────

def decode_hf_audio(audio_field) -> tuple:
    """
    Decode an HF audio field into (np.ndarray[float32], int).

    HF audio fields come as:
      {'array': np.ndarray, 'sampling_rate': int, 'path': str}
    """
    if isinstance(audio_field, dict):
        array = np.array(audio_field["array"], dtype=np.float32)
        sr = int(audio_field["sampling_rate"])
        return array, sr

    # Fallback: raw bytes
    if isinstance(audio_field, (bytes, bytearray)):
        buf = io.BytesIO(audio_field)
        array, sr = sf.read(buf, dtype="float32", always_2d=False)
        return array, sr

    raise TypeError(f"Unsupported audio field type: {type(audio_field)}")


def preprocess(array: np.ndarray, sr: int) -> np.ndarray:
    """Mono → 16 kHz → fixed-length float32 numpy array."""
    if array.ndim == 2:
        array = librosa.to_mono(array.T)
    if sr != TARGET_SR:
        array = librosa.resample(array.astype(np.float32), orig_sr=sr, target_sr=TARGET_SR)
    array = array.astype(np.float32)
    if len(array) == 0:
        raise ValueError("Zero-length audio after resampling")
    if np.isnan(array).any() or np.isinf(array).any():
        raise ValueError("Audio contains NaN/Inf after resampling")
    # Crop or repeat-pad
    if len(array) >= NUM_SAMPLES:
        array = array[:NUM_SAMPLES]
    else:
        repeats = NUM_SAMPLES // len(array) + 1
        array = np.tile(array, repeats)[:NUM_SAMPLES]
    return array


# ─── Core streaming function ──────────────────────────────────────────────────

def stream_and_save(
    cfg: dict,
    lang: str,
    role: str,
    label: int,
    out_dir: str,
    count: int,
    writer,
    prefix: str,
    existing_ids: set,
) -> int:
    """
    Stream `count` clips from an HF dataset, preprocess and save as WAV.
    Skips clip_ids already present in `existing_ids` (resume support).
    Returns number of newly saved clips.
    """
    from datasets import load_dataset

    print(f"\n  [{role.upper()}] Loading {cfg['hf_path']} [{cfg['config']}] …")

    retry_delays = [5, 15, 30]
    dataset = None
    for attempt, delay in enumerate(retry_delays + [None]):
        try:
            dataset = load_dataset(
                cfg["hf_path"],
                cfg["config"],
                split=cfg["split"],
                streaming=True,
                trust_remote_code=False,  # Never use this
            )
            break
        except Exception as e:
            if delay is None:
                print(f"  [ERROR] Could not load dataset after {len(retry_delays)} retries: {e}")
                return 0
            print(f"  [RETRY {attempt+1}] {e} — waiting {delay}s …")
            time.sleep(delay)

    saved = 0
    skipped = 0
    already_have = sum(1 for cid in existing_ids if cid.startswith(prefix))
    target = count - already_have

    if target <= 0:
        print(f"  Already have {already_have}/{count} clips for this class. Skipping download.")
        return 0

    print(f"  Need {target} more clips (already have {already_have})")

    for item in dataset:
        if saved >= target:
            break

        clip_id = f"{prefix}_{already_have + saved:05d}"

        try:
            audio_field = item[cfg["audio_col"]]
            array, sr = decode_hf_audio(audio_field)
            array = preprocess(array, sr)

            out_path = os.path.join(out_dir, f"{clip_id}.wav")
            sf.write(out_path, array, TARGET_SR, subtype="PCM_16")

            speaker_id = str(item.get(cfg.get("speaker_col", ""), "unknown") or "unknown")
            generator_id = str(item.get(cfg.get("generator_col", ""), "none") or "none")

            writer.writerow([
                clip_id,
                out_path,
                label,
                speaker_id,
                lang,
                generator_id,
                cfg["hf_path"],
            ])

            saved += 1
            if saved % 25 == 0 or saved == target:
                print(f"    {already_have + saved}/{count} saved …")

        except KeyboardInterrupt:
            print("\n  [INTERRUPTED] Saving progress and exiting.")
            sys.exit(0)

        except Exception as e:
            skipped += 1
            if skipped <= 10:
                print(f"    [SKIP #{skipped}] {e}")
            continue

    print(f"  Done: {saved} new clips saved, {skipped} skipped.")
    return saved


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Build real IndicVoices(FLEURS)+IndicSynth manifest for VANIRAKSHAK"
    )
    parser.add_argument("--lang", choices=["hi", "mr"], default="hi")
    parser.add_argument("--count", type=int, default=200,
                        help="Max clips per class (bonafide + spoof)")
    parser.add_argument("--out", default=None, help="Output manifest CSV path")
    parser.add_argument("--force", action="store_true",
                        help="Overwrite existing manifest instead of resuming")
    args = parser.parse_args()

    lang = args.lang
    count = args.count
    lang_name = {"hi": "hindi", "mr": "marathi"}[lang]

    out_dir = f"data/samples/{lang_name}"
    os.makedirs(out_dir, exist_ok=True)

    manifest_path = args.out or f"data/manifests/{lang_name}_manifest.csv"
    os.makedirs(os.path.dirname(manifest_path), exist_ok=True)

    # ── Resume: load existing clip IDs ───────────────────────────────────────
    existing_ids: set = set()
    existing_rows: list = []
    header = ["clip_id", "path", "label", "speaker_id", "language", "generator_id", "source_dataset"]

    if os.path.exists(manifest_path) and not args.force:
        with open(manifest_path, newline="") as f:
            reader = csv.DictReader(f)
            for row in reader:
                existing_ids.add(row["clip_id"])
                existing_rows.append(row)
        print(f"  Resuming: {len(existing_ids)} clips already in manifest.")
    else:
        print(f"  Starting fresh manifest: {manifest_path}")

    print(f"\n{'='*60}")
    print(f"  Language : {lang} ({lang_name})")
    print(f"  Per class: {count}")
    print(f"  Bonafide : google/fleurs")
    print(f"  Spoof    : ksmashhero/IndicSynth")
    print(f"{'='*60}\n")

    cfg = LANG_MAP[lang]

    # Open manifest in append mode
    mode = "w" if args.force or not existing_rows else "a"
    with open(manifest_path, mode, newline="") as f:
        writer = csv.writer(f)
        if mode == "w":
            writer.writerow(header)

        b_saved = stream_and_save(
            cfg["bonafide"], lang, "bonafide", 1,
            out_dir, count, writer, f"fleurs_{lang}",
            existing_ids,
        )

        s_saved = stream_and_save(
            cfg["spoof"], lang, "spoof", 0,
            out_dir, count, writer, f"synth_{lang}",
            existing_ids,
        )

    total = len(existing_ids) + b_saved + s_saved
    print(f"\n{'='*60}")
    print(f"  Manifest  → {manifest_path}")
    print(f"  Bonafide new: {b_saved}  |  Spoof new: {s_saved}  |  Total clips: {total}")
    print(f"{'='*60}")
    print(f"\nNext steps:")
    print(f"  python scripts/create_splits.py \\")
    print(f"      --manifest {manifest_path} \\")
    print(f"      --splits_dir data/splits/{lang_name}")
    print(f"  python scripts/train.py --config configs/{lang_name}.yaml")


if __name__ == "__main__":
    main()
