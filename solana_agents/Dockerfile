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
