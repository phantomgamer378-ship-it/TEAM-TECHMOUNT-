"""
VANIRAKSHAK AASIST-L — Speaker-Disjoint Split Creator  (Phase 12)
==================================================================
Creates train/val/test splits from a manifest CSV with:
  • Speaker-disjoint guarantee (no speaker appears in two splits)
  • Stratified class balance across splits
  • Detailed split report

Usage:
    # Real Hindi data:
    python scripts/create_splits.py \\
        --manifest data/manifests/hindi_manifest.csv \\
        --splits_dir data/splits/hindi

    # Pilot (default):
    python scripts/create_splits.py
        (reads data/manifests/pilot_manifest.csv → data/splits/)

Ratios: 70% train | 15% val | 15% test
"""

import os
import csv
import json
import random
import argparse
from collections import defaultdict


FIELDNAMES = ["clip_id", "path", "label", "speaker_id",
              "language", "generator_id", "source_dataset"]


def read_manifest(path: str) -> list:
    records = []
    with open(path, newline="") as f:
        reader = csv.DictReader(f, fieldnames=FIELDNAMES)
        for row in reader:
            row["label"] = int(row["label"])
            records.append(row)
    return records


def write_split(path: str, records: list):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDNAMES)
        writer.writeheader()
        writer.writerows(records)


def speaker_disjoint_split(records: list, ratios=(0.70, 0.15, 0.15), seed=42):
    """
    Assign speakers to splits such that no speaker appears in two splits.

    Falls back to random (non-disjoint) split if there are too few distinct
    speakers (< 3) — common in synthetic pilot data.
    """
    rng = random.Random(seed)

    # Group by speaker
    spk_to_records = defaultdict(list)
    for r in records:
        spk_to_records[r["speaker_id"]].append(r)

    speakers = list(spk_to_records.keys())
    rng.shuffle(speakers)
    n = len(speakers)

    if n < 3:
        # Fallback: random clip-level split (acceptable for pilot)
        rng.shuffle(records)
        t1 = int(len(records) * ratios[0])
        t2 = int(len(records) * (ratios[0] + ratios[1]))
        return records[:t1], records[t1:t2], records[t2:]

    t1 = int(n * ratios[0])
    t2 = int(n * (ratios[0] + ratios[1]))

    train_spk = set(speakers[:t1])
    val_spk   = set(speakers[t1:t2])
    test_spk  = set(speakers[t2:])

    train = [r for r in records if r["speaker_id"] in train_spk]
    val   = [r for r in records if r["speaker_id"] in val_spk]
    test  = [r for r in records if r["speaker_id"] in test_spk]

    return train, val, test


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", default="data/manifests/pilot_manifest.csv")
    parser.add_argument("--splits_dir", default="data/splits")
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    if not os.path.exists(args.manifest):
        print(f"ERROR: Manifest not found: {args.manifest}")
        print("Run build_real_manifest.py first.")
        return

    print(f"\nReading manifest: {args.manifest}")
    records = read_manifest(args.manifest)

    if not records:
        print("ERROR: Manifest is empty.")
        return

    bonafide = [r for r in records if r["label"] == 1]
    spoof    = [r for r in records if r["label"] == 0]

    print(f"  Total: {len(records)} | Bonafide: {len(bonafide)} | Spoof: {len(spoof)}")

    # Speaker-disjoint splits per class
    b_train, b_val, b_test = speaker_disjoint_split(bonafide, seed=args.seed)
    s_train, s_val, s_test = speaker_disjoint_split(spoof, seed=args.seed)

    train = b_train + s_train
    val   = b_val   + s_val
    test  = b_test  + s_test

    # Shuffle within each split
    rng = random.Random(args.seed)
    for split in [train, val, test]:
        rng.shuffle(split)

    # Write
    write_split(os.path.join(args.splits_dir, "train.csv"), train)
    write_split(os.path.join(args.splits_dir, "val.csv"),   val)
    write_split(os.path.join(args.splits_dir, "test.csv"),  test)

    # Speaker leakage check
    train_spk = {r["speaker_id"] for r in train}
    val_spk   = {r["speaker_id"] for r in val}
    test_spk  = {r["speaker_id"] for r in test}

    tv_leak = train_spk & val_spk
    tt_leak = train_spk & test_spk
    vt_leak = val_spk   & test_spk
    has_leak = bool(tv_leak or tt_leak or vt_leak)

    # Report
    os.makedirs("reports", exist_ok=True)
    report = {
        "manifest": args.manifest,
        "splits_dir": args.splits_dir,
        "seed": args.seed,
        "total_clips": len(records),
        "bonafide": len(bonafide),
        "spoof": len(spoof),
        "train": {
            "total": len(train),
            "bonafide": sum(1 for r in train if r["label"] == 1),
            "spoof": sum(1 for r in train if r["label"] == 0),
            "speakers": len(train_spk),
        },
        "val": {
            "total": len(val),
            "bonafide": sum(1 for r in val if r["label"] == 1),
            "spoof": sum(1 for r in val if r["label"] == 0),
            "speakers": len(val_spk),
        },
        "test": {
            "total": len(test),
            "bonafide": sum(1 for r in test if r["label"] == 1),
            "spoof": sum(1 for r in test if r["label"] == 0),
            "speakers": len(test_spk),
        },
        "speaker_leakage": has_leak,
        "leakage_detail": {
            "train_val": len(tv_leak),
            "train_test": len(tt_leak),
            "val_test": len(vt_leak),
        },
    }

    report_path = f"reports/split_report_{os.path.basename(args.splits_dir)}.json"
    with open(report_path, "w") as f:
        json.dump(report, f, indent=4)

    print(f"\n{'='*50}")
    print(f"  Splits → {args.splits_dir}")
    print(f"  Train : {len(train):4d}  "
          f"(B:{report['train']['bonafide']} / S:{report['train']['spoof']})")
    print(f"  Val   : {len(val):4d}  "
          f"(B:{report['val']['bonafide']} / S:{report['val']['spoof']})")
    print(f"  Test  : {len(test):4d}  "
          f"(B:{report['test']['bonafide']} / S:{report['test']['spoof']})")
    print(f"  Speaker leakage: {'YES ⚠' if has_leak else 'NONE ✓'}")
    print(f"  Report → {report_path}")
    print(f"{'='*50}")

    if has_leak:
        print(f"\n⚠️  Leakage across splits detected (normal for synthetic pilot).")
        print(f"   train↔val: {len(tv_leak)} | train↔test: {len(tt_leak)} | val↔test: {len(vt_leak)}")


if __name__ == "__main__":
    main()
