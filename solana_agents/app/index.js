#!/usr/bin/env node
"use strict";

require("dotenv").config();
const express = require("express");
const axios = require("axios");
const { Connection, PublicKey } = require("@solana/web3.js");

const app = express();
app.use(express.json());

function logInfo(msg)  { console.log(new Date().toISOString(), "[INFO]", msg); }
function logError(msg) { console.error(new Date().toISOString(), "[ERROR]", msg); }

const PORT = process.env.PORT || 4000;
const RAGCHAIN_URL = process.env.RAGCHAIN_URL || "";
const QUANT_URL = process.env.QUANT_URL || "";
const SOLANA_RPC_URL = process.env.SOLANA_RPC_URL || "";
const SOLANA_PRIVATE_KEY = process.env.SOLANA_PRIVATE_KEY || "";

app.get("/health", async (req, res) => {
  try {
    if (RAGCHAIN_URL) await axios.get(`${RAGCHAIN_URL}/health`);
    if (QUANT_URL) await axios.get(`${QUANT_URL}/health`);
    res.json({ status: "solana_agents healthy" });
  } catch (err) {
    logError("Health fail: " + err.message);
    res.status(503).json({ error: err.message });
  }
});

app.get("/api/v1/fetch-ideas", async (req, res) => {
  if (!RAGCHAIN_URL) return res.status(400).json({ error: "No RAGCHAIN_URL set" });
  try {
    const out = await axios.get(`${RAGCHAIN_URL}/ephemeral_ideas`);
    res.json(out.data);
  } catch (e) {
    logError("fetch-ideas: " + e.message);
    res.status(500).json({ error: e.message });
  }
});

app.get("/api/v1/run-quant", async (req, res) => {
  if (!QUANT_URL) return res.status(400).json({ error: "No QUANT_URL set" });
  try {
    const out = await axios.get(`${QUANT_URL}/example-circuits`);
    res.json(out.data);
  } catch (err) {
    logError("run-quant: " + err.message);
    res.status(500).json({ error: err.message });
  }
});

app.get("/solana-config", (req, res) => {
  res.json({
    SOLANA_RPC_URL: SOLANA_RPC_URL.slice(0, 50) + "...",
    hasPrivateKey: !!SOLANA_PRIVATE_KEY
  });
});

app.get("/solana-balance/:pubKey", async (req, res) => {
  if (!SOLANA_RPC_URL) {
    return res.status(400).json({ error: "SOLANA_RPC_URL not set" });
  }
  try {
    const conn = new Connection(SOLANA_RPC_URL);
    const pubKey = new PublicKey(req.params.pubKey);
    const balance = await conn.getBalance(pubKey);
    res.json({ publicKey: req.params.pubKey, balance });
  } catch (e) {
    logError("Balance error: " + e.message);
    res.status(500).json({ error: e.message });
  }
});

app.listen(PORT, () => {
  logInfo("solana_agents listening on port " + PORT);
});
