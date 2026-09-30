"""
Audio preprocessing for VANIRAKSHAK AASIST-L pipeline.

Pipeline:
  raw bytes / file path
  → decode
  → mono
  → resample to 16kHz
  → amplitude check
  → crop / pad to 64600 samples (~4 sec)
  → float32 tensor

Augmentations (training only, disabled by default):
  - gain variation
  - additive white noise
  - RIR convolution
  - telephone bandlimiting
  - MP3 simulation
"""
import random
from pathlib import Path
from typing import Optional, Tuple

import numpy as np
import soundfile as sf
import librosa
import torch

TARGET_SR: int = 16000
NUM_SAMPLES: int = 64600   # From AASIST-L upstream config


# ─────────────────────────────────────────────────────────────────────────────
# Core preprocessing
# ─────────────────────────────────────────────────────────────────────────────

def load_and_preprocess(
    path: str,
    num_samples: int = NUM_SAMPLES,
    target_sr: int = TARGET_SR,
    deterministic: bool = True,
) -> torch.Tensor:
    """
    Load an audio file and return a fixed-length float32 tensor.

    Args:
        path:         Path to audio file (.wav, .flac, .mp3 …)
        num_samples:  Target number of samples (default: 64600)
        target_sr:    Target sample rate (default: 16000)
        deterministic: If False, use random crop (use True for val/test)

    Returns:
        Tensor of shape [num_samples], dtype float32.

    Raises:
        ValueError: on NaN, Inf, or zero-length audio.
        OSError:    if file cannot be read.
    """
    array, sr = sf.read(path, dtype="float32", always_2d=False)

    # ── Mono ─────────────────────────────────────────────────────────────────
    if array.ndim == 2:
        array = librosa.to_mono(array.T)

    # ── Resample ─────────────────────────────────────────────────────────────
    if sr != target_sr:
        array = librosa.resample(array, orig_sr=sr, target_sr=target_sr)

    # ── Sanity checks ─────────────────────────────────────────────────────────
    if len(array) == 0:
        raise ValueError(f"Zero-length audio: {path}")
    if np.isnan(array).any() or np.isinf(array).any():
        raise ValueError(f"Audio contains NaN/Inf: {path}")

    # ── Crop / Pad ───────────────────────────────────────────────────────────
    array = _crop_or_pad(array, num_samples, deterministic)

    return torch.from_numpy(array)


def _crop_or_pad(
    array: np.ndarray,
    num_samples: int,
    deterministic: bool = True,
) -> np.ndarray:
    length = len(array)
    if length >= num_samples:
        if deterministic:
            start = 0
        else:
            start = random.randint(0, length - num_samples)
        return array[start : start + num_samples]
    else:
        # Repeat-pad (better than zero-pad for short clips)
        repeats = num_samples // length + 1
        array = np.tile(array, repeats)
        return array[:num_samples]


# ─────────────────────────────────────────────────────────────────────────────
# Augmentations  (TRAIN only — never apply to val/test)
# ─────────────────────────────────────────────────────────────────────────────

def augment(
    tensor: torch.Tensor,
    gain: bool = False,
    noise: bool = False,
    telephone: bool = False,
) -> torch.Tensor:
    """Apply enabled augmentations to a single audio tensor [num_samples]."""
    array = tensor.numpy()

    if gain:
        factor = random.uniform(0.5, 1.5)
        array = array * factor

    if noise:
        snr_db = random.uniform(15.0, 35.0)
        signal_power = np.mean(array ** 2)
        noise_power = signal_power / (10 ** (snr_db / 10))
        array = array + np.random.randn(*array.shape).astype(np.float32) * np.sqrt(noise_power)

    if telephone:
        # Simulate telephone bandlimiting (300–3400 Hz)
        from scipy.signal import butter, sosfilt
        sos = butter(4, [300 / (TARGET_SR / 2), 3400 / (TARGET_SR / 2)], btype="band", output="sos")
        array = sosfilt(sos, array).astype(np.float32)

    # Final sanity guard
    if np.isnan(array).any() or np.isinf(array).any():
        # Augmentation corrupted the signal; return original
        return tensor

    return torch.from_numpy(array)
