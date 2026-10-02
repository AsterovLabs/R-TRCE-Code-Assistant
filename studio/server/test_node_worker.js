/**
 * studio/server/test_node_worker.js -- Verification Suite for Node.js Worker Daemon
 */

const { spawn } = require('child_process');
const path = require('path');
const readline = require('readline');
const assert = require('assert');

const ROOT_DIR = path.resolve(__dirname, '..', '..');
const WORKER_SCRIPT = path.join(__dirname, 'node_worker.js');

console.log('[TEST] Starting Node.js Worker verification suite...');

const worker = spawn('node', [WORKER_SCRIPT], {
  cwd: ROOT_DIR,
  stdio: ['pipe', 'pipe', 'inherit']
});

const rl = readline.createInterface({
  input: worker.stdout,
  terminal: false
});

let reqCounter = 0;
const pending = new Map();

function send(action, payload = {}) {
  const id = `test-js-${++reqCounter}`;
  const msg = JSON.stringify({ id, action, payload }) + '\n';
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject });
    worker.stdin.write(msg);
  });
}

rl.on('line', (line) => {
  line = line.trim();
  if (!line) return;
  const msg = JSON.parse(line);
  if (msg.event === 'ready') {
    console.log(`[TEST] Node.js Worker ready (PID ${msg.pid}, version: ${msg.version})`);
    runTests();
    return;
  }
  if (msg.id && pending.has(msg.id)) {
    const { resolve } = pending.get(msg.id);
    pending.delete(msg.id);
    resolve(msg);
  }
});

async function runTests() {
  try {
    // 1. Ping
    console.log('[TEST 1] Testing ping...');
    const pingRes = await send('ping');
    assert.strictEqual(pingRes.ok, true, 'ping should succeed');
    assert.strictEqual(pingRes.result.pong, true, 'pong should be true');
    console.log('  -> PASS: ping works');

    // 2. Parse & AST Analysis
    console.log('[TEST 2] Testing parse on JS functions & classes...');
    const sampleCode = `
import express from 'express';

function calculateScore(a, b) {
  return a + b;
}

const formatUser = (user) => {
  return user.name;
};

class SessionStore {
  save(data) {}
}
`;
    const parseRes = await send('parse', { code: sampleCode });
    assert.strictEqual(parseRes.ok, true, 'parse should succeed');
    assert.strictEqual(parseRes.result.component_count, 3, 'should extract 3 components');
    assert.strictEqual(parseRes.result.archetype, 'HTTP Web API & Server Controller');
    console.log(`  -> PASS: parse extracted components: ${parseRes.result.component_count}, archetype: ${parseRes.result.archetype}`);

    // 3. Pitfalls Sentinel
    console.log('[TEST 3] Testing JS pitfall detection...');
    const trapCode = `
var oldVar = 100;
if (val == null) {
  console.log('loose');
}
if (x === NaN) {
  console.log('nan');
}
if (0.1 + 0.2 === 0.3) {
  console.log('float');
}
`;
    const pitfallRes = await send('pitfalls', { code: trapCode });
    assert.strictEqual(pitfallRes.ok, true, 'pitfalls should succeed');
    assert.strictEqual(pitfallRes.result.count >= 4, true, `should detect at least 4 traps (found ${pitfallRes.result.count})`);
    console.log(`  -> PASS: detected student traps count: ${pitfallRes.result.count}`);

    // 4. TRCE Annotation Synthesis & Check
    console.log('[TEST 4] Testing JSDoc TRCE annotation synthesis...');
    const unannotated = `
function processTransaction(id, amount) {
  return { id, amount };
}
`;
    const annRes = await send('annotate', { code: unannotated, prefix: 'trce-js' });
    assert.strictEqual(annRes.ok, true, 'annotate should succeed');
    assert.strictEqual(annRes.result.inserted_count, 1, 'should annotate 1 component');
    assert.strictEqual(annRes.result.annotated_text.includes('@trce-id trce-js-'), true);

    const checkRes = await send('check', { code: annRes.result.annotated_text });
    assert.strictEqual(checkRes.ok, true, 'check should succeed');
    assert.strictEqual(checkRes.result.coverage_pct, 100, 'coverage should be 100%');
    console.log('  -> PASS: synthesized JSDoc TRCE annotation and validated 100% coverage');

    // 5. Interactive VM Execution
    console.log('[TEST 5] Testing JS VM eval and workspace...');
    const evalRes = await send('eval', {
      code: `
const x = 50;
const y = 20;
console.log("Calculated:", x * y);
x * y;
`
    });
    assert.strictEqual(evalRes.ok, true, 'eval should succeed');
    assert.strictEqual(evalRes.result.entries[0].output[0], 'Calculated: 1000');
    assert.strictEqual(evalRes.result.entries[0].value_text[0], '1000');
    console.log('  -> PASS: eval executed in VM sandbox and captured output');

    console.log('\n================================================================');
    console.log('  ALL NODE.JS WORKER TESTS PASSED SUCCESSFULLY! (5/5)');
    console.log('================================================================\n');

    worker.kill();
    process.exit(0);

  } catch (err) {
    console.error('\n[FAIL] Test suite error:', err);
    worker.kill();
    process.exit(1);
  }
}
