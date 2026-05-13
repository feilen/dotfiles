---
name: mk-unit-test
description: "Create or improve unit tests with parameterized coverage. Use when writing new tests, improving existing test coverage, or when agent finishes implementing a function and tests would be valuable. Triggers: 'add tests', 'test this', 'improve coverage', 'parameterize tests', 'unit test', after implementing new public functions."
argument-hint: "[instructions] [--file <filename>] [--class <classname>] [--existing <test-file>]"
---

# Unit Test Creation Skill

Create comprehensive unit tests that maximize coverage through parameterized testing. Tests should be easy to diagnose when they fail - a person or agent reading the failure should immediately understand what broke and where.

## Arguments

Parse arguments in order:
1. Everything before the first `--` flag is free-form instructions
2. `--file <filename>`: Source file containing code to test
3. `--class <classname>`: Specific class to focus on (requires `--file`)
4. `--existing <test-file>`: Existing test file to improve/extend

If no arguments provided, ask user what they want to test.

## When to Use This Skill

**Proactive triggers** (suggest using this skill):
- After implementing a new public function or class
- When user says "add tests", "test this", "improve coverage"
- When reviewing code that lacks test coverage
- When a bug is fixed (add regression test)

**Skip when**:
- Code is trivial (simple getters/setters with no logic)
- Test already exists with good coverage
- User explicitly declines

---

## Phase 0: Setup

Create tasks for all phases to track progress:

```
TaskCreate: "Analyze source code"
TaskCreate: "Design parameterized test cases"  
TaskCreate: "Implement tests"
...
<create subtasks for each test>
...
TaskCreate: "Run and iterate"
TaskCreate: "Cleanup with /deduplicate-code"
```

Detect language from file extension:
- `.cs` -> C#/NUnit (see `references/csharp-patterns.md`)
- `.py` -> Python/pytest (see `references/python-patterns.md`)
- Other -> Ask user for test framework preference

---

## Phase 1: Analysis

Read the source file and identify:

### 1.1 Testable Functions

List all public methods/functions. For each, note:
- Name and purpose
- Parameters and their types
- Return type
- Side effects (if any)
- Dependencies that may need mocking

### 1.2 Parameter Domains

For each parameter, identify its domain - the set of meaningful values to test:

| Type | Domain Strategy |
|------|-----------------|
| `bool` | `[true, false]` - always test both |
| `enum` | All enum values |
| `int/float` | Boundary values: `0`, `1`, `-1`, `max`, `min`, typical value |
| `string` | `null`, `""`, `"valid"`, `"edge case"` (unicode, long, etc.) |
| `collection` | `null`, empty, single item, multiple items |
| `nullable<T>` | `null` + domain of `T` |
| Custom types | Identify key states/configurations |

### 1.3 Invalid Combinations

Some parameter combinations are invalid or redundant. Note these for `.Ignore()` / `skip`:
- Mutually exclusive flags
- Parameters that only matter when another is set
- Platform-specific limitations

### 1.4 Private Methods

If `--class` specified, scan for private methods with significant logic. **Flag these for user review** rather than automatically testing:

```
Found private methods with testable logic:
- `ProcessInternal(data)` - 15 lines, multiple branches
- `ValidateInput(input)` - 8 lines, validation logic

Test these via reflection? (requires exposing internals)
```

---

## Phase 2: Test Design

### 2.1 Choose Parameterization Strategy

**For <= 3 parameter axes with small domains**: Exhaustive permutation
- Use nested foreach in test case generator
- Total cases = product of domain sizes

**For > 3 axes or large domains**: Strategic sampling
- Test each parameter value at least once
- Use pairwise/combinatorial coverage for interactions
- Explicitly test known edge case combinations

### 2.2 Design Test Case Generator

Prefer creating a class/function that yields all test cases with:
- Descriptive names showing all parameter values
- Skip markers for invalid combinations with reason

If only a handful of test cases, write them out manually.

See language-specific patterns in `references/`.

### 2.3 Plan Assertions

Each test should verify:
- Return value (if applicable)
- State changes (if applicable)
- Side effects (if applicable)
- Exception behavior for error cases

