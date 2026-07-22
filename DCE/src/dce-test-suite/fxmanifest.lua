-- DCE Sprint 1.10 — Platform Validation Suite
-- This is NOT a gameplay system.
-- This is a validation harness for Core certification.
-- All tests consume the published SDK only.
--
-- Load order:
--   1. init.lua — Bootstrap entry point (Citizen.CreateThread)
--   2. test-harness.lua — Test utilities, assertions, reporters
--   3. phase-*.lua — Individual test phases (register on globals)
--
-- CRITICAL: test-harness.lua MUST load before any phase files
-- so that _G.DCETestHarness exists when phases are registered.
-- init.lua should be first since it creates the bootstrap thread.

fx_version 'cerulean'
game 'gta5'

author 'DCE Validation Team'
description 'DCE Sprint 1.10 Platform Validation & Integration Readiness'
version '1.0.0'

shared_scripts {
    '@dce-core/shared/globals.lua',
}

server_scripts {
    -- Bootstrap first (creates the bootstrap thread)
    'init.lua',
    -- Harness second (must exist before phases reference it)
    'test-harness.lua',
    -- Phases load after harness, so _G.DCETestHarness is available
    'phase-1-sdk-stress.lua',
    'phase-2-plugin-stress.lua',
    'phase-3-eventbus-load.lua',
    'phase-4-scheduler-stress.lua',
    'phase-5-registry-integrity.lua',
    'phase-6-memory-validation.lua',
    'phase-7-failure-injection.lua',
    'phase-8-startup-scalability.lua',
    'phase-9-sdk-docs-validation.lua',
    'phase-10-certification.lua',
}