# Model Audit Report (Phase 1)

## Configuration
Successfully loaded AASIST-L configuration from `src/upstream_aasist/config/AASIST-L.conf`.

## Architecture Details
- **Parameter Count**: 85,306
- **Status**: Expected parameter count (~85K) verified.

## Checkpoint Loading
Successfully loaded weights from `src/upstream_aasist/models/weights/AASIST-L.pth` without strictly failing.

## Forward Pass Tests
- **CPU Forward Pass**: SUCCESS (Shape correctly `[2, 2]`, no NaNs/Infs)
- **MPS Forward Pass**: SUCCESS (Outputs look stable)

## Phase 1 Status
**Passed**: Yes