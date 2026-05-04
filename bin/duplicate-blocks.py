#!/usr/bin/env python3
"""
Pre-commit hook to detect duplicate code blocks in staged changes.

Extracts contiguous blocks of added lines from staged diffs and checks
if those blocks already exist elsewhere in the codebase.
"""

import argparse
import os
import subprocess
import sys
import re
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path

# Configuration
MIN_BLOCK_SIZE = 3
MIN_LINE_LENGTH = 10
DEEP_MODE = False
SKIP_EXTENSIONS = {'.png', '.jpg', '.jpeg', '.gif', '.meta', '.asset', '.prefab',
                   '.unity', '.bin', '.dll', '.exe', '.so', '.dylib', '.pdf'}

def _is_wsl() -> bool:
    return 'microsoft' in Path('/proc/version').read_text().lower() if Path('/proc/version').exists() else False

def _wsl_path(winpath: str) -> str:
    """Convert Windows path to WSL path (C:/foo -> /mnt/c/foo)."""
    if len(winpath) >= 2 and winpath[1] == ':':
        drive = winpath[0].lower()
        return f'/mnt/{drive}{winpath[2:].replace(chr(92), "/")}'
    return winpath

def _setup_git_env() -> dict:
    """Return env dict with GIT_DIR translated for WSL if needed."""
    env = os.environ.copy()
    if not _is_wsl():
        return env

    gitfile = Path('.git')
    if gitfile.is_file():
        content = gitfile.read_text().strip()
        if content.startswith('gitdir:'):
            gitdir = content[7:].strip()
            if len(gitdir) >= 2 and gitdir[1] == ':':
                env['GIT_DIR'] = _wsl_path(gitdir)
    return env

_GIT_ENV = None
def _get_git_env() -> dict:
    global _GIT_ENV
    if _GIT_ENV is None:
        _GIT_ENV = _setup_git_env()
    return _GIT_ENV


# Configurable message shown when duplicates are found
DUPLICATE_WARNING_MESSAGE = """
WARNING: The following introduced blocks are fully duplicated in other places in the same file.
Suggest rewriting them to avoid introducing quite as much duplicated code.
Where possible, if duplicated blocks are within the same function, restructure the function to have both paths touch
the same portion of code. Try to avoid writing helpers where a restructure is possible.
"""

