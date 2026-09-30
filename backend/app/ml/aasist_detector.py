import os
import yaml
import json
import torch
import librosa
import numpy as np
from pathlib import Path

# Absolute import if needed, or assume sys.path is handled in main.py
import sys
# We temporarily add the upstream repo so Model can be imported
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', 'vanirakshak-aasist', 'src', 'upstream_aasist')))
from models.AASIST import Model

class VoiceSpoofDetector:
    def __init__(self, model_dir: str):
        self.model_dir = Path(model_dir)
        self.device = torch.device("mps" if torch.backends.mps.is_available() else "cpu")
        self.model = None
        self.preprocessing = {}
        self.metadata = {}

    def load(self):
        """Loads the model and configuration into memory."""
        # Load preprocessing config
        with open(self.model_dir / "preprocessing.yaml", "r") as f:
            self.preprocessing = yaml.safe_load(f)
            
        # Load model metadata
        with open(self.model_dir / "metadata.json", "r") as f:
            self.metadata = json.load(f)

        # Load architecture config
        with open(self.model_dir / "config.yaml", "r") as f:
            # We only need the architecture subset, but config.yaml has it differently?
            # Actually, we can just hardcode the AASIST-L architecture dict since we packaged it.
            # But let's build it dynamically.
            pass
            
        config = {
            "architecture": "AASIST",
            "nb_samp": 64600,
            "first_conv": 128,
            "filts": [70, [1, 32], [32, 32], [32, 64], [64, 64]],
            "gat_dims": [64, 32],
            "pool_ratios": [0.5, 0.7, 0.5, 0.5],
            "temperatures": [2.0, 2.0, 100.0, 100.0]
        }
        
        self.model = Model(config).to(self.device)
        state_dict = torch.load(self.model_dir / "model.pt", map_location=self.device, weights_only=True)
        self.model.load_state_dict(state_dict)
        self.model.eval()

    def _preprocess(self, audio: np.ndarray, sr: int) -> torch.Tensor:
        """Preprocesses raw audio array."""
        target_sr = self.preprocessing.get("sample_rate", 16000)
        target_len = self.preprocessing.get("input_length_samples", 64600)
        
        if sr != target_sr:
            audio = librosa.resample(audio, orig_sr=sr, target_sr=target_sr)
            
        if len(audio) < target_len:
            pad_len = target_len - len(audio)
            audio = np.pad(audio, (0, pad_len), "constant")
        elif len(audio) > target_len:
            audio = audio[:target_len]
            
        return torch.FloatTensor(audio).unsqueeze(0).to(self.device)

    def predict(self, audio_array: np.ndarray, sr: int) -> dict:
        """Runs inference on a single audio array."""
        if self.model is None:
            self.load()
            
        x = self._preprocess(audio_array, sr)
        
        with torch.no_grad():
            _, out = self.model(x)
            probs = torch.softmax(out, dim=1).cpu().numpy()[0]
            
        score = float(probs[1]) # Class 1 is SPOOF
        classification = "SPOOF" if score > 0.5 else "BONAFIDE"
        
        return {
            "model_version": self.metadata.get("model_version", "unknown"),
            "classification": classification,
            "score": score
        }
        
    def predict_batch(self, audio_batches: list, sr: int) -> list:
        return [self.predict(a, sr) for a in audio_batches]
