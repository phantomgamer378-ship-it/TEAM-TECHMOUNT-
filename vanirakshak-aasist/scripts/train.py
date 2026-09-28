"""
VANIRAKSHAK AASIST-L — Training Entry Point  (Phase 13-14)
===========================================================
Loads config, builds datasets, runs Trainer, evaluates final model.

Usage:
    # Pilot (synthetic data, already split):
    python scripts/train.py --config configs/pilot.yaml

    # Real Hindi data (after build_real_manifest + create_splits):
    python scripts/train.py --config configs/hindi.yaml

    # Override epochs:
    python scripts/train.py --config configs/hindi.yaml --epochs 20
"""

import os
import sys
import json
import argparse
import logging

# ── Path setup ────────────────────────────────────────────────────────────────
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "src"))
sys.path.insert(0, os.path.join(ROOT, "src", "upstream_aasist"))

import torch
import yaml
from torch.utils.data import DataLoader

from vanirakshak_aasist.device import get_device
from vanirakshak_aasist.dataset import VanirakshakDataset
from vanirakshak_aasist.train import Trainer
from vanirakshak_aasist.evaluate import evaluate
from models.AASIST import Model

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("vanirakshak.train")


def load_config(path: str) -> dict:
    with open(path) as f:
        cfg = yaml.safe_load(f)
    return cfg


def load_model(cfg: dict, device: torch.device) -> torch.nn.Module:
    """Load AASIST-L with pretrained weights."""
    aasist_cfg_path = os.path.join(ROOT, "src", "upstream_aasist", "config", "AASIST-L.conf")
    with open(aasist_cfg_path) as f:
        aasist_cfg = json.load(f)

    model = Model(aasist_cfg["model_config"])

    weight_path = os.path.join(ROOT, "src", "upstream_aasist", "models", "weights", "AASIST-L.pth")
    if not os.path.exists(weight_path):
        logger.error(f"Pretrained weights not found: {weight_path}")
        logger.error("Download from: https://github.com/clovaai/aasist")
        sys.exit(1)

    logger.info(f"Loading pretrained weights from {weight_path}")
    state_dict = torch.load(weight_path, map_location="cpu", weights_only=True)

    # Handle DataParallel prefix
    if next(iter(state_dict.keys())).startswith("module."):
        state_dict = {k.replace("module.", ""): v for k, v in state_dict.items()}

    missing, unexpected = model.load_state_dict(state_dict, strict=False)
    if missing:
        logger.warning(f"Missing keys ({len(missing)}): {missing[:5]}")
    if unexpected:
        logger.warning(f"Unexpected keys ({len(unexpected)}): {unexpected[:5]}")

    model = model.to(device)
    logger.info(f"Model on {device} ✓")
    return model