# Language-specific identifier patterns for --deep mode
# Each pattern should match variable/function names but not keywords
LANG_PATTERNS: dict[str, dict] = {
    'python': {
        'extensions': {'.py'},
        'identifier': r'\b([a-zA-Z_][a-zA-Z0-9_]*)\b',
        'keywords': {'and', 'as', 'assert', 'async', 'await', 'break', 'class', 'continue',
                     'def', 'del', 'elif', 'else', 'except', 'finally', 'for', 'from',
                     'global', 'if', 'import', 'in', 'is', 'lambda', 'nonlocal', 'not',
                     'or', 'pass', 'raise', 'return', 'try', 'while', 'with', 'yield',
                     'True', 'False', 'None', 'self', 'cls'},
        'string_pattern': r'(["\'])(?:(?!\1|\\).|\\.)*\1|["\']["\']["\'][\s\S]*?["\']["\']["\']',
    },
    'csharp': {
        'extensions': {'.cs'},
        'identifier': r'\b([a-zA-Z_][a-zA-Z0-9_]*)\b',
        'keywords': {'abstract', 'as', 'base', 'bool', 'break', 'byte', 'case', 'catch',
                     'char', 'checked', 'class', 'const', 'continue', 'decimal', 'default',
                     'delegate', 'do', 'double', 'else', 'enum', 'event', 'explicit',
                     'extern', 'false', 'finally', 'fixed', 'float', 'for', 'foreach',
                     'goto', 'if', 'implicit', 'in', 'int', 'interface', 'internal', 'is',
                     'lock', 'long', 'namespace', 'new', 'null', 'object', 'operator',
                     'out', 'override', 'params', 'private', 'protected', 'public',
                     'readonly', 'ref', 'return', 'sbyte', 'sealed', 'short', 'sizeof',
                     'stackalloc', 'static', 'string', 'struct', 'switch', 'this', 'throw',
                     'true', 'try', 'typeof', 'uint', 'ulong', 'unchecked', 'unsafe',
                     'ushort', 'using', 'var', 'virtual', 'void', 'volatile', 'while',
                     'async', 'await', 'dynamic', 'nameof', 'when', 'where', 'yield'},
        'string_pattern': r'@"(?:[^"]|"")*"|"(?:[^"\\]|\\.)*"',
    },
    'cpp': {
        'extensions': {'.cpp', '.hpp', '.c', '.h', '.cc', '.cxx', '.hxx'},
        'identifier': r'\b([a-zA-Z_][a-zA-Z0-9_]*)\b',
        'keywords': {'alignas', 'alignof', 'and', 'and_eq', 'asm', 'auto', 'bitand',
                     'bitor', 'bool', 'break', 'case', 'catch', 'char', 'char16_t',
                     'char32_t', 'class', 'compl', 'const', 'constexpr', 'const_cast',
                     'continue', 'decltype', 'default', 'delete', 'do', 'double',
                     'dynamic_cast', 'else', 'enum', 'explicit', 'export', 'extern',
                     'false', 'float', 'for', 'friend', 'goto', 'if', 'inline', 'int',
                     'long', 'mutable', 'namespace', 'new', 'noexcept', 'not', 'not_eq',
                     'nullptr', 'operator', 'or', 'or_eq', 'private', 'protected',
                     'public', 'register', 'reinterpret_cast', 'return', 'short',
                     'signed', 'sizeof', 'static', 'static_assert', 'static_cast',
                     'struct', 'switch', 'template', 'this', 'thread_local', 'throw',
                     'true', 'try', 'typedef', 'typeid', 'typename', 'union', 'unsigned',
                     'using', 'virtual', 'void', 'volatile', 'wchar_t', 'while', 'xor',
                     'xor_eq', 'override', 'final', 'NULL'},
        'string_pattern': r'"(?:[^"\\]|\\.)*"',
    },
    'hlsl': {
        'extensions': {'.hlsl', '.cginc', '.shader', '.compute', '.cg'},
        'identifier': r'\b([a-zA-Z_][a-zA-Z0-9_]*)\b',
        'keywords': {'AppendStructuredBuffer', 'BlendState', 'Buffer', 'ByteAddressBuffer',
                     'CompileShader', 'ComputeShader', 'ConsumeStructuredBuffer',
                     'DepthStencilState', 'DepthStencilView', 'DomainShader',
                     'GeometryShader', 'HullShader', 'InputPatch', 'LineStream',
                     'OutputPatch', 'PixelShader', 'PointStream', 'RWBuffer',
                     'RWByteAddressBuffer', 'RWStructuredBuffer', 'RWTexture1D',
                     'RWTexture2D', 'RWTexture3D', 'RasterizerState', 'RenderTargetView',
                     'SamplerComparisonState', 'SamplerState', 'StructuredBuffer',
                     'Texture1D', 'Texture2D', 'Texture3D', 'TextureCube', 'TriangleStream',
                     'VertexShader', 'bool', 'break', 'case', 'cbuffer', 'centroid',
                     'class', 'column_major', 'const', 'continue', 'default', 'discard',
                     'do', 'double', 'else', 'extern', 'false', 'float', 'for', 'groupshared',
                     'half', 'if', 'in', 'inout', 'int', 'interface', 'line', 'lineadj',
                     'linear', 'matrix', 'min10float', 'min12int', 'min16float', 'min16int',
                     'min16uint', 'namespace', 'nointerpolation', 'noperspective', 'out',
                     'packoffset', 'pass', 'point', 'precise', 'register', 'return',
                     'row_major', 'sample', 'sampler', 'shared', 'snorm', 'static',
                     'struct', 'switch', 'tbuffer', 'technique', 'true', 'typedef',
                     'triangle', 'triangleadj', 'uint', 'uniform', 'unorm', 'unsigned',
                     'vector', 'void', 'volatile', 'while',
                     'float2', 'float3', 'float4', 'float2x2', 'float3x3', 'float4x4',
                     'int2', 'int3', 'int4', 'uint2', 'uint3', 'uint4', 'half2', 'half3', 'half4',
                     'fixed', 'fixed2', 'fixed3', 'fixed4', 'sampler2D', 'samplerCUBE'},
        'string_pattern': r'"(?:[^"\\]|\\.)*"',
    },
    'shell': {
        'extensions': {'.sh', '.bash', '.zsh'},
        'identifier': r'\$\{?([a-zA-Z_][a-zA-Z0-9_]*)\}?|\b([a-zA-Z_][a-zA-Z0-9_]*)\b',
        'keywords': {'if', 'then', 'else', 'elif', 'fi', 'case', 'esac', 'for', 'while',
                     'until', 'do', 'done', 'in', 'function', 'select', 'time', 'coproc',
                     'local', 'return', 'exit', 'break', 'continue', 'declare', 'typeset',
                     'export', 'readonly', 'unset', 'shift', 'set', 'true', 'false',
                     'test', 'echo', 'printf', 'read', 'cd', 'pwd', 'source'},
        'string_pattern': r'"(?:[^"\\$]|\\.|\$[^(])*"|\'[^\']*\'',
    },
}


