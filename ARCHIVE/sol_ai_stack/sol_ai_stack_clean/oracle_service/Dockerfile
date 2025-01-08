FROM node:18-slim
WORKDIR /app

COPY package.json ./
RUN npm install
COPY . /app

EXPOSE 6000
CMD ["node", "oracle.js"]
