You are acting as a senior Machine Learning Engineer + MLOps Engineer + ML Systems Developer with 10+ years of experience building, adapting, fine-tuning, evaluating, and deploying speech/audio ML systems.

Your task is to help me build a SAFE, REPRODUCIBLE, MAC-OPTIMIZED fine-tuning pipeline for VANIRAKSHAK's voice anti-spoofing model.

========================================================
PROJECT
========================================================

Project:
VANIRAKSHAK

Primary ML objective:
Fine-tune the pretrained AASIST-L audio anti-spoofing model so it can better distinguish:

BONAFIDE / REAL SPEECH

from

SPOOF / SYNTHETIC / MANIPULATED SPEECH

with particular focus on:

- Hindi
- Marathi
- English where useful
- Hindi-English code-mixed speech where available
- Marathi-English code-mixed speech where available
- AI-generated speech
- TTS speech
- voice-converted speech
- noisy audio
- compressed / telephone-like audio conditions

IMPORTANT:

We are NOT training AASIST-L from scratch.

We are starting from the official pretrained AASIST-L checkpoint and fine-tuning it.

The official AASIST-L model must remain the model architecture unless there is a strong technical reason to modify it.

Do not replace AASIST-L with another model just because a newer model exists.

Do not use Unsloth for AASIST-L training.

Use native PyTorch.

========================================================
PRIMARY DATASETS
========================================================

Use ONLY these two datasets for the initial Indian-language training pipeline:

1. IndicVoices
   Role:
   BONAFIDE / REAL Indian speech

2. IndicSynth
   Role:
   SPOOF / SYNTHETIC Indian speech

Do NOT add additional datasets unless I explicitly approve them.

ASVspoof is NOT part of the final Indian training dataset in this project.

If ASVspoof is ever mentioned, treat it only as an optional external benchmark or pipeline sanity-check dataset, not as part of our Indian training mixture.

========================================================
CRITICAL DATASET SAFETY RULE
========================================================

DO NOT download entire datasets blindly.

IndicVoices and IndicSynth are very large.

We must work incrementally.

First:

- inspect metadata
- inspect dataset schema
- inspect available language names/configurations
- inspect audio columns
- inspect speaker identifiers
- inspect generator identifiers where available
- inspect duration
- inspect sampling rate
- inspect splits
- inspect licensing
- inspect whether data can be streamed or selectively downloaded

Then create a SMALL pilot subset.

Only after the pilot is verified should we scale.

Never consume hundreds of GB just for experimentation.

========================================================
TARGET HARDWARE
========================================================

Primary hardware:

Apple Silicon Mac M2

Use:

PyTorch
Apple MPS backend

The pipeline must automatically support:

1. MPS
2. CUDA
3. CPU

Priority on this machine:

MPS > CPU

Do not assume NVIDIA CUDA.

Create a device utility:

get_device()

Expected behavior:

if MPS is available:
    use "mps"

else if CUDA is available:
    use "cuda"

else:
    use "cpu"

Print the selected device at startup.

If MPS has unsupported operations, implement a safe fallback strategy.

Do not silently switch from MPS to CPU without reporting it.

========================================================
SAFE MPS CONFIGURATION
========================================================

Detect:

torch.backends.mps.is_available()

and:

torch.backends.mps.is_built()

Implement clear diagnostics.

If required, support:

PYTORCH_ENABLE_MPS_FALLBACK=1

but do not enable it blindly.

Document why it is enabled.

Any CPU fallback must be logged.

========================================================
PYTHON ENVIRONMENT
========================================================

Create a clean isolated environment.

Preferred:

python -m venv .venv

Do not use the global Python environment.

Create:

requirements.txt

and preferably also:

requirements-lock.txt

after installation.

Record:

- Python version
- PyTorch version
- torchaudio version
- torchvision version
- numpy version
- datasets version
- soundfile version
- librosa version
- pandas version
- scikit-learn version
- matplotlib version
- tqdm version

Use pinned versions after the first successful environment build.

========================================================
REPOSITORY STRUCTURE
========================================================

Create a clean project instead of heavily modifying the upstream repository.

Use:

vanirakshak-aasist/