def get_lang_config(filepath: str) -> dict | None:
    """Get language config based on file extension."""
    ext = '.' + filepath.rsplit('.', 1)[-1] if '.' in filepath else ''
    for lang, config in LANG_PATTERNS.items():
        if ext in config['extensions']:
            return config
    return None


def deep_normalize_line(line: str, lang_config: dict) -> str:
    """
    Normalize a line by replacing variable names with a generic placeholder.
    Keeps function/method names, type names, and member access chains.
    """
    if not lang_config:
        return line.strip()

    keywords = lang_config['keywords']
    string_pattern = lang_config.get('string_pattern', '')

    working = line.strip()

    # Replace strings with placeholder first
    if string_pattern:
        working = re.sub(string_pattern, '__STR__', working)

    # Pattern that captures identifier with context:
    # Group 1: the identifier
    # Group 2: optional whitespace
    # Group 3: optional '(' or '.'
    ident_with_context = r'\b([a-zA-Z_][a-zA-Z0-9_]*)(\s*)([.(])?'

    def replace_identifier(m):
        original = m.group(1)
        whitespace = m.group(2) or ''
        following_char = m.group(3) or ''

        # Keep keywords
        if original in keywords:
            return m.group(0)
        # Keep SCREAMING_CASE constants
        if re.match(r'^[A-Z][A-Z0-9_]*$', original) and len(original) > 1:
            return m.group(0)
        # Keep function/method calls (followed by '(')
        if following_char == '(':
            return m.group(0)
        # Keep member access (followed by '.') - likely a type or important object
        if following_char == '.':
            return m.group(0)
        # Keep type names (PascalCase) - likely class/struct names
        if re.match(r'^[A-Z][a-z]', original):
            return m.group(0)

        # Replace variable with placeholder
        return 'IDENT' + whitespace + following_char

    return re.sub(ident_with_context, replace_identifier, working)


def normalize_line(line: str, filepath: str = "") -> str:
    """
    Normalize a line for comparison.
    In DEEP_MODE, replaces identifiers with placeholders for structural matching.
    """
    stripped = line.strip()

    if not DEEP_MODE or not filepath:
        return stripped

    lang_config = get_lang_config(filepath)
    if not lang_config:
        return stripped

    return deep_normalize_line(stripped, lang_config)


