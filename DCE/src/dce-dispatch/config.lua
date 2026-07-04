-- DCE Dispatch Configuration

Config = Config or {}
Config.Dispatch = Config.Dispatch or {}

-- Dispatch call defaults
Config.Dispatch.DefaultPriority = "medium"
Config.Dispatch.CallTimeout = 600  -- seconds before an unanswered call expires

-- Native adapter settings
Config.Dispatch.Native = {
    EnableBlips = true,
    EnableNotifications = true,
    BlipSprite = 40,      -- default suspicious activity blip
    BlipColor = 1,        -- red
    NotificationPrefix = "[DCE Dispatch] ",
}

-- Integration settings
Config.Dispatch.Integration = {
    Mode = "native", -- "native", "ers", or "custom"
    ResourceName = "ers",
    ExportName = "DCEDispatchAdapter",
    EnableStandaloneFallback = true,
}
