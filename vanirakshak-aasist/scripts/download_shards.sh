#!/usr/bin/env bash
# ==============================================================================
# VANIRAKSHAK — Download FLEURS + IndicSynth parquet shards via curl
# ==============================================================================
# Usage:
#   bash scripts/download_shards.sh hi     # Hindi
#   bash scripts/download_shards.sh mr     # Marathi
#
# Downloads parquet files directly from HuggingFace CDN using curl (resilient
# to TCP resets). Python's datasets streaming is NOT used here.
# ==============================================================================

set -e
LANG="${1:-hi}"

# Base HF CDN URL for dataset files
HF_BASE="https://huggingface.co/datasets"

# Output directories
BONAFIDE_DIR="data/raw/fleurs_${LANG}"
SPOOF_DIR="data/raw/indicsynth_${LANG}"
mkdir -p "$BONAFIDE_DIR" "$SPOOF_DIR"

echo ""
echo "============================================================"
echo "  Downloading FLEURS + IndicSynth parquet shards"
echo "  Language: $LANG"
echo "============================================================"

# ── FLEURS config names ────────────────────────────────────────────────────────
if [ "$LANG" = "hi" ]; then
    FLEURS_CONFIG="hi_in"
elif [ "$LANG" = "mr" ]; then
    FLEURS_CONFIG="mr_in"
else
    echo "ERROR: unsupported lang $LANG (use hi or mr)"
    exit 1
fi

# ── IndicSynth config names ────────────────────────────────────────────────────
if [ "$LANG" = "hi" ]; then
    SYNTH_CONFIG="Hindi"
elif [ "$LANG" = "mr" ]; then
    SYNTH_CONFIG="Marathi"
fi

# ── Download helper ────────────────────────────────────────────────────────────
# Uses --continue-at - for resume, --retry for transient errors
download() {
    local url="$1"
    local out="$2"
    echo "  Downloading $(basename $out) …"
    curl \
        --location \
        --retry 5 \
        --retry-delay 3 \
        --retry-max-time 120 \
        --continue-at - \
        --max-time 300 \
        --progress-bar \
        --output "$out" \
        "$url" || {
            echo "  [WARN] Failed: $url — skipping"
            rm -f "$out"
        }
}

# ── FLEURS parquet shards ──────────────────────────────────────────────────────
# FLEURS parquet layout on HF: resolve/main/parquet-data/<config>/
FLEURS_SPLITS="train validation test"

echo ""
echo "  [BONAFIDE] google/fleurs [$FLEURS_CONFIG]"
for SPLIT in $FLEURS_SPLITS; do
    URL="${HF_BASE}/google/fleurs/resolve/main/parquet-data/${FLEURS_CONFIG}/${SPLIT}-00000-of-00001.parquet"
    OUT="${BONAFIDE_DIR}/${SPLIT}.parquet"
    if [ -f "$OUT" ] && [ -s "$OUT" ] && ! grep -q "Entry not found" "$OUT"; then
        echo "  Already exists: $OUT — skipping"
    else
        download "$URL" "$OUT"
    fi
done

# ── IndicSynth parquet shards ─────────────────────────────────────────────────
# IndicSynth layout: resolve/main/<Config>/train-*.parquet
echo ""
echo "  [SPOOF] ksmashhero/IndicSynth [$SYNTH_CONFIG]"

SHARD=0
while true; do
    SHARD_PAD=$(printf "%05d" $SHARD)
    URL="${HF_BASE}/ksmashhero/IndicSynth/resolve/main/${SYNTH_CONFIG}/train-${SHARD_PAD}-of-00107.parquet"
    OUT="${SPOOF_DIR}/train_${SHARD_PAD}.parquet"

    if [ -f "$OUT" ] && [ -s "$OUT" ] && ! grep -q "Entry not found" "$OUT"; then
        echo "  Already exists: $OUT — skipping"
        SHARD=$((SHARD + 1))
        [ $SHARD -ge 3 ] && break
        continue
    fi

    HTTP_CODE=$(curl --location --max-time 15 -o /dev/null -w "%{http_code}" "$URL" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
        download "$URL" "$OUT"
        SHARD=$((SHARD + 1))
        [ $SHARD -ge 3 ] && break
    else
        echo "  Shard $SHARD_PAD not found (HTTP $HTTP_CODE) — stopping."
        break
    fi
done

echo ""
echo "============================================================"
echo "  Download complete!"
echo "  Bonafide parquets → $BONAFIDE_DIR"
echo "  Spoof parquets    → $SPOOF_DIR"
echo "============================================================"
echo ""
echo "  Next: python scripts/build_manifest_from_local.py --lang $LANG"
