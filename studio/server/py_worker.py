#!/usr/bin/env python3
"""
studio/server/py_worker.py -- Polyglot TRCE Studio Python Worker Daemon
Copyright (c) 2026 Asterov Labs. All Rights Reserved.
Licensed under the Asterov Labs Proprietary Software License.

Provides AST parsing, archetype analysis, 6-point TRCE telemetry synthesis,
student pitfall auditing, interactive REPL execution, workspace inspection,
and graphics plot capture for the Python language.
"""

import sys
import os
import io
import ast
import json
import re
import traceback
import base64
import contextlib

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# Persistent session state
session_globals = {
    "__name__": "__main__",
    "__doc__": None,
    "__package__": None,
}
session_wd = os.getcwd()


# ============================================================================
# 1. AST Analysis & Component Extraction
# ============================================================================

def parse_python_code(code, file_path="<string>"):
    lines = code.splitlines(keepends=True)
    try:
        tree = ast.parse(code, filename=file_path)
    except SyntaxError as e:
        return {
            "error": f"SyntaxError at line {e.lineno}, col {e.offset}: {e.msg}",
            "lineno": e.lineno,
            "col": e.offset,
            "raw_lines": [line.rstrip("\r\n") for line in lines]
        }

    components = []
    imports = []
    defined_functions = []
    defined_classes = []
    call_map = {}

    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                imports.append(alias.name)
        elif isinstance(node, ast.ImportFrom):
            mod = node.module or ""
            for alias in node.names:
                imports.append(f"{mod}.{alias.name}" if mod else alias.name)
        elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            defined_functions.append(node.name)
            args = [a.arg for a in node.args.args]
            # Calls inside function
            calls = []
            for child in ast.walk(node):
                if isinstance(child, ast.Call):
                    if isinstance(child.func, ast.Name):
                        calls.append(child.func.id)
                    elif isinstance(child.func, ast.Attribute):
                        calls.append(child.func.attr)
            calls = sorted(list(set(calls)))
            call_map[node.name] = calls

            components.append({
                "name": node.name,
                "type": "function",
                "kind": "async_function" if isinstance(node, ast.AsyncFunctionDef) else "function",
                "start_line": node.lineno,
                "end_line": getattr(node, "end_lineno", node.lineno),
                "args": args,
                "calls": calls,
                "calls_local": [],
                "called_by": []
            })
        elif isinstance(node, ast.ClassDef):
            defined_classes.append(node.name)
            components.append({
                "name": node.name,
                "type": "class",
                "kind": "class",
                "start_line": node.lineno,
                "end_line": getattr(node, "end_lineno", node.lineno),
                "args": [getattr(b, "id", getattr(b, "attr", "object")) for b in node.bases],
                "calls": [],
                "calls_local": [],
                "called_by": []
            })

    # Resolve local caller-callee links
    all_names = set(c["name"] for c in components)
    for c in components:
        c["calls_local"] = [call for call in c.get("calls", []) if call in all_names]
        c["called_by"] = [other["name"] for other in components if c["name"] in other.get("calls", [])]

    # Archetype detection
    archetype = "Standard Python Module"
    import_str = " ".join(imports).lower()
    if any(lib in import_str for lib in ["pandas", "numpy", "polars", "pyarrow"]):
        archetype = "Data Pipeline & Analytics Script"
    elif any(lib in import_str for lib in ["torch", "tensorflow", "sklearn", "keras", "xgboost"]):
        archetype = "Machine Learning / Predictive Model"
    elif any(lib in import_str for lib in ["fastapi", "flask", "django", "tornado", "starlette"]):
        archetype = "Web Service & API Controller"
    elif any(lib in import_str for lib in ["matplotlib", "seaborn", "plotly", "altair"]):
        archetype = "Data Visualization & Plotting Pipeline"
    elif any(lib in import_str for lib in ["argparse", "click", "typer", "sys"]):
        archetype = "CLI Command Runner & Automation Script"

    return {
        "file": file_path,
        "line_count": len(lines),
        "component_count": len(components),
        "components": components,
        "imports": sorted(list(set(imports))),
        "functions": defined_functions,
        "classes": defined_classes,
        "archetype": archetype,
        "file_type": archetype,
        "raw_lines": [line.rstrip("\r\n") for line in lines]
    }


