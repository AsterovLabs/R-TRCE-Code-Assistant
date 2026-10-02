/**
 * studio/server/node_worker.js -- Polyglot TRCE Studio JavaScript/Node.js Worker Daemon
 * Copyright (c) 2026 Asterov Labs. All Rights Reserved.
 * Licensed under the Asterov Labs Proprietary Software License.
 */

const vm = require('vm');
const readline = require('readline');
const path = require('path');
const fs = require('fs');

const ROOT_DIR = path.resolve(__dirname, '..', '..');

// ============================================================================
// 1. Persistent Session State & Sandbox
// ============================================================================

let sessionWd = process.cwd();
let sessionContext = createSandbox();

function createSandbox() {
  const sandbox = {
    console: {
      log: (...args) => captureBuffer.stdout.push(args.map(formatArg).join(' ')),
      info: (...args) => captureBuffer.stdout.push(args.map(formatArg).join(' ')),
      warn: (...args) => captureBuffer.warnings.push(args.map(formatArg).join(' ')),
      error: (...args) => captureBuffer.stderr.push(args.map(formatArg).join(' '))
    },
    setTimeout,
    clearTimeout,
    setInterval,
    clearInterval,
    Buffer,
    URL,
    Math,
    Date,
    JSON,
    RegExp
  };
  return vm.createContext(sandbox);
}

const captureBuffer = {
  stdout: [],
  stderr: [],
  warnings: []
};

function formatArg(arg) {
  if (typeof arg === 'string') return arg;
  try {
    return JSON.stringify(arg, null, 2);
  } catch (e) {
    return String(arg);
  }
}

// ============================================================================
// 2. Lexical & AST Component Analysis
// ============================================================================

function parseJsCode(code, filePath = '<string>') {
  const lines = code.split(/\r?\n/);
  const components = [];
  const imports = [];
  const definedFunctions = [];
  const definedClasses = [];

  const funcDeclRe = /^(?:\s*export\s+)?(?:async\s+)?function\s+([a-zA-Z0-9_$]+)\s*\(([^)]*)\)/;
  const arrowFuncRe = /^(?:\s*export\s+)?(?:const|let|var)\s+([a-zA-Z0-9_$]+)\s*=\s*(?:async\s*)?\(([^)]*)\)\s*=>/;
  const classDeclRe = /^(?:\s*export\s+)?class\s+([a-zA-Z0-9_$]+)(?:\s+extends\s+([a-zA-Z0-9_$]+))?/;
  const methodRe = /^\s*(?:async\s+)?([a-zA-Z0-9_$]+)\s*\(([^)]*)\)\s*\{/;
  const importRe = /^(?:\s*import\s+.+from\s+['"]([^'"]+)['"]|(?:\s*const|let|var)\s+.+\s*=\s*require\(['"]([^'"]+)['"]\))/;

  lines.forEach((line, idx) => {
    const lineNum = idx + 1;

    // Imports
    const impM = line.match(importRe);
    if (impM) {
      imports.push(impM[1] || impM[2]);
    }

    // Function Declaration
    const fnM = line.match(funcDeclRe);
    if (fnM) {
      const name = fnM[1];
      definedFunctions.push(name);
      components.push({
        name,
        type: 'function',
        kind: 'function',
        start_line: lineNum,
        end_line: lineNum,
        args: fnM[2].split(',').map(s => s.trim()).filter(Boolean),
        calls: [],
        calls_local: [],
        called_by: []
      });
      return;
    }

    // Arrow Function Assignment
    const arrM = line.match(arrowFuncRe);
    if (arrM) {
      const name = arrM[1];
      definedFunctions.push(name);
      components.push({
        name,
        type: 'function',
        kind: 'arrow_function',
        start_line: lineNum,
        end_line: lineNum,
        args: arrM[2].split(',').map(s => s.trim()).filter(Boolean),
        calls: [],
        calls_local: [],
        called_by: []
      });
      return;
    }

    // Class Declaration
    const clsM = line.match(classDeclRe);
    if (clsM) {
      const name = clsM[1];
      definedClasses.push(name);
      components.push({
        name,
        type: 'class',
        kind: 'class',
        start_line: lineNum,
        end_line: lineNum,
        args: clsM[2] ? [clsM[2]] : [],
        calls: [],
        calls_local: [],
        called_by: []
      });
      return;
    }
  });

  // Archetype detection
  let archetype = 'Standard JavaScript Script / Module';
  const importStr = imports.join(' ').toLowerCase();
  const codeLower = code.toLowerCase();
  if (importStr.includes('express') || importStr.includes('fastify') || importStr.includes('koa')) {
    archetype = 'HTTP Web API & Server Controller';
  } else if (importStr.includes('react') || importStr.includes('vue') || importStr.includes('svelte')) {
    archetype = 'Frontend Component / Reactive UI Module';
  } else if (codeLower.includes('process.argv') || importStr.includes('commander') || importStr.includes('yargs')) {
    archetype = 'CLI Command Runner & Automation Script';
  }

  return {
    file: filePath,
    line_count: lines.length,
    component_count: components.length,
    components,
    imports: Array.from(new Set(imports)),
    functions: definedFunctions,
    classes: definedClasses,
    archetype,
    file_type: archetype,
    raw_lines: lines
  };
}

