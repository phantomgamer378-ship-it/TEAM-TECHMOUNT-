"""
vanirakshak_aasist — device selection utilities.

Priority: MPS > CUDA > CPU
Never silently falls back — always logs the selected device.
"""
import logging
import torch

logger = logging.getLogger(__name__)


def get_device(verbose: bool = True) -> torch.device:
    """
    Select the best available compute device.

    Returns:
        torch.device: mps | cuda | cpu
    """
    if torch.backends.mps.is_built() and torch.backends.mps.is_available():
        # Quick sanity forward pass to confirm MPS is actually usable
        try:
            _ = torch.ones(1, device="mps") * 2
            device = torch.device("mps")
            if verbose:
                logger.info("[device] Selected: MPS (Apple Silicon)")
                print(f"[device] ✓ MPS (Apple Silicon) — M-series GPU acceleration enabled")
            return device
        except Exception as e:
            logger.warning(f"[device] MPS available but test failed ({e}). Falling back to CPU.")
            print(f"[device] ⚠ MPS failed ({e}) → falling back to CPU")

    if torch.cuda.is_available():
        device = torch.device("cuda")
        if verbose:
            name = torch.cuda.get_device_name(0)
            logger.info(f"[device] Selected: CUDA ({name})")
            print(f"[device] ✓ CUDA — {name}")
        return device

    device = torch.device("cpu")
    if verbose:
        logger.info("[device] Selected: CPU (no GPU acceleration available)")
        print(f"[device] ⚠ CPU only — training will be slow")
    return device


def check_mps_diagnostics() -> dict:
    """Return a dict of MPS capability flags for environment reports."""
    return {
        "mps_built": torch.backends.mps.is_built(),
        "mps_available": torch.backends.mps.is_available(),
        "cuda_available": torch.cuda.is_available(),
        "device_selected": str(get_device(verbose=False)),
    }
