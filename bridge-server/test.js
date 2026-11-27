/**
 * Test script for AION UI Bridge Server
 *
 * Tests:
 * 1. Health check
 * 2. Send prompt
 * 3. Check conversation status
 * 4. List conversations
 */

const http = require('http');
const BASE_URL = 'http://localhost:3002';

function request(method, path, body = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const options = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      method: method,
      headers: { 'Content-Type': 'application/json' },
    };

    const req = http.request(options, res => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, data: JSON.parse(data) });
        } catch (e) {
          resolve({ status: res.statusCode, data: data });
        }
      });
    });

    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

async function runTests() {
  console.log('═══════════════════════════════════════════════════════════');
  console.log('  AION UI Bridge Server — Test Suite');
  console.log('═══════════════════════════════════════════════════════════\n');

  // Test 1: Health Check
  console.log('Test 1: Health Check');
  const health = await request('GET', '/health');
  console.log(`  Status: ${health.status}`);
  console.log(`  Response: ${JSON.stringify(health.data, null, 2)}\n`);

  // Test 2: Send Prompt
  console.log('Test 2: Send Prompt to AION UI');
  const sendResult = await request('POST', '/send', {
    prompt: 'buat ppt tentang AI dengan gaya minimalis',
  });
  console.log(`  Status: ${sendResult.status}`);
  console.log(`  Response: ${JSON.stringify(sendResult.data, null, 2)}\n`);

  // Test 3: Check Status
  if (sendResult.data && sendResult.data.conversationId) {
    console.log('Test 3: Check Conversation Status');
    const status = await request('GET', `/status?id=${sendResult.data.conversationId}`);
    console.log(`  Status: ${status.status}`);
    console.log(`  Messages: ${status.data?.messages?.length || 0}\n`);
  }

  // Test 4: List Conversations
  console.log('Test 4: List Recent Conversations');
  const list = await request('GET', '/conversations?limit=5');
  console.log(`  Status: ${list.status}`);
  console.log(`  Count: ${list.data?.conversations?.length || 0}\n`);

  console.log('═══════════════════════════════════════════════════════════');
  console.log('  Tests Complete');
  console.log('═══════════════════════════════════════════════════════════');
}

runTests().catch(err => {
  console.error('Test failed:', err.message);
  console.error('Make sure bridge server is running: node aion-bridge.js');
});
