import os
import sys
import json
from datasets import load_dataset_builder

def inspect_hf_dataset(dataset_name: str, config_name: str = None) -> dict:
    try:
        if config_name:
            builder = load_dataset_builder(dataset_name, config_name)
        else:
            builder = load_dataset_builder(dataset_name)
            
        info = builder.info
        
        # Get features
        features = {}
        if info.features:
            for k, v in info.features.items():
                features[k] = str(v)
                
        return {
            "dataset": dataset_name,
            "config": config_name,
            "description": info.description,
            "homepage": info.homepage,
            "license": info.license,
            "features": features,
            "splits": {k: {"num_examples": v.num_examples} for k, v in info.splits.items()} if info.splits else {},
            "size_in_bytes": info.dataset_size if info.dataset_size else "Unknown",
            "status": "Success"
        }
    except Exception as e:
        return {
            "dataset": dataset_name,
            "config": config_name,
            "status": "Error",
            "error_msg": str(e)
        }

def main():
    report_lines = ["# Dataset Audit Report (Phase 2)\n"]
    
    # Check IndicVoices
    report_lines.append("## IndicVoices")
    iv_stats = inspect_hf_dataset("dianavdavidson/indic_voices_hindi_only_random_sample_17274_2308_seed_42_clean")
    if iv_stats["status"] == "Success":
        report_lines.append(f"Successfully connected to **{iv_stats['dataset']}**")
        report_lines.append("### Features:")
        for k, v in iv_stats["features"].items():
            report_lines.append(f"- **{k}**: {v}")
        report_lines.append("\n### Splits:")
        for split_name, split_info in iv_stats["splits"].items():
            report_lines.append(f"- **{split_name}**: {split_info['num_examples']} examples")
    else:
        report_lines.append(f"Error inspecting IndicVoices: {iv_stats.get('error_msg')}")
        
    # Check IndicSynth
    report_lines.append("\n## IndicSynth (Hindi)")
    is_stats = inspect_hf_dataset("ksmashhero/IndicSynth", "Hindi")
    if is_stats["status"] == "Success":
        report_lines.append(f"Successfully connected to **{is_stats['dataset']}** (Hindi)")
        report_lines.append("### Features:")
        for k, v in is_stats["features"].items():
            report_lines.append(f"- **{k}**: {v}")
        report_lines.append("\n### Splits:")
        for split_name, split_info in is_stats["splits"].items():
            report_lines.append(f"- **{split_name}**: {split_info['num_examples']} examples")
    else:
        report_lines.append(f"Error inspecting IndicSynth: {is_stats.get('error_msg')}")

    report_path = "reports/dataset_audit.md"
    os.makedirs(os.path.dirname(report_path), exist_ok=True)
    with open(report_path, "w") as f:
        f.write("\n".join(report_lines))
        
    print(f"Report generated at: {report_path}")

if __name__ == "__main__":
    main()
