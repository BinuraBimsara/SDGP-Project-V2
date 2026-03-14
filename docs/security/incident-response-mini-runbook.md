# Incident Response Mini Runbook

## If Abuse Detected

1. Enable/raise App Check enforcement immediately.
2. Temporarily tighten Firestore/Storage rules for affected paths.
3. Disable vulnerable callable endpoint if needed.
4. Rotate affected API keys/secrets and re-issue tokens.
5. Review logs and identify impacted users/documents.
6. Patch, redeploy, and validate with emulator + production smoke tests.

## Post-Incident

- Add regression tests for the exploit path.
- Update rules/function validation to prevent recurrence.
- Document timeline and mitigation actions.
