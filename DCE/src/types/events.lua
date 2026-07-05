-- DCE Events Compatibility Shim
-- This file re-exports types from the new hierarchical structure.
-- Maintained for backward compatibility during migration.
-- Will be deprecated after full migration.

require "types.events.envelope"
require "types.events.admin"
require "types.events.organization"
require "types.events.dispatch"
require "types.events.evidence"
require "types.events.scenario"
require "types.events.world"
require "types.events.sdk"
