#!/usr/bin/env bash
set -e

echo "[INFO] This script removes references to 'agent-twitter-client' from solana_agents code and Dockerfile."
echo "[INFO] Then it rebuilds Docker images with no cache and restarts them."

sleep 3

###############################################
# Step A) Overwrite index.js without references
###############################################
echo "[INFO] Overwriting solana_agents/index.js to remove agent-twitter-client usage..."

if [ ! -f solana_agents/index.js ]; then
  echo "[ERROR] solana_agents/index.js not found!"
  exit 1
fi

cat > solana_agents/index.js <<'EOF'
require('dotenv').config();
const axios = require('axios');
const cron = require('node-cron');
const express = require('express');
const app = express();
app.use(express.json());

const {
  Connection,
  Keypair,
  Transaction,
  SystemProgram,
  sendAndConfirmTransaction,
  PublicKey
} = require("@solana/web3.js");

const { v4: uuidv4 } = require('uuid');

const logger = {
  info: (...args) => console.log(new Date().toISOString(), "[INFO]", ...args),
  error: (...args) => console.error(new Date().toISOString(), "[ERROR]", ...args),
  warn: (...args) => console.warn(new Date().toISOString(), "[WARN]", ...args),
};

const PORT = process.env.PORT || 4000;
const RAGCHAIN_SERVICE_URL = process.env.RAGCHAIN_SERVICE_URL;
const QUANT_SERVICE_URL = process.env.QUANT_SERVICE_URL;
const SOLANA_RPC_URL = process.env.SOLANA_RPC_URL;
const SOLANA_PRIVATE_KEY = process.env.SOLANA_PRIVATE_KEY;
const TWITTER_USERNAME = process.env.TWITTER_USERNAME;
const TWITTER_PASSWORD = process.env.TWITTER_PASSWORD;
const TWITTER_EMAIL = process.env.TWITTER_EMAIL;

logger.info("Starting solana_agents with config:", {
  PORT, QUANT_SERVICE_URL, SOLANA_RPC_URL
});

/**
 * For now, we remove all references to 'agent-twitter-client' and simply omit any tweet scraping logic.
 * If you want to re-implement Twitter functionality with a different library, you can add it here later.
 */

app.get('/health', (req, res) => {
  res.status(200).send({ status: "ok", publicKey: process.env.SOLANA_PUBLIC_KEY });
});

async function processTransaction(token, amount) {
  if (!SOLANA_PRIVATE_KEY) {
    throw new Error('Missing SOLANA_PRIVATE_KEY');
  }

  const connection = new Connection(SOLANA_RPC_URL);
  const keypair = Keypair.fromSecretKey(
    Uint8Array.from(Buffer.from(SOLANA_PRIVATE_KEY, 'base64'))
  );
  const toPublicKey = new PublicKey(process.env.SOLANA_PUBLIC_KEY);
  const lamports = amount * 1000000000;

  // Create a transaction to transfer lamports
  const transaction = new Transaction().add(
    SystemProgram.transfer({
      fromPubkey: keypair.publicKey,
      toPubkey: toPublicKey,
      lamports: lamports,
    })
  );

  logger.info('Attempting to send lamports to ', toPublicKey);

  try {
    const signature = await sendAndConfirmTransaction(
      connection,
      transaction,
      [keypair]
    );
    logger.info('Solana Transaction successful:', signature);
    return { success: true, signature: signature };
  } catch (e) {
    logger.error('Solana Transaction failed:', e);
    return { success: false, error: e.message };
  }
}

// Example CRON: daily tasks at midnight
cron.schedule('0 0 * * *', async () => {
  logger.info('Running daily tasks...');
  // Example call to quant_service
  try {
    const response = await axios.get(`${QUANT_SERVICE_URL}/health`);
    console.log('Response from quant_service:', response.data);
  } catch (error) {
    console.error('Error contacting quant service:', error);
  }
});

// (We remove the tweet scraping function since agent-twitter-client is no longer used.)

app.post('/trade', async (req, res) => {
  const data = req.body;
  logger.info("Received trade request: ", data);

  // Instead of scraping tweets, we do no extra step here
  const result = await processTransaction("SOL", 0.1);
  res.status(200).send({
    message: "Trading logic is a placeholder (agent-twitter-client removed).",
    solana: result
  });
});

app.listen(PORT, () => {
  logger.info(`solana_agents listening on port ${PORT}`);
});
EOF

echo "[INFO] Done overwriting solana_agents/index.js."

#################################################
# Step B) Overwrite Dockerfile without agent-twitter-client
#################################################
echo "[INFO] Overwriting solana_agents/Dockerfile to remove agent-twitter-client..."

if [ ! -f solana_agents/Dockerfile ]; then
  echo "[ERROR] solana_agents/Dockerfile not found!"
  exit 1
fi

cat > solana_agents/Dockerfile <<'EOF'
# Dockerfile for solana_agents without agent-twitter-client
FROM node:18-slim

WORKDIR /app
COPY . /app

# We remove agent-twitter-client from the npm install list
RUN npm install \
    express \
    node-cron \
    dotenv \
    axios \
    @solana/web3.js

EXPOSE 4000
CMD ["npm", "start"]
EOF

echo "[INFO] Done overwriting solana_agents/Dockerfile."

########################################
# Step C) Rebuild Docker Images
########################################
echo "[INFO] Rebuilding docker containers with no cache..."
docker-compose down
docker-compose build --no-cache
docker-compose up -d

echo "[INFO] Containers are starting...check logs with: docker-compose logs -f"
echo "[INFO] Once stable, re-run ./vots_unified_dashboard.sh if desired."

