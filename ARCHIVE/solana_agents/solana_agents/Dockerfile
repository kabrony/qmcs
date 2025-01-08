FROM node:18-slim

WORKDIR /app

COPY package.json ./
RUN npm install

COPY app/ ./app

EXPOSE 4000

CMD ["node", "app/index.js"]
