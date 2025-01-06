require('dotenv').config();
const express = require('express');
const { Connection, PublicKey } = require('@solana/web3.js');

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 4000;
const SOLANA_RPC_URL = process.env.SOLANA_RPC_URL || "";
const SOLANA_PRIVATE_KEY = process.env.SOLANA_PRIVATE_KEY || "";
const SOLANA_PUBLIC_KEY = process.env.SOLANA_PUBLIC_KEY || "";

console.log("[INFO] Starting solana_agents service...");
console.log("[INFO] Using SOLANA_RPC_URL:", SOLANA_RPC_URL);

app.get('/health', (req, res) => {
  res.json({status: "ok", publicKey: SOLANA_PUBLIC_KEY});
});

app.listen(PORT, () => {
  console.log(`[INFO] solana_agents listening on port ${PORT}`);
});
