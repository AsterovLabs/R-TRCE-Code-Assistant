/**
 * studio/server/test_worker.js -- Verification Suite for R Worker Daemon
 */

const { spawn } = require('child_process');
const path = require('path');
const readline = require('readline');
const assert = require('assert');

const ROOT_DIR = path.resolve(__dirname, '..', '..');
const WORKER_SCRIPT = path.join(__dirname, 'r_worker.R');

console.log('[TEST] Starting R Worker verification suite...');

const worker = spawn('Rscript', [WORKER_SCRIPT], {
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
  const id = `test-${++reqCounter}`;
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
    console.log(`[TEST] R Worker ready (PID ${msg.pid}, R version: ${msg.r_version})`);
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

    // 2. Parse code
    console.log('[TEST 2] Testing parse...');
    const sampleCode = 'calc_sum <- function(a, b) {\n  return(a + b)\n}\n';
    const parseRes = await send('parse', { code: sampleCode });
    assert.strictEqual(parseRes.ok, true, 'parse should succeed');
    assert.strictEqual(parseRes.result.component_count >= 1, true, 'at least 1 component');
    console.log('  -> PASS: parse extracted components:', parseRes.result.component_count);

    // 3. Analyze sample file
    console.log('[TEST 3] Testing analyze on samples/01_shiny_app.R...');
    const shinySample = path.join(ROOT_DIR, 'samples', '01_shiny_app.R');
    const analyzeRes = await send('analyze', { file: shinySample });
    assert.strictEqual(analyzeRes.ok, true, 'analyze should succeed');
    assert.strictEqual(analyzeRes.result.archetype.includes('Shiny'), true, 'should detect Shiny');
    console.log('  -> PASS: analyze detected archetype:', analyzeRes.result.archetype);

    // 4. Validate TRCE annotations
    console.log('[TEST 4] Testing check on r_worker.R...');
    const checkRes = await send('check', { file: WORKER_SCRIPT });
    assert.strictEqual(checkRes.ok, true, 'check should succeed');
    assert.strictEqual(checkRes.result.coverage_pct, 100.0, 'coverage should be 100%');
    console.log('  -> PASS: check confirmed coverage:', checkRes.result.coverage_pct + '%');

    // 5. Evaluate code & capture workspace
    console.log('[TEST 5] Testing eval (console execution & workspace capture)...');
    const evalRes = await send('eval', { code: 'my_var <- 100 * 2; print(my_var)' });
    console.log('  -> evalRes:', JSON.stringify(evalRes, null, 2));
    const stdoutEntry = evalRes.result.entries[1]?.output || '';
    const outputStr = Array.isArray(stdoutEntry) ? stdoutEntry.join('\n') : String(stdoutEntry);
    assert.strictEqual(outputStr.includes('200'), true, 'should capture print output 200');
    console.log('  -> PASS: eval executed and captured output');

    // 6. Plot generation
    console.log('[TEST 6] Testing eval with graphics plot generation...');
    const plotRes = await send('eval', { code: 'plot(1:5, 1:5)' });
    assert.strictEqual(plotRes.ok, true, 'plot eval should succeed');
    assert.strictEqual(plotRes.result.plots.length >= 1, true, 'should capture generated plot');
    assert.strictEqual(plotRes.result.plots[0].data_uri.startsWith('data:image/png;base64,'), true, 'plot must be base64 PNG');
    console.log('  -> PASS: plot captured as inline base64 URI');

    // 7. Pitfalls detection
    console.log('[TEST 7] Testing pitfalls on samples/05_student_traps.R...');
    const trapsSample = path.join(ROOT_DIR, 'samples', '05_student_traps.R');
    const pitfallsRes = await send('pitfalls', { file: trapsSample });
    assert.strictEqual(pitfallsRes.ok, true, 'pitfalls should succeed');
    assert.strictEqual(pitfallsRes.result.pitfall_count >= 5, true, 'traps detected');
    console.log('  -> PASS: detected student traps count:', pitfallsRes.result.pitfall_count);

    // 8. Annotate action
    console.log('[TEST 8] Testing annotate (6-point TRCE synthesis & injection)...');
    const testRCode = 'calculate_mean <- function(x) {\n  sum(x) / length(x)\n}\n';
    const annotateRes = await send('annotate', { code: testRCode, prefix: 'trce-mean', style: 'jsdoc' });
    assert.strictEqual(annotateRes.ok, true, 'annotate should succeed');
    assert.strictEqual(annotateRes.result.inserted_count >= 1, true, 'should insert annotations');
    assert.strictEqual(annotateRes.result.annotated_text.includes('@trce-id'), true, 'annotated text must contain @trce-id');
    console.log('  -> PASS: annotate synthesized and injected doc-comments (inserted:', annotateRes.result.inserted_count, ')');

    console.log('\n================================================================');
    console.log('  ALL R WORKER TESTS PASSED SUCCESSFULLY! (8/8)');
    console.log('================================================================');
    process.exit(0);
  } catch (err) {
    console.error('\n[TEST FAILED]:', err);
    process.exit(1);
  }
}
