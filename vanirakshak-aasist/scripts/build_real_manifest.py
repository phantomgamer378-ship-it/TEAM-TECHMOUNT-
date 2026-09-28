"""
VANIRAKSHAK AASIST-L — Real Data Manifest Builder
Phase 11: Scale-up with actual IndicVoices + IndicSynth streaming.

Usage:
    python scripts/build_real_manifest.py --lang hi --count 500
    python scripts/build_real_manifest.py --lang mr --count 500

Requirements:
    - HuggingFace account with datasets access
    - Enough disk space (estimate ~2MB per clip × count × 4 classes)
    - Stable internet (retries are built-in via datasets library)
"""
import os
import csv
import argparse
import soundfile as sf
import librosa
import numpy as np
from datasets import load_dataset

LANG_MAP = {
    "hi": {
        "bonafide": {
            "hf_path": "ai4bharat/indicvoices_r",
            "config": "hi",
            "split": "train",
            "audio_col": "audio",
            "speaker_col": "speaker_id",
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
            "hf_path": "ai4bharat/indicvoices_r",
            "config": "mr",
            "split": "train",
            "audio_col": "audio",
            "speaker_col": "speaker_id",
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

TARGET_SR = 16000
NUM_SAMPLES = 64600


def preprocess_audio(array: np.ndarray, sr: int) -> np.ndarray:
    """Mono → resample → pad/crop to fixed length."""
    if array.ndim > 1:
        array = librosa.to_mono(array.T)
    if sr != TARGET_SR:
        array = librosa.resample(array.astype(np.float32), orig_sr=sr, target_sr=TARGET_SR)
    array = array.astype(np.float32)
    if len(array) < NUM_SAMPLES:
        array = np.pad(array, (0, NUM_SAMPLES - len(array)))
    else:
        array = array[:NUM_SAMPLES]
    # Amplitude sanity check
    if np.isnan(array).any() or np.isinf(array).any():
        raise ValueError("Audio contains NaN or Inf values")
    return array


def stream_and_save(cfg: dict, lang: str, role: str, label: int,
                    out_dir: str, count: int, writer, prefix: str):
    print(f"  Streaming {role} ({lang}) from {cfg['hf_path']} [{cfg['config']}]...")
    dataset = load_dataset(
        cfg["hf_path"],
        cfg["config"],
        split=cfg["split"],
        streaming=True,
        trust_remote_code=True,
    )
    saved = 0
    skipped = 0
    for item in dataset:
        if saved >= count:
            break
        try:
            audio = item[cfg["audio_col"]]
            array = audio["array"]
            sr = audio["sampling_rate"]

            array = preprocess_audio(np.array(array), sr)

            clip_id = f"{prefix}_{saved:05d}"
            path = os.path.join(out_dir, f"{clip_id}.wav")
            sf.write(path, array, TARGET_SR)

            speaker_id = str(item.get(cfg.get("speaker_col", ""), "unknown"))
            generator_id = str(item.get(cfg.get("generator_col", ""), "none"))

            writer.writerow([
                clip_id, path, label,
                speaker_id, lang, generator_id,
                cfg["hf_path"]
            ])
            saved += 1
            if saved % 50 == 0:
                print(f"    {saved}/{count} saved...")
        except Exception as e:
            skipped += 1
            if skipped <= 5:
                print(f"    [SKIP] {e}")
            continue

    print(f"  Done: {saved} saved, {skipped} skipped.")
    return saved


def main():
    parser = argparse.ArgumentParser(description="Build real IndicVoices+IndicSynth manifest")
    parser.add_argument("--lang", choices=["hi", "mr"], default="hi", help="Language to process")
    parser.add_argument("--count", type=int, default=500, help="Samples per class (bonafide / spoof)")
    parser.add_argument("--out", default=None, help="Output manifest path")
    args = parser.parse_args()

    lang = args.lang
    count = args.count
    lang_name = {"hi": "hindi", "mr": "marathi"}[lang]

    out_dir = f"data/samples/{lang_name}"
    os.makedirs(out_dir, exist_ok=True)

    manifest_path = args.out or f"data/manifests/{lang_name}_manifest.csv"
    os.makedirs(os.path.dirname(manifest_path), exist_ok=True)

    print(f"\n{'='*60}")
    print(f"Building REAL manifest: {lang} — {count} per class")
    print(f"Output: {manifest_path}")
    print(f"{'='*60}\n")

    cfg = LANG_MAP[lang]

    with open(manifest_path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow([
            "clip_id", "path", "label", "speaker_id",
            "language", "generator_id", "source_dataset"
        ])

        # BONAFIDE
        b_saved = stream_and_save(
            cfg["bonafide"], lang, "bonafide", 1,
            out_dir, count, writer, f"iv_{lang}"
        )

        # SPOOF
        s_saved = stream_and_save(
            cfg["spoof"], lang, "spoof", 0,
            out_dir, count, writer, f"is_{lang}"
        )

    print(f"\nManifest complete → {manifest_path}")
    print(f"  Bonafide: {b_saved} | Spoof: {s_saved} | Total: {b_saved + s_saved}")
    print(f"\nNext step:")
    print(f"  python scripts/create_splits.py --manifest {manifest_path} --splits_dir data/splits/{lang_name}")
    print(f"  python scripts/train.py --config configs/{lang_name}.yaml")


if __name__ == "__main__":
    main()
