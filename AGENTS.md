# DCE AI Agent Instructions

## Your Role
You are contributing to the **Dynamic Criminal Ecosystem (DCE)**. DCE is a simulation framework, not a collection of scripted events. Every change must preserve modularity, scalability, and long-term maintainability.

---

## Core Philosophy
* **Crime is never spawned; it emerges from simulation.**
* Every feature must support this philosophy. Everything should answer: *"Why did this happen?"* instead of *"How do we spawn this?"*

---

## 1. Architectural Rules (Mandatory)

### Service Ownership & Registry
* **No Feature Without an Owner:** Every feature must belong to exactly one service. If ownership is unclear, architecture must be updated before implementation.
* **Service Registry:** Services never directly instantiate other services. Always request them through `DCE:GetService()`. Never bypass the registry.
* **Separation of Concerns:** Data and Logic are distinct. If a system is an **Adapter** (e.g., ERS, ox_inventory), it only translates data; it never owns it.

### Event Bus & Communication
* **Event-Driven:** Modules communicate exclusively through the Event Bus.
* **State Changes:** Emit events for state transitions (e.g., `Operation.StateChanged`), not for task execution (e.g., `RunEvidenceGeneration`).
* **Decoupling:** Never call another module's internals directly. 

### Data & Configuration
* **Data-Driven:** Never hardcode organizations, territories, addresses, or crime weights. Use `/schemas/` and configuration files.
* **Tunable:** Every threshold, probability, and interval must be in `Config`. Validate all configs at startup.

### Performance & Safety
* **Async Only:** No blocking server threads. Every SQL call must be async.
* **Graceful Degradation:** Features must define their tick frequency and performance budget. Never assume unlimited CPU.
* **Dependency Safety:** Always handle `DCE:GetService()` returning `nil`. Plugins and adapters must be removable without breaking Core.

---

## 2. The Operations Lifecycle
All criminal activities must follow the simulation-first model:
1. **Strategic Goal** (Organization)
2. **Operations Planner** (Strategy Layer)
3. **Operations Engine** (Simulation Layer)
4. **World Manifestation** (Player Interaction Layer)

---

## 3. Architecture Review Checklist
**Before proposing any code, verify:**
- [ ] Does a service already own this responsibility?
- [ ] Does this introduce duplicate ownership?
- [ ] Does this require an ADR (Architecture Decision Record)?
- [ ] Does this require an Event Bus event?
- [ ] Can this be implemented as a plugin?
- [ ] Is configuration data separated from code?
- [ ] Does it support persistence?
- [ ] Is it integration-agnostic?
- [ ] Is performance/LOD documented?
- [ ] Are failure states documented?

*If any answer is "No" or "Unknown", stop and document the architecture first.*

---

## 4. Documentation & Standards
* **ADRs:** Every architectural change requires an ADR in `/architecture/`.
* **Inline Docs:** Document every public API (Service functions/Event payloads) where defined.
* **Terminology:** Use `Organization`, `Agent`, `Operation`, `Incident`, `Territory`, `Heat`, `Intelligence` as defined in `docs/01_Project/Glossary.md`.
* **Clean Code:** Small files, clear boundaries, composition over inheritance. 
* **Shutdown:** Clean up all registrations and subscriptions on `onResourceStop`.

---

## 5. Agent Workflow
1. **Check for an existing spec** in `specifications/` or `docs/` before designing a new mechanism. 
2. **If no spec exists**, propose one before writing code.
3. **If a spec is ambiguous/wrong**, flag it explicitly for discussion.
4. **Breaking Changes:** Renaming events, services, or config keys is a breaking change; it requires a version bump and an ADR.
5. **No "While you're in there":** Only perform the smallest change that satisfies the rules. Do not restructure unrelated code.

---

*If a user request conflicts with these rules, you must explicitly state the conflict, propose the compliant alternative, and wait for confirmation before proceeding.*