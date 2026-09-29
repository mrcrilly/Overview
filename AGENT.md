# Instructions for Codex and AI contributors

## Automatically commit changes

Automatically create a local Git commit for all changes you make as part of each
completed task. Do not wait for the user to request a commit or ask for confirmation
before committing, unless the user explicitly instructs otherwise.

Before committing:

1. Inspect the working tree and distinguish your task's changes from pre-existing
   or unrelated user changes.
2. Review your diff and run checks appropriate to the change. Fix issues caused by
   your changes and report any checks that could not run.
3. Stage all task-related additions, modifications, and deletions, leaving unrelated
   changes untouched unless the user explicitly asks to include them.
4. Commit with a concise, descriptive message explaining the change.
5. Verify the commit and report its short hash along with any remaining changes.

Do not create empty commits. If committing is blocked, report the reason and the
uncommitted work. Automatic committing does not authorize pushing to a remote,
amending existing commits, or rewriting history.
