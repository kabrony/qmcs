const http = require('http');
const PORT = 6000;

http.createServer((_, res) => {
  res.writeHead(200, {"Content-Type": "application/json"});
  res.end(JSON.stringify({status: "Oracle (auto-named)", data: {price: 42.0}}));
}).listen(PORT, () => {
  console.log("[oracle_service] on port", PORT);
});
