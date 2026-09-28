import os
import sys
import csv
import json
import torch
import torch.nn as nn
from torch.utils.data import DataLoader
from evaluate import AudioSpoofDataset, evaluate_model
import torch.optim as optim

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'src', 'upstream_aasist')))
from models.AASIST import Model

def main():
    print("Running Pilot Fine-Tuning...")
    device = "mps" if torch.backends.mps.is_available() else "cpu"
    print(f"Using device: {device}")
    
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
    
    # Dataset
    num_samples = config["model_config"]["nb_samp"]
    train_dataset = AudioSpoofDataset("data/splits/train.csv", num_samples=num_samples)
    val_dataset = AudioSpoofDataset("data/splits/val.csv", num_samples=num_samples)
    
    train_loader = DataLoader(train_dataset, batch_size=4, shuffle=True)
    val_loader = DataLoader(val_dataset, batch_size=4, shuffle=False)
    
    criterion = nn.CrossEntropyLoss()
    # Weights usually expect logits, CCE expects labels
    optimizer = optim.Adam(model.parameters(), lr=1e-5, weight_decay=1e-4)
    
    epochs = 2 # Smoke test / mini pilot
    
    best_eer = float('inf')
    os.makedirs("checkpoints/experiment_001", exist_ok=True)
    
    metrics_log = []
    
    for epoch in range(1, epochs + 1):
        model.train()
        train_loss = 0.0
        
        for batch_idx, (x, y) in enumerate(train_loader):
            x = x.to(device)
            y = y.to(device)
            
            optimizer.zero_grad()
            _, out = model(x)
            loss = criterion(out, y)
            loss.backward()
            optimizer.step()
            
            train_loss += loss.item()
            
        train_loss /= len(train_loader)
        
        val_metrics = evaluate_model(model, val_loader, device)
        eer = val_metrics.get("eer", 1.0)
        
        print(f"Epoch {epoch:02d}/{epochs:02d} | train_loss={train_loss:.3f} | EER={eer:.3f} | F1={val_metrics.get('f1', 0):.2f} | LR=1e-05 | device={device}")
        
        log_entry = {
            "epoch": epoch,
            "train_loss": train_loss,
            "val_metrics": val_metrics
        }
        metrics_log.append(log_entry)
        
        # Save checkpoint
        torch.save(model.state_dict(), "checkpoints/experiment_001/last.pt")
        if eer < best_eer:
            best_eer = eer
            torch.save(model.state_dict(), "checkpoints/experiment_001/best.pt")
            
    with open("checkpoints/experiment_001/metrics.json", "w") as f:
        json.dump(metrics_log, f, indent=4)
        
    print("Fine-tuning completed. Best EER:", best_eer)

if __name__ == "__main__":
    main()