// ============================================================================
// 3. JavaScript Student Pitfalls Sentinel
// ============================================================================

function detectJsPitfalls(code) {
  const traps = [];
  const lines = code.split(/\r?\n/);

  lines.forEach((line, idx) => {
    const lineNum = idx + 1;
    const trimmed = line.trim();
    if (trimmed.startsWith('//') || trimmed.startsWith('*') || trimmed.startsWith('/*')) {
      return;
    }

    // Trap 1: Loose equality (== or !=)
    if (/[^=!><]==[^=]/.test(line) || /!=[^=]/.test(line)) {
      traps.append = traps.push({
        id: 'js-trap-loose-equality',
        name: 'Loose Equality Operator',
        severity: 'critical',
        line: lineNum,
        code: trimmed,
        title: "Use strict equality ('===' or '!==') instead of loose ('==' or '!=')",
        explanation: "Loose equality performs implicit type coercion (e.g., 0 == '' is true, null == undefined is true). This causes subtle logical bugs that are difficult to trace.",
        recommendation: "Replace '==' with '===' and '!=' with '!=='.",
        replacement: line.replace(/==(?!=)/g, '===').replace(/!=(?!=)/g, '!==').trim()
      });
    }

    // Trap 2: var declaration (hoisting danger)
    if (/\bvar\s+([a-zA-Z0-9_$]+)/.test(line)) {
      traps.push({
        id: 'js-trap-var-declaration',
        name: 'Legacy var Keyword (Hoisting)',
        severity: 'warning',
        line: lineNum,
        code: trimmed,
        title: "Legacy 'var' is function-scoped and hoisted",
        explanation: "'var' ignores block scoping (like inside 'if' and 'for' blocks), leading to variable leaks and overwrites across scopes.",
        recommendation: "Use 'const' for immutable values or 'let' for variables re-assigned later.",
        replacement: line.replace(/\bvar\s+/, 'const ').trim()
      });
    }

    // Trap 3: NaN equality trap (x === NaN)
    if (/===\s*NaN\b|\bNaN\s*===/.test(line)) {
      traps.push({
        id: 'js-trap-nan-comparison',
        name: 'Direct NaN Comparison',
        severity: 'critical',
        line: lineNum,
        code: trimmed,
        title: 'NaN is not equal to itself in IEEE 754 float arithmetic',
        explanation: "In JavaScript, NaN === NaN evaluates to false. Any comparison directly checking '=== NaN' will never succeed.",
        recommendation: 'Use Number.isNaN(x) to test whether a value is NaN.',
        replacement: 'Number.isNaN(val)'
      });
    }

    // Trap 4: Direct floating-point comparison (e.g. 0.1 + 0.2 === 0.3)
    if (/(?:0\.1\s*\+\s*0\.2\s*===|\+\s*0\.\d+\s*===)/.test(line)) {
      traps.push({
        id: 'js-trap-float-precision',
        name: 'Floating Point Precision Trap',
        severity: 'warning',
        line: lineNum,
        code: trimmed,
        title: 'Binary floating-point arithmetic precision limitation',
        explanation: 'Due to IEEE 754 64-bit float representation, 0.1 + 0.2 equals 0.30000000000000004. Strict comparison fails.',
        recommendation: 'Compare difference with Number.EPSILON: Math.abs(a - b) < Number.EPSILON.',
        replacement: 'Math.abs(a - b) < Number.EPSILON'
      });
    }

    // Trap 5: Accidental global variable (e.g. x = 10 without const/let)
    if (/^[a-zA-Z0-9_$]+\s*=\s*[^=]/.test(trimmed) && !/^(?:this\.|window\.|global\.)/.test(trimmed)) {
      traps.push({
        id: 'js-trap-undeclared-assignment',
        name: 'Implicit Global Assignment',
        severity: 'warning',
        line: lineNum,
        code: trimmed,
        title: 'Variable assigned without let, const, or var',
        explanation: 'Assigning to an undeclared identifier leaks into the global namespace in non-strict mode, polluting application state.',
        recommendation: "Prepend 'const ' or 'let ' to explicitly declare variable scope.",
        replacement: `const ${trimmed}`
      });
    }
  });

  return traps;
}

