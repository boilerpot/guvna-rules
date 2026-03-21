---
name: guvna-check
description: Audit the governance setup in this repository — check config, hooks, and policy coverage
user_invocable: true
---

# /guvna-check

Audit the governance configuration for this repository.

## Steps

1. **Check guvna.yml**: Does it exist? Are protected paths configured? Are reviewers set?

2. **Check .guvna-rules.yml**: Does it exist? What settings are active (prettier, typecheck, deny patterns)?

3. **Check guvna GitHub App**: Is there a `.github/` directory? Are there workflow files that could benefit from protection?

4. **Scan for gaps**:
   - Are there `.env` files not covered by protected paths?
   - Are there migration directories not protected?
   - Are there auth/security directories not protected?
   - Is TypeScript present but typecheck disabled?
   - Are there files that should be in deny patterns?

5. **Report findings** in a clear format:
   ```
   Governance Audit
   ================
   guvna.yml:        [found/missing]
   .guvna-rules.yml: [found/missing]
   Protected paths:  X configured
   Reviewers:        X configured
   Prettier:         [enabled/disabled]
   Typecheck:        [enabled/disabled]
   Deny patterns:    X configured

   Suggestions:
   - Consider protecting .github/workflows/**
   - Consider adding reviewers
   ```

6. Offer to fix any issues found (create missing config, add suggested protected paths).
