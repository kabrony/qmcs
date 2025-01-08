#!/usr/bin/env bash
set -e

echo "=== STEP 1: Ensure 'qmcs' folder exists (No .env Overwrite) ==="
echo "!!! NOTICE: This script will NOT create or overwrite '.env'."
echo "Make sure you have your .env file located at ~/qmcs/.env if needed."

echo "Your .env should have a line like:"
echo "    MONGO_DETAILS=\"mongodb+srv://doadmin:<PASSWORD>@private-db-...\""
echo "Press Ctrl+C now if you need to fix .env. Otherwise continuing in 5s..."
sleep 5

# STEP 2: Create a minimal docker-compose.yml (No .env Overwrite)
cat > ~/qmcs/docker-compose.yml << 'EOCOMP'
services:
  solana_agents:
    build:
      context: ./solana_agents
      dockerfile: Dockerfile
    container_name: solana_agents
    # We'll rely on .env for environment variables, but won't overwrite .env
    env_file: 
      - .env
    ports:
      - "4000:4000"
    networks:
      - qmcs_net

networks:
  qmcs_net:
    driver: bridge
EOCOMP

echo "=== STEP 2: Created docker-compose.yml (No .env Overwrite) ==="

# STEP 3: Minimal Dockerfile + patch + index.js for solana_agents
mkdir -p ~/qmcs/solana_agents

cat > ~/qmcs/solana_agents/patch_solana_agent.sh << 'EOPATCH'
#!/usr/bin/env bash
echo "=== (Optional) Patch for solana-agent-kit if needed ==="
EOPATCH
chmod +x ~/qmcs/solana_agents/patch_solana_agent.sh

cat > ~/qmcs/solana_agents/Dockerfile << 'EODOCKER'
FROM node:20-alpine

RUN apk update && apk add --no-cache git bash grep sed curl

WORKDIR /app

COPY package.json patch_solana_agent.sh ./
RUN npm install
RUN chmod +x patch_solana_agent.sh && ./patch_solana_agent.sh

COPY . .

EXPOSE 4000
CMD ["node", "index.js"]
EODOCKER

cat > ~/qmcs/solana_agents/package.json << 'EOPKG'
{
  "name": "solana_agents",
  "version": "1.0.0",
  "dependencies": {
    "express": "^4.18.2",
    "@solana/web3.js": "^1.87.6",
    "dotenv": "^16.3.1",
    "mongodb": "^6.3.0"
  },
  "scripts": {
    "start": "node index.js"
  }
}
EOPKG

cat > ~/qmcs/solana_agents/index.js << 'EOINDEX'
require('dotenv').config();
const express = require('express');
const { MongoClient } = require('mongodb');

const app = express();
app.use(express.json());

const port = 4000;

// Use MONGO_DETAILS from .env
const MONGO_DETAILS = process.env.MONGO_DETAILS || "";

let dbClient = null;

async function connectMongo() {
  if (!MONGO_DETAILS) {
    console.error("[solana_agents] No MONGO_DETAILS found in .env!");
    return;
  }

  console.log("[solana_agents] Using MONGO_DETAILS:", MONGO_DETAILS.replace(/:[^:]*@/, ":****@"));
  
  try {
    const client = new MongoClient(MONGO_DETAILS, {
      serverSelectionTimeoutMS: 8000,
      connectTimeoutMS: 15000,
      tls: true
    });
    await client.connect();
    await client.db("admin").command({ ping: 1 });
    console.log("[solana_agents] MongoDB connected successfully!");
    dbClient = client;
  } catch (err) {
    console.error("[solana_agents] MongoDB connection error:", err.message);
  }
}

// Health endpoint
app.get('/health', async (req, res) => {
  let status = "disconnected";
  if (dbClient) {
    try {
      await dbClient.db("admin").command({ ping: 1 });
      status = "connected";
    } catch (e) {
      status = "error";
    }
  }
  res.json({ status, timestamp: new Date().toISOString() });
});

// Start up
app.listen(port, async () => {
  console.log(`[solana_agents] listening on port ${port}`);
  await connectMongo();
});
EOINDEX

echo "=== STEP 3: Set up 'solana_agents' Dockerfile + patch + index.js (No .env Overwrite) ==="

# STEP 4: Build & Start
echo "=== STEP 4: Build & Start solana_agents. This will NOT overwrite .env ==="
cd ~/qmcs
docker compose build --no-cache solana_agents
docker compose up -d solana_agents
echo "=== DONE. Check logs with: docker compose logs -f solana_agents ==="
