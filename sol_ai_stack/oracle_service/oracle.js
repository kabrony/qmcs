const http = require('http');
const PORT = 6000;

// Placeholder service simulating external data fetch
http.createServer((req, res) => {
  res.writeHead(200, {"Content-Type": "application/json"});
  res.end(JSON.stringify({status: "Oracle running", data: {price: 42.0}}));
}).listen(PORT, () => {
  console.log("[INFO] oracle_service is up on port", PORT);
});
