# Threat Model Summary

## Key Risks Addressed

- Privilege escalation via client-side role writes.
- Counter tampering (`upvoteCount`, `commentCount`) from direct client updates.
- Untrusted callable invocation without App Check.
- Over-broad public storage reads.
- Insecure Android release posture (debug signing, backups, cleartext).

## Remaining Risks

- Missing explicit rate limiting for abuse-heavy endpoints.
- Need periodic dependency and rules audits.
- Need operational alerting for suspicious auth patterns.
