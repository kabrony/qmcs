FROM node:20-alpine

RUN apk update && apk add --no-cache git bash grep sed curl

WORKDIR /app

COPY package.json patch_solana_agent.sh ./
RUN npm install

RUN chmod +x patch_solana_agent.sh && ./patch_solana_agent.sh || echo "[solana_agents] No patch needed"

COPY . .

EXPOSE 4000
CMD ["node", "index.js"]