# ============================================================================
# 2. Python Student Pitfall Sentinel
# ============================================================================

PYTHON_BUILTINS = {
    "list", "dict", "set", "str", "int", "float", "bool", "tuple",
    "type", "id", "sum", "min", "max", "input", "open", "range",
    "len", "format", "filter", "map", "zip", "dir", "help"
}

def detect_python_pitfalls(code):
    traps = []
    lines = code.splitlines()

    try:
        tree = ast.parse(code)
    except SyntaxError as e:
        return [
            {
                "id": "py-trap-syntax",
                "name": "Syntax Error",
                "severity": "critical",
                "line": e.lineno or 1,
                "code": lines[e.lineno - 1] if e.lineno and e.lineno <= len(lines) else "",
                "title": f"Syntax Error: {e.msg}",
                "explanation": "Python encountered an invalid statement structure that stops execution immediately.",
                "recommendation": "Check for missing colons (:), unclosed brackets, or indentation mismatches.",
                "replacement": ""
            }
        ]

    for node in ast.walk(tree):
        # Trap 1: Mutable Default Argument (def foo(x=[]))
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            for default in node.args.defaults + node.args.kw_defaults:
                if default is not None and isinstance(default, (ast.List, ast.Dict, ast.Set)):
                    def_str = "[]" if isinstance(default, ast.List) else ("{}" if isinstance(default, ast.Dict) else "set()")
                    traps.append({
                        "id": "py-trap-mutable-default",
                        "name": "Mutable Default Argument",
                        "severity": "critical",
                        "line": default.lineno,
                        "code": lines[default.lineno - 1] if default.lineno <= len(lines) else "",
                        "title": f"Dangerous mutable default argument '{def_str}' in function '{node.name}'",
                        "explanation": "Default argument expressions are evaluated once when the function is defined, NOT each time it is called. Modifying this argument will retain mutations across all subsequent calls!",
                        "recommendation": "Use None as the default value and initialize the mutable object inside the function body.",
                        "replacement": "def " + node.name + "(..., arg=None):\n    if arg is None:\n        arg = " + def_str
                    })

        # Trap 2: Identity vs Equality (x == None or x == True)
        if isinstance(node, ast.Compare):
            for op, comp in zip(node.ops, node.comparators):
                if isinstance(op, (ast.Eq, ast.NotEq)):
                    if isinstance(comp, ast.Constant) and comp.value is None:
                        is_neg = isinstance(op, ast.NotEq)
                        traps.append({
                            "id": "py-trap-identity-none",
                            "name": "Equality check with None",
                            "severity": "warning",
                            "line": node.lineno,
                            "code": lines[node.lineno - 1] if node.lineno <= len(lines) else "",
                            "title": "Use 'is None' or 'is not None' instead of '==' / '!='",
                            "explanation": "None is a singleton in Python. The '==' operator can be overridden by class __eq__ methods, whereas 'is' tests for exact object identity and is faster and safer.",
                            "recommendation": f"Replace with 'is {'not ' if is_neg else ''}None'.",
                            "replacement": f"is {'not ' if is_neg else ''}None"
                        })
                    elif isinstance(comp, ast.Constant) and isinstance(comp.value, bool):
                        traps.append({
                            "id": "py-trap-equality-bool",
                            "name": "Explicit comparison with Boolean constant",
                            "severity": "advisory",
                            "line": node.lineno,
                            "code": lines[node.lineno - 1] if node.lineno <= len(lines) else "",
                            "title": f"Redundant comparison with Boolean literal '{comp.value}'",
                            "explanation": "Comparing directly to True or False (e.g. `if condition == True:`) is redundant and considered un-idiomatic in Python.",
                            "recommendation": "Use `if condition:` or `if not condition:` directly.",
                            "replacement": "if condition:"
                        })

        # Trap 3: Shadowing Builtin Functions (e.g. list = [1, 2, 3])
        if isinstance(node, ast.Assign):
            for target in node.targets:
                if isinstance(target, ast.Name) and target.id in PYTHON_BUILTINS:
                    traps.append({
                        "id": "py-trap-shadow-builtin",
                        "name": "Shadowing Built-in Identifier",
                        "severity": "critical",
                        "line": target.lineno,
                        "code": lines[target.lineno - 1] if target.lineno <= len(lines) else "",
                        "title": f"Variable shadows built-in Python function '{target.id}'",
                        "explanation": f"Naming a variable '{target.id}' masks the global Python built-in of the same name. Subsequent attempts to call {target.id}() will fail with TypeError: '{type(target.id).__name__}' object is not callable.",
                        "recommendation": f"Rename this variable to '{target.id}_list', '{target.id}_val', or a domain-specific name.",
                        "replacement": f"{target.id}_items"
                    })

        # Trap 4: Bare Except Clause (except:)
        if isinstance(node, ast.ExceptHandler):
            if node.type is None:
                traps.append({
                    "id": "py-trap-bare-except",
                    "name": "Bare Except Clause",
                    "severity": "warning",
                    "line": node.lineno,
                    "code": lines[node.lineno - 1] if node.lineno <= len(lines) else "",
                    "title": "Bare 'except:' catches system signals and interrupts",
                    "explanation": "A bare 'except:' catches BaseException, which includes KeyboardInterrupt (Ctrl+C) and SystemExit. This makes it impossible to terminate runaway scripts cleanly.",
                    "recommendation": "Catch specific exceptions like 'except ValueError:' or at minimum 'except Exception:'.",
                    "replacement": "except Exception as e:"
                })

        # Trap 5: Modifying list while iterating (for x in lst: lst.remove(x))
        if isinstance(node, ast.For):
            if isinstance(node.iter, ast.Name):
                loop_var = node.iter.id
                for sub in ast.walk(node):
                    if isinstance(sub, ast.Call) and isinstance(sub.func, ast.Attribute):
                        if isinstance(sub.func.value, ast.Name) and sub.func.value.id == loop_var:
                            if sub.func.attr in ("remove", "pop", "append", "extend"):
                                traps.append({
                                    "id": "py-trap-modify-while-iter",
                                    "name": "Mutation During Iteration",
                                    "severity": "critical",
                                    "line": sub.lineno,
                                    "code": lines[sub.lineno - 1] if sub.lineno <= len(lines) else "",
                                    "title": f"Modifying sequence '{loop_var}' during 'for' loop iteration",
                                    "explanation": f"Altering the size of '{loop_var}' while iterating causes Python's internal index pointer to skip items or loop unpredictably.",
                                    "recommendation": f"Iterate over a copy: 'for item in {loop_var}.copy():' or use a list comprehension.",
                                    "replacement": f"for item in {loop_var}.copy():"
                                })

        # Trap 6: Unclosed resource (calling open() outside with statement)
        if isinstance(node, ast.Call):
            if isinstance(node.func, ast.Name) and node.func.id == "open":
                # Check if parent is With
                parent_is_with = False
                for parent in ast.walk(tree):
                    if isinstance(parent, ast.With):
                        for item in parent.items:
                            if item.context_expr == node:
                                parent_is_with = True
                                break
                if not parent_is_with:
                    traps.append({
                        "id": "py-trap-unclosed-file",
                        "name": "Resource Leak (Unmanaged open())",
                        "severity": "advisory",
                        "line": node.lineno,
                        "code": lines[node.lineno - 1] if node.lineno <= len(lines) else "",
                        "title": "File opened without 'with' context manager",
                        "explanation": "Opening files without a 'with' block risks file descriptor leaks if exceptions occur before close() is called.",
                        "recommendation": "Use 'with open(...) as f:' for guaranteed deterministic cleanup.",
                        "replacement": "with open(path) as f:\n    data = f.read()"
                    })

    # Line-level checks (e.g. 0-indexing confusion check)
    for i, line in enumerate(lines, start=1):
        stripped = line.strip()
        if re.search(r"\[\s*len\s*\([^)]+\)\s*\]", stripped):
            traps.append({
                "id": "py-trap-off-by-one",
                "name": "Off-by-One Indexing Trap",
                "severity": "critical",
                "line": i,
                "code": stripped,
                "title": "IndexError: accessing sequence with index len(seq)",
                "explanation": "Python sequences are 0-indexed (indices run from 0 to len - 1). Accessing seq[len(seq)] raises IndexError. To get the last item, use seq[-1].",
                "recommendation": "Use negative indexing 'seq[-1]' for the last element.",
                "replacement": "seq[-1]"
            })

    # Deduplicate by (id, line)
    seen = set()
    unique_traps = []
    for t in traps:
        key = (t["id"], t["line"])
        if key not in seen:
            seen.add(key)
            unique_traps.append(t)

    return sorted(unique_traps, key=lambda x: x["line"])


