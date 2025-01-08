const http = require('http');

const PORT = 4000;
http.createServer((req, res) => {
  res.writeHead(200, {"Content-Type": "application/json"});
  res.end(JSON.stringify({status: "solana_agents listening on port 4000"}));
}).listen(PORT, () => {
  console.log(`[INFO] solana_agents listening on port ${PORT}`);
});
