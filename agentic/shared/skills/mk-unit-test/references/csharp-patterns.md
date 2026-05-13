# C# / NUnit Parameterized Test Patterns

## Pattern 1: Simple TestCase Attribute

For small numbers of explicit cases:

```csharp
[TestCase(true, "hello", ExpectedResult = 5)]
[TestCase(false, "hello", ExpectedResult = 0)]
[TestCase(true, "", ExpectedResult = 0)]
[TestCase(true, null, ExpectedResult = 0)]
public int TestStringLength(bool countIt, string input)
{
    return countIt && input != null ? input.Length : 0;
}
```

## Pattern 2: TestCaseSource with Static Method

For cases generated from data:

```csharp
public class MyTests
{
    private static IEnumerable<TestCaseData> ProcessingTestCases()
    {
        yield return new TestCaseData("valid", true)
            .SetDescription("valid input returns true");
        yield return new TestCaseData("", false)
            .SetDescription("empty input returns false");
        yield return new TestCaseData(null, false)
            .SetDescription("null input returns false");
    }

    [TestCaseSource(nameof(ProcessingTestCases))]
    public void TestProcessing(string input, bool expected)
    {
        var result = Processor.Process(input);
        Assert.That(result, Is.EqualTo(expected),
            $"For input '{input ?? "null"}': expected {expected}, got {result}");
    }
}
```

## Pattern 3: TestCaseSource with Generator Class (Full Permutation)

For exhaustive parameter combinations. This is the preferred pattern for thorough coverage:

```csharp
public class TestCaseClass
{
    public static IEnumerable TestCases
    {
        get
        {
            // Define all parameter domains
            var alphaValues = new[] { true, false };
            var modeValues = new[] { Mode.Fast, Mode.Accurate, Mode.Balanced };
            var sizeValues = new[] { 0, 1, 100, int.MaxValue };
            
            // Generate all permutations
            foreach (var alpha in alphaValues)
            foreach (var mode in modeValues)
            foreach (var size in sizeValues)
            {
                var test = new TestCaseData(alpha, mode, size)
                    .SetDescription($"alpha={alpha}, mode={mode}, size={size}");
                
                // Skip invalid combinations with reason
                if (size == 0 && mode == Mode.Accurate)
                {
                    test.Ignore("Accurate mode requires size > 0");
                }
                if (alpha && size == int.MaxValue)
                {
                    test.Ignore("Alpha processing not supported for max size");
                }
                
                yield return test;
            }
        }
    }
}

[TestFixture]
public class ProcessorTests
{
    [TestCaseSource(typeof(TestCaseClass), nameof(TestCaseClass.TestCases))]
    public void TestProcessor(bool alpha, Mode mode, int size)
    {
        // Arrange
        var processor = new Processor(alpha, mode);
        
        // Act
        var result = processor.Process(size);
        
        // Assert
        Assert.That(result.IsValid, Is.True,
            $"Processing failed for alpha={alpha}, mode={mode}, size={size}. " +
            $"Error: {result.ErrorMessage}");
    }
}
```

## Pattern 4: Conditional Ignores

Handle platform-specific or environment-specific skips:

```csharp
public static IEnumerable TestCases
{
    get
    {
        foreach (var format in new[] { Format.A, Format.B, Format.C })
        {
            var test = new TestCaseData(format)
                .SetDescription($"format={format}");
            
            // Skip in batch mode (e.g., CI without GPU)
            if (Application.isBatchMode)
            {
                test.Ignore("Requires interactive mode");
            }
            
            // Skip unsupported format on this platform
            if (format == Format.C && !SystemInfo.supportsFormatC)
            {
                test.Ignore("Format C not supported on this platform");
            }
            
            yield return test;
        }
    }
}
```

## Pattern 5: Tolerance-Based Assertions

For floating point or fuzzy comparisons:

