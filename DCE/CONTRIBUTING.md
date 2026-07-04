# Contributing to DCE

This project uses the architecture and service-boundary rules described in the repository docs and in [AGENTS.md](AGENTS.md).

## Contribution Expectations

- Follow the documented ownership model and avoid direct cross-service state mutation.
- Prefer updates to the relevant spec or architecture doc before implementation changes.
- Keep changes scoped to the owning service and document any new event or config contract.

## Review Checklist

- Does the change preserve the service ownership model?
- Does it use the Event Bus for cross-module state changes?
- Does it keep configuration values in config rather than hardcoding them?
- Does it document any new public API or event payload?
