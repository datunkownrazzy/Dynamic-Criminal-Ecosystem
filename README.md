# DCE — Dynamic Criminal Ecosystem

DCE is a modular simulation framework for FiveM that aims to make criminal organizations feel persistent, adaptive, and consequential rather than scripted. The project is built around the idea that crime should be simulated from underlying state — resources, territory, heat, time, weather, and pressure — so that dispatches, investigations, and pursuits emerge naturally from the world instead of being spawned as isolated events.

> Core principle: crime is simulated, not spawned.

## What this repository contains

This repository currently focuses on the design and engineering foundation of DCE:

- Architecture and product documentation in [DCE/docs](DCE/docs)
- Engineering specifications in [DCE/specifications](DCE/specifications)
- Architecture decision records in [DCE/architecture](DCE/architecture)
- Project guidance and contribution standards in [DCE/CONTRIBUTING.md](DCE/CONTRIBUTING.md) and [DCE/STYLE_GUIDE.md](DCE/STYLE_GUIDE.md)

This is not yet a drop-in FiveM resource package; it is the planning, architecture, and specification backbone for the framework.

## Current status

- Documentation and architecture foundations are in place.
- Core implementation work is still in progress.
- The project is centered on the v1.0 milestone, with goals around background simulation, persistence, evidence handling, escalation, plugin extensibility, and admin visibility.

## Start here

If you are new to the project, the best entry points are:

1. [DCE/docs/01_Project/Vision.md](DCE/docs/01_Project/Vision.md) — the high-level purpose and direction of DCE
2. [DCE/docs/01_Project/Goals.md](DCE/docs/01_Project/Goals.md) — the v1.0 milestones and deferred work
3. [DCE/docs/02_Architecture/Architecture_Overview.md](DCE/docs/02_Architecture/Architecture_Overview.md) — the overall architecture and module boundaries
4. [DCE/docs/01_Project/AI_Developer_GUIDE.md](DCE/docs/01_Project/AI_Developer_GUIDE.md) — guidance for contributors and AI-assisted development

## Documentation map

- Foundation: [DCE/docs/01_Project](DCE/docs/01_Project)
- Architecture: [DCE/docs/02_Architecture](DCE/docs/02_Architecture)
- Core systems: [DCE/docs/03_Core](DCE/docs/03_Core)
- Simulation layers: [DCE/docs/04_Simulation](DCE/docs/04_Simulation)
- Organizations and territories: [DCE/docs/05_Organizations](DCE/docs/05_Organizations) and [DCE/docs/06_Territories](DCE/docs/06_Territories)
- Dispatch, evidence, and investigations: [DCE/docs/10_Dispatch](DCE/docs/10_Dispatch), [DCE/docs/11_Evidence](DCE/docs/11_Evidence), and [DCE/docs/12_Investigations](DCE/docs/12_Investigations)

## Repository layout

- [DCE/docs](DCE/docs) — project documentation organized by domain
- [DCE/specifications](DCE/specifications) — engineering specifications that define the core interfaces and contracts
- [DCE/architecture](DCE/architecture) — architecture decision records
- [DCE/CHANGELOG.MD](DCE/CHANGELOG.MD) and [DCE/ROADMAP.md](DCE/ROADMAP.md) — release history and planning notes

## Contributing

If you are implementing against these specifications, start with [DCE/docs/02_Architecture/Coding_Standards.md](DCE/docs/02_Architecture/Coding_Standards.md) and [DCE/docs/01_Project/PROJECT_PRINCIPLES.md](DCE/docs/01_Project/PROJECT_PRINCIPLES.md). They describe the architectural rules, service/event boundaries, and expectations for contributing safely.

## License

This project is licensed under the GNU General Public License v3. See [DCE/LICENSE](DCE/LICENSE).