├── README.md
├── LICENSES.md
├── pyproject.toml
├── requirements.txt
├── requirements-lock.txt
│
├── configs/
│   ├── base.yaml
│   ├── pilot.yaml
│   ├── hindi.yaml
│   ├── marathi.yaml
│   └── full.yaml
│
├── src/
│   └── vanirakshak_aasist/
│       ├── __init__.py
│       ├── device.py
│       ├── seed.py
│       ├── audio.py
│       ├── dataset.py
│       ├── collate.py
│       ├── model.py
│       ├── checkpoint.py
│       ├── metrics.py
│       ├── calibration.py
│       ├── logging_utils.py
│       ├── validation.py
│       └── utils.py
│
├── scripts/
│   ├── environment_check.py
│   ├── inspect_dataset.py
│   ├── sample_dataset.py
│   ├── build_manifest.py
│   ├── validate_manifest.py
│   ├── preprocess_audio.py
│   ├── create_splits.py
│   ├── smoke_test.py
│   ├── train.py
│   ├── evaluate.py
│   └── inference.py
│
├── data/
│   ├── raw/
│   ├── manifests/
│   ├── samples/
│   ├── processed/
│   └── splits/
│
├── checkpoints/
│
├── logs/
│
├── reports/
│
├── experiments/
│
└── notebooks/
    ├── dataset_inspection.ipynb
    └── evaluation_analysis.ipynb

Keep data files outside Git.

Create .gitignore.

========================================================
UPSTREAM AASIST
========================================================

Clone or vendor the official AASIST repository.

Do NOT blindly rewrite the upstream model.

Identify:

- model definition
- AASIST-L configuration
- pretrained AASIST-L weights
- original expected input shape
- original sample length
- original preprocessing assumptions
- original output/logit convention
- original loss function
- original optimizer configuration
- original checkpoint loading behavior

Document these before modifying anything.

The official AASIST repository uses a configuration-driven architecture and provides pretrained AASIST-L weights.

Preserve the original implementation as much as possible.

Preferred approach:

Create a wrapper around the official AASIST-L model.

Do not fork the entire training system unnecessarily.

========================================================
MODEL VERIFICATION BEFORE TRAINING
========================================================

Before touching the dataset:

1. Load pretrained AASIST-L.
2. Print parameter count.
3. Verify expected parameter count is approximately 85K.
4. Print model architecture.
5. Confirm checkpoint loads successfully.
6. Run a single forward pass.
7. Confirm output shape.
8. Confirm no NaNs.
9. Confirm no Infs.
10. Run one CPU forward pass if possible.
11. Run one MPS forward pass.

Create:

scripts/smoke_test.py

The smoke test must fail loudly if:

- checkpoint missing
- incorrect state dict
- incorrect tensor dimensions
- device failure
- NaN output
- Inf output

========================================================
DO NOT TRAIN YET
========================================================

Before the first training run, verify:

MODEL
DATA
LABELS
DEVICE
AUDIO SHAPE
LOSS
OPTIMIZER

independently.

========================================================
DATASET ROLE
========================================================

IndicVoices:

Use as BONAFIDE.

IndicSynth:

Use as SPOOF.

Create one unified manifest.

Example:

clip_id
path
label
speaker_id
language
generator_id
source_dataset
duration
sample_rate
channel_count

Label convention:

1 = BONAFIDE
0 = SPOOF

Do not assume this without validating it in our own pipeline.

========================================================
DATASET INSPECTION
========================================================

Create a dataset inspection script.

It must report:

- dataset size
- number of speakers
- number of languages
- Hindi count
- Marathi count
- audio duration statistics
- sampling-rate statistics
- channel statistics
- missing values
- duplicate paths
- duplicate clip IDs
- corrupted audio count
- available generator identifiers in IndicSynth
- speaker identifiers in IndicVoices if provided
- available metadata fields

Generate a report:

reports/dataset_inventory.json

and:

reports/dataset_inventory.md

Do not continue until this report looks sane.

========================================================
DO NOT DOWNLOAD EVERYTHING
========================================================

For the pilot:

Use only a limited number of samples.

Target approximately:

Hindi:
200–500 genuine
200–500 spoof

Marathi:
200–500 genuine
200–500 spoof

