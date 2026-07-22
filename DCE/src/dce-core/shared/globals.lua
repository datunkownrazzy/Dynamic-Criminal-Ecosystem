-- DCE Runtime Compatibility -- Sprint 1.10.2 Platform SDK Standardization
-- This file provides runtime initialization for DCE globals.
-- It is loaded via shared_scripts and must use the FiveM shared_scripts merging pattern.
--
-- NOTE: This file contains ONLY runtime initialization, never type ownership.
-- The type annotations below are BRIDGES for LuaLS workspace indexing.
-- Authoritative type declarations are in src/types/.
-- Type ownership remains in src/types/, never here.
--
-- INTERNAL / UNSUPPORTED (Sprint 1.10.2):
-- _G.DCE, _G.DCERegistry, _G.DCEEventBus, and all other internal globals
-- are Core implementation details and are NOT part of the public platform contract.
--
-- Internal globals marked as "INTERNAL" remain for backward compatibility
-- during Sprint 1, but are UNSUPPORTED and may change without notice.
--
-- The ONLY supported entry point for external resources is:
--   local DCE = exports["dce-core"]:GetDCEAPI()
--
-- No production resource may depend on _G.DCE or any internal _G.* global.

---@type DCEFramework
--- INTERNAL (UNSUPPORTED): _G.DCE is not part of the public platform contract.
--- Use exports["dce-core"]:GetDCEAPI() instead.
DCE = DCE or {}

---@type table
--- INTERNAL (UNSUPPORTED): Config is not part of the public platform contract.
Config = Config or {}