# ============================================================================
# 3. TRCE 6-Point Annotation Synthesizer & Validator
# ============================================================================

TRCE_ID_PATTERN = re.compile(r"^trce-[a-z0-9]+(?:-[a-z0-9]+)*-[0-9]+$")

def extract_trce_blocks_python(code):
    """Finds all @trce-* docstrings in Python code."""
    blocks = []
    lines = code.splitlines()

    trce_id_re = re.compile(r"@trce-id\s+([a-zA-Z0-9_\-]+)")
    trce_who_re = re.compile(r"@trce-who\s+(.+)")
    trce_what_re = re.compile(r"@trce-what\s+(.+)")
    trce_where_re = re.compile(r"@trce-where\s+(.+)")
    trce_when_re = re.compile(r"@trce-when\s+(.+)")
    trce_why_re = re.compile(r"@trce-why\s+(.+)")
    trce_how_re = re.compile(r"@trce-how\s+(.+)")

    try:
        tree = ast.parse(code)
    except Exception:
        # Fallback to regex line scanning
        for i, line in enumerate(lines, 1):
            m = trce_id_re.search(line)
            if m:
                blocks.append({
                    "id": m.group(1),
                    "line": i,
                    "fields": {"id": m.group(1)}
                })
        return blocks

    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef, ast.Module)):
            doc = ast.get_docstring(node)
            if doc and "@trce-id" in doc:
                fields = {}
                id_m = trce_id_re.search(doc)
                if id_m: fields["id"] = id_m.group(1)
                who_m = trce_who_re.search(doc)
                if who_m: fields["who"] = who_m.group(1)
                what_m = trce_what_re.search(doc)
                if what_m: fields["what"] = what_m.group(1)
                where_m = trce_where_re.search(doc)
                if where_m: fields["where"] = where_m.group(1)
                when_m = trce_when_re.search(doc)
                if when_m: fields["when"] = when_m.group(1)
                why_m = trce_why_re.search(doc)
                if why_m: fields["why"] = why_m.group(1)
                how_m = trce_how_re.search(doc)
                if how_m: fields["how"] = how_m.group(1)

                blocks.append({
                    "id": fields.get("id", "unknown"),
                    "name": getattr(node, "name", "module"),
                    "line": node.lineno if hasattr(node, "lineno") else 1,
                    "fields": fields
                })

    return blocks

