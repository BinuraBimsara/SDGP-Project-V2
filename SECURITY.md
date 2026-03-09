# Security Policy

This project uses Firebase security controls and server-authoritative mutations.

## Reporting

Report vulnerabilities privately to project maintainers. Do not open public issues for active vulnerabilities.

## Core Controls

- Firestore least-privilege rules for users, complaints, comments, and counters.
- Storage rules restrict uploads/reads to authenticated users and enforce image constraints.
- Callable Cloud Functions require auth + App Check and validate arguments.
- Android release avoids debug signing, disallows cleartext traffic, and disables backup extraction.

## Security Baseline

- Keep dependencies updated.
- Keep Firebase rules and function input validation in sync.
- Use App Check enforcement in production.
- Promote privileged roles only from trusted backend/admin flow.
