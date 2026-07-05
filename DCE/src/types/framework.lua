-- DCE Framework Compatibility Shim
-- This file re-exports types from the new hierarchical structure.
-- Maintained for backward compatibility during migration.
-- Will be deprecated after full migration.
--
-- NOTE: This is a compatibility shim only. It must never redefine classes.
-- The authoritative DCE declaration is in types/framework/core.lua.

-- Reference the new framework types
require "types.framework.core"
require "types.framework.sdk"