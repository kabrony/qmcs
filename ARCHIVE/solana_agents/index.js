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
