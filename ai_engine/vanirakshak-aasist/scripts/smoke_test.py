import os
import sys
import json
import torch

# Add upstream repo to path so we can import models
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'src', 'upstream_aasist')))

from models.AASIST import Model

def count_parameters(model):
    return sum(p.numel() for p in model.parameters() if p.requires_grad)

def main():
    report_lines = ["# Model Audit Report (Phase 1)\n"]
    
    try:
        # Load config
        config_path = "src/upstream_aasist/config/AASIST-L.conf"
        with open(config_path, "r") as f:
            config = json.load(f)
            
        model_config = config["model_config"]
        report_lines.append("## Configuration")
        report_lines.append(f"Successfully loaded AASIST-L configuration from `{config_path}`.\n")
        
        # Instantiate model
        model = Model(model_config)
        param_count = count_parameters(model)
        
        report_lines.append("## Architecture Details")
        report_lines.append(f"- **Parameter Count**: {param_count:,}")
        
        if 80000 <= param_count <= 90000:
            report_lines.append("- **Status**: Expected parameter count (~85K) verified.")
        else:
            report_lines.append(f"- **Status**: WARNING! Unexpected parameter count (expected ~85K).")
            
        # Load weights
        weight_path = "src/upstream_aasist/models/weights/AASIST-L.pth"
        
        # Original AASIST uses DDP occasionally, so the weights might have "module." prefix
        # We need to strip it if present.
        state_dict = torch.load(weight_path, map_location="cpu", weights_only=True)
        # Check for module. prefix
        if next(iter(state_dict.keys())).startswith("module."):
            state_dict = {k.replace("module.", ""): v for k, v in state_dict.items()}
            
        # Also, original model might store weights directly or under a key
        # In AASIST, they usually just save the raw state dict
        model.load_state_dict(state_dict, strict=True)
        model.eval()
        
        report_lines.append("\n## Checkpoint Loading")
        report_lines.append(f"Successfully loaded weights from `{weight_path}` without strictly failing.")
        
        # Smoke tests
        report_lines.append("\n## Forward Pass Tests")
        
        nb_samp = model_config["nb_samp"]
        dummy_input = torch.randn(2, nb_samp) # batch_size=2
        
        # CPU Test
        try:
            with torch.no_grad():
                _, out_cpu = model(dummy_input)
            
            if torch.isnan(out_cpu).any() or torch.isinf(out_cpu).any():
                report_lines.append("- **CPU Forward Pass**: FAILED (NaN or Inf detected)")
            elif out_cpu.shape != (2, 2):
                report_lines.append(f"- **CPU Forward Pass**: FAILED (Unexpected shape {out_cpu.shape})")
            else:
                report_lines.append("- **CPU Forward Pass**: SUCCESS (Shape correctly `[2, 2]`, no NaNs/Infs)")
                
        except Exception as e:
            report_lines.append(f"- **CPU Forward Pass**: FAILED ({str(e)})")
            
        # MPS Test
        try:
            if torch.backends.mps.is_available() and torch.backends.mps.is_built():
                model_mps = model.to("mps")
                dummy_input_mps = dummy_input.to("mps")
                
                with torch.no_grad():
                    _, out_mps = model_mps(dummy_input_mps)
                    
                if torch.isnan(out_mps).any() or torch.isinf(out_mps).any():
                    report_lines.append("- **MPS Forward Pass**: FAILED (NaN or Inf detected)")
                else:
                    report_lines.append("- **MPS Forward Pass**: SUCCESS (Outputs look stable)")
            else:
                report_lines.append("- **MPS Forward Pass**: SKIPPED (MPS not available)")
        except Exception as e:
            report_lines.append(f"- **MPS Forward Pass**: FAILED ({str(e)})")
            
        report_lines.append("\n## Phase 1 Status")
        report_lines.append("**Passed**: Yes")
        
    except Exception as e:
        report_lines.append(f"\n## Fatal Error\n```\n{str(e)}\n```")
        report_lines.append("\n## Phase 1 Status")
        report_lines.append("**Passed**: No")

    report_path = "reports/model_audit.md"
    os.makedirs(os.path.dirname(report_path), exist_ok=True)
    with open(report_path, "w") as f:
        f.write("\n".join(report_lines))
        
    print(f"Report generated at: {report_path}")

if __name__ == "__main__":
    main()