**Assertion messages must include**:
- Expected value
- Actual value
- All input parameters that led to this result
- For larger input/output, a focused view of likely surrounding context (e.g. for an image, pixel values surrounding the failure)

Bad: `Assert.AreEqual(expected, actual)`
Good: `Assert.AreEqual(expected, actual, $"For input ({x}, {y}, {z}): expected {expected}, got {actual}")`

---

## Phase 3: Implementation

### 3.1 Test File Structure

```
// What: Tests for [ClassName/FunctionName]
// Why: Verify [core behavior being tested]
// Coverage: [what parameter combinations are covered]

[Test class with case generator]

[Test methods using parameterization]

[Helper methods for complex assertions]
```

### 3.2 Test Case Generator

Read the appropriate reference file for your language:
- C#/NUnit: `references/csharp-patterns.md`
- Python/pytest: `references/python-patterns.md`

Key requirements:
- Generator yields `TestCaseData` (C#) or `pytest.param` (Python)
- Each case has descriptive name/id showing all parameters
- Invalid combinations marked with skip reason

### 3.3 Test Methods

- One test method per logical behavior being tested
- Use `[TestCaseSource]` (C#) or `@pytest.mark.parametrize` (Python)
- Keep test body focused - setup, act, assert
- Use helper methods for complex assertions
- Deeper tests can involve multiple rounds of acting/assertion if the tested behavior could misbehave in deeper contexts

### 3.4 Helper Methods

Create helpers for:
- Complex equality checks (floating point tolerance, deep object comparison)
- Common setup/teardown
- Assertion formatting

Helpers should produce descriptive failure messages.

---

## Phase 4: Iteration

### 4.1 Run Tests

Try to run tests automatically:

**C# (.NET CLI)**:
```bash
dotnet test --filter "FullyQualifiedName~TestClassName"
```

**C# (Unity)**: Cannot auto-run unless set up to do so. Otherwise:
```
Please run the tests in Unity Test Runner and report any failures.
Test file: [path]
```

**Python**:
```bash
pytest [test_file.py] -v
```

If auto-run fails or isn't available, ask user to run and report back.

### 4.2 Fix Failures

For each failure:
1. Read the failure message (should tell you exactly what went wrong)
2. Determine if it's a test bug or code bug
3. Fix and re-run

### 4.3 Iterate

Repeat until all tests pass or user says to stop.

---

## Phase 5: Cleanup

### 5.1 Deduplicate

Run the deduplicate-code skill on the test file:

```
/deduplicate-code Deduplicate the following test case files. Where possible, if two or more tests differ only by input or are similar enough, combine them into one test with test parametrization. --file [test-file-path]
```

This catches:
- Repeated setup code that should be a helper
- Similar assertion patterns that can be unified

### 5.2 Final Review

Check that:
- All test methods have descriptive comments
- Failure messages are informative
- No obvious missing coverage
- Code follows project conventions

---

## Quick Reference: Descriptive Failures

The goal is that anyone reading a test failure can immediately understand:
1. **What** was being tested
2. **What** inputs caused the failure  
3. **What** was expected vs actual
4. **Where** in the code/process things went wrong

### Pattern: Include All Context

```csharp
// Bad - useless failure message
Assert.IsTrue(result.IsValid);

// Good - tells you everything
Assert.IsTrue(result.IsValid, 
    $"Validation failed for input '{input}' (length={input.Length}, encoding={encoding}). " +
    $"Errors: {string.Join(", ", result.Errors)}");
```

### Pattern: Custom Assertion Helpers

```csharp
private static void AssertColorsEqual(Color actual, Color expected, string context)
{
    var distance = Vector4.Distance(actual, expected);
    Assert.IsTrue(distance < TOLERANCE,
        $"{context}: Expected {expected}, got {actual} (distance={distance:F6}, tolerance={TOLERANCE})");
}
```

### Pattern: Structured Test Names

Test names should read like documentation:
- `TestProcessing_WhenInputIsNull_ThrowsArgumentException`
- `TestMipmapper_WithSRGB_ProducesCorrectGamma`
