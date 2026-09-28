"""
Evaluation metrics for VANIRAKSHAK AASIST-L.
"""
from typing import Dict, List, Tuple
import torch
import numpy as np
from sklearn.metrics import roc_curve, f1_score, precision_score, recall_score
from scipy.optimize import brentq
from scipy.interpolate import interp1d

def compute_eer(y_true: np.ndarray, y_score: np.ndarray) -> float:
    """
    Compute Equal Error Rate (EER).
    
    Returns 0.5 (random guess) if EER cannot be computed due to edge cases
    (e.g. only one class present in y_true, or all scores identical).
    """
    try:
        if len(set(y_true)) < 2:
            return 0.5
            
        fpr, tpr, thresholds = roc_curve(y_true, y_score, pos_label=1)
        
        # Guard against identical scores causing NaN interpolation
        if np.isnan(fpr).any() or np.isnan(tpr).any():
            return 0.5
            
        interp_fn = interp1d(fpr, tpr, bounds_error=False, fill_value=(tpr[0], tpr[-1]))
        eer = brentq(lambda x: 1. - x - float(interp_fn(x)), 0., 1.)
        return float(eer)
    except Exception:
        return 0.5


def compute_metrics(y_true: List[int], y_score: List[float], threshold: float = 0.5) -> Dict[str, float]:
    """
    Compute standard classification metrics.
    
    Args:
        y_true: Ground truth labels (1=Bonafide, 0=Spoof)
        y_score: Predicted probabilities for Bonafide
        threshold: Decision threshold
    """
    if not y_true:
        return {}
        
    y_true_arr = np.array(y_true)
    y_score_arr = np.array(y_score)
    
    preds = (y_score_arr >= threshold).astype(int)
    
    eer = compute_eer(y_true_arr, y_score_arr)
    f1 = f1_score(y_true_arr, preds, zero_division=0)
    p = precision_score(y_true_arr, preds, zero_division=0)
    r = recall_score(y_true_arr, preds, zero_division=0)
    
    return {
        "eer": float(eer),
        "f1": float(f1),
        "precision": float(p),
        "recall": float(r)
    }