// ============================================================================
// 4. TRCE 6-Point Annotation Synthesizer & Validator
// ============================================================================

const TRCE_ID_PATTERN = /^trce-[a-z0-9]+(?:-[a-z0-9]+)*-[0-9]+$/;

function extractTrceBlocksJs(code) {
  const blocks = [];
  const lines = code.split(/\r?\n/);

  let inBlock = false;
  let currentBlock = null;

  lines.forEach((line, idx) => {
    const lineNum = idx + 1;
    if (line.includes('/**') || line.includes('/*')) {
      inBlock = true;
      currentBlock = { line: lineNum, fields: {} };
    }

    if (inBlock && currentBlock) {
      const idM = line.match(/@trce-id\s+([a-zA-Z0-9_\-]+)/);
      if (idM) currentBlock.fields.id = idM[1];
      const whoM = line.match(/@trce-who\s+(.+)/);
      if (whoM) currentBlock.fields.who = whoM[1].trim();
      const whatM = line.match(/@trce-what\s+(.+)/);
      if (whatM) currentBlock.fields.what = whatM[1].trim();
      const whereM = line.match(/@trce-where\s+(.+)/);
      if (whereM) currentBlock.fields.where = whereM[1].trim();
      const whenM = line.match(/@trce-when\s+(.+)/);
      if (whenM) currentBlock.fields.when = whenM[1].trim();
      const whyM = line.match(/@trce-why\s+(.+)/);
      if (whyM) currentBlock.fields.why = whyM[1].trim();
      const howM = line.match(/@trce-how\s+(.+)/);
      if (howM) currentBlock.fields.how = howM[1].trim();
    }

    if (line.includes('*/')) {
      if (inBlock && currentBlock && currentBlock.fields.id) {
        currentBlock.id = currentBlock.fields.id;
        blocks.push(currentBlock);
      }
      inBlock = false;
      currentBlock = null;
    }
  });

  return blocks;
}

function validateJsAnnotations(code, filePath = '<string>') {
  const parsed = parseJsCode(code, filePath);
  const blocks = extractTrceBlocksJs(code);

  const errors = [];
  const duplicates = [];
  const seenIds = new Set();

  blocks.forEach(b => {
    const tid = b.id;
    if (!tid || !TRCE_ID_PATTERN.test(tid)) {
      errors.push(`Invalid trace ID format: '${tid}' at line ${b.line}`);
    }
    if (seenIds.has(tid)) {
      duplicates.push(tid);
    } else {
      seenIds.add(tid);
    }

    const missingFields = [];
    ['who', 'what', 'where', 'when', 'why', 'how'].forEach(f => {
      if (!b.fields[f]) missingFields.push(f);
    });
    if (missingFields.length > 0) {
      errors.push(`Trace '${tid}' missing 6-point field(s): ${missingFields.join(', ')}`);
    }
  });

  const compCount = parsed.component_count;
  const annotatedCount = blocks.length;
  const covPct = compCount === 0 ? 100 : Math.min(100, Math.floor((annotatedCount / compCount) * 100));

  return {
    valid: errors.length === 0 && duplicates.length === 0 && (compCount === 0 || covPct >= 100),
    component_count: compCount,
    annotated_count: annotatedCount,
    coverage_pct: covPct,
    missing: parsed.components.filter(c => !blocks.some(b => b.fields.where?.includes(c.name))).map(c => c.name),
    duplicates,
    errors,
    traces: blocks
  };
}

