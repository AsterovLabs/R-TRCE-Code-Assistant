/**
 * studio/server/test_py_worker.js -- Verification Suite for Python Worker Daemon
 */

const { spawn } = require('child_process');
const path = require('path');
const readline = require('readline');
const assert = require('assert');

const ROOT_DIR = path.resolve(__dirname, '..', '..');
const WORKER_SCRIPT = path.join(__dirname, 'py_worker.py');

console.log('[TEST] Starting Python Worker verification suite...');

const worker = spawn('python3', [WORKER_SCRIPT], {
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
  const id = `test-py-${++reqCounter}`;
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
    console.log(`[TEST] Python Worker ready (PID ${msg.pid}, version: ${msg.version.split(' ')[0]})`);
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
    console.log('[TEST 2] Testing parse on Python functions & classes...');
    const sampleCode = `
import math
import sys

def compute_distance(x1, y1, x2, y2):
    dx = x2 - x1
    dy = y2 - y1
    return math.sqrt(dx*dx + dy*dy)

class Point:
    def __init__(self, x, y):
        self.x = x
        self.y = y
`;
    const parseRes = await send('parse', { code: sampleCode });
    assert.strictEqual(parseRes.ok, true, 'parse should succeed');
    assert.strictEqual(parseRes.result.component_count, 3, 'should extract 3 components (compute_distance, Point, __init__)');
    console.log(`  -> PASS: parse extracted components: ${parseRes.result.component_count}`);

    // 3. Archetype Analysis
    console.log('[TEST 3] Testing archetype classification...');
    const dsCode = `
import pandas as pd
import numpy as np

def process_data(df):
    return df.dropna()
`;
    const analyzeRes = await send('analyze', { code: dsCode });
    assert.strictEqual(analyzeRes.ok, true, 'analyze should succeed');
    assert.strictEqual(analyzeRes.result.archetype, 'Data Pipeline & Analytics Script');
    console.log(`  -> PASS: detected archetype: ${analyzeRes.result.archetype}`);

    // 4. Student Pitfalls Sentinel
    console.log('[TEST 4] Testing Python pitfall detection...');
    const trapCode = `
def bad_defaults(item, cache=[]):
    cache.append(item)
    return cache

def bad_identity(val):
    if val == None:
        return True
    return False

def bad_shadow():
    list = [1, 2, 3]
    return list

def off_by_one(items):
    last = items[len(items)]
    return last

def bad_except():
    try:
        x = 1 / 0
    except:
        pass
`;
    const pitfallRes = await send('pitfalls', { code: trapCode });
    assert.strictEqual(pitfallRes.ok, true, 'pitfalls should succeed');
    assert.strictEqual(pitfallRes.result.count >= 5, true, `should detect at least 5 traps (found ${pitfallRes.result.count})`);
    console.log(`  -> PASS: detected student traps count: ${pitfallRes.result.count}`);

    // 5. TRCE 6-Point Annotation Synthesizer
    console.log('[TEST 5] Testing TRCE annotation synthesis...');
    const unannotatedCode = `
def calculate_kpi(revenue, cost):
    return revenue - cost

class MetricTracker:
    def log(self, val):
        pass
`;
    const annotateRes = await send('annotate', { code: unannotatedCode, prefix: 'trce-py' });
    assert.strictEqual(annotateRes.ok, true, 'annotate should succeed');
    assert.strictEqual(annotateRes.result.inserted_count >= 2, true, 'should annotate at least 2 components');
    assert.strictEqual(annotateRes.result.annotated_text.includes('@trce-id trce-py-'), true);
    assert.strictEqual(annotateRes.result.annotated_text.includes('@trce-who'), true);
    console.log(`  -> PASS: synthesized and injected ${annotateRes.result.inserted_count} TRCE docstrings`);

    // 6. TRCE Check
    console.log('[TEST 6] Testing TRCE validation on annotated code...');
    const checkRes = await send('check', { code: annotateRes.result.annotated_text });
    assert.strictEqual(checkRes.ok, true, 'check should succeed');
    assert.strictEqual(checkRes.result.valid, true, 'annotated code should pass validation');
    assert.strictEqual(checkRes.result.coverage_pct, 100, 'coverage should be 100%');
    console.log(`  -> PASS: check confirmed coverage: ${checkRes.result.coverage_pct}%`);

    // 7. Interactive REPL Evaluation & Workspace
    console.log('[TEST 7] Testing Python REPL eval and workspace inspection...');
    const evalRes = await send('eval', {
      code: `
a = 15
b = 30
total = a + b
print(f"Total is {total}")
total * 2
`
    });
    assert.strictEqual(evalRes.ok, true, 'eval should succeed');
    assert.strictEqual(evalRes.result.entries[0].output[0], 'Total is 45');
    assert.strictEqual(evalRes.result.entries[0].value_text[0], '90');
    assert.strictEqual(evalRes.result.workspace.some(w => w.name === 'total' && w.preview === '45'), true);
    console.log('  -> PASS: eval executed, captured stdout, returned value_text, and recorded workspace');

    // 8. Session Reset
    console.log('[TEST 8] Testing session reset...');
    const resetRes = await send('reset_session');
    assert.strictEqual(resetRes.ok, true, 'reset should succeed');
    const wsRes = await send('workspace');
    assert.strictEqual(wsRes.result.workspace.some(w => w.name === 'total'), false, 'workspace should be empty');
    console.log('  -> PASS: session reset cleared user variables');

    console.log('\n================================================================');
    console.log('  ALL PYTHON WORKER TESTS PASSED SUCCESSFULLY! (8/8)');
    console.log('================================================================\n');

    worker.kill();
    process.exit(0);

  } catch (err) {
    console.error('\n[FAIL] Test suite error:', err);
    worker.kill();
    process.exit(1);
  }
}