This is a PIPELINE VALIDATION SET, not the final training corpus.

If those exact quantities are difficult because of dataset access/schema restrictions, choose the closest practical subset and document it.

========================================================
DATA QUALITY FILTERING
========================================================

Create automatic checks.

Reject or quarantine:

- unreadable audio
- zero-length audio
- extremely short clips
- NaN values
- Inf values
- unsupported sample rates unless resampled
- multi-channel data when conversion fails
- obvious duplicates

Do not delete original source data.

Use:

data/quarantine/

for problematic files.

Log every rejected sample with a reason.

========================================================
AUDIO STANDARDIZATION
========================================================

For AASIST-L input:

standardize to:

mono
16 kHz
fixed-length tensor expected by the model

Use the original AASIST-L expected sample length where appropriate.

The upstream configuration uses:

64600 samples

which is approximately 4 seconds at 16 kHz.

Do not blindly modify this.

Confirm from the model/config.

Audio pipeline:

input
→ decode
→ channel normalization
→ sample-rate normalization
→ amplitude normalization where justified
→ crop or pad
→ tensor
→ model

Do not apply aggressive transformations that could destroy spoof artifacts.

========================================================
CROP / PAD STRATEGY
========================================================

Implement:

TRAIN:
random crop when longer than target length

VALIDATION:
deterministic crop

TEST:
deterministic evaluation

For short files:

use a documented padding strategy.

Avoid leaking the same crop across train/validation/test.

========================================================
SPLITTING — CRITICAL
========================================================

NEVER randomly split audio files without checking speaker leakage.

We need:

SPEAKER-DISJOINT SPLITS

and, where metadata supports it:

GENERATOR-DISJOINT SPLITS

Train:

different speakers from test.

Validation:

different speakers from train and test.

For spoof data:

where generator metadata exists, reserve at least some generator sources for evaluation.

Goal:

The model must learn:

"what is spoof"

not:

"what does generator X sound like?"

========================================================
SPLIT FILES
========================================================

Create:

data/splits/train.csv
data/splits/val.csv
data/splits/test.csv

Include:

clip_id
path
label
speaker_id
language
generator_id
source_dataset

Also save split statistics.

Create:

reports/split_report.json

The script must automatically check:

- speaker overlap
- generator overlap
- duplicate clip overlap
- class balance

If leakage exists:

FAIL THE PIPELINE.

Do not proceed.

========================================================
LANGUAGE STRATEGY
========================================================

Initial focus:

Hindi
Marathi

Keep the manifest language-aware.

Do NOT train separate completely independent models initially.

Primary approach:

shared AASIST-L backbone

with multilingual training data.

Later experiments may investigate language-specific calibration.

But do NOT add language-specific heads during the initial pipeline unless there is a measurable justification.

========================================================
DATA MIXING
========================================================

Avoid accidental domination by one language.

Monitor:

Hindi real
Hindi spoof
Marathi real
Marathi spoof

Class balance.

Create configurable sampling:

uniform by class

and optionally:

balanced by language + class

Do not duplicate samples unnecessarily.

========================================================
AUGMENTATION
========================================================

Only apply augmentation to TRAIN.

Possible augmentations:

- gain variation
- low-level noise
- room/reverberation
- MP3 compression
- telephone band limitation
- mild additive noise

But make every augmentation configurable.

Never augment validation or test.

Start with NO AUGMENTATION.

First establish a baseline.

Then introduce augmentation as a controlled experiment.

========================================================
BASELINE EXPERIMENT
========================================================

Experiment 0:

Pretrained AASIST-L
NO fine-tuning

Evaluate it on a small pilot set.

This establishes:

"How does the original model behave on Indian speech?"

Save:

reports/baseline_metrics.json

Do not fabricate any metric.

========================================================
FINE-TUNING EXPERIMENT
========================================================

Experiment 1:

Pretrained AASIST-L

Fine-tune on:

Hindi + Marathi

Real + spoof

Start conservatively.

Suggested initial values:

batch size:
4 or 8

learning rate:
1e-5

epochs:
10

optimizer:
Adam

scheduler:
cosine or conservative scheduler

weight decay:
1e-4

These are INITIAL EXPERIMENT VALUES.

Do not claim they are optimal.