def is_trivial(line: str) -> bool:
    stripped = line.strip()
    return len(stripped) < MIN_LINE_LENGTH


@dataclass
class AddedHunk:
    """A contiguous block of added lines from a diff."""
    file: str
    start_line: int
    lines: list[tuple[int, str]]  # (line_number, content)


@dataclass
class DuplicateMatch:
    """A block of introduced code that matches existing code."""
    introduced_file: str
    introduced_lines: tuple[int, int]
    existing_file: str
    existing_lines: tuple[int, int]
    content: list[str]


def _parse_file_list(output: str) -> list[str]:
    files = [f for f in output.strip().split('\n') if f]
    return [f for f in files if not any(f.endswith(ext) for ext in SKIP_EXTENSIONS)]


def get_staged_files() -> list[str]:
    result = subprocess.run(
        ["git", "diff", "--cached", "--name-only", "--diff-filter=AM"],
        capture_output=True, text=True, check=True, env=_get_git_env()
    )
    return _parse_file_list(result.stdout)


def get_changed_files_since(base_ref: str) -> list[str]:
    result = subprocess.run(
        ["git", "diff", "--name-only", "--diff-filter=AM", f"{base_ref}...HEAD"],
        capture_output=True, text=True, check=True, env=_get_git_env()
    )
    return _parse_file_list(result.stdout)


def get_added_hunks(filepath: str, base_ref: str | None = None, use_staged: bool = False) -> list[AddedHunk]:
    """
    Parse diff for a file and extract contiguous blocks of added lines.
    If base_ref is provided, compares base_ref...HEAD (or base_ref vs staged if use_staged=True).
    Otherwise uses staged changes vs HEAD.
    """
    if use_staged and base_ref:
        cmd = ["git", "diff", "--cached", "-U0", base_ref, "--", filepath]
    elif base_ref:
        cmd = ["git", "diff", "-U0", f"{base_ref}...HEAD", "--", filepath]
    else:
        cmd = ["git", "diff", "--cached", "-U0", filepath]

    result = subprocess.run(cmd, capture_output=True, text=True, check=True, env=_get_git_env())

    hunks = []
    current_hunk_lines = []
    current_line = 0
    hunk_start = 0

    def flush_hunk():
        nonlocal current_hunk_lines, hunk_start
        if current_hunk_lines:
            hunks.append(AddedHunk(
                file=filepath,
                start_line=hunk_start,
                lines=current_hunk_lines[:]
            ))
            current_hunk_lines = []

    for line in result.stdout.split('\n'):
        if line.startswith('@@'):
            flush_hunk()
            match = re.search(r'\+(\d+)', line)
            if match:
                current_line = int(match.group(1))
                hunk_start = current_line
        elif line.startswith('+') and not line.startswith('+++'):
            current_hunk_lines.append((current_line, line[1:]))
            current_line += 1
        elif line.startswith('-'):
            pass  # deleted line, don't increment
        else:
            # context line or end of hunk - flush if we have added lines
            flush_hunk()
            current_line += 1

    flush_hunk()
    return hunks


def extract_meaningful_lines(hunk: AddedHunk) -> list[tuple[int, str, str]]:
    """
    Filter hunk to only non-trivial lines.
    Returns [(line_num, normalized_content, original_content), ...]
    """
    result = []
    for line_num, content in hunk.lines:
        if is_trivial(content):
            continue
        norm = normalize_line(content, hunk.file)
        result.append((line_num, norm, content.strip()))
    return result


