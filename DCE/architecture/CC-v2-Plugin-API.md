# DCE Control Center v2 - Plugin API

## Overview

The Control Center uses a plugin architecture where external DCE resources can register UI extensions. This allows adding functionality without modifying the core.

## Plugin Manifest Structure

Plugins register via their resource's `fxmanifest.lua`:

```lua
fx_version 'cerulean'
games { 'gta5', 'rdr3' }

author 'Your Name'
description 'Plugin Description'
version '1.0.0'

client_scripts {
    'client/plugin.lua'
}

server_scripts {
    'server/plugin.lua'
}

-- Optional: Register with Control Center
lua_modules {
    'shared/manifest.lua'
}
```

## Registering a Plugin

In your plugin's server code:

```lua
-- server/plugin.lua
local DCE = exports['dce-core']:GetDCEAPI()

-- Get the PluginRegistry service
local PluginRegistry = DCE and DCE.GetService and DCE.GetService("PluginRegistry")

if PluginRegistry then
    PluginRegistry.Register(GetCurrentResourceName(), {
        Name = "My Awesome Plugin",
        Version = "1.0.0",
        Description = "Does something awesome",
        
        -- UI definitions
        ControlCenter = {
            windows = {
                {
                    id = "my-plugin-window",
                    title = "My Window",
                    icon = "🔧",
                    width = 800,
                    height = 600,
                    category = "tools"
                }
            },
            
            toolbar = {
                {
                    id = "my-plugin-btn",
                    icon = "🔧",
                    tooltip = "My Plugin",
                    category = "tools"
                }
            }
        },
        
        -- Events this plugin publishes
        Provides = {
            "event:my-plugin:action"
        }
    })
end

-- Listen for plugin initialization
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Your plugin setup here
    end
end)
```

## Client-Side Plugin Interface

In your plugin's client code:

```javascript
// client/plugin.lua (via resource file)
(function() {
    'use strict';

    // Wait for DCE to be available
    const waitForDCE = setInterval(() => {
        if (window.DCE) {
            clearInterval(waitForDCE);
            
            // Register your plugin
            DCE.Plugins['my-plugin-window'] = {
                // Required: Render plugin UI
                render: function(container) {
                    container.innerHTML = `
                        <div class="card">
                            <div class="card-header">My Plugin</div>
                            <div>Your plugin content here</div>
                        </div>
                    `;
                    
                    this.bindEvents();
                },
                
                // Optional: Bind event handlers after render
                bindEvents: function() {
                    // Your event binding code
                },
                
                // Optional: Handle DCE EventBus events
                onEvent: function(eventName, payload) {
                    switch(eventName) {
                        case 'location:created':
                            this.refreshData();
                            break;
                    }
                },
                
                // Optional: Cleanup when window closes
                onDestroy: function() {
                    // Clean up timers, subscriptions, etc.
                }
            };
        }
    }, 100);
})();
```

## NUI Callbacks

Plugins can expose server callbacks through NUI:

```lua
-- Server-side callback
RegisterNUICallback('my-plugin:action', function(data, cb)
    -- Handle action
    cb({ success = true })
end)
```

## Permission Scopes

Plugins can request specific permission scopes:

```lua
-- In manifest
Permissions = {
    required = { "location:edit", "organization:view" },
    optional = { "location:delete" }
}
```

## EventBus Integration

Plugins can subscribe to DCE events:

```javascript
// In plugin render
DCE.Notifications.info('Subscribing to location updates...');

DCE.NUI.post('dcc-eventbus:subscribe', { 
    eventName: 'location:created' 
});

DCE.NUI.post('dcc-eventbus:subscribe', { 
    eventName: 'location:updated' 
});
```

## Hot Reload Support

The Control Center supports hot reloading of plugin scripts. When a plugin resource restarts:

1. Plugin unregisters from PluginRegistry
2. NUI receives `lifecycle:cleanup` message
3. Plugin re-registers on resource start
4. UI rebuilds from plugin manifest

## Plugin Categories

- `world` - Location/territory management
- `organization` - Organization-related tools
- `dispatch` - Police/fire/EMS tools
- `evidence` - Evidence/crime scene tools
- `ai` - Population/AI controls
- `analytics` - Metrics and monitoring
- `services` - DCE service management
- `tools` - General utilities

## Built-in Plugin IDs

These are reserved and cannot be used by custom plugins:
- `world-manager`
- `organization-manager`
- `dispatch-manager`
- `evidence-manager`
- `ai-manager`
- `analytics`
- `server-monitor`
- `dev-tools`