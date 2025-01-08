# ================================
# create_or_fix_files.sh
# ================================
# This script creates (or replaces) minimal examples of
#   quant_service/main.py
#   ragchain_service/main.py
#   solana_agents/index.js
# that won't produce syntax errors. 

cat > quant_service/main.py << 'EOF'
from fastapi import FastAPI

app = FastAPI()

@app.get("/health")
def health():
    return {"status": "quant_service OK"}

@app.get("/")
def root():
    return {"message": "Hello from quant_service placeholder."}
EOF


cat > ragchain_service/main.py << 'EOF'
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
cat > solana_agents/index.js << 'EOF'
require('dotenv').config();
const express = require('express');
const axios = require('axios');
const { Connection, Keypair, PublicKey, Transaction, SystemProgram } = require("@solana/web3.js");

const PORT = process.env.PORT || 4000;
const SOLANA_RPC_URL = process.env.SOLANA_RPC_URL || "https://api.mainnet-beta.solana.com/";
const SOLANA_PRIVATE_KEY = process.env.SOLANA_PRIVATE_KEY;

const app = express();
app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ status: "ok", solana_rpc: SOLANA_RPC_URL });
});

app.listen(PORT, () => {
  console.log(`[INFO] solana_agents listening on port ${PORT}`);
});
EOF

echo "Created minimal files for quant_service, ragchain_service, solana_agents."
echo "Next steps:"
echo " 1) Verify these files match your logic & environment variables."
echo " 2) Rebuild images:  docker-compose build --no-cache"
echo " 3) Start containers: docker-compose up -d"
echo " 4) Check logs:       docker-compose logs -f"
