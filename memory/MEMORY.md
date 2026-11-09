# Memory Index

This file is always loaded into the AI's conversation context. Each entry is a pointer
to a standalone memory file. Lines after 200 are truncated, so keep this concise.

* [User Profile](templates/user.md) — Role, preferences, communication style
* [Feedback: Testing Approach](templates/feedback.md) — Integration tests must hit real DB, not mocks
* [Project: Auth Rewrite](templates/project.md) — Legal/compliance-driven, not tech debt
* [Reference: Bug Tracker](templates/reference.md) — Pipeline bugs tracked in Linear "INGEST"
