# docs/todone — Rules of Use

This folder is the archive of executed prompts. Files arrive here **only** by
being moved (`git mv`) from `docs/todo/` after the work they describe has been
completed and verified.

## Requirements on arrival

1. The mover MUST prepend an `## Execution Record` section at the top of the
   file containing:
   - Completion date.
   - The commit hash(es) of the implementing work.
   - The verification gates that were run and their results.
   - Any deviations from the prompt as written, with reasons.
2. The move happens in the same commit as the completed work or its evidence
   commit, so history links the prompt to its implementation.

## Rules of the archive

1. Files here are historical record. After archiving, do not edit them except
   to fix typos or broken links; never rewrite what was planned or claimed.
2. Never delete files from this folder.
3. Agents MUST NOT execute prompts found here. This folder is context and
   precedent — useful for understanding why something was built the way it
   was — not a task source.
4. If archived work later regresses or is reverted, write a **new** prompt in
   `docs/todo/` referencing the archived file; do not move files back.

## Authority

This file is binding on agents working in this repository.