def build_loaders(cfg: dict) -> tuple:
    """Return (train_loader, val_loader, test_loader)."""
    t_cfg = cfg["training"]
    batch_size = t_cfg.get("batch_size", 8)

    splits_dir = cfg.get("splits_dir", "data/splits")

    aug_cfg = cfg.get("augmentation", {})
    aug_enabled = aug_cfg.get("enabled", False)
    aug_dict = {
        "gain":      aug_cfg.get("gain", False),
        "noise":     aug_cfg.get("noise", False),
        "telephone": aug_cfg.get("telephone", False),
    } if aug_enabled else {}

    train_ds = VanirakshakDataset(
        os.path.join(splits_dir, "train.csv"),
        is_train=True,
        augmentation=aug_dict,
    )
    val_ds = VanirakshakDataset(
        os.path.join(splits_dir, "val.csv"),
        is_train=False,
    )
    test_ds = VanirakshakDataset(
        os.path.join(splits_dir, "test.csv"),
        is_train=False,
    )

    train_loader = DataLoader(
        train_ds, batch_size=batch_size, shuffle=True,
        num_workers=0, pin_memory=False, drop_last=True,
    )
    val_loader = DataLoader(
        val_ds, batch_size=batch_size, shuffle=False,
        num_workers=0, pin_memory=False,
    )
    test_loader = DataLoader(
        test_ds, batch_size=batch_size, shuffle=False,
        num_workers=0, pin_memory=False,
    )

    logger.info(
        f"Train: {len(train_ds)} | Val: {len(val_ds)} | Test: {len(test_ds)}"
        f" | Aug: {'ON' if aug_enabled else 'OFF'}"
    )
    return train_loader, val_loader, test_loader


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True, help="Path to YAML config")
    parser.add_argument("--epochs", type=int, default=None,
                        help="Override epochs in config")
    parser.add_argument("--checkpoint_dir", default=None,
                        help="Override checkpoint directory")
    args = parser.parse_args()

    # ── Config ────────────────────────────────────────────────────────────────
    cfg = load_config(args.config)
    if args.epochs:
        cfg["training"]["epochs"] = args.epochs

    ckpt_dir = args.checkpoint_dir or cfg.get("checkpoints", {}).get(
        "dir", "checkpoints/experiment_001"
    )
    os.makedirs(ckpt_dir, exist_ok=True)

    # ── Device ────────────────────────────────────────────────────────────────
    device = get_device()
    logger.info(f"Device: {device}")

    # ── Model ─────────────────────────────────────────────────────────────────
    model = load_model(cfg, device)

    # ── Data ──────────────────────────────────────────────────────────────────
    train_loader, val_loader, test_loader = build_loaders(cfg)

    if len(train_loader) == 0:
        logger.error("Train set is empty! Run build_real_manifest.py and create_splits.py first.")
        sys.exit(1)

    # ── Train ─────────────────────────────────────────────────────────────────
    logger.info("=" * 60)
    logger.info("Starting fine-tuning …")
    logger.info(f"Config : {args.config}")
    logger.info(f"Epochs : {cfg['training']['epochs']}")
    logger.info(f"Ckpt   : {ckpt_dir}")
    logger.info("=" * 60)

    trainer = Trainer(
        model=model,
        train_loader=train_loader,
        val_loader=val_loader,
        device=device,
        cfg=cfg,
        checkpoint_dir=ckpt_dir,
    )
    best_eer = trainer.train()

    # ── Final test-set evaluation ─────────────────────────────────────────────
    logger.info("\nLoading best checkpoint for final test evaluation …")
    best_ckpt = os.path.join(ckpt_dir, "best.pt")
    if os.path.exists(best_ckpt):
        state = torch.load(best_ckpt, map_location=device, weights_only=True)
        model.load_state_dict(state, strict=False)
    else:
        logger.warning("best.pt not found — using last model state for test eval")

    test_metrics, _, _ = evaluate(model, test_loader, device)

    logger.info("=" * 60)
    logger.info("FINAL TEST RESULTS")
    logger.info(f"  EER       : {test_metrics.get('eer', 'N/A'):.4f}")
    logger.info(f"  F1        : {test_metrics.get('f1', 'N/A'):.4f}")
    logger.info(f"  Precision : {test_metrics.get('precision', 'N/A'):.4f}")
    logger.info(f"  Recall    : {test_metrics.get('recall', 'N/A'):.4f}")
    logger.info("=" * 60)

    # Append test results to metrics.json
    metrics_path = os.path.join(ckpt_dir, "metrics.json")
    if os.path.exists(metrics_path):
        with open(metrics_path) as f:
            history = json.load(f)
    else:
        history = []

    history.append({"test_final": test_metrics})
    with open(metrics_path, "w") as f:
        json.dump(history, f, indent=4)

    # Acceptance gate
    eer = test_metrics.get("eer", 1.0)
    if eer < 0.15:
        logger.info("✅ ACCEPTANCE CRITERIA MET: EER < 15%")
    elif eer < 0.25:
        logger.info("⚠️  BORDERLINE: EER < 25%. Consider more data or augmentation.")
    else:
        logger.warning(f"❌ EER = {eer:.3f} — criteria NOT met. Check data quality.")


if __name__ == "__main__":
    main()
