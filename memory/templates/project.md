---
name: project-example
description: "Auth middleware rewrite driven by legal compliance, not tech debt"
metadata:
  type: project
---

Auth middleware rewrite is driven by legal/compliance requirements
around session token storage.

**Why:** Legal flagged the old middleware for storing session tokens
in a way that doesn't meet new compliance requirements. This is not
a tech-debt cleanup — scope decisions should favor compliance over ergonomics.

**How to apply:** When making scope decisions on the auth rewrite,
prioritize compliance requirements over developer experience improvements.