def find_duplicate_blocks(meaningful_lines: list[tuple[int, str, str]], max_gap: int = 3) -> list[tuple[int, int, tuple[str, ...], tuple[str, ...]]]:
    """
    Find all blocks of MIN_BLOCK_SIZE consecutive meaningful lines within contiguous runs.
    Returns [(start_idx, end_idx, normalized_content_tuple, original_content_tuple), ...]

    Generates sliding windows of exactly MIN_BLOCK_SIZE lines to find partial matches.
    """
    if len(meaningful_lines) < MIN_BLOCK_SIZE:
        return []

    blocks = []

    # First, identify contiguous runs
    runs = []
    run_start = 0
    for i in range(1, len(meaningful_lines)):
        gap = meaningful_lines[i][0] - meaningful_lines[i-1][0]
        if gap > max_gap:
            if i - run_start >= MIN_BLOCK_SIZE:
                runs.append((run_start, i))
            run_start = i

    if len(meaningful_lines) - run_start >= MIN_BLOCK_SIZE:
        runs.append((run_start, len(meaningful_lines)))

    # Generate MIN_BLOCK_SIZE sliding windows within each run
    for run_start, run_end in runs:
        for i in range(run_start, run_end - MIN_BLOCK_SIZE + 1):
            end_idx = i + MIN_BLOCK_SIZE - 1
            normalized = tuple(norm for _, norm, _ in meaningful_lines[i:i + MIN_BLOCK_SIZE])
            original = tuple(orig for _, _, orig in meaningful_lines[i:i + MIN_BLOCK_SIZE])
            blocks.append((i, end_idx, normalized, original))

    return blocks


def get_file_contents_from_ref(filepath: str, ref: str = "HEAD") -> list[str] | None:
    """Get file contents from a git ref (default HEAD)."""
    result = subprocess.run(
        ["git", "show", f"{ref}:{filepath}"],
        capture_output=True, text=True, env=_get_git_env()
    )
    if result.returncode != 0:
        return None
    return result.stdout.split('\n')


def get_file_contents_staged(filepath: str) -> list[str] | None:
    """Get file contents from the staging area (index)."""
    result = subprocess.run(
        ["git", "show", f":{filepath}"],
        capture_output=True, text=True, env=_get_git_env()
    )
    if result.returncode != 0:
        return None
    return result.stdout.split('\n')


def get_file_contents(filepath: str) -> list[str] | None:
    """Get current file contents from disk."""
    try:
        with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
            return f.readlines()
    except (FileNotFoundError, PermissionError):
        return None


def _build_meaningful_lines(file_lines: list[str], filepath: str = "") -> list[tuple[int, str, str]]:
    """
    Build list of (line_number, normalized_content, original_content) for non-trivial lines.
    """
    result = []
    for i, line in enumerate(file_lines, 1):
        if is_trivial(line):
            continue
        norm = normalize_line(line, filepath)
        result.append((i, norm, line.strip()))
    return result


def find_block_in_lines(block: tuple[str, ...], file_lines: list[str], filepath: str = "", max_gap: int = 3) -> list[tuple[int, int]]:
    """
    Find all occurrences of a normalized block in file lines.
    Returns [(start_line, end_line), ...] with 1-indexed line numbers.
    """
    meaningful = _build_meaningful_lines(file_lines, filepath)

    if len(meaningful) < len(block):
        return []

    matches = []
    for i in range(len(meaningful) - len(block) + 1):
        # Check consecutive constraint
        is_consecutive = True
        for j in range(1, len(block)):
            gap = meaningful[i + j][0] - meaningful[i + j - 1][0]
            if gap > max_gap:
                is_consecutive = False
                break

        if not is_consecutive:
            continue

        # Compare normalized content
        candidate = tuple(meaningful[i + j][1] for j in range(len(block)))
        if candidate == block:
            start_line = meaningful[i][0]
            end_line = meaningful[i + len(block) - 1][0]
            matches.append((start_line, end_line))

    return matches


def ranges_overlap(r1: tuple[int, int], r2: tuple[int, int]) -> bool:
    return not (r1[1] < r2[0] or r2[1] < r1[0])


def find_duplicates_in_staged() -> list[DuplicateMatch]:
    """Find introduced blocks in staged changes that duplicate existing code."""
    return find_duplicates_in_diff(staged=True, base_ref=None, use_staged_contents=False)


