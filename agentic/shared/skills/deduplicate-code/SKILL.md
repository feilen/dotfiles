---
name: deduplicate-code
description: "Detect and fix duplicate code blocks. Compares current branch against a base (default origin/master), or analyzes a specific file. Refactors duplicates and commits the result."
argument-hint: "[instructions] [--base <branch>] [--staged] [--file <path> [path...] ]"
---

## Task: Find and fix duplicate code blocks

This skill detects duplicate code blocks and refactors them to reduce duplication, then commits the changes. It runs in two passes: first finding exact duplicates, then finding structural duplicates (similar code patterns with different variable names).

### Arguments

- `[instructions]`: Optional free-form text before any flags. Use this to provide context, constraints, or guidance for how to handle the duplicates (e.g., "prefer using the existing helper in Utils.cs", "don't touch the PlayerManager class").
- No flags: Compare HEAD against `origin/master`
- `--base <branch>`: Compare against a specific branch/commit
- `--staged`: With `--base`, analyze staged changes instead of committed changes. Use this when iterating on fixes before committing - it reads the staged file contents and compares staged hunks against base.
- `--file <path> [<path> ...]`: Analyze a single file for internal duplicates (no git comparison)

Parse instructions by taking everything before the first `--` flag.

---

## Pass 1: Exact Duplicates

### Step 1.1: Run duplicate detection

```bash
python3 ~/.local/bin/duplicate-blocks.py [args]
```

Pass through `--base`, `--staged`, or `--file` if provided. Capture the full output.

**Important:** When using `--base` without `--staged`, the tool compares committed changes (base...HEAD). If you're iterating on fixes that aren't committed yet, add `--staged` to analyze staged changes against the base.

If no duplicates found (exit code 0), proceed to Pass 2.

### Step 1.2: Analyze each duplicate

For each duplicate reported, read both locations:
- The **introduced** code (in the changed file)
- The **existing** code it duplicates

Understand what the duplicated code does and why it might have been duplicated.

### Step 1.3: Decide on fix strategy

For each duplicate, choose ONE of:

**A. Restructure the function** (preferred when duplicates are in the same function)
- Reorder logic so both code paths share the same block
- Avoid creating helpers if restructuring is possible

**B. Extract shared logic** (when duplicates span functions/files)
- Create a shared function only if restructuring isn't feasible
- Place the shared function at appropriate scope (same class, utility, etc.)

**C. Skip with explanation** (rare)
- If duplication is genuinely correct (e.g., intentionally parallel implementations, test fixtures)
- Document why in your response

### Step 1.4: Scope of changes

**When using `--base` (branch comparison):**
- Only modify the *introduced* code to call/share with existing code
- Changes to existing code are allowed only if needed to enable sharing (e.g., extracting a method from existing code that new code can also call)
- Do not refactor existing duplicates that predate the branch

**When using `--file` (specific file analysis):**
- Refactor all duplicates within those file(s)
- Full freedom to restructure

### Step 1.5: Apply fixes

Make the necessary edits. After all fixes are applied:

1. Stage the changes: `git add <modified files>`
2. Run the duplicate detector again with `--staged` to verify fixes worked against the staged content
3. If new duplicates appear (from your refactoring), fix those too
4. Repeat until clean or you've made 3 passes (to avoid infinite loops)

---

## Pass 2: Structural Duplicates (Deep Mode)

After Pass 1 is complete (either all exact duplicates fixed or none found), run a second pass with `--deep` to find structurally similar code.

### Step 2.1: Run deep duplicate detection

```bash
python3 ~/.local/bin/duplicate-blocks.py --deep [args]
```

Pass through the same `--base`, `--staged`, or `--file` arguments as Pass 1.

If no duplicates found (exit code 0), proceed to commit.

### Step 2.2: Conservative analysis

Deep mode finds code that is *structurally similar* but may use different variable names. These matches require more careful evaluation because:
- The code may be intentionally different (different domains, different semantics)
- Variable name differences may reflect meaningful distinctions
- Forcing unification may reduce clarity

For each deep duplicate, read both locations and ask:
1. Are these doing the **same logical operation**, just with different variable names?
2. Would unifying them **improve** the code, or just reduce line count?
3. Is there a **natural abstraction** here, or would extraction feel forced?

### Step 2.3: Fix only clear wins

Only fix deep duplicates that meet **all** of these criteria:
- The logic is genuinely identical (not just structurally similar)
- A shared abstraction makes the code more readable, not less
- The extracted function has a clear, self-documenting name

**Skip** deep duplicates when:
- The variables represent meaningfully different things (e.g., `width` vs `height` doing the same math)
- The code is simple enough that a helper would be over-engineering
- Unification would require awkward parameterization

Document skipped items with brief reasoning.

### Step 2.4: Apply conservative fixes

Apply fixes only for clear wins identified in 2.3. Re-run `--deep` to verify, but don't chase diminishing returns - it's fine to leave structural duplicates that don't meet the criteria.

---

## Final Step: Commit

Once both passes are complete (or you've noted skipped items):

1. Stage all modified files
2. Create a single commit with message format:
   ```
   Deduplicate code blocks
   
   - [brief description of each fix]
   - [any skipped items and why]
   ```

Report what was fixed and what (if anything) was intentionally left duplicated.
