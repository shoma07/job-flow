# Security

## Secrets and sensitive data

- Do not commit API keys, tokens, passwords, private keys, or other secrets.
- Stop and ask if a value looks like a secret or production credential.

## Restricted operations

- Do not modify files outside the repository root.

## Dependency and code safety

- Prefer existing repository dependencies and tools over introducing new ones.
- Avoid risky shell operations, destructive git commands, and history rewriting unless explicitly requested.
- Surface errors instead of silently swallowing them.

## Unconfirmed items

- External secret-management system used by maintainers
