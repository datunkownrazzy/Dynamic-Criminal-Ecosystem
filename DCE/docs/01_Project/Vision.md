# DCE Vision

**Status:** Accepted
**Version:** 1.0
**Owner:** Datunknownrazzy
---

## What DCE Is

Dynamic Criminal Ecosystem (DCE) is a modular simulation framework for FiveM that creates a persistent, evolving criminal underworld for roleplay servers.

Criminal organizations make autonomous decisions based on resources, territory, pressure from law enforcement, and environmental conditions. Rather than spawning isolated callouts, DCE simulates causes and consequences, allowing dispatches, investigations, pursuits, and emergency responses to emerge naturally from the world's state.

## The Problem DCE Solves

Most FiveM "gang AI" resources are event generators. They spawn a robbery, a shootout, or a drug deal on a timer, let players respond, then clean everything up and reset. Every incident is self-contained. Nothing a server experiences today changes what it experiences tomorrow. The world doesn't remember.

This makes servers feel repetitive over time. Players start recognizing the scripted patterns. Police work stops mattering beyond the current call, because there's no persistent criminal structure being weakened or strengthened by it.

## The Core Idea

**Crime is simulated, not spawned.**

DCE runs an ongoing criminal economy in the background — organizations earn money, hold territory, recruit, patrol, and react to pressure — whether or not any player is nearby. When something crosses into a player's radius, the world "materializes" the relevant detail: NPCs, vehicles, dispatch calls, evidence. When players intervene — an arrest, a raid, a killed leader, a seized shipment — the consequences persist and ripple forward into how that organization behaves next.

Dispatch calls, investigations, and roleplay scenarios are not designed as standalone content. They are the visible surface of an underlying simulation that keeps running.

## Who This Is For

- **Server owners** who want their city to feel alive and continuous, where player and police actions have lasting weight.
- **Police/EMS/detective roleplayers** who want investigative work to build toward something instead of resolving in a single call.
- **Developers** who want to extend or integrate with a criminal-simulation framework rather than write one from scratch — through adapters (CAD/MDT/evidence) and plugins (new organizations, behaviors, scenario packs).

## What Success Looks Like

- A server can run for months and no two weeks unfold the same way, because outcomes compound instead of resetting.
- Police investigations produce visible, lasting change in organizations — not just an arrest report.
- A dispatcher receives realistically imperfect information (what a witness reports), not omniscient ground truth.
- Other developers can build plugins (new organizations, new CAD/MDT adapters, new scenario types) without touching DCE's core.
- The framework remains configurable enough that a heavily roleplay-focused server and a fast-paced action-focused server can both use it and feel appropriately different.

## What DCE Is Not

- It is not a random-event spawner. Every event should be explainable by the current world state — resources, heat, territory, time, weather — not a bare timer roll.
- It is not a single monolithic script. It is a set of independently useful services connected by clear interfaces.
- It is not tied to one CAD/MDT/dispatch resource. Integration is adapter-based by design.
- It is not "finished" at v1.0. The architecture exists specifically so the simulation can grow (more organization types, deeper economy, civilian systems) without being rewritten.

## Guiding Principle

Every design decision should be testable against one question:

> **Does this make the world feel like it has memory and consequence, or does it make the world feel like a set of buttons that reset?**

If a proposed feature can't clearly support the first answer, it doesn't belong in DCE core — it belongs in a plugin, or it doesn't belong at all.
