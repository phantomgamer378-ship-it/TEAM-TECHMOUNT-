import os
import sys
import csv
import json
import torch
import torch.nn as nn
from torch.utils.data import Dataset, DataLoader
import soundfile as sf
from sklearn.metrics import roc_curve, auc, f1_score, precision_score, recall_score
from scipy.optimize import brentq
from scipy.interpolate import interp1d

# Add upstream repo to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'src', 'upstream_aasist')))
from models.AASIST import Model

class AudioSpoofDataset(Dataset):
    def __init__(self, manifest_path, num_samples=64600):
        self.records = []
        with open(manifest_path, "r") as f:
            reader = csv.DictReader(f)
            for row in reader:
                self.records.append(row)
        self.num_samples = num_samples
        
    def __len__(self):
        return len(self.records)
        
    def __getitem__(self, idx):
        record = self.records[idx]
        path = record["path"]
        label = int(record["label"])
        
        # Load audio
        try:
            audio, _ = sf.read(path)
            # Ensure float32
            audio = audio.astype('float32')
            
            # Pad or crop
            if len(audio) < self.num_samples:
                # pad with zeros
                pad_len = self.num_samples - len(audio)
                audio = torch.nn.functional.pad(torch.from_numpy(audio), (0, pad_len))
            elif len(audio) > self.num_samples:
                # simple deterministic crop
                audio = torch.from_numpy(audio[:self.num_samples])
            else:
                audio = torch.from_numpy(audio)
                
            return audio, label
        except Exception as e:
            # Fallback for corrupted data in pilot
            return torch.zeros(self.num_samples, dtype=torch.float32), label

def compute_eer(y_true, y_score):
    try:
        fpr, tpr, thresholds = roc_curve(y_true, y_score, pos_label=1)
        # Ensure FPR range covers [0,1] properly
        if len(set(y_true)) < 2:
            return 0.5  # Cannot compute EER without both classes
        interp_fn = interp1d(fpr, tpr, bounds_error=False, fill_value=(tpr[0], tpr[-1]))
        eer = brentq(lambda x: 1. - x - float(interp_fn(x)), 0., 1.)
        return eer
    except (ValueError, Exception):
        return 0.5  # Fallback: 50% EER signals model is no better than random

def evaluate_model(model, loader, device, desc="Evaluation"):
    model.eval()
    all_scores = []
    all_labels = []
    
    with torch.no_grad():
        for batch_idx, (x, y) in enumerate(loader):
            x = x.to(device)
            _, out = model(x)
            
            # out is shape [B, 2] usually, logits for [SPOOF, BONAFIDE]
            # Probabilities for BONAFIDE (class 1)
            probs = torch.softmax(out, dim=1)[:, 1]
            all_scores.extend(probs.cpu().numpy())
            all_labels.extend(y.numpy())
            
    if not all_labels:
        return {}
        
    eer = compute_eer(all_labels, all_scores)
    # Threshold at 0.5 for F1, etc
    preds = [1 if s >= 0.5 else 0 for s in all_scores]
    f1 = f1_score(all_labels, preds, zero_division=0)
    p = precision_score(all_labels, preds, zero_division=0)
    r = recall_score(all_labels, preds, zero_division=0)
    
    return {
        "eer": float(eer),
        "f1": float(f1),
        "precision": float(p),
        "recall": float(r)
    }

def main():
    print("Running Baseline Evaluation...")
    device = "mps" if torch.backends.mps.is_available() else "cpu"
    print(f"Using device: {device}")
    
    # Load model
    config_path = "src/upstream_aasist/config/AASIST-L.conf"
    with open(config_path, "r") as f:
        config = json.load(f)
        
    model = Model(config["model_config"])
    weight_path = "src/upstream_aasist/models/weights/AASIST-L.pth"
    state_dict = torch.load(weight_path, map_location="cpu", weights_only=True)
    if next(iter(state_dict.keys())).startswith("module."):
        state_dict = {k.replace("module.", ""): v for k, v in state_dict.items()}
    model.load_state_dict(state_dict)
    model.to(device)
    
    # Eval dataset
    val_dataset = AudioSpoofDataset("data/splits/test.csv", num_samples=config["model_config"]["nb_samp"])
    val_loader = DataLoader(val_dataset, batch_size=4, shuffle=False)
    
    metrics = evaluate_model(model, val_loader, device)
    
    os.makedirs("reports", exist_ok=True)
    with open("reports/baseline_metrics.json", "w") as f:
        json.dump(metrics, f, indent=4)
        
    print("Baseline Metrics:", metrics)

if __name__ == "__main__":
    main()