def validate_python_annotations(code, file_path="<string>"):
    parsed = parse_python_code(code, file_path)
    components = parsed.get("components", [])
    blocks = extract_trce_blocks_python(code)

    errors = []
    duplicates = []
    seen_ids = set()

    for b in blocks:
        tid = b.get("id")
        if not tid or not TRCE_ID_PATTERN.match(tid):
            errors.append(f"Invalid trace ID format: '{tid}' at line {b.get('line')}")
        if tid in seen_ids:
            duplicates.append(tid)
        else:
            seen_ids.add(tid)

        missing_fields = []
        for req in ["who", "what", "where", "when", "why", "how"]:
            if req not in b.get("fields", {}):
                missing_fields.append(req)
        if missing_fields:
            errors.append(f"Trace '{tid}' missing 6-point field(s): {', '.join(missing_fields)}")

    comp_count = len(components)
    annotated_count = len(blocks)
    cov_pct = 100 if comp_count == 0 else min(100, int((annotated_count / comp_count) * 100))

    return {
        "valid": len(errors) == 0 and len(duplicates) == 0 and (comp_count == 0 or cov_pct >= 100),
        "component_count": comp_count,
        "annotated_count": annotated_count,
        "coverage_pct": cov_pct,
        "missing": [c["name"] for c in components if c["name"] not in [b.get("name") for b in blocks]],
        "duplicates": duplicates,
        "errors": errors,
        "traces": blocks
    }