Make all hyperparameters configurable.

========================================================
FINE-TUNING MODES
========================================================

Implement two modes:

MODE A:
full fine-tuning

MODE B:
partial fine-tuning

For partial fine-tuning:

freeze early/backbone layers

train classification/head layers where technically appropriate.

Run:

Experiment A
Experiment B

Compare:

validation EER
F1
precision
recall

Do not assume partial or full is better.

Measure it.

========================================================
LOSS
========================================================

Use a loss appropriate for the binary anti-spoofing output.

First inspect the official AASIST implementation and preserve its expected loss/output semantics.

Do not blindly replace the upstream loss.

Verify:

- labels
- logits
- softmax/sigmoid usage
- class ordering

Create a unit test for label-to-output mapping.

========================================================
LABEL / LOGIT SANITY TEST
========================================================

Create a tiny artificial dataset.

Test:

known label = BONAFIDE

known label = SPOOF

Verify that:

training target
matches
model output interpretation.

The pipeline must fail if class ordering is reversed.

========================================================
TRAINING LOOP
========================================================

The training loop must include:

- epoch counter
- training loss
- validation loss
- validation EER
- F1
- precision
- recall
- learning rate
- epoch duration
- device
- best checkpoint tracking

Print a concise progress line.

Example:

Epoch 03/10
train_loss=0.231
val_loss=0.198
EER=0.142
F1=0.81
LR=1e-05
device=mps

Do not print huge amounts of irrelevant information.

========================================================
CHECKPOINTING
========================================================

Save:

best_model.pt
last_model.pt

Also save:

optimizer state
scheduler state
epoch
metrics
config
git commit hash if available

Checkpoint names:

