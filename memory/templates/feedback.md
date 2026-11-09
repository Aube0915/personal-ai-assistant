---
name: feedback-example
description: "Behavioral correction: always use real DB in integration tests, never mocks"
metadata:
  type: feedback
---

Integration tests must hit a real database, not mocks.

**Why:** Prior incident where mock/prod divergence masked a broken migration.
The mocked tests passed but the production migration failed, causing a 4-hour outage.

**How to apply:** When writing or reviewing integration tests, always spin up
a real test database. Mock only at unit-test level for isolated logic.
