-- DCE Type System - Main Entry Point
-- Re-exports all type declarations for LuaLS discovery.
-- This file provides a single import point for the type hierarchy.
--
-- Usage:
--   require("DCE.src.types")  -- Loads all type declarations
--   DCE.types.DCEFramework    -- Access framework types

-- Runtime Types
require "types.runtime.citizen"
require "types.runtime.fivem"

-- Framework Types
require "types.framework.core"
require "types.framework.sdk"

-- Service Types
require "types.services.base"
require "types.services.logger"
require "types.services.registry"
require "types.services.scheduler"
require "types.services.eventbus"
require "types.services.plugin-manager"

-- Domain Types (flat files in domains/)
require "types.domains.world"
require "types.domains.organizations"
require "types.domains.dispatch"
require "types.domains.evidence"
require "types.domains.scenario"
require "types.domains.admin"

-- Model Types (flat files in models/)
require "types.models.region"
require "types.models.organization"
require "types.models.dispatch-call"

-- Event Envelope
require "types.events.envelope"

-- Event Types (flat files in events/)
require "types.events.organization"
require "types.events.dispatch"
require "types.events.evidence"
require "types.events.scenario"
require "types.events.world"
require "types.events.sdk"

-- Adapter Types (flat files in adapters/)
require "types.adapters.dispatch"
require "types.adapters.evidence"
require "types.adapters.mdt"
require "types.adapters.analytics"
require "types.adapters.scenario"