checkpoints/
├── experiment_001/
│   ├── best.pt
│   ├── last.pt
│   ├── config.yaml
│   └── metrics.json
Training must resume from checkpoint.
========================================================
EARLY STOPPING
Implement early stopping.
Monitor:
validation EER
or another clearly defined primary metric.
Do not select a model using training loss alone.
========================================================
MPS MEMORY SAFETY
Because this is an M2 Mac:
keep batch size configurable
detect OOM errors
optionally reduce batch size
clear cache between experiments
avoid loading the entire dataset into RAM
use lazy audio loading
use small workers initially
default DataLoader workers conservatively on macOS
Do not create huge preloaded tensors.
If memory usage is unstable:
reduce batch size first.
Do not silently kill the process.
========================================================
DATA LOADING OPTIMIZATION
Prefer lazy loading.
Do not decode all audio into RAM.
Use:
DataLoader
with configurable:
batch_size
num_workers
pin_memory
For MPS:
do not assume CUDA pin_memory semantics help.
Benchmark:
num_workers=0
first.
Then test:
num_workers=2
only if stable.
Document the chosen value.
========================================================
MAC SAFETY
Never:
overwrite original datasets
modify upstream checkpoint files
delete data automatically
change system Python
install system-wide packages
write secrets into source files
Everything should remain inside the project directory.
========================================================
CONFIGURATION
ALL experiment choices must live in YAML.
Example:
configs/pilot.yaml
device: auto
sample_rate: 16000
num_samples: 64600
batch_size: 4
learning_rate: 1e-5
epochs: 10
languages:
hi
mr
augmentation:
enabled: false
checkpoint:
pretrained: true
seed: 42
Do not hard-code these values into Python.
========================================================
REPRODUCIBILITY
Set deterministic seeds where practical.
Store:
seed
Python version
PyTorch version
dataset revision/hash where available
configuration
model checkpoint
git commit
Create:
run_manifest.json
for every experiment.
========================================================
EXPERIMENT TRACKING
Do not install MLflow immediately.
First make the pipeline reliable.
Use simple structured files:
experiments/
experiment_001/
experiment_002/
experiment_003/
Each experiment contains:
config.yaml
metrics.json
predictions.csv
training.log
checkpoint path
After the pipeline stabilizes, MLflow can be added.
========================================================
EVALUATION
Primary anti-spoof metric:
EER
Also calculate:
precision
recall
F1
confusion matrix
ROC curve
AUC where meaningful
For every experiment report:
overall
Hindi
Marathi
Also report:
BONAFIDE error
SPOOF error
========================================================
GENERATIVE GENERALIZATION
Where generator metadata is available:
create:
seen-generator evaluation
and:
unseen-generator evaluation
This is critical.
Example:
TRAIN:
XTTS
VITS
TEST:
FreeVC
The exact generators must come from actual metadata and availability.
Do not invent generator IDs.
========================================================
SPEAKER GENERALIZATION
Create:
speaker-disjoint test set.
Report:
test speakers count
train speakers count
validation speakers count
No speaker can appear across splits.
========================================================
ERROR ANALYSIS
After every serious experiment:
save prediction-level output:
clip_id
true_label
predicted_label
score
language
speaker_id
generator_id
dataset
Then inspect:
false positives
false negatives
Generate:
reports/error_analysis.md
Include examples such as:
real speech classified as spoof
spoof classified as real
Hindi vs Marathi differences
generator-specific failure patterns
noisy audio failures
========================================================
CALIBRATION
AASIST output is not automatically a trustworthy probability.
Treat raw scores as model scores until calibrated.
After the classifier is reliable:
evaluate calibration.
Possible methods:
temperature scaling
Platt scaling
isotonic regression
Only add calibration after baseline fine-tuning works.
Do not call an uncalibrated score:
"probability of fraud"
without qualification.
========================================================
VANIRAKSHAK SCORE
Do NOT directly use AASIST output as the final VANIRAKSHAK risk score.
AASIST outputs:
VOICE SPOOF EVIDENCE
Then VANIRAKSHAK's future risk engine combines:
AASIST spoof evidence
+
speaker verification
+
scam intent
+
conversation context
+
liveness
Keep these systems separate.
========================================================
INFERENCE API
Create:
scripts/inference.py
Input:
audio file
Output JSON:
{
"model": "VANIRAKSHAK-AASIST-L",
"label": "SPOOF",
"score": 0.87,
"model_version": "...",
"language": "mr",
"processing_ms": 123
}
IMPORTANT:
The language field here is metadata from the pipeline.
AASIST-L itself is not an ASR language detector.
========================================================
NO FALSE CLAIMS
Never write:
"99% accurate"
unless our own evaluation actually produces that result.
Never copy the official AASIST benchmark result and describe it as our result.
Official AASIST-L benchmark performance is only the pretrained model's published benchmark context.
Our metrics must come from our own dataset and evaluation.
========================================================
LICENSING
Create:
LICENSES.md
Document:
AASIST license
IndicVoices license
IndicSynth license
any additional library licenses
CRITICAL:
Do not assume IndicSynth is commercially usable.
The currently listed dataset terms indicate non-commercial/research use.
Flag this clearly:
"Training/academic use requires license review before commercial deployment."
Do not build a commercial release on top of a dataset whose terms prohibit commercial use without identifying a replacement/licensing path.
========================================================
DATA PROVENANCE
For every source record, store:
source_dataset
dataset_revision
download/access date
language
speaker ID
generator ID if available
license reference
Never lose data provenance.
========================================================
PHASED EXECUTION MODEL
Do NOT perform the entire project in one uncontrolled run.
Use phases.
PHASE 0
Environment audit
PHASE 1
Upstream AASIST-L verification
PHASE 2
Dataset inspection
PHASE 3
Pilot dataset creation
PHASE 4
Preprocessing verification
PHASE 5
Split generation + leakage testing
PHASE 6
Pretrained baseline evaluation
PHASE 7
Fine-tuning smoke test
PHASE 8
Pilot fine-tuning
PHASE 9
Evaluation
PHASE 10
Error analysis
PHASE 11
Scale dataset
PHASE 12
Augmentation experiments
PHASE 13
Partial vs full fine-tuning comparison
PHASE 14
Calibration
PHASE 15
Final model packaging
========================================================
PHASE 0 — ENVIRONMENT AUDIT
Execute only environment checks.
Check:
macOS version
CPU architecture
RAM
Python
PyTorch
torchaudio
MPS
Git
disk space
Generate:
reports/environment_report.md
DO NOT download datasets yet.
Acceptance criteria:
MPS available OR documented CPU fallback.
Stop and report before continuing.
========================================================
PHASE 1 — MODEL AUDIT
Clone official AASIST source.
Locate:
AASIST-L architecture
config
pretrained checkpoint
data assumptions
Load the model.
Verify:
parameter count
checkpoint
forward pass
CPU
MPS
Generate:
reports/model_audit.md
Stop if anything is inconsistent.
========================================================
PHASE 2 — DATASET AUDIT
Inspect IndicVoices and IndicSynth metadata.
Do not download full dataset.
Find:
Hindi
Marathi
Report:
counts
metadata fields
audio format
sample rate
speaker information
generator information
Generate:
reports/dataset_audit.md
========================================================
PHASE 3 — PILOT DATA
Create:
~200–500 Hindi genuine
~200–500 Hindi spoof
~200–500 Marathi genuine
~200–500 Marathi spoof
Do not exceed available resources without reason.
Store only the selected pilot data or references.
Build:
pilot_manifest.csv
========================================================
PHASE 4 — AUDIO PIPELINE
Test random pilot files.
For each:
load
convert to mono
resample to 16kHz
crop/pad
convert tensor
Visualize spectrograms for a few samples.
Check:
shape
dtype
min
max
mean
std
No NaNs.
========================================================
PHASE 5 — SPLITS
Create speaker-disjoint splits.
Where generator metadata exists:
create generator-disjoint evaluation.
Run leakage checks.
Acceptance criteria:
ZERO speaker overlap
ZERO duplicate clip overlap
documented generator overlap or disjointness
FAIL if leakage.
========================================================
PHASE 6 — PRETRAINED BASELINE
Run inference only.
No training.
Evaluate pretrained AASIST-L on pilot data.
Generate:
baseline_metrics.json
baseline_confusion_matrix.png
baseline_predictions.csv
This tells us the domain gap.
========================================================
PHASE 7 — TRAINING SMOKE TEST
Use a tiny dataset:
20–50 examples per class.
Train for:
1–2 epochs
Purpose:
verify:
forward
backward
optimizer
MPS
checkpoint
resume
loss
evaluation
Do not interpret metrics scientifically.
========================================================
PHASE 8 — PILOT FINE-TUNING
Train:
10 epochs initially.
Use:
batch size 4 or 8
learning rate 1e-5
no augmentation initially.
Save checkpoints every epoch.
Track:
loss
EER
F1
precision
recall
========================================================
PHASE 9 — EVALUATION
Evaluate on completely held-out:
speakers
and generator sources where possible.
Break down by:
Hindi
Marathi
overall
Save:
evaluation_report.md
========================================================
PHASE 10 — ERROR ANALYSIS
Inspect worst errors.
Group by:
language
duration
speaker
generator
audio condition
Identify failure modes.
Do not immediately change the model.
First understand the failures.
========================================================
PHASE 11 — SCALE
Only after pilot success:
expand the dataset incrementally.
Suggested progression:
1K samples
→
5K
→
10K
→
larger selected subset
Never jump directly to the maximum dataset.
At each stage:
measure
train
evaluate
compare
========================================================
PHASE 12 — AUGMENTATION
Run controlled experiments:
A:
none
B:
gain
C:
noise
D:
telephone filtering
E:
compression
F:
combined mild augmentation
Compare against the same evaluation set.
Do not change multiple unrelated variables simultaneously.
========================================================
PHASE 13 — FULL VS PARTIAL FINE-TUNING
Run:
Experiment A:
full fine-tuning
Experiment B:
partial fine-tuning
Keep the exact same data split.
Compare:
EER
F1
generalization
training time
memory
inference latency
========================================================
PHASE 14 — CALIBRATION
Only after selecting a stable classifier.
Evaluate:
raw score calibration.
Create calibrated score if beneficial.
Document:
raw score
calibrated score
========================================================
PHASE 15 — MODEL PACKAGING
Produce:
model.pt
model metadata JSON
training config
dataset provenance
evaluation report
license file
inference script
README
Example:
artifacts/final/
├── aasist_l_vanirakshak.pt
├── metadata.json
├── config.yaml
├── metrics.json
├── README.md
└── LICENSES.md
========================================================
FINAL ACCEPTANCE CRITERIA
Do not declare the model "ready" unless all are true:
[ ] Environment reproducible
[ ] MPS works
[ ] Pretrained model verified
[ ] Dataset provenance documented
[ ] Hindi available
[ ] Marathi available
[ ] BONAFIDE/SPOOF labels verified
[ ] Speaker-disjoint split verified
[ ] Generator-disjoint evaluation attempted where metadata permits
[ ] No train/test duplicate leakage
[ ] Baseline measured
[ ] Fine-tuning completed
[ ] Best checkpoint saved
[ ] Resume-from-checkpoint tested
[ ] EER measured
[ ] Precision measured
[ ] Recall measured
[ ] F1 measured
[ ] Confusion matrix generated
[ ] Error analysis completed
[ ] License reviewed
[ ] Final model reproducible
========================================================
CODING QUALITY RULES
Write production-quality Python.
Use:
type hints
docstrings
small functions
clear names
logging
exceptions
validation
Avoid:
huge scripts
global mutable state
hard-coded paths
hard-coded hyperparameters
silent failures
All paths should be configurable.
========================================================
GIT RULES
Use Git.
Create commits after each stable phase.
Suggested commits:
feat: initialize ml environment
feat: verify aasist-l checkpoint
feat: add dataset inspection
feat: add pilot manifest
feat: add preprocessing
feat: add leakage-safe splits
feat: add baseline evaluation
feat: add mps training
feat: add evaluation
feat: add checkpoint resume
feat: add error analysis
Do not commit:
datasets
checkpoints
secrets
large generated artifacts
========================================================
STOP / APPROVAL RULE
This is extremely important.
Do NOT execute all phases automatically.
After every major phase:
explain what was done
show files created
show commands executed
show validation results
show any warnings
state whether the phase passed or failed
wait for approval before destructive/expensive actions
Especially ask before:
large dataset downloads
large preprocessing jobs
long training runs
changing model architecture
changing label semantics
changing dataset sources
========================================================
FIRST TASK
Start ONLY with PHASE 0.
Do not clone large datasets.
Do not begin training.
Do not download IndicVoices fully.
Do not download IndicSynth fully.
Perform an environment audit for my M2 Mac.
Then:
verify Apple Silicon
verify Python
verify PyTorch
verify MPS
verify available disk
verify RAM
verify Git
Create:
reports/environment_report.md
At the end, provide:
Environment summary
Device selected
Package versions
Potential compatibility problems
Exact next command(s)
Whether Phase 0 passed
WAIT FOR MY APPROVAL BEFORE PHASE 1.

