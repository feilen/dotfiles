---
name: final-touches
description: "Pre-PR cleanup that reviews INTRODUCED code (git diff) against a base branch. Auto-fixes obvious issues (dead code, unused imports, magic numbers, missing docs) and pauses for user input on nuanced items (test coverage, new dependencies, binary blobs). Use before opening a PR, after feature work is done, or when someone says 'clean up for review', 'final polish', 'prep for PR', or similar."
argument-hint: "[instructions] --base <branch|commit>"
---

## Task: Pre-PR cleanup on introduced code

This skill reviews code changes introduced since a base branch, auto-fixes obvious issues, and flags items needing human judgment. Focus is on the diff only - don't touch unrelated code.

### Arguments

- `--base <ref>` (required): Branch or commit to diff against (e.g., `main`, `origin/main`, `abc123`)
- `[instructions]`: Optional free-form text before flags for guidance (e.g., "focus on the API layer", "ignore test files")

Parse instructions by taking everything before the first `--` flag.

---

## Execution Model

Use **TaskCreate/TaskUpdate** to track all work items. This ensures nothing gets dropped and provides clear progress visibility.

### Phase 0: Setup tasks

After extracting the diff (Step 1), create a task list with all checks and fixes that will be performed:

```
TaskCreate: "Critical checks" (parent)
  - "Check merge conflict markers"
  - "Scan for secrets/credentials" 
  - "Check for large binary files"
  - "Check for vague function names"

TaskCreate: "Auto-fixes" (parent, blocked until critical checks pass)
  - "Remove dead/unreachable code"
  - "Clean unused imports"
  - "Extract magic numbers"
  - "Add missing doc comments"
  - "Remove debug logging"
  - "Inline single-use helpers"
  - "Add access modifiers"
  - "Add inline hints"

TaskCreate: "Flagged for review" (parent)
  - Items added dynamically as issues are found
```

### Phase 1: Run critical checks in parallel

Spawn **four parallel sub-agents** for the critical checks (Step 2):
- Agent 1: Merge conflict markers
- Agent 2: Secrets scan
- Agent 3: Large binary detection
- Agent 4: Vague function names

Each agent updates its task status. If ANY critical check fails (except vague names, which are flagged for review), **STOP** - do not proceed to auto-fixes.

### Phase 2: Run auto-fixes

Only after all critical checks pass. For each auto-fix category:
1. Mark task "in progress"
2. Apply fixes to relevant files
3. Mark task "completed" with summary of changes

### Phase 3: Flag items for review

Create child tasks under "Flagged for review" for each item needing human judgment. These remain open for user to address.

### Phase 4: Summary

Mark parent tasks complete and present the final summary with task status.

---

## Step 1: Extract the diff

Get the list of changed files and their introduced lines:

```bash
git diff <base>...HEAD --unified=0 --diff-filter=AM --name-only
```

For each file, get the actual diff to identify introduced lines (lines starting with `+`):

```bash
git diff <base>...HEAD -- <file>
```

**Exclusions:**
- Skip `.meta` files entirely
- Skip binary files from code analysis (but flag large ones later)
- Focus only on `+` lines (introduced code), not `-` lines or context

---

## Step 2: Critical checks (blockers)

Run these **in parallel using three sub-agents** (Agent tool with `run_in_background: false`). Each agent handles one check and reports back. If ANY check fails, abort immediately.

**Agent prompt template:**
```
Check the diff between <base> and HEAD for [specific check].
Files changed: [list from Step 1]
Report: found/not-found, with file:line details if found.
```

### 2.1 Merge conflict markers

```bash
git diff <base>...HEAD | grep -nE '^\+.*((<{7}|={7}|>{7}))'
```

If found: **STOP and report immediately.** These must be resolved before any other work.

### 2.2 Secrets and credentials

Scan introduced lines for patterns:
- API keys: `['"](sk-|api[-_]?key|apikey)['":\s]*[a-zA-Z0-9]{20,}`
- Passwords: `password\s*=\s*['"][^'"]+['"]` (non-empty string literals)
- Tokens: `token\s*=\s*['"][^'"]+['"]`
- Private keys: `-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----`
- AWS keys: `AKIA[0-9A-Z]{16}`
- Connection strings with credentials

If found: **STOP and report immediately.** Do not commit. Ask user how to proceed.

### 2.3 Large binary files

```bash
git diff <base>...HEAD --stat | grep -E 'Bin 0 ->' 
```

Also check file sizes for new files:

```bash
git diff <base>...HEAD --name-only --diff-filter=A | xargs -I{} ls -la {} 2>/dev/null | awk '$5 > 500000'
```

If files > 500KB found: Flag for user review. Suggest git-lfs for large assets.

### 2.4 Vague or non-descriptive function names

Extract newly introduced function names from the diff and flag any that are vague, overly short, or don't describe what the function does.

**Extract function names** (for files matching `*.{cs,shader,cginc,cpp,c,rs,h,hpp}`):