```csharp
private static readonly float TOLERANCE = 1e-6f;

private static void AssertApproximatelyEqual(
    float actual, 
    float expected, 
    string context)
{
    Assert.That(
        Mathf.Abs(actual - expected), 
        Is.LessThan(TOLERANCE),
        $"{context}: expected {expected:F8}, got {actual:F8}, " +
        $"diff={Mathf.Abs(actual - expected):F8}, tolerance={TOLERANCE}");
}

private static void AssertColorsEqual(
    Color actual, 
    Color expected, 
    TextureFormat format,
    string context)
{
    var tolerance = GetToleranceForFormat(format);
    var distance = Vector4.Distance(actual, expected);
    
    Assert.That(distance, Is.LessThan(tolerance),
        $"{context}: expected {expected}, got {actual}. " +
        $"Distance={distance:F6}, tolerance={tolerance:F6}, format={format}");
}

private static float GetToleranceForFormat(TextureFormat format)
{
    return format switch
    {
        TextureFormat.RGBA4444 => 1f / 15f,
        TextureFormat.RGBA32 => 1f / 255f,
        TextureFormat.RGBAFloat => 1e-6f,
        _ => 1f / 255f
    };
}
```

## Pattern 6: Testing Exceptions

```csharp
[TestCase(null)]
[TestCase("")]
public void TestInvalidInput_ThrowsArgumentException(string input)
{
    var ex = Assert.Throws<ArgumentException>(() => Processor.Process(input));
    Assert.That(ex.Message, Does.Contain("input"),
        $"Exception message should mention 'input', got: {ex.Message}");
}

[TestCaseSource(nameof(InvalidCombinations))]
public void TestInvalidCombinations_ThrowsInvalidOperationException(
    bool flagA, 
    bool flagB)
{
    var processor = new Processor();
    
    var ex = Assert.Throws<InvalidOperationException>(() => 
        processor.Configure(flagA, flagB));
    
    Assert.That(ex.Message, Does.Contain("mutually exclusive"),
        $"For flagA={flagA}, flagB={flagB}: " +
        $"expected mention of 'mutually exclusive', got: {ex.Message}");
}
```

## Pattern 7: Testing Private Methods via Reflection

Only use when flagged for review and user approves:

```csharp
[TestFixture]
public class InternalMethodTests
{
    private MethodInfo _processInternalMethod;
    private object _instance;

    [SetUp]
    public void Setup()
    {
        _instance = new MyClass();
        _processInternalMethod = typeof(MyClass)
            .GetMethod("ProcessInternal", 
                BindingFlags.NonPublic | BindingFlags.Instance);
    }

    [TestCase("valid", ExpectedResult = true)]
    [TestCase("invalid", ExpectedResult = false)]
    public bool TestProcessInternal(string input)
    {
        var result = _processInternalMethod.Invoke(_instance, new object[] { input });
        return (bool)result;
    }
}
```

## Pattern 8: Unity-Specific Async Tests

For tests that need to wait for frames or async operations:

```csharp
[UnityTest]
public IEnumerator TestAsyncOperation()
{
    var operation = StartAsyncOperation();
    
    yield return new WaitUntil(() => operation.IsDone);
    
    Assert.That(operation.Result, Is.Not.Null,
        "Async operation should produce a result");
}

[UnityTest]
[TestCaseSource(typeof(AsyncTestCases), nameof(AsyncTestCases.Cases))]
public IEnumerator TestAsyncWithParameters(int timeout, bool shouldSucceed)
{
    var operation = StartOperation(timeout);
    
    float elapsed = 0;
    while (!operation.IsDone && elapsed < timeout + 1)
    {
        elapsed += Time.deltaTime;
        yield return null;
    }
    
    Assert.That(operation.Succeeded, Is.EqualTo(shouldSucceed),
        $"timeout={timeout}, shouldSucceed={shouldSucceed}: " +
        $"operation.Succeeded={operation.Succeeded}, elapsed={elapsed:F2}s");
}
```

## Test File Template

```csharp
using NUnit.Framework;
using System.Collections;
using System.Collections.Generic;

// What: Tests for [ClassName]
// Why: Verify [core behavior] under all parameter combinations
// Coverage: [N] test cases covering [parameter axes]

namespace Tests
{
    public class TestCaseGenerator
    {
        public static IEnumerable TestCases
        {
            get
            {
                // TODO: Generate permutations
                yield break;
            }
        }
    }

    [TestFixture]
    public class ClassNameTests
    {
        [TestCaseSource(typeof(TestCaseGenerator), nameof(TestCaseGenerator.TestCases))]
        public void TestMethodName(/* parameters */)
        {
            // Arrange
            
            // Act
            
            // Assert with descriptive message
        }
    }
}
```
