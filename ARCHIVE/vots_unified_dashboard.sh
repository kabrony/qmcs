#!/usr/bin/env bash
###############################################################################
# vots_unified_dashboard.sh
#
# A comprehensive Verifiable Output of Testing Script (VOTS) that checks:
#   1) openai_service model availability + basic chat completions
#   2) openai_service "advanced memory" usage (/add_doc & /ask)
#   3) Health checks for: 
#       - openai_service
#       - solana_agents
#       - ragchain_service
#       - quant_service
#       - oracle_service
#       - argus_service
#   4) Basic DB connectivity (Redis, Mongo) via quant_service
#
# PRE-REQS:
#   - 'jq' + 'curl' installed.
#   - Docker containers up for each service on the correct ports.
#   - export OPENAI_API_KEY="sk-..."
#
###############################################################################

LOG_DIR="vots_logs"
mkdir -p "$LOG_DIR"
TIMESTAMP="$(date +'%Y%m%d_%H%M%S')"
LOG_FILE="$LOG_DIR/unified_dashboard_check_${TIMESTAMP}.log"
REPORT_FILE="vots_unified_report.txt"
VOTS_STATUS="PASSED"

# Adjust these service URLs/ports to match your docker-compose environment
OPENAI_SERVICE_URL="http://localhost:5103"
SOLANA_AGENTS_URL="http://localhost:5106"
RAGCHAIN_URL="http://localhost:5105"
QUANT_URL="http://localhost:5104"
ORACLE_URL="http://localhost:5102"
ARGUS_URL="http://localhost:5101"

# The VOTS script expects these aliases from /models for openai_service
REQUIRED_MODELS=("gpt-4o" "gpt-3.5-turbo" "o1" "o1-mini")

