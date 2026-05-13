# Python / pytest Parameterized Test Patterns

## Pattern 1: Simple @pytest.mark.parametrize

For explicit cases with descriptive IDs:

```python
import pytest

@pytest.mark.parametrize("input_str,expected", [
    pytest.param("hello", 5, id="normal string"),
    pytest.param("", 0, id="empty string"),
    pytest.param(None, 0, id="None input"),
    pytest.param("  ", 2, id="whitespace only"),
])
def test_string_length(input_str, expected):
    result = get_length(input_str) if input_str is not None else 0
    assert result == expected, (
        f"For input {input_str!r}: expected {expected}, got {result}"
    )
```

## Pattern 2: Multiple Parameter Axes

Cartesian product with `@pytest.mark.parametrize` stacking:

```python
import pytest

@pytest.mark.parametrize("alpha", [True, False], ids=["alpha=True", "alpha=False"])
@pytest.mark.parametrize("mode", ["fast", "accurate", "balanced"])
@pytest.mark.parametrize("size", [0, 1, 100, 1000])
def test_processor(alpha, mode, size):
    """Test processor with all parameter combinations."""
    processor = Processor(alpha=alpha, mode=mode)
    result = processor.process(size)
    
    assert result.is_valid, (
        f"Processing failed for alpha={alpha}, mode={mode}, size={size}. "
        f"Error: {result.error_message}"
    )
```

## Pattern 3: Generated Test Cases with Skip Markers

For complex logic determining valid combinations:

```python
import pytest
from itertools import product

def generate_test_cases():
    """Generate all valid parameter combinations."""
    alpha_values = [True, False]
    modes = ["fast", "accurate", "balanced"]
    sizes = [0, 1, 100, 1000]
    formats = ["rgb", "rgba", "grayscale"]
    
    for alpha, mode, size, fmt in product(alpha_values, modes, sizes, formats):
        test_id = f"alpha={alpha}-mode={mode}-size={size}-fmt={fmt}"
        
        # Skip invalid combinations
        if size == 0 and mode == "accurate":
            yield pytest.param(
                alpha, mode, size, fmt,
                id=test_id,
                marks=pytest.mark.skip(reason="Accurate mode requires size > 0")
            )
        elif alpha and fmt == "grayscale":
            yield pytest.param(
                alpha, mode, size, fmt,
                id=test_id,
                marks=pytest.mark.skip(reason="Alpha not supported for grayscale")
            )
        else:
            yield pytest.param(alpha, mode, size, fmt, id=test_id)

@pytest.mark.parametrize("alpha,mode,size,fmt", generate_test_cases())
def test_image_processor(alpha, mode, size, fmt):
    processor = ImageProcessor(alpha=alpha, mode=mode, format=fmt)
    result = processor.process(size)
    
    assert result is not None, (
        f"Processing returned None for alpha={alpha}, mode={mode}, "
        f"size={size}, format={fmt}"
    )
```

## Pattern 4: Test Case Class

For complex test data with setup:

```python
import pytest
from dataclasses import dataclass
from typing import Any

@dataclass
class ProcessingTestCase:
    name: str
    input_data: Any
    expected_output: Any
    should_raise: type[Exception] | None = None
    skip_reason: str | None = None

TEST_CASES = [
    ProcessingTestCase(
        name="valid_input",
        input_data={"key": "value"},
        expected_output={"processed": True},
    ),
    ProcessingTestCase(
        name="empty_input",
        input_data={},
        expected_output={"processed": False},
    ),
    ProcessingTestCase(
        name="null_input",
        input_data=None,
        expected_output=None,
        should_raise=ValueError,
    ),
    ProcessingTestCase(
        name="platform_specific",
        input_data={"special": True},
        expected_output={"processed": True},
        skip_reason="Requires special hardware",
    ),
]

def generate_cases():
    for tc in TEST_CASES:
        marks = []
        if tc.skip_reason:
            marks.append(pytest.mark.skip(reason=tc.skip_reason))
        yield pytest.param(tc, id=tc.name, marks=marks)

@pytest.mark.parametrize("tc", generate_cases())
def test_processing(tc: ProcessingTestCase):
    if tc.should_raise:
        with pytest.raises(tc.should_raise):
            process(tc.input_data)
    else:
        result = process(tc.input_data)
        assert result == tc.expected_output, (
            f"Test '{tc.name}': expected {tc.expected_output}, got {result}. "
            f"Input was: {tc.input_data}"
        )
```

## Pattern 5: Fixtures with Parameterization

For tests that need complex setup:

```python
import pytest

@pytest.fixture(params=["sqlite", "postgres", "mysql"], ids=lambda x: f"db={x}")
def database(request):
    """Provide a database connection for each backend."""
    db = create_database(request.param)
    yield db
    db.cleanup()

@pytest.fixture(params=[True, False], ids=["with_cache", "without_cache"])
def cache_enabled(request):
    return request.param

def test_query_execution(database, cache_enabled):
    """Test query execution across database backends and cache settings."""
    processor = QueryProcessor(database, cache=cache_enabled)
    result = processor.execute("SELECT 1")
    
    assert result is not None, (
        f"Query failed for database={database.type}, cache={cache_enabled}"
    )
```

## Pattern 6: Approximate Equality

For floating point comparisons:

```python
import pytest
from math import isclose

TOLERANCE = 1e-6

def assert_approx_equal(actual, expected, context, tolerance=TOLERANCE):
    """Assert two values are approximately equal with descriptive error."""
    assert isclose(actual, expected, rel_tol=tolerance), (
        f"{context}: expected {expected:.8f}, got {actual:.8f}, "
        f"diff={abs(actual - expected):.8f}, tolerance={tolerance}"
    )

def assert_arrays_approx_equal(actual, expected, context, tolerance=TOLERANCE):
    """Assert two arrays are element-wise approximately equal."""
    assert len(actual) == len(expected), (
        f"{context}: length mismatch - expected {len(expected)}, got {len(actual)}"
    )
    for i, (a, e) in enumerate(zip(actual, expected)):
        assert isclose(a, e, rel_tol=tolerance), (
            f"{context}[{i}]: expected {e:.8f}, got {a:.8f}, "
            f"diff={abs(a - e):.8f}, tolerance={tolerance}"
        )

@pytest.mark.parametrize("x,y,expected", [
    (0.0, 0.0, 0.0),
    (1.0, 0.0, 1.0),
    (0.5, 0.5, 0.7071067811865476),  # sqrt(0.5)
])
def test_magnitude(x, y, expected):
    result = magnitude(x, y)
    assert_approx_equal(result, expected, f"magnitude({x}, {y})")
```

## Pattern 7: Testing Exceptions

```python
import pytest

@pytest.mark.parametrize("input_value,expected_error", [
    pytest.param(None, ValueError, id="None raises ValueError"),
    pytest.param("", ValueError, id="empty string raises ValueError"),
    pytest.param(-1, ValueError, id="negative raises ValueError"),
])
def test_invalid_inputs(input_value, expected_error):
    with pytest.raises(expected_error) as exc_info:
        process(input_value)
    
    assert "invalid" in str(exc_info.value).lower(), (
        f"For input {input_value!r}: exception message should mention 'invalid', "
        f"got: {exc_info.value}"
    )

@pytest.mark.parametrize("flag_a,flag_b", [
    (True, True),
])
def test_mutually_exclusive_flags(flag_a, flag_b):
    """Verify mutually exclusive flags raise appropriate error."""
    with pytest.raises(InvalidConfigurationError) as exc_info:
        configure(flag_a=flag_a, flag_b=flag_b)
    
    assert "mutually exclusive" in str(exc_info.value), (
        f"For flag_a={flag_a}, flag_b={flag_b}: "
        f"expected 'mutually exclusive' in error, got: {exc_info.value}"
    )
```

## Pattern 8: Async Tests

```python
import pytest

@pytest.mark.asyncio
@pytest.mark.parametrize("timeout,should_succeed", [
    pytest.param(1.0, True, id="normal timeout succeeds"),
    pytest.param(0.001, False, id="too short timeout fails"),
])
async def test_async_operation(timeout, should_succeed):
    result = await perform_async_operation(timeout=timeout)
    
    assert result.succeeded == should_succeed, (
        f"timeout={timeout}, should_succeed={should_succeed}: "
        f"result.succeeded={result.succeeded}, "
        f"elapsed={result.elapsed_time:.3f}s"
    )
```

## Test File Template

```python
"""
What: Tests for [module/class name]
Why: Verify [core behavior] under all parameter combinations
Coverage: [N] test cases covering [parameter axes]
"""
import pytest
from itertools import product

# Test case generation
def generate_test_cases():
    """Generate all parameter combinations with skip markers for invalid ones."""
    # Define parameter domains
    param_a_values = [...]
    param_b_values = [...]
    
    for param_a, param_b in product(param_a_values, param_b_values):
        test_id = f"a={param_a}-b={param_b}"
        
        # Skip invalid combinations
        if is_invalid(param_a, param_b):
            yield pytest.param(
                param_a, param_b,
                id=test_id,
                marks=pytest.mark.skip(reason="[reason]")
            )
        else:
            yield pytest.param(param_a, param_b, id=test_id)

# Assertion helpers
def assert_with_context(actual, expected, context):
    """Assert equality with descriptive error message."""
    assert actual == expected, (
        f"{context}: expected {expected!r}, got {actual!r}"
    )

# Tests
@pytest.mark.parametrize("param_a,param_b", generate_test_cases())
def test_main_functionality(param_a, param_b):
    # Arrange
    
    # Act
    
    # Assert with descriptive message
    pass
```
