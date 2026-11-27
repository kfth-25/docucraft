// CORS Proxy for 9router AI
// Jalankan: node cors-proxy.js
// Lalu update AiConfig.baseUrl ke 'http://localhost:3000/v1'

const http = require('http');

const TARGET = 'http://127.0.0.1:20128';
const PORT = 3000;

const server = http.createServer((req, res) => {
  // Add CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  // Handle preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(200, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Max-Age': '86400',
    });
    res.end();
    return;
  }

  // Forward request to 9router (strip /proxy prefix if present)
  let reqPath = req.url;
  if (reqPath.startsWith('/proxy')) {
    reqPath = reqPath.substring('/proxy'.length);
  }
  const url = new URL(reqPath, TARGET);
  const options = {
    hostname: url.hostname,
    port: url.port,
    path: url.pathname + url.search,
    method: req.method,
    headers: {
      ...req.headers,
      host: url.host,
    },
  };

  const proxyReq = http.request(options, (proxyRes) => {
    // Ensure CORS headers are present in the response
    const headers = {
      ...proxyRes.headers,
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    };
    res.writeHead(proxyRes.statusCode, headers);
    proxyRes.pipe(res);
  });

  proxyReq.on('error', (e) => {
    console.error('Proxy error:', e.message);
    res.writeHead(502);
    res.end('Bad Gateway');
  });

  req.pipe(proxyReq);
});

server.listen(PORT, () => {
  console.log(`CORS Proxy running on http://localhost:${PORT}`);
  console.log(`Forwarding to ${TARGET}`);
  console.log('');
  console.log('Update AiConfig.baseUrl to: http://localhost:' + PORT + '/v1');
});