def find_duplicates_since_base(base_ref: str, use_staged: bool = False) -> list[DuplicateMatch]:
    """Find introduced blocks since base_ref that duplicate existing code."""
    return find_duplicates_in_diff(staged=False, base_ref=base_ref, use_staged_contents=use_staged)


def find_duplicates_in_diff(staged: bool = True, base_ref: str | None = None, use_staged_contents: bool = False) -> list[DuplicateMatch]:
    """
    Main analysis: find introduced blocks that duplicate existing code in the same file.

    If staged=True, analyzes staged changes (for pre-commit hook).
    If base_ref is provided, analyzes changes between base_ref and HEAD.
    If use_staged_contents=True, reads file contents from staging area instead of disk.

    Only searches within the same file for duplicates (not the entire codebase).
    """
    if staged:
        changed_files = get_staged_files()
    elif use_staged_contents:
        changed_files = get_staged_files()
    else:
        changed_files = get_changed_files_since(base_ref)

    if not changed_files:
        return []

    matches = []

    for changed_file in changed_files:
        if use_staged_contents:
            hunks = get_added_hunks(changed_file, base_ref=base_ref, use_staged=True)
            file_lines = get_file_contents_staged(changed_file)
        elif staged:
            hunks = get_added_hunks(changed_file, base_ref=None)
            file_lines = get_file_contents(changed_file)
        else:
            hunks = get_added_hunks(changed_file, base_ref=base_ref)
            file_lines = get_file_contents(changed_file)

        if not file_lines:
            continue

        for hunk in hunks:
            meaningful = extract_meaningful_lines(hunk)
            blocks = find_duplicate_blocks(meaningful)

            for start_idx, end_idx, block_normalized, block_original in blocks:
                introduced_start = meaningful[start_idx][0]
                introduced_end = meaningful[end_idx][0]
                introduced_range = (introduced_start, introduced_end)

                existing_matches = find_block_in_lines(block_normalized, file_lines, changed_file)

                for existing_start, existing_end in existing_matches:
                    # Skip if this overlaps with the introduced range
                    if ranges_overlap(introduced_range, (existing_start, existing_end)):
                        continue

                    matches.append(DuplicateMatch(
                        introduced_file=changed_file,
                        introduced_lines=(introduced_start, introduced_end),
                        existing_file=changed_file,
                        existing_lines=(existing_start, existing_end),
                        content=list(block_original)
                    ))

    return dedupe_matches(matches)


def dedupe_matches(matches: list[DuplicateMatch]) -> list[DuplicateMatch]:
    """Remove redundant matches, keeping longest blocks."""
    if not matches:
        return []

    # Group by (introduced_file, existing_file)
    grouped = defaultdict(list)
    for m in matches:
        key = (m.introduced_file, m.existing_file)
        grouped[key].append(m)

    result = []
    for key, group in grouped.items():
        # Sort by block size descending
        group.sort(key=lambda m: -len(m.content))

        kept = []
        for m in group:
            # Check if this match is subsumed by an already-kept match
            subsumed = False
            for k in kept:
                if (k.introduced_lines[0] <= m.introduced_lines[0] and
                    m.introduced_lines[1] <= k.introduced_lines[1] and
                    k.existing_lines[0] <= m.existing_lines[0] and
                    m.existing_lines[1] <= k.existing_lines[1]):
                    subsumed = True
                    break
            if not subsumed:
                kept.append(m)

        result.extend(kept)

    return result


@dataclass
class InternalDuplicate:
    """A block that appears multiple times within a file."""
    file: str
    locations: list[tuple[int, int]]  # [(start, end), ...]
    content: list[str]


