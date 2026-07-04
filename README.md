# DCE — Dynamic Criminal Ecosystem
A modular simulation framework for FiveM that creates a persistent, evolving criminal underworld for roleplay servers. Organizations make autonomous decisions based on resources, territory, law enforcement pressure, and environmental conditions — dispatch calls, investigations, and pursuits emerge from the world's state instead of being spawned as standalone scripted events.

Start here: docs/01_Project/Vision.md


# Status

🚧 Pre-implementation. Foundation and Architecture documentation complete. Core implementation in progress.

Documentation Map

Phase 1 — Foundation (docs/01_Project/)


Vision — what DCE is and why it exists
Philosophy — how we reason about design decisions
Goals — what v1.0 must deliver, what's deferred, what failure looks like
Glossary — consistent terminology used across code and docs
PROJECT_PRINCIPLES — the non-negotiables every change is checked against


Phase 2 — Architecture (docs/02_Architecture/, specifications/)


Architecture Overview — module map and resource boundaries
DCE-0001: Service Registry
DCE-0002: Event Bus
Lifecycle & Dependency Resolution
Coding Standards & AI Developer Guide
DCE-0003: Plugin Manifest Specification
Configuration Philosophy


Phase 3 — Core (docs/03_Core/, specifications/) — in progress


Core Overview
Scheduler
Logger
Configuration (implementation spec)


Phase 4 — Simulation (docs/04_Simulation/) — planned


World Engine
Simulation Layers
Regions
Weather
Time


# Repository Structure

DCE/
 docs/
    01_Project/
    02_Architecture/
    03_Core/
    04_Simulation/
    specifications/    # immutable-until-revised engineering specs (DCE-XXXX)
    architecture/       # ADRs — Architecture Decision Records
    diagrams/
    schemas/            # JSON/YAML config & plugin manifest examples
    examples/
    sdk/
    tests/
    src/
    plugins/
    tools/

Core Principle


Crime is simulated, not spawned.



See PROJECT_PRINCIPLES.md for the full list every design decision is checked against.

Contributing / Working With AI Assistants

If you're implementing against these specs (human or AI), read Coding Standards & AI Developer Guide before writing code — it explains how to work within the Service Registry / Event Bus pattern and what to flag rather than silently work around.

License
GNU GENERAL PUBLIC LICENSE Version 3