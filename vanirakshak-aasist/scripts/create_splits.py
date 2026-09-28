import os
import csv
import random
import json

def main():
    print("Creating splits...")
    manifest_path = "data/manifests/pilot_manifest.csv"
    if not os.path.exists(manifest_path):
        print(f"Error: {manifest_path} not found.")
        return
        
    records = []
    with open(manifest_path, "r") as f:
        reader = csv.DictReader(f)
        for row in reader:
            records.append(row)
            
    bonafide = [r for r in records if int(r["label"]) == 1]
    spoof    = [r for r in records if int(r["label"]) == 0]

    random.seed(42)
    random.shuffle(bonafide)
    random.shuffle(spoof)

    def stratified_split(items):
        n = len(items)
        train_end = int(n * 0.7)
        val_end   = int(n * 0.85)
        return items[:train_end], items[train_end:val_end], items[val_end:]

    b_train, b_val, b_test = stratified_split(bonafide)
    s_train, s_val, s_test = stratified_split(spoof)

    train_records = b_train + s_train
    val_records   = b_val   + s_val
    test_records  = b_test  + s_test
            
    # Save splits
    splits_dir = "data/splits"
    os.makedirs(splits_dir, exist_ok=True)
    
    def write_split(name, data):
        path = os.path.join(splits_dir, f"{name}.csv")
        if not data:
            return
        with open(path, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=data[0].keys())
            writer.writeheader()
            writer.writerows(data)
            
    write_split("train", train_records)
    write_split("val", val_records)
    write_split("test", test_records)
    
    # Validate overlap
    train_s = set([r["speaker_id"] for r in train_records])
    val_s = set([r["speaker_id"] for r in val_records])
    test_s = set([r["speaker_id"] for r in test_records])
    
    leakage_1 = train_s.intersection(val_s)
    leakage_2 = train_s.intersection(test_s)
    leakage_3 = val_s.intersection(test_s)
    
    has_leakage = len(leakage_1) > 0 or len(leakage_2) > 0 or len(leakage_3) > 0
    
    report = {
        "train_size": len(train_records),
        "val_size": len(val_records),
        "test_size": len(test_records),
        "train_speakers": len(train_s),
        "val_speakers": len(val_s),
        "test_speakers": len(test_s),
        "speaker_leakage": has_leakage,
        "note": "Synthetic pilot data uses dummy speaker IDs; leakage expected and documented."
    }
    
    report_path = "reports/split_report.json"
    with open(report_path, "w") as f:
        json.dump(report, f, indent=4)
        
    if has_leakage:
        print(f"WARNING: Speaker leakage detected (expected for synthetic pilot). Continuing.")
    else:
        print(f"Splits created successfully. No leakage.")
        
if __name__ == "__main__":
    main()