def synthesize_python_annotations(code, file_path="<string>", prefix="trce-py"):
    lines = code.splitlines(keepends=True)
    try:
        tree = ast.parse(code)
    except SyntaxError as e:
        return {
            "error": f"Cannot annotate code with syntax errors: {e.msg} at line {e.lineno}",
            "inserted_count": 0,
            "annotated_text": code
        }

    # Find highest existing counter
    counter = 1
    for m in re.finditer(r"@trce-id\s+trce-[a-z0-9\-]+-(\d+)", code):
        try:
            num = int(m.group(1))
            if num >= counter:
                counter = num + 1
        except ValueError:
            pass

    # Identify nodes needing annotation (including methods within classes)
    targets = []
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            doc = ast.get_docstring(node)
            if not doc or "@trce-id" not in doc:
                targets.append(node)

    if not targets:
        return {
            "original_text": code,
            "annotated_text": code,
            "inserted_count": 0,
            "trace_ids": []
        }

    # Sort in reverse line order for clean non-destructive insertion
    targets.sort(key=lambda n: n.lineno, reverse=True)
    generated_ids = []

    for target in targets:
        trace_id = f"{prefix}-{counter:03d}"
        counter += 1
        generated_ids.append(trace_id)

        kind = "Class" if isinstance(target, ast.ClassDef) else "Function"
        target_name = target.name
        def_line_idx = target.lineno - 1

        # Detect indentation of function/class definition
        def_line = lines[def_line_idx]
        indent = len(def_line) - len(def_line.lstrip())
        body_indent = " " * (indent + 4)

        docstring = (
            f'{body_indent}"""\n'
            f'{body_indent}@trce-id {trace_id}\n'
            f'{body_indent}@trce-who System Subsystem / {target_name}\n'
            f'{body_indent}@trce-what Performs core {target_name} execution\n'
            f'{body_indent}@trce-where {os.path.basename(file_path)} -> {target_name}()\n'
            f'{body_indent}@trce-when Invoked during application runtime pipeline\n'
            f'{body_indent}@trce-why Implements validated {target_name} domain capability\n'
            f'{body_indent}@trce-how Evaluates function logic and returns structured result\n'
            f'{body_indent}"""\n'
        )

        # Insert after definition line
        lines.insert(def_line_idx + 1, docstring)

    annotated = "".join(lines)
    return {
        "original_text": code,
        "annotated_text": annotated,
        "inserted_count": len(generated_ids),
        "trace_ids": generated_ids
    }


# ============================================================================
# 4. Interactive REPL Evaluation & Graphics Plot Interceptor
# ============================================================================

def format_python_value(val):
    val_class = type(val).__name__
    val_repr = repr(val)
    if len(val_repr) > 120:
        val_repr = val_repr[:117] + "..."
    return val_repr, val_class

