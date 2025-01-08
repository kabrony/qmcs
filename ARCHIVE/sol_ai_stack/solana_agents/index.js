const http = require('http');
const PORT = 4000;

http.createServer((req, res) => {
  res.writeHead(200, {"Content-Type": "text/plain"});
  res.end("Solana Agents running on port 4000");
}).listen(PORT, () => {
  console.log("[INFO] solana_agents listening on port", PORT);
});
