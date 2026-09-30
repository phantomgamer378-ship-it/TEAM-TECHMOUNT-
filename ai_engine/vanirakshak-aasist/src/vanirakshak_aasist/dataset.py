"""
VANIRAKSHAK Dataset — PyTorch Dataset with lazy audio loading.

Label convention:
  1 = BONAFIDE (real speech)
  0 = SPOOF    (synthetic / voice-cloned / TTS)
"""
import csv
import logging
from typing import Dict, List, Optional, Tuple

import torch
from torch.utils.data import Dataset

from .audio import load_and_preprocess, augment, NUM_SAMPLES

logger = logging.getLogger(__name__)


class VanirakshakDataset(Dataset):
    """
    Lazy-loading anti-spoofing dataset.

    Args:
        manifest_path: CSV with columns [clip_id, path, label, speaker_id,
                       language, generator_id, source_dataset]
        num_samples:   Fixed audio length expected by AASIST-L (default 64600)
        is_train:      If True enables random crop + augmentation
        augmentation:  Dict of aug flags, e.g. {"gain": True, "noise": False}
        languages:     If set, filter to these ISO language codes only
    """

    REQUIRED_COLS = {"clip_id", "path", "label"}

    def __init__(
        self,
        manifest_path: str,
        num_samples: int = NUM_SAMPLES,
        is_train: bool = False,
        augmentation: Optional[Dict[str, bool]] = None,
        languages: Optional[List[str]] = None,
    ):
        self.num_samples = num_samples
        self.is_train = is_train
        self.augmentation = augmentation or {}
        self.records = self._load_manifest(manifest_path, languages)

        if not self.records:
            raise ValueError(f"No records found in {manifest_path}"
                             + (f" for languages {languages}" if languages else ""))

        labels = set(int(r["label"]) for r in self.records)
        if len(labels) < 2:
            logger.warning("Dataset contains only one class label: %s", labels)

    def _load_manifest(self, path: str, languages: Optional[List[str]]) -> List[Dict]:
        records = []
        with open(path, "r", newline="") as f:
            reader = csv.DictReader(f)
            if not self.REQUIRED_COLS.issubset(reader.fieldnames or []):
                raise ValueError(f"Manifest missing required columns: {self.REQUIRED_COLS}")
            for row in reader:
                if languages and row.get("language", "") not in languages:
                    continue
                records.append(row)
        return records

    def __len__(self) -> int:
        return len(self.records)

    def __getitem__(self, idx: int) -> Tuple[torch.Tensor, int]:
        record = self.records[idx]
        label = int(record["label"])

        try:
            audio = load_and_preprocess(
                record["path"],
                num_samples=self.num_samples,
                deterministic=not self.is_train,
            )
        except Exception as e:
            logger.warning("Failed to load %s: %s — using zeros", record["path"], e)
            audio = torch.zeros(self.num_samples, dtype=torch.float32)

        if self.is_train and any(self.augmentation.values()):
            audio = augment(audio, **self.augmentation)

        return audio.float(), label

    def class_counts(self) -> Dict[int, int]:
        """Return {label: count} for class-balance diagnostics."""
        counts: Dict[int, int] = {}
        for r in self.records:
            lbl = int(r["label"])
            counts[lbl] = counts.get(lbl, 0) + 1
        return counts

    def speaker_ids(self) -> set:
        return {r.get("speaker_id", "") for r in self.records}
