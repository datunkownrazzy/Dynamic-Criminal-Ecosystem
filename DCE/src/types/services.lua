-- DCE Services Compatibility Shim
-- This file re-exports types from the new hierarchical structure.
-- Maintained for backward compatibility during migration.
-- Will be deprecated after full migration.

require "types.services.base"
require "types.services.logger"
require "types.services.registry"
require "types.services.scheduler"
require "types.services.eventbus"
require "types.services.plugin-manager"
