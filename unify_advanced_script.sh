#!/usr/bin/env bash
#
# unify_advanced_script.sh
# Appends an "advanced memory synergy" snippet to each microservice's main file
# and optionally runs Docker rebuild.

OUTPUT_LOG="unify_advanced_script.log"

echo "[INFO] unify_advanced_script.sh started." | tee -a "$OUTPUT_LOG"

ADVANCED_MEMORY_SNIPPET=$(cat << 'MEMBLOCK'
// ========== ADVANCED MEMORY SYNERGY ==========
// Example synergy code for ephemeral store or Argus advanced memory logic.
// Placeholder snippet. In real usage, adjust for your actual synergy calls.

async function unifyMemorySynergy() {
  console.log("[SYNERGY] Attempt advanced ephemeral alignment (placeholder).");
  // Insert real calls to ragchain or argus ephemeral, e.g.:
  //   storeEphemeralThought("Testing synergy");
}
// ========== END ADVANCED MEMORY SNIPPET ==========
MEMBLOCK
)

SERVICES_MAIN_FILES=(
  "solana_agents/index.js"
  "quant_service/main.py"
  "ragchain_service/main.py"
  "openai_service/main.py"
  "argus_service/main.py"
  "oracle_service/main.py"
)

echo "[INFO] Inserting snippet into each main file..." | tee -a "$OUTPUT_LOG"
for file_path in "${SERVICES_MAIN_FILES[@]}"; do
  if [[ -f "$file_path" ]]; then
    echo "[INFO] Appending snippet to $file_path" | tee -a "$OUTPUT_LOG"
    {
      echo ""
      echo "$ADVANCED_MEMORY_SNIPPET"
    } >> "$file_path"
  else
    echo "[WARN] $file_path not found, skipping." | tee -a "$OUTPUT_LOG"
  fi
done

echo "" | tee -a "$OUTPUT_LOG"
read -rp "Would you like to rebuild Docker images with no cache and start containers? [y/N] " DOCKER_BUILD
if [[ "$DOCKER_BUILD" =~ ^[Yy]$ ]]; then
  echo "[INFO] Rebuilding images (no-cache) and starting containers..." | tee -a "$OUTPUT_LOG"
  docker-compose down 2>&1 | tee -a "$OUTPUT_LOG"
  docker-compose build --no-cache 2>&1 | tee -a "$OUTPUT_LOG"
  docker-compose up -d 2>&1 | tee -a "$OUTPUT_LOG"
else
  echo "[SKIP] Docker rebuild step. (Run manually if needed.)" | tee -a "$OUTPUT_LOG"
fi

echo "[INFO] unify_advanced_script.sh complete. Review logs in $OUTPUT_LOG."
