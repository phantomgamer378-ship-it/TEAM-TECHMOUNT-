"""
Evaluation logic for VANIRAKSHAK AASIST-L.
"""
import logging
from typing import Dict, Tuple, List

import torch
from torch.utils.data import DataLoader

from .metrics import compute_metrics

logger = logging.getLogger(__name__)

def evaluate(
    model: torch.nn.Module,
    loader: DataLoader,
    device: torch.device,
) -> Tuple[Dict[str, float], List[float], List[int]]:
    """
    Run evaluation loop over a dataloader.
    
    Returns:
        metrics: Dict of computed metrics (eer, f1, etc)
        scores: List of predicted probabilities for Bonafide
        labels: List of ground truth labels
    """
    model.eval()
    all_scores = []
    all_labels = []
    
    with torch.no_grad():
        for batch_idx, (x, y) in enumerate(loader):
            x = x.to(device)
            
            # Forward pass: AASIST returns (hidden, logits)
            _, logits = model(x)
            
            # Logits shape: [B, 2] -> [Spoof, Bonafide]
            # Softmax to get probability of Bonafide
            probs = torch.softmax(logits, dim=1)[:, 1]
            
            all_scores.extend(probs.cpu().numpy().tolist())
            all_labels.extend(y.numpy().tolist())
            
    metrics = compute_metrics(all_labels, all_scores)
    return metrics, all_scores, all_labels
