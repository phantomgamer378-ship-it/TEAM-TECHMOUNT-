import os
import sys
import csv
import json
import torch
import torch.nn as nn
from torch.utils.data import DataLoader
from evaluate import AudioSpoofDataset

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'src', 'upstream_aasist')))
from models.AASIST import Model

def main():
    print("Running Error Analysis (Phase 10)...")
    device = "mps" if torch.backends.mps.is_available() else "cpu"
    
    config_path = "src/upstream_aasist/config/AASIST-L.conf"
    with open(config_path, "r") as f:
        config = json.load(f)
        
    model = Model(config["model_config"])
    weight_path = "checkpoints/experiment_001/best.pt"
    
    if not os.path.exists(weight_path):
        print("Model checkpoint not found. Using pretrained AASIST-L.")
        weight_path = "src/upstream_aasist/models/weights/AASIST-L.pth"
        
    state_dict = torch.load(weight_path, map_location="cpu", weights_only=True)
    if next(iter(state_dict.keys())).startswith("module."):
        state_dict = {k.replace("module.", ""): v for k, v in state_dict.items()}
    model.load_state_dict(state_dict)
    model.to(device)
    model.eval()
    
    # Dataset
    num_samples = config["model_config"]["nb_samp"]
    test_dataset = AudioSpoofDataset("data/splits/test.csv", num_samples=num_samples)
    test_loader = DataLoader(test_dataset, batch_size=1, shuffle=False)
    
    results = []
    
    with torch.no_grad():
        for i, (x, y) in enumerate(test_loader):
            x = x.to(device)
            _, out = model(x)
            prob = torch.softmax(out, dim=1)[0, 1].item()
            pred = 1 if prob >= 0.5 else 0
            true_label = int(y[0].item())
            
            record = test_dataset.records[i]
            results.append({
                "clip_id": record["clip_id"],
                "true_label": true_label,
                "predicted_label": pred,
                "score": prob,
                "language": record["language"],
                "speaker_id": record["speaker_id"],
                "generator_id": record["generator_id"],
                "source_dataset": record["source_dataset"]
            })
            
    # Save raw predictions
    os.makedirs("reports", exist_ok=True)
    with open("reports/predictions.csv", "w", newline="") as f:
        if results:
            writer = csv.DictWriter(f, fieldnames=results[0].keys())
            writer.writeheader()
            writer.writerows(results)
            
    # Analyze
    false_positives = [r for r in results if r["predicted_label"] == 1 and r["true_label"] == 0]
    false_negatives = [r for r in results if r["predicted_label"] == 0 and r["true_label"] == 1]
    
    report_lines = [
        "# Error Analysis Report (Phase 10)",
        "",
        f"**Total Evaluated**: {len(results)}",
        f"**False Positives (Spoof predicted as Bonafide)**: {len(false_positives)}",
        f"**False Negatives (Bonafide predicted as Spoof)**: {len(false_negatives)}",
        "",
        "## False Positives by Language",
    ]
    
    langs_fp = {}
    for r in false_positives:
        langs_fp[r["language"]] = langs_fp.get(r["language"], 0) + 1
    for k, v in langs_fp.items():
        report_lines.append(f"- **{k}**: {v}")
        
    report_lines.append("\n## False Positives by Generator")
    gens_fp = {}
    for r in false_positives:
        gens_fp[r["generator_id"]] = gens_fp.get(r["generator_id"], 0) + 1
    for k, v in gens_fp.items():
        report_lines.append(f"- **{k}**: {v}")
        
    report_lines.append("\n## False Negatives by Language")
    langs_fn = {}
    for r in false_negatives:
        langs_fn[r["language"]] = langs_fn.get(r["language"], 0) + 1
    for k, v in langs_fn.items():
        report_lines.append(f"- **{k}**: {v}")
        
    with open("reports/error_analysis.md", "w") as f:
        f.write("\n".join(report_lines))
        
    print("Error analysis complete. Report saved to reports/error_analysis.md")

if __name__ == "__main__":
    main()
