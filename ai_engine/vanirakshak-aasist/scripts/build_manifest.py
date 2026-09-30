import os
import csv
import soundfile as sf
import librosa
from datasets import load_dataset

def process_and_save_audio(audio_array, sr, target_path, target_sr=16000):
    # Ensure mono
    if len(audio_array.shape) > 1 and audio_array.shape[0] > 1:
        audio_array = librosa.to_mono(audio_array)
        
    # Resample if needed
    if sr != target_sr:
        audio_array = librosa.resample(audio_array, orig_sr=sr, target_sr=target_sr)
        
    sf.write(target_path, audio_array, target_sr)

def main():
    print("Building pilot manifest...")
    manifest_path = "data/manifests/pilot_manifest.csv"
    samples_dir = "data/samples"
    os.makedirs(samples_dir, exist_ok=True)
    os.makedirs(os.path.dirname(manifest_path), exist_ok=True)
    
    records = []
    target_count = 20 # Fast micro-pilot
    
    with open(manifest_path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow([
            "clip_id", "path", "label", "speaker_id", 
            "language", "generator_id", "source_dataset"
        ])
        
        import numpy as np
        
        # Helper to generate dummy wav
        def gen_dummy(clip_id, label, spk, lang, gen, src):
            path = os.path.join(samples_dir, f"{clip_id}.wav")
            # 4 secs at 16kHz
            array = np.random.randn(64600).astype(np.float32) * 0.1
            sf.write(path, array, 16000)
            writer.writerow([clip_id, path, label, spk, lang, gen, src])
            
        print("Generating synthetic pilot for pipeline validation...")
        
        for i in range(target_count):
            gen_dummy(f"iv_hi_{i:04d}", 1, f"spk_{i%5}", "hi", "none", "IndicVoices_Dummy")
            
        for i in range(target_count):
            gen_dummy(f"is_hi_{i:04d}", 0, f"spk_{i%5 + 5}", "hi", "VITS", "IndicSynth_Dummy")
            
        for i in range(target_count):
            gen_dummy(f"iv_mr_{i:04d}", 1, f"spk_{i%5 + 10}", "mr", "none", "IndicVoices_Dummy")
            
        for i in range(target_count):
            gen_dummy(f"is_mr_{i:04d}", 0, f"spk_{i%5 + 15}", "mr", "VITS", "IndicSynth_Dummy")

    print(f"Manifest created at {manifest_path}")

if __name__ == "__main__":
    main()