###############################################################################
# Helper Functions
###############################################################################
log_info() {
  echo "[INFO] $(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}
log_error() {
  echo "[ERROR] $(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE" >&2
}
write_report() {
  echo "$1" | tee -a "$REPORT_FILE"
}

check_health() {
  # Return 0 if /health responds 2xx, else 1
  local url="$1/health"
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' "$url" 2>/dev/null)"
  if [[ "$code" == "200" ]]; then
    return 0
  else
    return 1
  fi
}

api_get() {
  curl -s -H "Content-Type: application/json" "$1"
}

api_post() {
  local url="$1"
  local data="$2"
  curl -s -X POST -H "Content-Type: application/json" -d "$data" "$url"
}

###############################################################################
# 0) Initialize
###############################################################################
echo "VOTS Unified Dashboard Script - Start at $(date)" > "$REPORT_FILE"
log_info "=== Starting VOTS for Unified Dashboard System ==="

###############################################################################
# 1) OPENAI_SERVICE
###############################################################################
write_report ""
write_report "--- Check 1: OpenAI Service Basic Checks ---"
log_info "Checking $OPENAI_SERVICE_URL/health..."

if check_health "$OPENAI_SERVICE_URL"; then
  log_info "openai_service health: OK"
  write_report "OpenAI Service Health: PASSED"
else
  log_error "openai_service health check FAILED - no 200 from $OPENAI_SERVICE_URL/health"
  write_report "OpenAI Service Health: FAILED"
  VOTS_STATUS="FAILED"
fi

# 1a) Model Availability
log_info "Fetching /models from openai_service..."
models_json="$(api_get "$OPENAI_SERVICE_URL/models")"
if [[ -z "$models_json" ]]; then
  log_error "No/empty response from $OPENAI_SERVICE_URL/models"
  write_report "Model retrieval: NO RESPONSE"
  VOTS_STATUS="FAILED"
else
  # If there's an error field, capture it
  err_msg="$(echo "$models_json" | jq -r '.error?.message' 2>/dev/null || echo "")"
  if [[ "$err_msg" != "null" && -n "$err_msg" ]]; then
    log_error "Model list retrieval error: $err_msg"
    write_report "Model list retrieval: FAILED"
    VOTS_STATUS="FAILED"
  else
    # parse model IDs
    available_ids="$(echo "$models_json" | jq -r '.data[].id' 2>/dev/null || echo "")"
    if [[ -z "$available_ids" ]]; then
      log_error "No model IDs found in .data[].id from /models"
      write_report "Model availability: NO MODELS RETURNED"
      VOTS_STATUS="FAILED"
    else
      log_info "Models returned:\n$available_ids"
      for model_alias in "${REQUIRED_MODELS[@]}"; do
        if echo "$available_ids" | grep -q "$model_alias"; then
          log_info "Alias '$model_alias' is found."
        else
          log_error "Alias '$model_alias' NOT found in model list."
          VOTS_STATUS="FAILED"
        fi
      done
      write_report "Model availability check: DONE"
    fi
  fi
fi

# 1b) Basic Chat Completion
log_info "Testing /chat for basic chat completion..."
write_report "--- Basic Chat Completion ---"
chat_data='{"messages":[{"role":"user","content":"Hello from the Unified Dashboard!"}]}'
chat_resp="$(api_post "$OPENAI_SERVICE_URL/chat" "$chat_data")"
chat_err="$(echo "$chat_resp" | jq -r '.error?.message' 2>/dev/null || echo "")"

if [[ "$chat_err" != "null" && -n "$chat_err" ]]; then
  log_error "Chat completion failed: $chat_err"
  write_report "Chat completion: FAILED"
  VOTS_STATUS="FAILED"
else
  write_report "Chat completion: PASSED"
  log_info "Chat completion: PASSED"
fi

###############################################################################
# 1c) ADVANCED MEMORY TEST: /add_doc + /ask
###############################################################################
write_report ""
write_report "--- Check 1B: OpenAI Service ADVANCED MEMORY (Chroma) ---"
log_info "Storing doc with /add_doc, then asking a question with /ask..."

DOC_TEXT="Solana is a high-performance blockchain with very fast transactions."
add_doc_payload="{\"text\":\"$DOC_TEXT\",\"chunk_size\":80,\"chunk_overlap\":10}"
add_doc_resp="$(api_post "$OPENAI_SERVICE_URL/add_doc" "$add_doc_payload")"
add_doc_err="$(echo "$add_doc_resp" | jq -r '.error?.message' 2>/dev/null || echo "")"
chunks_stored="$(echo "$add_doc_resp" | jq -r '.chunks | length' 2>/dev/null || echo "0")"

if [[ -n "$add_doc_err" && "$add_doc_err" != "null" ]]; then
  log_error "/add_doc => FAILED: $add_doc_err"
  write_report "Advanced Memory: add_doc => FAILED"
  VOTS_STATUS="FAILED"
else
  log_info "Successfully stored doc with $chunks_stored chunk(s)."
  write_report "Advanced Memory: add_doc => PASSED"

  ask_payload='{"query":"What is Solana known for?"}'
  ask_resp="$(api_post "$OPENAI_SERVICE_URL/ask" "$ask_payload")"
  ask_err="$(echo "$ask_resp" | jq -r '.error?.message' 2>/dev/null || echo "")"
  ask_answer="$(echo "$ask_resp" | jq -r '.answer' 2>/dev/null || echo "")"

  if [[ -n "$ask_err" && "$ask_err" != "null" ]]; then
    log_error "Advanced Memory: /ask => FAILED: $ask_err"
    write_report "Advanced Memory: /ask => FAILED"
    VOTS_STATUS="FAILED"
  else
    # Minimal heuristic: check if "fast" or "high-performance" or "solana" is in the answer
    if echo "$ask_answer" | grep -iq "fast\|high-performance\|solana"; then
      log_info "Advanced Memory: /ask => PASSED (found relevant text)."
      write_report "Advanced Memory: /ask => PASSED"
    else
      log_error "Advanced Memory: /ask => Possibly incomplete. Answer: $ask_answer"
      VOTS_STATUS="FAILED"
    fi
  fi
fi


###############################################################################
# 2) Solana Agents
###############################################################################
write_report ""
write_report "--- Check 2: Solana Agents Service ---"
if check_health "$SOLANA_AGENTS_URL"; then
  log_info "Solana Agents health: OK"
  write_report "Solana Agents Health: PASSED"

  block_height_json="$(api_get "$SOLANA_AGENTS_URL/solana-block-height")"
  block_height="$(echo "$block_height_json" | jq -r '.blockHeight' 2>/dev/null || echo "")"
  if [[ -n "$block_height" && "$block_height" != "null" ]]; then
    log_info "Solana block height: $block_height"
  else
    log_error "Failed to retrieve block height from solana_agents. Possibly no data or unimplemented."
    VOTS_STATUS="FAILED"
  fi
else
  partial_resp="$(curl -s "$SOLANA_AGENTS_URL/health" 2>&1 || echo "")"
  log_error "Solana Agents health check FAILED - no 200. Possibly wrong port or container down. Response:\n$partial_resp"
  write_report "Solana Agents Health: FAILED"
  VOTS_STATUS="FAILED"
fi

###############################################################################
# 3) RAGChain
###############################################################################
write_report ""
write_report "--- Check 3: RAGChain Service ---"
if check_health "$RAGCHAIN_URL"; then
  log_info "RAGChain health: OK"
  write_report "RAGChain Health: PASSED"

  add_doc_resp="$(api_post "$RAGCHAIN_URL/add_document" '{"text":"VOTS test doc"}')"
  success_val="$(echo "$add_doc_resp" | jq -r '.success' 2>/dev/null || echo "")"
  if [[ "$success_val" == "true" ]]; then
    log_info "RAGChain doc insertion: PASSED"
  else
    log_error "RAGChain doc insertion: FAILED"
    VOTS_STATUS="FAILED"
  fi
else
  log_error "RAGChain health check FAILED"
  write_report "RAGChain Health: FAILED"
  VOTS_STATUS="FAILED"
fi

###############################################################################
# 4) Quant Service
###############################################################################
write_report ""
write_report "--- Check 4: Quant Service ---"
if check_health "$QUANT_URL"; then
  log_info "Quant Service health: OK"
  write_report "Quant Health: PASSED"

  # Redis
  redis_resp="$(api_get "$QUANT_URL/test_redis")"
  if [[ "$redis_resp" == "ok" ]]; then
    log_info "Quant-Redis check: PASSED"
  else
    log_error "Quant-Redis check: FAILED (response != 'ok')"
    VOTS_STATUS="FAILED"
  fi

  # Mongo
  mongo_resp="$(api_get "$QUANT_URL/test_mongo")"
  if [[ "$mongo_resp" == "ok" ]]; then
    log_info "Quant-Mongo check: PASSED"
  else
    log_error "Quant-Mongo check: FAILED (response != 'ok')"
    VOTS_STATUS="FAILED"
  fi
else
  log_error "Quant Service health check FAILED"
  write_report "Quant Health: FAILED"
  VOTS_STATUS="FAILED"
fi

###############################################################################
# 5) Oracle Service
###############################################################################
write_report ""
write_report "--- Check 5: Oracle Service ---"
if check_health "$ORACLE_URL"; then
  log_info "Oracle Service health: OK"
  write_report "Oracle Health: PASSED"
else
  log_error "Oracle Service health check FAILED"
  write_report "Oracle Health: FAILED"
  VOTS_STATUS="FAILED"
fi

###############################################################################
# 6) Argus Service
###############################################################################
write_report ""
write_report "--- Check 6: Argus Service ---"
if check_health "$ARGUS_URL"; then
  log_info "Argus Service health: OK"
  write_report "Argus Health: PASSED"

  metrics_json="$(api_get "$ARGUS_URL/metrics")"
  mem_usage="$(echo "$metrics_json" | jq -r '.memory_usage' 2>/dev/null || echo "")"
  if [[ -n "$mem_usage" && "$mem_usage" != "null" ]]; then
    log_info "Argus memory usage: $mem_usage"
  else
    log_error "Argus metrics check: FAILED (no memory_usage?)."
    VOTS_STATUS="FAILED"
  fi
else
  log_error "Argus Service health check FAILED"
  write_report "Argus Health: FAILED"
  VOTS_STATUS="FAILED"
fi

###############################################################################
# 7) Final Summary
###############################################################################
write_report ""
write_report "--- FINAL SUMMARY ---"
if [[ "$VOTS_STATUS" == "FAILED" ]]; then
  write_report "Overall VOTS Status: FAILED"
  log_error "Overall status: FAILED. See $LOG_FILE for details."
else
  write_report "Overall VOTS Status: PASSED"
  log_info "Overall status: PASSED."
fi

write_report "Detailed log file: $LOG_FILE"
write_report "###############################################################################"
write_report "UNIFIED DASHBOARD SYSTEM INTEGRATION NOTES:"
write_report " - Check Solana Agents port alignment or container logs if health fails."
write_report " - If quant_service /test_redis or /test_mongo return not 'ok', fix logic."
write_report " - For advanced usage, see memory code in openai_service (/add_doc & /ask),"
write_report "   or 'executeTrade()' in solana_agents, etc."
write_report "###############################################################################"

log_info "VOTS Script Completed. Check '$REPORT_FILE' for summary. Full logs in '$LOG_FILE'."
