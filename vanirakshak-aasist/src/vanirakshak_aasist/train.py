"""
Trainer logic for VANIRAKSHAK AASIST-L.
"""
import os
import json
import logging
from typing import Dict, Any

import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader

from .evaluate import evaluate

logger = logging.getLogger(__name__)

class Trainer:
    def __init__(
        self,
        model: nn.Module,
        train_loader: DataLoader,
        val_loader: DataLoader,
        device: torch.device,
        cfg: Dict[str, Any],
        checkpoint_dir: str = "checkpoints"
    ):
        self.model = model
        self.train_loader = train_loader
        self.val_loader = val_loader
        self.device = device
        self.cfg = cfg
        self.checkpoint_dir = checkpoint_dir
        
        t_cfg = cfg["training"]
        self.epochs = t_cfg.get("epochs", 10)
        self.patience = t_cfg.get("early_stopping_patience", 3)
        self.save_best = cfg.get("checkpoints", {}).get("save_best", True)
        self.save_last = cfg.get("checkpoints", {}).get("save_last", True)
        
        # Optimizer
        lr = float(t_cfg.get("learning_rate", 1e-5))
        wd = float(t_cfg.get("weight_decay", 1e-4))
        self.optimizer = optim.Adam(self.model.parameters(), lr=lr, weight_decay=wd)
        
        # Loss (CrossEntropy expects logits, handles softmax internally)
        # AASIST outputs log-probs sometimes, but looking at upstream AASIST.py:
        # output = self.out_layer(last_hidden) (which is a linear layer to 2 units)
        # So it outputs raw logits. nn.CrossEntropyLoss is correct.
        self.criterion = nn.CrossEntropyLoss()
        
        os.makedirs(self.checkpoint_dir, exist_ok=True)
        self.metrics_log = []

    def train(self):
        best_eer = float('inf')
        patience_counter = 0
        
        logger.info(f"Starting training for {self.epochs} epochs on {self.device}")
        
        for epoch in range(1, self.epochs + 1):
            self.model.train()
            train_loss = 0.0
            
            for batch_idx, (x, y) in enumerate(self.train_loader):
                x = x.to(self.device)
                y = y.to(self.device)
                
                self.optimizer.zero_grad()
                _, logits = self.model(x)
                
                loss = self.criterion(logits, y)
                loss.backward()
                self.optimizer.step()
                
                train_loss += loss.item()
                
            train_loss /= len(self.train_loader)
            
            val_metrics, _, _ = evaluate(self.model, self.val_loader, self.device)
            eer = val_metrics.get("eer", 1.0)
            
            logger.info(f"Epoch {epoch:02d}/{self.epochs:02d} | train_loss={train_loss:.4f} | EER={eer:.4f}")
            print(f"Epoch {epoch:02d}/{self.epochs:02d} | train_loss={train_loss:.4f} | EER={eer:.4f}")
            
            self.metrics_log.append({
                "epoch": epoch,
                "train_loss": train_loss,
                "val_metrics": val_metrics
            })
            
            # Save logic
            if self.save_last:
                torch.save(self.model.state_dict(), os.path.join(self.checkpoint_dir, "last.pt"))
                
            if eer < best_eer:
                best_eer = eer
                patience_counter = 0
                if self.save_best:
                    torch.save(self.model.state_dict(), os.path.join(self.checkpoint_dir, "best.pt"))
            else:
                patience_counter += 1
                
            if patience_counter >= self.patience:
                logger.info(f"Early stopping triggered at epoch {epoch}")
                print(f"Early stopping triggered at epoch {epoch}")
                break
                
        # Save metrics
        with open(os.path.join(self.checkpoint_dir, "metrics.json"), "w") as f:
            json.dump(self.metrics_log, f, indent=4)
            
        logger.info(f"Training complete. Best EER: {best_eer:.4f}")
        return best_eer