```bash
# C#/C++/C/Rust - match function definitions
git diff <base>...HEAD --unified=0 -- '*.cs' '*.cpp' '*.c' '*.rs' '*.h' '*.hpp' | \
  grep -E '^\+' | \
  grep -oE '(public|private|protected|internal|static|async|unsafe|extern|virtual|override|inline)?\s*\w+\s+(\w+)\s*\(' | \
  grep -oE '\w+\s*\($' | \
  grep -oE '^\w+' | sort -u

# Shaders/HLSL - match function definitions  
git diff <base>...HEAD --unified=0 -- '*.shader' '*.cginc' '*.hlsl' | \
  grep -E '^\+' | \
  grep -oE '\w+\s+(\w+)\s*\([^)]*\)\s*{' | \
  grep -oE '^\w+\s+\w+' | awk '{print $2}' | sort -u
```

**Flag names that are:**
- Single words that don't describe action (e.g., `Process`, `Handle`, `Do`, `Run`, `Execute`, `Helper`)
- Numbered or sequential names (e.g., `Step1`, `Part2`, `FirstSteps`)
- Abbreviations without context (e.g., `Proc`, `Mgr`, `Impl`)
- Generic names (e.g., `DoIt`, `DoStuff`, `HandleThis`, `ProcessData`)

