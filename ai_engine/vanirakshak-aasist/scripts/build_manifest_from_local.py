"""
VANIRAKSHAK AASIST-L — Local Parquet Manifest Builder  (Phase 11, offline)
===========================================================================
Reads already-downloaded FLEURS + IndicSynth parquet shards from disk,
decodes audio with soundfile, saves WAVs, and writes the manifest CSV.

Run AFTER download_shards.sh has fetched the parquet files.

Usage:
    python scripts/build_manifest_from_local.py --lang hi --count 200
    python scripts/build_manifest_from_local.py --lang mr --count 200

Parquet locations expected:
    data/raw/fleurs_hi/train.parquet
    data/raw/fleurs_hi/validation.parquet
    data/raw/fleurs_hi/test.parquet
    data/raw/indicsynth_hi/train_00000.parquet
    (etc.)
"""

import os
import io
import csv
import glob
import argparse
import traceback
from pathlib import Path

import numpy as np
import soundfile as sf
import librosa
import pyarrow.parquet as pq

TARGET_SR = 16000
NUM_SAMPLES = 64600


# ─── Audio helpers ────────────────────────────────────────────────────────────

def decode_audio_field(field) -> tuple:
    """
    Decode an HF-style audio field from parquet row.

    FLEURS stores audio as a struct with 'bytes' (binary) + 'path' (str).
    IndicSynth may store as dict with 'array' (list) + 'sampling_rate'.
    """
    if isinstance(field, dict):
        if "bytes" in field and field["bytes"]:
            buf = io.BytesIO(field["bytes"])
            array, sr = sf.read(buf, dtype="float32", always_2d=False)
            return array, sr
        elif "array" in field and field["array"] is not None:
            array = np.array(field["array"], dtype=np.float32)
            sr = int(field.get("sampling_rate", TARGET_SR))
            return array, sr

    if isinstance(field, (bytes, bytearray)):
        buf = io.BytesIO(field)
        array, sr = sf.read(buf, dtype="float32", always_2d=False)
        return array, sr

    raise TypeError(f"Cannot decode audio field of type {type(field)}: {str(field)[:100]}")


def preprocess(array: np.ndarray, sr: int) -> np.ndarray:
    """Mono → 16 kHz → fixed length float32."""
    if array.ndim == 2:
        array = librosa.to_mono(array.T)
    if sr != TARGET_SR:
        array = librosa.resample(array.astype(np.float32), orig_sr=sr, target_sr=TARGET_SR)
    array = array.astype(np.float32)
    if len(array) == 0:
        raise ValueError("Zero-length after resampling")
    if np.isnan(array).any() or np.isinf(array).any():
        raise ValueError("NaN/Inf in audio")
    if len(array) >= NUM_SAMPLES:
        return array[:NUM_SAMPLES]
    repeats = NUM_SAMPLES // len(array) + 1
    return np.tile(array, repeats)[:NUM_SAMPLES]


# ─── Core builder ─────────────────────────────────────────────────────────────