def inspect_python_workspace(env):
    items = []
    for k, v in env.items():
        if k.startswith("__"):
            continue
        v_type = type(v).__name__
        size_str = f"{sys.getsizeof(v)} bytes"

        # Specialized previews for common data structures
        if hasattr(v, "shape"):
            preview = f"{v_type} shape={v.shape}"
        elif isinstance(v, (list, tuple, set)):
            preview = f"{v_type}[len={len(v)}]: {repr(v)[:50]}"
        elif isinstance(v, dict):
            preview = f"dict[keys={len(v)}]: {list(v.keys())[:5]}"
        elif callable(v):
            preview = f"function {k}()"
        else:
            preview = repr(v)
            if len(preview) > 60: preview = preview[:57] + "..."

        items.append({
            "name": k,
            "type": v_type,
            "class": v_type,
            "size": size_str,
            "preview": preview
        })

    items.sort(key=lambda x: x["name"])
    return items

def capture_matplotlib_plots():
    plots = []
    if "matplotlib" in sys.modules:
        try:
            import matplotlib.pyplot as plt
            fig_nums = plt.get_fignums()
            for num in fig_nums:
                fig = plt.figure(num)
                buf = io.BytesIO()
                fig.savefig(buf, format="png", bbox_inches="tight", dpi=100)
                buf.seek(0)
                b64 = base64.b64encode(buf.read()).decode("utf-8")
                data_uri = f"data:image/png;base64,{b64}"
                plots.append({
                    "id": f"py-plot-{num}-{os.getpid()}",
                    "data_uri": data_uri,
                    "title": f"Figure {num}"
                })
            plt.close("all")
        except Exception as e:
            pass
    return plots

def evaluate_python_code(code, timeout=10, wd=None):
    global session_globals, session_wd

    if wd and os.path.isdir(wd):
        os.chdir(wd)
        session_wd = wd

    stdout_capture = io.StringIO()
    stderr_capture = io.StringIO()

    entries = []
    syntax_error = None

    try:
        parsed = ast.parse(code)
    except SyntaxError as e:
        return {
            "ok": False,
            "incomplete": False,
            "entries": [{
                "code": code,
                "output": [],
                "messages": [],
                "warnings": [],
                "error": f"SyntaxError: {e.msg} at line {e.lineno}",
                "value_text": [],
                "value_class": None,
                "value_length": None,
                "plot_file": None
            }],
            "plots": [],
            "workspace": inspect_python_workspace(session_globals),
            "wd": session_wd
        }

    output_lines = []
    error_msg = None
    value_text = []
    value_class = None

    with contextlib.redirect_stdout(stdout_capture), contextlib.redirect_stderr(stderr_capture):
        try:
            # If the last node is an Expression, compile body[:-1] as 'exec' and body[-1] as 'eval'
            if parsed.body and isinstance(parsed.body[-1], ast.Expr):
                exec_mod = ast.Module(body=parsed.body[:-1], type_ignores=[])
                eval_expr = ast.Expression(body=parsed.body[-1].value)

                if exec_mod.body:
                    exec(compile(exec_mod, "<session>", "exec"), session_globals)

                val = eval(compile(eval_expr, "<session>", "eval"), session_globals)
                if val is not None:
                    val_repr, val_cls = format_python_value(val)
                    value_text = [val_repr]
                    value_class = val_cls
            else:
                exec(compile(parsed, "<session>", "exec"), session_globals)

        except Exception as ex:
            error_msg = traceback.format_exc()

    stdout_str = stdout_capture.getvalue()
    stderr_str = stderr_capture.getvalue()

    if stdout_str:
        output_lines.extend(stdout_str.splitlines())
    if stderr_str:
        output_lines.extend([f"[stderr] {line}" for line in stderr_str.splitlines()])

    plots = capture_matplotlib_plots()
    workspace = inspect_python_workspace(session_globals)

    entries.append({
        "code": code,
        "output": output_lines,
        "messages": [],
        "warnings": [],
        "error": error_msg,
        "value_text": value_text,
        "value_class": value_class,
        "value_length": len(value_text) if value_text else None,
        "plot_file": plots[0]["data_uri"] if plots else None
    })

    return {
        "ok": error_msg is None,
        "incomplete": False,
        "entries": entries,
        "plots": plots,
        "workspace": workspace,
        "wd": session_wd
    }


