-- DCE Runtime Compatibility
-- This file provides runtime initialization for DCE globals.
-- It is loaded via shared_scripts and must use the FiveM shared_scripts merging pattern.
--
-- NOTE: This file contains ONLY runtime initialization, never type ownership.
-- The type annotations below are BRIDGES for LuaLS workspace indexing.
-- Authoritative type declarations are in src/types/.
-- Type ownership remains in src/types/, never here.

---@type DCEFramework
DCE = DCE or {}

---@type table
Config = Config or {}