---
name: address-pr-feedback
description: Address recent open review feedback on the current branch's pull request with minimal, discrete changes.
effort: low
disable-model-invocation: true
---

Address open PR review feedback for the current branch. This skill focuses on making small, obvious fixes rather than large refactors.

## Steps

1. **Get current branch and PR info:**
   - Run `git branch --show-current` to get the current branch name
   - Run `git remote get-url origin` to extract owner/repo (parse from git URL)

2. **Find the PR for this branch:**
   - Use `mcp__github__list_pull_requests` with `head` set to the branch name to find the PR number
   - If no PR exists, report this and stop

3. **Get review comments:**
   - Use `mcp__github__pull_request_read` with `method: "get_review_comments"` to fetch review threads
   - Filter to comments that are:
     - NOT resolved (`isResolved: false`)
     - NOT outdated (`isOutdated: false`)
     - Created within the last 2-3 days

4. **Address each comment:**
   For each qualifying comment:
   - Read the file and understand the context
   - Determine if the fix is simple (1-2 lines, obvious change)
   - If YES: make the minimal change to address the feedback
   - If NO: skip it and note it for the summary

   **Guidelines for "simple" changes:**
   - Renaming a variable or function
   - Adding/removing a single line
   - Fixing a typo or formatting issue
   - Adding a small comment or doc
   - Changing a constant or default value
   - Renames or simple copies of files

   **Also simple, even across multiple files:**
   - Renaming/moving a file or class (update all references mechanically)
   - Copying files to a new location (e.g., copying test fixtures so tests are self-contained)

   **NOT simple (skip these):**
   - Architectural changes
   - Adding new functionality
   - Removing functionality
   - Changes spanning multiple files that require *judgment* per file (not mechanical find-and-replace)
   - Anything requiring significant testing

5. **Verify changes compile:**
   - Run setup, linters or unit tests to ensure the codebase still compiles

6. **Commit immediately:**
   - Stage only the changed files
   - Commit with a short message of which reviews were addressed
   - Instead of showing actual changes, open a tmux split with `git diff --stat HEAD~1 HEAD` after committing.

7. **Report summary:**
   - List which feedback items were addressed
   - List which feedback items were skipped (and why)
   - Note if there were any compilation issues
