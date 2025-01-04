require('dotenv').config();
const express = require('express');
const { MongoClient } = require('mongodb');

const app = express();
app.use(express.json());

const port = 4000;
const MONGO_DETAILS = process.env.MONGO_DETAILS || '';
const SOLANA_RPC_URL = process.env.SOLANA_RPC_URL || 'https://api.mainnet-beta.solana.com';

let mongoDB = null;

// Print a quick test to confirm code is updated:
console.log("[solana_agents] CODE TEST -> If you see this, code was updated.");

// Initialize Mongo
(async function initMongo() {
  if (!MONGO_DETAILS) {
    console.log("[solana_agents] No MONGO_DETAILS provided");
    return;
  }
  try {
    console.log("[solana_agents] Using MONGO_DETAILS:", MONGO_DETAILS.replace(/:[^:]*@/, ':****@'));
    const client = new MongoClient(MONGO_DETAILS, { serverSelectionTimeoutMS: 8000 });
    await client.connect();
    mongoDB = client.db();
    console.log("[solana_agents] MongoDB connected successfully!");
  } catch (err) {
    console.error("[solana_agents] MongoDB connection error:", err.message);
  }
})();

// Health
app.get('/health', (req, res) => {
  res.json({ status: 'ok', rpc: SOLANA_RPC_URL });
});

app.listen(port, () => {
  console.log(`[solana_agents] listening on port ${port}`);
});