def find_duplicates_in_file(filepath: str) -> list[InternalDuplicate]:
    """Find duplicate blocks within a single file."""
    file_lines = get_file_contents(filepath)
    if not file_lines:
        return []

    meaningful = _build_meaningful_lines(file_lines, filepath)
    if len(meaningful) < MIN_BLOCK_SIZE:
        return []

    # Find all blocks of MIN_BLOCK_SIZE and track their locations
    # Key by normalized content, store (start_line, end_line, original_content_tuple)
    block_locations = defaultdict(list)

    i = 0
    while i <= len(meaningful) - MIN_BLOCK_SIZE:
        run_end = i + 1
        while run_end < len(meaningful):
            gap = meaningful[run_end][0] - meaningful[run_end - 1][0]
            if gap > 3:
                break
            run_end += 1

        run_length = run_end - i
        if run_length >= MIN_BLOCK_SIZE:
            for j in range(run_length - MIN_BLOCK_SIZE + 1):
                start_idx = i + j
                # normalized content as key
                block_norm = tuple(norm for _, norm, _ in meaningful[start_idx:start_idx + MIN_BLOCK_SIZE])
                # original content for display
                block_orig = tuple(orig for _, _, orig in meaningful[start_idx:start_idx + MIN_BLOCK_SIZE])
                start_line = meaningful[start_idx][0]
                end_line = meaningful[start_idx + MIN_BLOCK_SIZE - 1][0]
                block_locations[block_norm].append((start_line, end_line, block_orig))

        i = run_end if run_end > i + 1 else i + 1

    # Filter to duplicates only
    duplicates = {block: locs for block, locs in block_locations.items() if len(locs) > 1}

    # Greedily extend each duplicate
    extended = {}
    for block_norm, locations in duplicates.items():
        current_norm = list(block_norm)
        current_orig = list(locations[0][2])  # use first location's original
        current_locs = [(s, e) for s, e, _ in locations]

        while True:
            new_locs = []
            ext_norm = None
            ext_orig = None

            for start_line, end_line in current_locs:
                next_line = None
                next_norm = None
                next_orig = None
                for ln, norm, orig in meaningful:
                    if ln > end_line and ln - end_line <= 3:
                        next_line = ln
                        next_norm = norm
                        next_orig = orig
                        break
                    elif ln > end_line:
                        break

                if next_line is None:
                    break

                if ext_norm is None:
                    ext_norm = next_norm
                    ext_orig = next_orig
                elif ext_norm != next_norm:
                    break

                new_locs.append((start_line, next_line))
            else:
                if len(new_locs) == len(current_locs) and ext_norm:
                    current_norm.append(ext_norm)
                    current_orig.append(ext_orig)
                    current_locs = new_locs
                    continue
            break

        extended[tuple(current_norm)] = (current_locs, tuple(current_orig))

    # Remove subsumed blocks
    final = {}
    for block_norm, (locs, block_orig) in extended.items():
        is_subsumed = False
        for other_norm, (other_locs, _) in extended.items():
            if other_norm == block_norm or len(other_norm) <= len(block_norm):
                continue

            all_contained = all(
                any(o_start <= b_start and b_end <= o_end for o_start, o_end in other_locs)
                for b_start, b_end in locs
            )
            if all_contained:
                is_subsumed = True
                break

        if not is_subsumed:
            final[block_norm] = (locs, block_orig)

    return [
        InternalDuplicate(file=filepath, locations=locs, content=list(block_orig))
        for block_norm, (locs, block_orig) in final.items()
    ]


@dataclass(frozen=True)
class _GroupKey:
    """Key for grouping duplicate matches by introduced location and content."""
    introduced_file: str
    introduced_lines: tuple[int, int]
    content: tuple[str, ...]


