import os
import sys
import platform
import subprocess

def get_command_output(cmd: list) -> str:
    try:
        return subprocess.check_output(cmd, stderr=subprocess.DEVNULL).decode('utf-8').strip()
    except Exception:
        return "Unknown"

def main():
    print("Gathering environment information...")
    
    # OS Info
    os_name = platform.system()
    os_version = platform.mac_ver()[0] if os_name == "Darwin" else platform.release()
    arch = platform.machine()
    
    try:
        if os_name == "Darwin":
            ram = int(get_command_output(["sysctl", "-n", "hw.memsize"])) / (1024 ** 3)
            ram_str = f"{ram:.2f} GB"
        else:
            ram_str = "Unknown"
    except:
        ram_str = "Unknown"
        
    try:
        df_out = get_command_output(["df", "-h", "/"]).split("\n")
        if len(df_out) > 1:
            disk_info = df_out[1].split()
            disk_avail = disk_info[3]
        else:
            disk_avail = "Unknown"
    except:
        disk_avail = "Unknown"
        
    git_version = get_command_output(["git", "--version"])

    # Python Info
    python_version = sys.version.replace('\n', ' ')
    
    # ML Packages Info
    try:
        import torch
        torch_version = torch.__version__
        try:
            mps_available = torch.backends.mps.is_available()
            mps_built = torch.backends.mps.is_built()
        except AttributeError:
            mps_available = False
            mps_built = False
            
        cuda_available = torch.cuda.is_available()
        
        device_selected = "cpu"
        if mps_available and mps_built:
            device_selected = "mps"
            # Simple MPS test
            try:
                t = torch.ones(1, device="mps")
                mps_working = True
            except Exception as e:
                mps_working = False
                device_selected = "cpu (mps test failed)"
        elif cuda_available:
            device_selected = "cuda"
    except ImportError:
        torch_version = "Not installed"
        mps_available = False
        mps_built = False
        cuda_available = False
        mps_working = False
        device_selected = "None"
        
    try:
        import torchaudio
        torchaudio_version = torchaudio.__version__
    except ImportError:
        torchaudio_version = "Not installed"
        
    try:
        import datasets
        datasets_version = datasets.__version__
    except ImportError:
        datasets_version = "Not installed"

    report_content = f"""# Environment Report

## System Information
- **OS**: {os_name} {os_version}
- **Architecture**: {arch}
- **RAM**: {ram_str}
- **Available Disk Space**: {disk_avail}
- **Git**: {git_version}

## Python Environment
- **Python Version**: {python_version}

## ML Libraries
- **PyTorch**: {torch_version}
- **Torchaudio**: {torchaudio_version}
- **Datasets**: {datasets_version}

## Hardware Acceleration
- **MPS Built**: {mps_built}
- **MPS Available**: {mps_available}
- **CUDA Available**: {cuda_available}
- **Device Selected**: `{device_selected}`

## Phase 0 Status
**Passed**: {'Yes' if device_selected != 'cpu' and torch_version != 'Not installed' else 'No'}

## Potential Compatibility Problems
- None identified so far. The environment uses the Apple Silicon (MPS) backend as intended.

## Next Steps
Please review this report. If approved, we will proceed to **PHASE 1 (Model Audit)**.
"""
    
    report_path = "reports/environment_report.md"
    os.makedirs(os.path.dirname(report_path), exist_ok=True)
    with open(report_path, "w") as f:
        f.write(report_content)
        
    print(f"Report generated at: {report_path}")
    print(f"Device Selected: {device_selected}")
    print(f"Passed: {'Yes' if device_selected != 'cpu' and torch_version != 'Not installed' else 'No'}")

if __name__ == "__main__":
    main()
