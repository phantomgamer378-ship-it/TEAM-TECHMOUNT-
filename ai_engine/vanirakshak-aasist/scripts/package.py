import os
import shutil
import json

def main():
    print("Packaging final model (Phase 15)...")
    out_dir = "artifacts/final"
    os.makedirs(out_dir, exist_ok=True)
    
    # Copy model
    best_model = "checkpoints/experiment_001/best.pt"
    if os.path.exists(best_model):
        shutil.copy(best_model, os.path.join(out_dir, "aasist_l_vanirakshak.pt"))
        
    # Copy config
    shutil.copy("src/upstream_aasist/config/AASIST-L.conf", os.path.join(out_dir, "config.json"))
    
    # Copy metrics
    metrics = "checkpoints/experiment_001/metrics.json"
    if os.path.exists(metrics):
        shutil.copy(metrics, os.path.join(out_dir, "training_metrics.json"))
        
    baseline = "reports/baseline_metrics.json"
    if os.path.exists(baseline):
        shutil.copy(baseline, os.path.join(out_dir, "baseline_metrics.json"))
        
    # Create metadata
    metadata = {
        "model_name": "VANIRAKSHAK-AASIST-L-Pilot",
        "base_model": "AASIST-L",
        "training_data": {
            "IndicVoices": "dianavdavidson/indic_voices_hindi_only_random_sample_17274_2308_seed_42_clean",
            "IndicSynth": "ksmashhero/IndicSynth"
        },
        "languages": ["hi", "mr"],
        "sample_rate": 16000,
        "input_length": 64600
    }
    with open(os.path.join(out_dir, "metadata.json"), "w") as f:
        json.dump(metadata, f, indent=4)
        
    # Create README
    readme = """# VANIRAKSHAK AASIST-L Pilot Model

This is the pilot fine-tuned version of AASIST-L for the VANIRAKSHAK platform, trained on Hindi and Marathi speech from IndicVoices (Bonafide) and IndicSynth (Spoof).

## Usage
1. Load `aasist_l_vanirakshak.pt` into the `Model` class from the AASIST repository.
2. Provide audio shaped `[batch, 64600]` at 16kHz.
3. Apply Softmax to output logits to get spoof/bonafide probability.
"""
    with open(os.path.join(out_dir, "README.md"), "w") as f:
        f.write(readme)
        
    print(f"Model packaged successfully at {out_dir}")

if __name__ == "__main__":
    main()
