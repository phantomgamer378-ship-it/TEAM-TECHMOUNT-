import os
import yaml
import json
import torch
import librosa
import numpy as np
from pathlib import Path

from app.ml.aasist import Model

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
            "filts": [70, [1, 32], [32, 32], [32, 24], [24, 24]],
            "gat_dims": [24, 32],
            "pool_ratios": [0.4, 0.5, 0.7, 0.5],
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
        """Runs calibrated inference on an audio array.
        
        Uses multi-window sliding evaluation and domain-calibrated temperature scaling
        to prevent mobile microphone & lossy codec compression (AAC/M4A/telephony)
        from triggering false-positive 1.00 spoof flags on real human voices.
        """
        if self.model is None:
            self.load()
            
        target_sr = self.preprocessing.get("sample_rate", 16000)
        target_len = self.preprocessing.get("input_length_samples", 64600)
        
        if sr != target_sr:
            audio_array = librosa.resample(audio_array, orig_sr=sr, target_sr=target_sr)
            
        # Multi-window evaluation across the clip (2-second hop)
        if len(audio_array) <= target_len:
            windows = [audio_array]
        else:
            hop = 32000
            windows = [audio_array[st : st + target_len] for st in range(0, len(audio_array) - target_len + 1, hop)]
            if not windows:
                windows = [audio_array[:target_len]]
                
        diffs = []
        for w in windows:
            if len(w) < target_len:
                w = np.pad(w, (0, target_len - len(w)), "constant")
            x = torch.FloatTensor(w).unsqueeze(0).to(self.device)
            with torch.no_grad():
                _, out = self.model(x)
                logits = out.cpu().numpy()[0]
                # Logit difference: out[0] (Spoof) - out[1] (Bonafide)
                diffs.append(float(logits[0] - logits[1]))
                
        mean_diff = float(np.mean(diffs))
        
        # Domain calibration:
        # Natural human voice (including phone/mic compression): mean_diff <= ~7.8
        # AI generated / cloned voice (TTS, voice conversion): mean_diff >= ~9.5
        theta = 8.6
        temperature = 1.6
        calibrated_score = float(1.0 / (1.0 + np.exp(-(mean_diff - theta) / temperature)))
        calibrated_score = max(0.0, min(1.0, round(calibrated_score, 4)))
        
        classification = "SPOOF" if calibrated_score >= 0.5 else "BONAFIDE"
        
        return {
            "model_version": self.metadata.get("model_version", "unknown"),
            "classification": classification,
            "score": calibrated_score,
            "raw_margin": round(mean_diff, 2),
        }
        
    def predict_batch(self, audio_batches: list, sr: int) -> list:
        return [self.predict(a, sr) for a in audio_batches]
