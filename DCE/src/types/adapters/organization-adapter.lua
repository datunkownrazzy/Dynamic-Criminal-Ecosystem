-- DCE Organization Adapter Type Declarations
-- This file contains ONLY type declarations for the OrganizationAdapter service.
-- The OrganizationAdapter is the service that provides organization CRUD operations for the Control Center.
-- It is provided by dce-organizations and consumed by Control Center editors.
-- No runtime logic, no business logic.

--- @class IOrganizationAdapter
--- Organization Adapter Interface for the Control Center.
---@field ListOrganizations fun():table List all organizations
---@field GetOrganization fun(orgId:string):table|nil Get organization by ID
---@field CreateOrganization fun(orgData:table):boolean, string|nil Create an organization
---@field UpdateOrganization fun(orgId:string, orgData:table):boolean, string|nil Update an organization
---@field DeleteOrganization fun(orgId:string):boolean Delete an organization