function synthesizeJsAnnotations(code, filePath = '<string>', prefix = 'trce-js') {
  const lines = code.split(/\r?\n/);
  const parsed = parseJsCode(code, filePath);

  let counter = 1;
  const idMatches = code.match(/@trce-id\s+trce-[a-z0-9\-]+-(\d+)/g) || [];
  idMatches.forEach(m => {
    const num = parseInt(m.split('-').pop(), 10);
    if (num >= counter) counter = num + 1;
  });

  const targets = parsed.components.filter(c => {
    // Check if lines preceding c.start_line have @trce-id
    const startIdx = c.start_line - 1;
    let hasAnnotation = false;
    for (let i = Math.max(0, startIdx - 10); i < startIdx; i++) {
      if (lines[i].includes('@trce-id')) {
        hasAnnotation = true;
        break;
      }
    }
    return !hasAnnotation;
  });

  if (targets.length === 0) {
    return {
      original_text: code,
      annotated_text: code,
      inserted_count: 0,
      trace_ids: []
    };
  }

  // Insert in reverse line order
  targets.sort((a, b) => b.start_line - a.start_line);
  const generatedIds = [];

  targets.forEach(target => {
    const traceId = `${prefix}-${String(counter++).padStart(3, '0')}`;
    generatedIds.push(traceId);

    const targetIdx = target.start_line - 1;
    const targetLine = lines[targetIdx];
    const indentMatch = targetLine.match(/^(\s*)/);
    const indent = indentMatch ? indentMatch[1] : '';

    const docblock = [
      `${indent}/**`,
      `${indent} * @trce-id ${traceId}`,
      `${indent} * @trce-who System Subsystem / ${target.name}`,
      `${indent} * @trce-what Performs ${target.name} execution`,
      `${indent} * @trce-where ${path.basename(filePath)} -> ${target.name}()`,
      `${indent} * @trce-when Invoked during application runtime pipeline`,
      `${indent} * @trce-why Implements validated ${target.name} domain capability`,
      `${indent} * @trce-how Evaluates function logic and returns structured result`,
      `${indent} */`
    ].join('\n');

    lines.splice(targetIdx, 0, docblock);
  });

  const annotatedText = lines.join('\n');
  return {
    original_text: code,
    annotated_text: annotatedText,
    inserted_count: generatedIds.length,
    trace_ids: generatedIds
  };
}

// ============================================================================
// 5. Interactive Node.js VM Evaluation & Workspace Inspector
// ============================================================================

function evaluateJsCode(code, timeout = 10, wd = sessionWd) {
  if (wd && fs.existsSync(wd)) {
    sessionWd = wd;
  }

  captureBuffer.stdout = [];
  captureBuffer.stderr = [];
  captureBuffer.warnings = [];

  let resultVal = undefined;
  let errorMsg = null;

  try {
    const script = new vm.Script(code);
    resultVal = script.runInContext(sessionContext, {
      timeout: timeout * 1000
    });
  } catch (err) {
    errorMsg = err.stack || err.message;
  }

  const outputLines = [...captureBuffer.stdout];
  if (captureBuffer.stderr.length > 0) {
    outputLines.push(...captureBuffer.stderr.map(l => `[stderr] ${l}`));
  }

  const valueText = [];
  let valueClass = null;
  if (resultVal !== undefined) {
    valueClass = typeof resultVal;
    valueText.push(formatArg(resultVal));
  }

  const workspace = inspectJsWorkspace();

  return {
    ok: errorMsg === null,
    incomplete: false,
    entries: [{
      code,
      output: outputLines,
      messages: [],
      warnings: captureBuffer.warnings,
      error: errorMsg,
      value_text: valueText,
      value_class: valueClass,
      value_length: valueText.length > 0 ? 1 : null,
      plot_file: null
    }],
    plots: [],
    workspace,
    wd: sessionWd
  };
}

function inspectJsWorkspace() {
  const ignored = new Set([
    'console', 'setTimeout', 'clearTimeout', 'setInterval', 'clearInterval',
    'Buffer', 'URL', 'Math', 'Date', 'JSON', 'RegExp'
  ]);
  const items = [];

  for (const [k, v] of Object.entries(sessionContext)) {
    if (ignored.has(k) || k.startsWith('_')) continue;
    const type = typeof v;
    let preview = formatArg(v);
    if (preview.length > 60) preview = preview.slice(0, 57) + '...';

    items.push({
      name: k,
      type,
      class: type,
      size: `${JSON.stringify(v)?.length || 32} bytes`,
      preview
    });
  }

  return items.sort((a, b) => a.name.localeCompare(b.name));
}

