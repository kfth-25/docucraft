// CORS proxy for Flutter Web → local AI backend
// Usage: node tools/proxy-server.js
// Proxies /proxy/* → http://127.0.0.1:20128/v1/*

const http = require('http');

const TARGET = 'http://127.0.0.1:20128';
const PORT = 3000;

const server = http.createServer((req, res) => {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Request-Id');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // Strip /proxy prefix and forward to target
  const targetPath = req.url.replace(/^\/proxy/, '/v1');
  const targetUrl = new URL(targetPath, TARGET);

  const options = {
    hostname: targetUrl.hostname,
    port: targetUrl.port,
    path: targetUrl.pathname + targetUrl.search,
    method: req.method,
    headers: { ...req.headers, host: targetUrl.host },
  };

  const proxy = http.request(options, (proxyRes) => {
    res.writeHead(proxyRes.statusCode, proxyRes.headers);
    proxyRes.pipe(res, { end: true });
  });

  proxy.on('error', (err) => {
    console.error('Proxy error:', err.message);
    res.writeHead(502);
    res.end(JSON.stringify({ error: 'Backend unavailable', detail: err.message }));
  });

  req.pipe(proxy, { end: true });
});

server.listen(PORT, () => {
  console.log(`CORS proxy running on http://localhost:${PORT}`);
  console.log(`Proxying /proxy/* → ${TARGET}/v1/*`);
});