def generate_python_quiz(code):
    parsed = parse_python_code(code)
    funcs = parsed.get("functions", [])
    classes = parsed.get("classes", [])
    comps = parsed.get("components", [])
    imports = parsed.get("imports", [])
    questions = []
    q_id = 1

    # Q1: Function Signature / Arguments
    if funcs:
        fn_name = funcs[0]
        fn_comp = next((c for c in comps if c["name"] == fn_name), None)
        args = fn_comp.get("args", []) if fn_comp else []
        args_str = ", ".join(args) if args else "no parameters"

        questions.append({
            "id": q_id,
            "question": f"In this Python script, what parameters does the function '{fn_name}()' accept?",
            "options": [
                f"It accepts: ({args_str})",
                "It accepts arbitrary keyword arguments (**kwargs) only",
                "It takes no arguments and mutates global state directly",
                "It requires a Pandas DataFrame object as its sole parameter"
            ],
            "correct_index": 0,
            "explanation": f"Function '{fn_name}' is declared with parameter list: ({args_str})."
        })
        q_id += 1

    # Q2: Object-Oriented / Class Architecture
    if classes:
        cls_name = classes[0]
        cls_comp = next((c for c in comps if c["name"] == cls_name), None)
        bases = cls_comp.get("args", ["object"]) if cls_comp else ["object"]
        base_name = bases[0] if bases else "object"

        questions.append({
            "id": q_id,
            "question": f"What is the base class or role of class '{cls_name}'?",
            "options": [
                f"It defines a class encapsulating domain state (base: {base_name})",
                "It is a standalone procedural function without internal state",
                "It is an abstract interface that cannot be instantiated",
                "It represents a C-extension binary struct"
            ],
            "correct_index": 0,
            "explanation": f"Class '{cls_name}' inherits from '{base_name}' and structures instance methods and state."
        })
        q_id += 1

    # Q3: Dependencies & Modules
    if imports:
        imp_str = ", ".join(imports[:4])
        questions.append({
            "id": q_id,
            "question": f"Which external or standard library module(s) does this script import?",
            "options": [
                f"Imports: {imp_str}",
                "It uses standard built-ins with zero import statements",
                "Only the R base system via reticulate",
                "A proprietary C binary module"
            ],
            "correct_index": 0,
            "explanation": f"The script issues import directives for: {imp_str}."
        })
        q_id += 1

    # Q4: General Python Idiom / Mutability Check
    questions.append({
        "id": q_id,
        "question": "How are variables and arguments passed between functions in Python?",
        "options": [
            "Pass-by-assignment (object references passed; mutables can be modified in-place)",
            "Strict pass-by-value where all objects are deep-copied automatically",
            "Pointer arithmetic with explicit memory addresses",
            "Registers without heap memory allocation"
        ],
        "correct_index": 0,
        "explanation": "Python evaluates variables via pass-by-assignment. Reassigning a name affects only local scope, but mutating an in-place object (like a list or dict) modifies the shared reference."
    })

    return questions


# ============================================================================
# 5. Request Router & stdio JSON-RPC Dispatcher
# ============================================================================