**Skip (don't flag):**
- Unity/framework lifecycle methods: `Awake`, `Start`, `Update`, `FixedUpdate`, `LateUpdate`, `OnEnable`, `OnDisable`, `OnDestroy`, etc.
- Interface implementations and overrides (detected by `override` keyword)
- Standard patterns: `Get*`, `Set*`, `Is*`, `Has*`, `Try*`, `On*` (event handlers)
- Shader entry points: `vert`, `frag`, `surf`

**Good examples** (descriptive, action-oriented):
| Name | Why it's good |
|------|---------------|
| `LoadAndPrepareExecutionBuffer` | States the action and the target |
| `TryGetEntrypointNameFromHash` | Clear Try pattern, describes transformation |
| `RegisterTriggerEventConsumer` | Action + what's being registered |
| `ApplyLightCullingMaskFilter` | Action + specific target |
| `DeserializePublicVariables` | Action + what's being processed |
| `UnsubscribeFromUpdates` | Action + specific subsystem |
| `SendCustomEventDelayedFrames` | Action + timing qualifier |
| `vertFog` / `vertTriplanar` | Shader convention + variant qualifier |

**Bad examples** (flag these):
| Name | Problem | Suggested fix |
|------|---------|---------------|
| `Process` | No object, no context | `ProcessIncomingMessages` |
| `FirstSteps` | Describes sequence, not action | `InitializePlayerSession` |
| `DoIt` | Completely opaque | Describe what "it" is |
| `HandleStuff` | Generic verb + placeholder | `HandleNetworkDisconnect` |
| `Helper` | Role, not action | Inline or name by purpose |
| `Step2` | Sequence number, not meaning | `ValidateInputBuffers` |
| `Mgr` | Abbreviation without context | `ConnectionManager.Connect` |
| `Data` | Noun only, no verb | `TransformVertexData` |

If vague names found: Flag for user review with suggested improvements based on the function body.

---

## Step 3: Auto-fix issues

**Task tracking:** Before starting, ensure all auto-fix tasks from Phase 0 are created. As you work through each category:
1. `TaskUpdate` the task to `in_progress`
2. Apply fixes
3. `TaskUpdate` to `completed` with a one-line summary (e.g., "Removed 3 unused imports in Foo.cs, Bar.cs")

For each changed file, analyze introduced code and apply fixes directly:

### 3.1 Dead/unreachable code

Detect and remove:
- Unreachable code after `return`, `throw`, `break`, `continue`
- Variables assigned but never read
- Functions defined but never called (within the same file - cross-file is flagged in Step 4)

### 3.2 Unused imports (introduced only)

For imports/usings added in the diff:
- Check if any symbol from that import is used in the file
- If not, remove the import line

**Language patterns:**
- C#: `using Namespace;` or `using Alias = Namespace;`
- TypeScript/JS: `import { X } from 'Y'` or `import X from 'Y'`
- Python: `import X` or `from X import Y`
- Rust: `use crate::X` or `use X`

### 3.3 Magic numbers

Numbers in logic that should be named constants:
- **Fix:** Extract to a `const` or `static readonly` with a descriptive name
- **Skip:** 0, 1, -1, 2 in simple contexts (array indices, increment/decrement)
- **Skip:** Numbers in test assertions (expected values)

### 3.4 Missing doc comments

For new public/exported functions, methods, or classes without doc comments:
- Add a single-line doc comment describing what it does
- Keep it brief - one sentence max

**Language styles:**
| Language | Style |
|----------|-------|
| C# | `/// <summary>Brief description.</summary>` |
| Rust | `/// Brief description.` |
| TypeScript/JS | `/** Brief description. */` |
| Python | `"""Brief description."""` as first line of function body |

### 3.5 Debug logging (non-test files)

Remove or convert debug statements in production code:
- `Console.WriteLine` without log level -> remove or convert to proper logging
- `Debug.Log` / `Debug.LogWarning` / `Debug.LogError` -> keep only if intentional; flag verbose ones
- `print()` in Python production code -> remove or convert to logging
- `console.log` in JS/TS production code -> remove or convert

**Skip:** Files in test directories, files with "test" or "debug" in the name.

### 3.6 Helpers used once (same file)

If a private helper function is:
- Defined in the same file
- Called exactly once
- Less than ~10 lines
- Not recursive

Then: Inline it into the caller and remove the helper.

### 3.7 Missing access modifiers (C#/Rust)

For helpers only used within the current file:
- C#: Add `private` if no modifier specified and not used outside file
- Rust: Ensure `pub` is not used for internal-only functions

### 3.8 Inline candidates

For small, hot-path functions (simple getters, single-expression bodies):
- C#: Add `[MethodImpl(MethodImplOptions.AggressiveInlining)]` (requires `using System.Runtime.CompilerServices;`)
- Rust: Add `#[inline]`

**Be conservative:** Only apply to obvious cases (property getters, simple wrappers).

---

## Step 4: Flag for user input (pause and ask)

**Task tracking:** For each flagged item, create a child task under the "Flagged for review" parent task. Use descriptive names like:
- "Review: No test for ProcessData() in Foo.cs"
- "Review: New dependency lodash"
- "Review: Large file Assets/bigfile.png (2.3MB)"

These tasks remain open for the user to address or dismiss.

These require human judgment - present them and wait for direction:

### 4.1 Insufficient test coverage

For each new public function/method:
- Check if a corresponding test exists (search for test files referencing the function name)
- If no test found, flag it:
  ```
  - [ ] `FileName.cs:42` - `ProcessData()` has no test coverage. Add test?
  ```

### 4.2 New external dependencies

Scan for new imports of external packages not previously used in the file:
- Check `package.json`, `Cargo.toml`, `.csproj` for new entries
- Flag with: "New dependency `X` added - confirm intended?"

### 4.3 Cross-file dead code

Functions added in the diff that aren't called anywhere in the codebase:
- Search: `rg "FunctionName" --type <lang>` 
- If only definition found (no calls), flag:
  ```
  - [ ] `FileName.cs:42` - `NewFunction()` not called anywhere. Intentional?
  ```

### 4.4 Unusual file changes

Flag if the diff includes changes to:
- Project files (`.csproj`, `package.json`, `Cargo.toml`) that look auto-generated
- Config files that shouldn't normally change
- Files outside the expected feature directory

### 4.5 Performance concerns

Flag patterns that may cause performance issues:

| Pattern | Detection | Flag text |
|---------|-----------|-----------|
| LINQ in loops | `.ToList()`, `.Where()`, `.Select()` inside `for`/`foreach`/`while` | "LINQ allocation in loop - consider caching" |
| Repeated allocations | `new` inside tight loops | "Allocation in loop - consider pooling or hoisting" |
| O(n^2) patterns | Nested iterations over same/related collections | "Potential O(n^2) - review complexity" |
| Boxing | Value types cast to `object` or interface | "Potential boxing - review if hot path" |

---

## Step 5: Stage and summarize

After all auto-fixes are applied:

1. **Mark auto-fix parent task complete** with summary of all changes

2. Stage the changes:
   ```bash
   git add <modified files>
   ```

3. Show diff of what was changed:
   ```bash
   git diff --cached --stat
   ```

4. **Show task list** to user (via TaskList) so they can see:
   - Completed checks and fixes
   - Open review items that need their attention

5. Present summary in this format:

```
## Final Touches Summary

### Auto-fixed:
- Removed 3 unused imports in `Foo.cs`
- Added doc comments to 2 new functions in `Bar.cs`
- Inlined `Helper()` into `Main()` in `Baz.cs`
- Extracted magic number to `MaxRetryCount` constant in `Api.cs`

### Flagged for review:
- [ ] `NewFeature.cs:42` - No test coverage for `ProcessData()`
- [ ] `package.json` - New dependency `lodash` added - confirm intended?
- [ ] `Assets/bigfile.png` (2.3MB) - Consider git-lfs

### Performance notes:
- [ ] `DataProcessor.cs:87` - LINQ in loop, consider caching

### Verified clean:
- No merge markers
- No secrets detected
- No debug logging in production paths
```

---

## Step 6: Wait for user

**Do NOT commit.** Present the summary and wait for user to:
- Approve and commit themselves
- Request changes to the auto-fixes
- Address the flagged items
- Ask for more details on any item

If user asks to commit, create a commit with message:
```
Pre-PR cleanup: remove dead code, add docs

- [list of significant changes]
```