def print_results(matches: list[DuplicateMatch]):
    if not matches:
        sys.exit(0)

    print("=" * 70)
    print(DUPLICATE_WARNING_MESSAGE)
    print("=" * 70)
    print()

    grouped: dict[_GroupKey, list[tuple[str, tuple[int, int]]]] = defaultdict(list)
    for m in matches:
        key = _GroupKey(m.introduced_file, m.introduced_lines, tuple(m.content))
        grouped[key].append((m.existing_file, m.existing_lines))

    for key in sorted(grouped.keys(), key=lambda k: (-len(k.content), k.introduced_file)):
        duplicates = grouped[key]
        print(f"Introduced in {key.introduced_file}:{key.introduced_lines[0]}-{key.introduced_lines[1]}")
        for existing_file, existing_lines in duplicates:
            print(f"  duplicates {existing_file}:{existing_lines[0]}-{existing_lines[1]}")
        print(f"  ({len(key.content)} lines):")
        for line in key.content[:4]:
            print(f"    {line[:72]}")
        if len(key.content) > 4:
            print(f"    ... ({len(key.content) - 4} more)")
        print()

    sys.exit(1)


def print_file_results(duplicates: list[InternalDuplicate]):
    if not duplicates:
        print("No duplicate blocks found.")
        sys.exit(0)

    print(f"Found {len(duplicates)} duplicate blocks:\n")

    for dup in sorted(duplicates, key=lambda x: (-len(x.content), -len(x.locations))):
        print(f"Block of {len(dup.content)} lines appears {len(dup.locations)} times:")
        for start, end in dup.locations:
            print(f"  {dup.file}:{start}-{end}")
        print("  content:")
        for line in dup.content[:4]:
            print(f"    {line[:72]}")
        if len(dup.content) > 4:
            print(f"    ... ({len(dup.content) - 4} more)")
        print()

    sys.exit(1)


def debug_normalize_file(filepath: str):
    """Output the entire file with deep normalization applied."""
    file_lines = get_file_contents(filepath)
    if not file_lines:
        print(f"Error: could not read {filepath}", file=sys.stderr)
        sys.exit(1)

    lang_config = get_lang_config(filepath)
    if not lang_config:
        print(f"Warning: no language config for {filepath}, showing raw", file=sys.stderr)

    for i, line in enumerate(file_lines, 1):
        if lang_config:
            normalized = deep_normalize_line(line.rstrip(), lang_config)
        else:
            normalized = line.rstrip()
        print(f"{i:4d}  {normalized}")


def main():
    global MIN_BLOCK_SIZE, MIN_LINE_LENGTH, DEEP_MODE

    parser = argparse.ArgumentParser(description="Detect duplicate code blocks in staged changes")
    parser.add_argument("--file", "-f", nargs="+", metavar="FILE",
                        help="Analyze file(s) for internal duplicates (no git required)")
    parser.add_argument("--base", "-b", help="Compare HEAD against a base branch/commit (e.g., origin/master)")
    parser.add_argument("--staged", "-s", action="store_true",
                        help="With --base, analyze staged changes instead of committed changes")
    parser.add_argument("--deep", "-d", action="store_true",
                        help="Structural matching: replace identifiers with placeholders to find similar patterns")
    parser.add_argument("--debug-normalize", metavar="FILE",
                        help="Output a file with deep normalization applied (for debugging)")
    parser.add_argument("--min-block", type=int, default=MIN_BLOCK_SIZE,
                        help=f"Minimum block size (default: {MIN_BLOCK_SIZE})")
    parser.add_argument("--min-line-length", type=int, default=MIN_LINE_LENGTH,
                        help=f"Minimum line length to consider (default: {MIN_LINE_LENGTH})")
    args = parser.parse_args()

    MIN_BLOCK_SIZE = args.min_block
    MIN_LINE_LENGTH = args.min_line_length
    DEEP_MODE = args.deep

    if args.debug_normalize:
        debug_normalize_file(args.debug_normalize)
        return

    if args.file:
        all_duplicates = []
        for filepath in args.file:
            all_duplicates.extend(find_duplicates_in_file(filepath))
        print_file_results(all_duplicates)
        return

    try:
        if args.base:
            matches = find_duplicates_since_base(args.base, use_staged=args.staged)
        else:
            matches = find_duplicates_in_staged()
        print_results(matches)
    except subprocess.CalledProcessError as e:
        print(f"Git error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
