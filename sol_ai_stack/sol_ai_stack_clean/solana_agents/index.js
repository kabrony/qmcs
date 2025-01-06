const http = require('http');
const PORT = 4000;

http.createServer((_, res) => {
  res.writeHead(200, {"Content-Type": "text/plain"});
  res.end("Solana Agents (auto-named) on 4000");
}).listen(PORT, () => {
  console.log("[solana_agents] on port", PORT);
});