// ============================================================================
// 6. Request Router & stdio JSON-RPC Dispatcher
// ============================================================================

function generateJsQuiz(code) {
  const parsed = parseJsCode(code);
  const funcs = parsed.functions || [];
  const classes = parsed.classes || [];
  const questions = [];
  let qId = 1;

  if (funcs.length > 0) {
    const fnName = funcs[0];
    const comp = parsed.components.find(c => c.name === fnName);
    const args = comp?.args || [];
    const argsStr = args.length > 0 ? args.join(', ') : 'no parameters';

    questions.push({
      id: qId++,
      question: `In this JavaScript script, what parameters does '${fnName}()' accept?`,
      options: [
        `Accepts parameters: (${argsStr})`,
        'Accepts arbitrary arguments via arguments object only',
        'Takes no parameters and reads from window directly',
        'Requires an ArrayBuffer as its sole argument'
      ],
      correct_index: 0,
      explanation: `'${fnName}' is declared with parameters: (${argsStr}).`
    });
  }

  if (classes.length > 0) {
    const clsName = classes[0];
    questions.push({
      id: qId++,
      question: `What structural paradigm does '${clsName}' represent?`,
      options: [
        'An ES6 Class with constructor and prototype methods',
        'A legacy jQuery selector plugin',
        'A stateless functional component with hooks',
        'A WebAssembly compiled module'
      ],
      correct_index: 0,
      explanation: `'${clsName}' defines an ES6 Class structure managing instance lifecycle and methods.`
    });
  }

  questions.push({
    id: qId++,
    question: 'Why should strict equality (===) be preferred over loose equality (==) in modern JavaScript?',
    options: [
      'Strict equality checks both value and type without implicit coercion (e.g. 0 !== "")',
      'Strict equality converts all operands to strings before comparing',
      'Loose equality is faster because it bypasses engine type checks',
      'Strict equality only works on primitive numbers'
    ],
    correct_index: 0,
    explanation: 'Strict equality (===) prevents unexpected type coercions (like 0 == "" or null == undefined) and avoids subtle runtime logic bugs.'
  });

  return questions;
}

function handleAction(action, payload) {
  switch (action) {
    case 'ping':
      return {
        pong: true,
        version: process.version,
        language: 'javascript',
        root_dir: ROOT_DIR,
        pid: process.pid
      };

    case 'parse':
    case 'analyze':
      return parseJsCode(payload.code || '', payload.file || '<string>');

    case 'pitfalls':
      const traps = detectJsPitfalls(payload.code || '');
      return { count: traps.length, traps };

    case 'quiz':
      return generateJsQuiz(payload.code || '');

    case 'annotate':
      return synthesizeJsAnnotations(payload.code || '', payload.file || '<string>', payload.prefix || 'trce-js');

    case 'check':
      return validateJsAnnotations(payload.code || '', payload.file || '<string>');

    case 'eval':
      return evaluateJsCode(payload.code || '', payload.timeout || 10, payload.wd || sessionWd);

    case 'workspace':
      return { workspace: inspectJsWorkspace(), count: Object.keys(sessionContext).length };

    case 'reset_session':
      sessionContext = createSandbox();
      return { reset: true, message: 'JavaScript session reset successfully' };

    case 'open_project':
      if (payload.path && fs.existsSync(payload.path)) {
        sessionWd = payload.path;
        return { ok: true, path: payload.path };
      }
      return { ok: false, error: `Invalid directory: ${payload.path}` };

    default:
      throw new Error(`Unknown JavaScript worker action: '${action}'`);
  }
}

const rl = readline.createInterface({
  input: process.stdin,
  terminal: false
});

// Handshake
process.stdout.write(JSON.stringify({
  event: 'ready',
  pid: process.pid,
  version: process.version,
  language: 'javascript'
}) + '\n');

rl.on('line', (line) => {
  line = line.trim();
  if (!line) return;

  let msg;
  try {
    msg = JSON.parse(line);
  } catch (err) {
    process.stdout.write(JSON.stringify({ ok: false, error: err.message }) + '\n');
    return;
  }

  const { id, action, payload } = msg;
  try {
    const result = handleAction(action, payload || {});
    process.stdout.write(JSON.stringify({ id, ok: true, result }) + '\n');
  } catch (err) {
    process.stdout.write(JSON.stringify({ id, ok: false, error: err.message }) + '\n');
  }
});