def process_parquets(
    parquet_paths: list,
    label: int,
    lang: str,
    role: str,
    out_dir: str,
    count: int,
    writer,
    prefix: str,
    audio_col: str,
    speaker_col: str,
    generator_col: str = None,
) -> int:
    """Read parquet files and save WAVs up to `count` clips."""
    os.makedirs(out_dir, exist_ok=True)
    saved = 0
    skipped = 0

    for pq_path in parquet_paths:
        if saved >= count:
            break
        print(f"    Reading {os.path.basename(pq_path)} …")

        try:
            table = pq.read_table(pq_path)
            rows = table.to_pydict()
        except Exception as e:
            print(f"    [ERROR] Cannot read parquet {pq_path}: {e}")
            continue

        # Figure out audio column
        available_cols = list(rows.keys())
        audio_key = audio_col if audio_col in available_cols else None
        if audio_key is None:
            # Try common fallbacks
            for candidate in ["audio", "audio_array", "speech", "file"]:
                if candidate in available_cols:
                    audio_key = candidate
                    break
        if audio_key is None:
            print(f"    [ERROR] No audio column found. Available: {available_cols}")
            continue

        n_rows = len(rows[audio_key])
        print(f"    Rows: {n_rows} | Audio col: '{audio_key}'")

        for i in range(n_rows):
            if saved >= count:
                break
            try:
                audio_field = rows[audio_key][i]
                array, sr = decode_audio_field(audio_field)
                array = preprocess(array, sr)

                clip_id = f"{prefix}_{saved:05d}"
                out_path = os.path.join(out_dir, f"{clip_id}.wav")
                sf.write(out_path, array, TARGET_SR, subtype="PCM_16")

                # Speaker
                spk = "unknown"
                if speaker_col and speaker_col in rows:
                    spk = str(rows[speaker_col][i] or "unknown")

                # Generator
                gen = "none"
                if generator_col and generator_col in rows:
                    gen = str(rows[generator_col][i] or "none")

                writer.writerow([
                    clip_id, out_path, label,
                    spk, lang, gen,
                    f"local:{os.path.basename(pq_path)}",
                ])
                saved += 1
                if saved % 25 == 0 or saved == count:
                    print(f"    {saved}/{count} saved …")

            except Exception as e:
                skipped += 1
                if skipped <= 10:
                    print(f"    [SKIP #{skipped}] row {i}: {e}")
                continue

    print(f"  {role}: {saved} saved, {skipped} skipped.")
    return saved


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--lang", choices=["hi", "mr"], default="hi")
    parser.add_argument("--count", type=int, default=200)
    parser.add_argument("--out", default=None)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    lang = args.lang
    count = args.count
    lang_name = {"hi": "hindi", "mr": "marathi"}[lang]
    fleurs_config = {"hi": "hi_in", "mr": "mr_in"}[lang]
    synth_config  = {"hi": "Hindi", "mr": "Marathi"}[lang]

    # Locate parquet files
    bonafide_dir = f"data/raw/fleurs_{lang}"
    spoof_dir    = f"data/raw/indicsynth_{lang}"

    bonafide_parquets = sorted(glob.glob(f"{bonafide_dir}/*.parquet"))
    spoof_parquets    = sorted(glob.glob(f"{spoof_dir}/*.parquet"))

    if not bonafide_parquets:
        print(f"\n❌ No FLEURS parquets found in {bonafide_dir}/")
        print(f"   Run first:  bash scripts/download_shards.sh {lang}")
        return
    if not spoof_parquets:
        print(f"\n❌ No IndicSynth parquets found in {spoof_dir}/")
        print(f"   Run first:  bash scripts/download_shards.sh {lang}")
        return

    print(f"\n  Bonafide parquets: {len(bonafide_parquets)} file(s)")
    for p in bonafide_parquets:
        print(f"    {p}  ({os.path.getsize(p)//1024} KB)")
    print(f"  Spoof parquets: {len(spoof_parquets)} file(s)")
    for p in spoof_parquets:
        print(f"    {p}  ({os.path.getsize(p)//1024} KB)")

    out_dir = f"data/samples/{lang_name}"
    os.makedirs(out_dir, exist_ok=True)

    manifest_path = args.out or f"data/manifests/{lang_name}_manifest.csv"
    os.makedirs(os.path.dirname(manifest_path), exist_ok=True)

    header = ["clip_id", "path", "label", "speaker_id",
              "language", "generator_id", "source_dataset"]

    mode = "w" if args.force or not os.path.exists(manifest_path) else "a"
    write_header = (mode == "w")

    print(f"\n{'='*60}")
    print(f"  Building manifest: {manifest_path}  (mode={mode})")
    print(f"{'='*60}\n")

    with open(manifest_path, mode, newline="") as f:
        writer = csv.writer(f)
        if write_header:
            writer.writerow(header)

        print(f"  [BONAFIDE] google/fleurs [{fleurs_config}]")
        b_saved = process_parquets(
            bonafide_parquets, label=1, lang=lang,
            role="bonafide", out_dir=out_dir,
            count=count, writer=writer,
            prefix=f"fleurs_{lang}",
            audio_col="audio",
            speaker_col="id",
        )

        print(f"\n  [SPOOF] ksmashhero/IndicSynth [{synth_config}]")
        s_saved = process_parquets(
            spoof_parquets, label=0, lang=lang,
            role="spoof", out_dir=out_dir,
            count=count, writer=writer,
            prefix=f"synth_{lang}",
            audio_col="audio",
            speaker_col="Source Speaker_ID",
            generator_col="Generative Model",
        )

    print(f"\n{'='*60}")
    print(f"  Manifest    → {manifest_path}")
    print(f"  Bonafide    : {b_saved}")
    print(f"  Spoof       : {s_saved}")
    print(f"  Total clips : {b_saved + s_saved}")
    print(f"{'='*60}")
    print(f"\nNext steps:")
    print(f"  python scripts/create_splits.py \\")
    print(f"      --manifest {manifest_path} \\")
    print(f"      --splits_dir data/splits/{lang_name}")
    print(f"  python scripts/train.py --config configs/{lang_name}.yaml")


if __name__ == "__main__":
    main()
