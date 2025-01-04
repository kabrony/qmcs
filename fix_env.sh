#!/usr/bin/env bash
set -e

echo "=== [1/4] Backing up existing .env (if any) to .env_backup_YYYYMMDD_HHMMSS ==="
cd ~/qmcs
if [ -f .env ]; then
  mv .env .env_backup_$(date +%Y%m%d_%H%M%S)
  echo "Existing .env backed up successfully."
fi

echo "=== [2/4] Creating a valid .env with NO spaces in keys or headings ==="
cat > .env << 'EOF'
# =======================================================
#  Database Configurations
# =======================================================
MYSQL_DATABASE=rag_flow
MYSQL_USER=ragflowuser
MYSQL_PASSWORD=ragflow123
MYSQL_ROOT_PASSWORD=mysecretpassword

# Redis
REDIS_PASSWORD=myredispass

# =======================================================
#  MongoDB
# =======================================================
# Example connection string:
# mongodb+srv://USER:PASSWORD@YOUR-CLUSTER.mongodb.ondigitalocean.com/admin?tls=true&authSource=admin&replicaSet=...
# Replace the following line with your own MONGO_DETAILS string:
MONGO_DETAILS="mongodb+srv://doadmin:9UI20fY5CA183t4D@private-db-mongodb-nyc3-54764-54a30691.mongo.ondigitalocean.com/admin?tls=true&authSource=admin&replicaSet=db-mongodb-nyc3-54764"

# =======================================================
#  Solana
# =======================================================
SOLANA_RPC_URL="https://api.mainnet-beta.solana.com"
SOLANA_PRIVATE_KEY="4gySDsCf5SeZ2FXCfuHvGPb1pj3yaJoYtcf9YmCEdjhgeM8EcUBFqjLpK9Re6rDezXaek2gyhj5PRXjv87Cbq3hP"

# =======================================================
#  Additional Keys
# =======================================================
OPENAI_API_KEY="sk-svcacct-S2fD-plOsk3jNPcdPlUb9lEUz3KlgEwhaAsJLXicSNDkHdeuozJX0jha7AYI58hT3BlbkFJHjhSeT1RzlB"
GEMINI_API_KEY="AIzaSyCoaDruS_LQBvgFFD46jiSINB6aLODC7Xk"
DEEPSEEK_API_KEY="sk-2753ea93a4704ebe8ecbd2e0"
TAVILY_API_KEY="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"

# =======================================================
#  (Add any extra environment variables if needed)
# =======================================================
EOF

echo "=== [3/4] Next Steps: Build or Rebuild Docker Services (solana_agents) ==="
echo "cd ~/qmcs"
echo "docker compose build --no-cache solana_agents"

echo "=== [4/4] Then Start (or Restart) the Service(s) ==="
echo "docker compose up -d solana_agents"
echo
echo "To see logs in real-time: docker compose logs -f solana_agents"

echo
echo "=== Done! ==="
