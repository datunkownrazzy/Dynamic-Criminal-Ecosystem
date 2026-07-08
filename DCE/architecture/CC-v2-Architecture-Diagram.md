# DCE Control Center v2 - Architecture Diagram

## System Architecture Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              CLIENT SIDE                                      │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────┐     ┌──────────────────┐     ┌──────────────────────────┐
│   FiveM Game     │────▶│ NUI Lifecycle    │────▶│ Desktop Environment       │
│   (Natives)      │     │ Manager          │     │ (index.html)             │
│                  │     │                  │     │                          │
│ - SetNuiFocus    │     │ - State Machine  │     │ - Windows Container      │
│ - SendNUIMessage │     │ - Clean State    │     │ - Dock/Toolbar           │
└──────────────────┘     │ - Focus Control  │     │ - Status Bar             │
                           │ - ESC Handling   │     │ - Notifications          │
                           └──────────────────┘     └──────────────────────────┘
                                    ▲                         ▲
                                    │                           │
                                    ▼                           │
                           ┌──────────────────┐                   │
                           │   EventForwarder │                   │
                           │                  │                   │
                           │ - NUI Messages   │◀──────────────────┘
                           │ - Subscriptions  │
                           └──────────────────┘
                                    ▲
                                    │
┌───────────────────────────────────┼─────────────────────────────────────────┐
│                                   │                                         │
│                         NETWORK EVENTS                                     │
│ - dce-cc:client:open              │                                         │
│ - dce-cc:client:close             │                                         │
│ - dce-cc:client:eventbus          │                                         │
└───────────────────────────────────┼─────────────────────────────────────────┘
                                    ▼

┌─────────────────────────────────────────────────────────────────────────────┐
│                              SERVER SIDE                                     │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────┐
│      init.lua    │
│                  │
│ - Service Load   │
│ - NUI Callbacks  │
│ - Commands       │
│ - Exports        │
└──────────────────┘
         ▲
         │
         ▼
┌──────────────────┐     ┌───────────────────────┐     ┌─────────────────────┐
│  ControlCenter   │────▶│   LocationEditor      │────▶│  OrganizationEditor │
│    Service       │     │     Service           │     │      Service        │
│                  │     │                       │     │                     │
│ - Session State  │     │ - CRUD Operations     │     │ - Org Management    │
│ - Event Forward  │     │ - Undo/Redo           │     │ - Territory Links   │
│ - Permissions    │     │ - Validation          │     │                     │
└──────────────────┘     └───────────────────────┘     └─────────────────────┘
         ▲
         │
         ▼
┌──────────────────┐     ┌───────────────────────┐
│ PluginRegistry   │────▶│  PermissionController │
│    Service       │     │      Controller       │
│                  │     │                     │
│ - Plugin Reg.    │     │ - Role Checks         │
│ - Manifest Mgmt  │     │ - ACE Integration     │
└──────────────────┘     └───────────────────────┘

┌──────────────────┐     ┌───────────────────────┐
│  WindowControl-  │     │   Adapters            │
│    ler           │     │                       │
│                  │     │ - Native Provider     │
│ - Window State   │     │ - MLO Provider        │
│ - Coordination   │     │ - Instanced Provider  │
└──────────────────┘     └───────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                           DCE CORE INTEGRATION                               │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────┐     ┌───────────────────────┐     ┌─────────────────────┐
│   EventBus       │◀───▶│   LocationManager     │◀───▶│   Organizations     │
│                  │     │     Service           │     │     Service         │
│ - Events         │     │                       │     │                     │
│ - Subscribing    │     │ - Provider Registry   │     │ - Org CRUD          │
└──────────────────┘     └───────────────────────┘     └─────────────────────┘
```

## Data Flow

```
User Action → Lifecycle Manager → NUI → Window Manager → Plugin → Service → EventBus → Core Systems

Example: Create Location
1. User clicks "Create Location" in World Manager plugin
2. Plugin validates form data
3. Plugin posts to dcc-location:create
4. LocationEditor service validates against schema
5. LocationEditor calls LocationManager service
6. LocationManager emits location:created event
7. EventBus forwards to all subscribers
8. Other services react to new location
9. UI updates via event subscription
```

## Plugin API Contract

```javascript
// Plugin interface that all plugins must implement
DCE.Plugins['plugin-id'] = {
    // Render plugin UI into container
    render: function(containerElement) { ... },
    
    // Optional: Handle activation (dock click)
    onActivate: function() { ... },
    
    // Optional: Event handlers
    onEvent: function(eventName, payload) { ... },
    
    // Optional: Cleanup
    onDestroy: function() { ... }
}
```

## Service Dependency Graph

```
ControlCenter (depends on: DCE.GetService)
    ├── LocationEditor (depends on: LocationManager)
    ├── OrganizationEditor (depends on: Organizations, LocationManager)
    └── PluginRegistry (standalone)

PermissionController (standalone)
WindowController (depends on: DCE.GetService)

Adapters
    ├── NativeProvider (no dependencies)
    ├── MLOProvider (no dependencies)
    └── InstancedProvider (no dependencies)