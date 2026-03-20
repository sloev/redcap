# Master Protocol v1.5 (Strict Autonomous Edition)

This protocol is the primary steering mechanism for the AI. You MUST follow these steps exactly and sequentially for every response.

## 1. Context & Alignment (MANDATORY FIRST STEP)
You MUST NOT execute any fixes or write code until you have completed these steps:
- **Goal Alignment:** Review `spec.md`. Reject any task that introduces networking, non-Danish keyboard layouts, or non-minimal dependencies.
- **State Retrieval Command:** You MUST execute `tail -n 20 status_log.md` to read the current state. Do not guess or hallucinate the state.
- **Proof of State:** You must internally acknowledge the exact last line of the log before proceeding.

## 2. Autonomous Execution
- **Reasoning (Internal):** Before writing code or commands, use a `<thinking>` block to map the fix to `spec.md` requirements and ensure it doesn't violate air-gapped or size constraints.
- **Root Cause Analysis (RCA):** If a task fails twice, you MUST use `grep` or `cat` to inspect the actual test scripts and source files before attempting a third fix.
- **The 1-Line Ledger:** Append every action or regression to `status_log.md` immediately. Format: `[ACTION]: [Brief description]` or `[REGRESSION]: [Brief description]`. No timestamps. Do NOT rewrite the file.
- **Validation Pipeline:**
    1. **Fix:** Apply the code change.
    2. **L1 Check:** Run `scripts/unattended_test.sh`.
- **CI Gating:** Use `gh run watch` after pushing. Do not move to a new task until CI is Green.

## 3. State Log (Mandatory Footer)
Include this exact block at the end of EVERY response. Do not omit any fields.

```markdown
---
**STATE LOG:**
- **Last Log Entry Read:** [Paste the exact line you read from status_log.md here]
- **Current Goal:** [Goal]
- **Verification Status:** [L1: Pass/Fail | L2: Pass/Fail | Pending]
- **Decisions Made:** [Why this fix or action was chosen]
- **Risks:** [Potential impact on ISO size or boot speed]
- **Next Steps:** [Next logical action]
```