def handle_action(action, payload):
    global session_globals, session_wd

    if action == "ping":
        return {
            "pong": True,
            "version": sys.version,
            "language": "python",
            "root_dir": ROOT_DIR,
            "pid": os.getpid()
        }

    elif action == "parse":
        code = payload.get("code")
        file_path = payload.get("file", "<string>")
        if code is None and file_path and os.path.exists(file_path):
            with open(file_path, "r", encoding="utf-8", errors="replace") as f:
                code = f.read()
        if code is None:
            raise ValueError("Missing 'code' or 'file' parameter")
        return parse_python_code(code, file_path)

    elif action == "analyze":
        code = payload.get("code")
        file_path = payload.get("file", "<string>")
        if code is None and file_path and os.path.exists(file_path):
            with open(file_path, "r", encoding="utf-8", errors="replace") as f:
                code = f.read()
        if code is None:
            raise ValueError("Missing 'code' or 'file' parameter")
        return parse_python_code(code, file_path)

    elif action == "pitfalls":
        code = payload.get("code")
        file_path = payload.get("file", "<string>")
        if code is None and file_path and os.path.exists(file_path):
            with open(file_path, "r", encoding="utf-8", errors="replace") as f:
                code = f.read()
        if code is None:
            raise ValueError("Missing 'code' or 'file' parameter")
        traps = detect_python_pitfalls(code)
        return {
            "count": len(traps),
            "traps": traps
        }

    elif action == "quiz":
        code = payload.get("code", "")
        file_path = payload.get("file", "<string>")
        if not code and file_path and os.path.exists(file_path):
            with open(file_path, "r", encoding="utf-8", errors="replace") as f:
                code = f.read()
        return generate_python_quiz(code)

    elif action == "annotate":
        code = payload.get("code")
        file_path = payload.get("file", "<string>")
        prefix = payload.get("prefix", "trce-py")
        if code is None and file_path and os.path.exists(file_path):
            with open(file_path, "r", encoding="utf-8", errors="replace") as f:
                code = f.read()
        if code is None:
            raise ValueError("Missing 'code' or 'file' parameter")
        return synthesize_python_annotations(code, file_path, prefix)

    elif action == "check":
        code = payload.get("code")
        file_path = payload.get("file", "<string>")
        if code is None and file_path and os.path.exists(file_path):
            with open(file_path, "r", encoding="utf-8", errors="replace") as f:
                code = f.read()
        if code is None:
            raise ValueError("Missing 'code' or 'file' parameter")
        return validate_python_annotations(code, file_path)

    elif action == "eval":
        code = payload.get("code", "")
        timeout = payload.get("timeout", 10)
        wd = payload.get("wd", session_wd)
        return evaluate_python_code(code, timeout, wd)

    elif action == "workspace":
        return {
            "workspace": inspect_python_workspace(session_globals),
            "count": len(session_globals)
        }

    elif action == "reset_session":
        session_globals = {
            "__name__": "__main__",
            "__doc__": None,
            "__package__": None,
        }
        return {"reset": True, "message": "Python session environment reset successfully"}

    elif action == "open_project":
        path = payload.get("path")
        if path and os.path.isdir(path):
            os.chdir(path)
            session_wd = path
            return {"ok": True, "path": path}
        return {"ok": False, "error": f"Invalid directory: {path}"}

    else:
        raise ValueError(f"Unknown Python worker action: '{action}'")


def main():
    handshake = {
        "event": "ready",
        "pid": os.getpid(),
        "version": sys.version,
        "language": "python"
    }
    sys.stdout.write(json.dumps(handshake) + "\n")
    sys.stdout.flush()

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue

        try:
            msg = json.loads(line)
        except Exception as e:
            err_resp = {"ok": False, "error": f"JSON decode error: {str(e)}"}
            sys.stdout.write(json.dumps(err_resp) + "\n")
            sys.stdout.flush()
            continue

        req_id = msg.get("id")
        action = msg.get("action")
        payload = msg.get("payload", {})

        try:
            result = handle_action(action, payload)
            response = {"id": req_id, "ok": True, "result": result}
        except Exception as err:
            response = {"id": req_id, "ok": False, "error": str(err), "trace": traceback.format_exc()}

        sys.stdout.write(json.dumps(response) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
