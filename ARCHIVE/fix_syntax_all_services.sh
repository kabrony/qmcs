# ================================
# fix_syntax_all_services.sh
# ================================
# This script overwrites:
#   1) quant_service/main.py
#   2) ragchain_service/main.py
#   3) solana_agents/index.js
#
# with minimal placeholder code that has correct syntax.
# Next, rebuild images and check logs.

cat << 'EOF' > quant_service/main.py
from fastapi import FastAPI

app = FastAPI()

@app.get("/health")
def health():
    return {"status": "quant_service OK"}

@app.get("/")
def root():
    return {"message": "Hello from quant_service placeholder."}
EOF

cat << 'EOF' > ragchain_service/main.py
from fastapi import FastAPI

app = FastAPI()

@app.get("/health")
def health():
    return {"status": "ragchain_service OK"}

@app.get("/")
def root():
    return {"message": "Hello from ragchain_service placeholder."}
EOF

mkdir -p solana_agents
cat << 'EOF' > solana_agents/index.js
require('dotenv').config();
const express = require('express');
const axios = require('axios');
const {
  Connection,
  Keypair,
  Transaction,
  SystemProgram,
  sendAndConfirmTransaction,
  PublicKey
} = require("@solana/web3.js");

const PORT = process.env.PORT || 4000;
const SOLANA_RPC_URL = process.env.SOLANA_RPC_URL || "https://api.mainnet-beta.solana.com/";
const SOLANA_PRIVATE_KEY = process.env.SOLANA_PRIVATE_KEY || "";

const app = express();
app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ status: "ok", rpcUrl: SOLANA_RPC_URL });
});

app.listen(PORT, () => {
  console.log(`[INFO] solana_agents listening on port ${PORT}`);
});
EOF

echo "[INFO] Created minimal, syntax-valid placeholder files for quant_service, ragchain_service, solana_agents."
echo "Next steps:"
echo "  1) Run:  chmod +x fix_syntax_all_services.sh && ./fix_syntax_all_services.sh"
echo "  2) docker-compose down"
echo "  3) docker-compose build --no-cache"
echo "  4) docker-compose up -d"
echo "  5) docker-compose logs -f"
echo "Confirm no SyntaxError. Then adapt each file to your real logic."
