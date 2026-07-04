# DCE Style Guide

## Terminology

Use the terminology defined in [docs/01_Project/Glossary.md](docs/01_Project/Glossary.md): Organization, Agent, Operation, Incident, Territory, Heat, and Intelligence.

## Documentation Style

- Prefer concise, architecture-focused prose over narrative filler.
- Keep service ownership, event contracts, and config dependencies explicit.
- Use the existing naming conventions for services and events.

## Code Style

- Keep modules small and ownership-focused.
- Prefer registration through the Service Registry over direct cross-module imports.
- Make behavior configurable and document public APIs.