## Why this approach is safer

The most important decision is that we're **not treating this as "download dataset → run training."**

The sequence is:

```text
Environment
    ↓
AASIST-L verification
    ↓
Dataset inspection
    ↓
Small pilot
    ↓
Audio validation
    ↓
Leakage-safe split
    ↓
Pretrained baseline
    ↓
1–2 epoch smoke test
    ↓
Pilot fine-tuning
    ↓
Evaluation
    ↓
Error analysis
    ↓
Scale
That matters because the official AASIST code was designed around ASVspoof's dataset/protocol structure rather than IndicVoices/IndicSynth directly.
And we're deliberately not downloading the full datasets initially. IndicVoices is currently listed at about 745 GB on Hugging Face, while the IndicSynth listing is about 845 GB, so blindly pulling everything onto an M2 Mac would be a poor first move.
The really important ML rule is also preserved: speaker-disjoint + generator-aware evaluation. Otherwise we could end up with an impressive-looking number that reflects leakage rather than actual spoof-detection generalization.
Your final model goal
                 IndicVoices
              REAL / BONAFIDE
                     │
                     │
                     ├──────────┐
                     │          │
                     │       Manifest
                     │          │
                 IndicSynth     │
                SPOOF / FAKE    │
                     │          │
                     └────┬─────┘
                          ↓
                 Leakage-safe split
                          ↓
                    Audio pipeline
                          ↓
                 Pretrained AASIST-L
                          ↓
                   Fine-tuning
                          ↓
             VANIRAKSHAK AASIST-L
                          ↓
              REAL / SPOOF + score
And then that AASIST-L output becomes only one input into the larger VANIRAKSHAK risk engine; it is not the scam detector, speaker verifier, or final fraud score.