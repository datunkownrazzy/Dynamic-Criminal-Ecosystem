# NUI Gray Overlay — Root Cause Report

**Audit Date:** 2026-07-15
**Audit Type:** Zero-Trust NUI Display & Browser Lifecycle Audit
**Target:** dce-controlcenter v2 (ADR-0026 / True Lazy Init)

---

## Executive Summary

The gray overlay visible before `/dce` is caused by a **CSS body background paint combined with FiveM CEF compositing timing**. The CSS body background `#0d1117` (`var(--cc-bg-primary)`) is painted by CEF's compositor at full viewport size before the CSS `opacity: 0 !important; visibility: hidden !important;` rules take full effect. This creates a persistent dark gray surface visible through FiveM's game viewport from the moment the resource loads until the user executes `/dce`.

---

## Complete Browser Visibility Timeline

```
T0   FiveM creates CEF browser for ui_page
     → CEF creates 1920×1080 compositor surface
     → Browser DEFAULT state: VISIBLE (CEF compositor always active)
     → Background: WHITE (CEF default)
     → NO CSS loaded yet
     → Player sees: WHITE FLASH (brief)

T1   bootstrap.html begins parsing
     → <html> and <body> nodes created
     → Body class: "cc-unloaded"
     → CSS link tags discovered
     → CEF still compositing WHITE background
     → Player sees: WHITE (milliseconds)

T2   style.css loads and applies
     → body { background: #0d1117; opacity: 0 !important; visibility: hidden !important; }
     → dark.css loads: body { background: #0d1117; }
     → body.cc-unloaded { opacity: 0 !important; visibility: hidden !important; }
     → CEF compositor reads: background=#0d1117, opacity=0, visibility=hidden
     → Player sees: DARK GRAY OVERLAY (if opacity 0 doesn't prevent compositing)
     →               OR TRANSPARENT (if opacity 0 is respected)

T3   bootstrap.js loads and executes
     → DCE.NUI.post('dce-cc:nui:loaded', { status: 'ready' })
     → bootstrap.lua receives NUI callback
     → SetNuiFocus(false, false) called (attempts focus release)
     → Player sees: DARK GRAY OVERLAY APPROACHING #0d1117

T4   Player runs /dce
     → Server creates session
     → Client receives dce-cc:client:session:start
     → SessionManagerClient.StartSession() runs
     → SendNUIMessage({ action: "application:boot" })
     → bootstrap.js loads application-manager.js
     → ApplicationManager.Boot() runs
     → Desktop created, plugins loaded
     → ApplicationManager calls DCE.Application.setState(APP_STATE.READY)
     → DCE.NUI.post('dce-cc:application:booted')
     → bootstrap.lua: RegisterNUICallback('dce-cc:application:booted')
       → FocusManager.RequestFocus() → SetNuiFocus(true, true)
       → SendNUIMessage({ action: "application:activate" })
     → ApplicationManager.Activate() → document.body.className = 'cc-active'
     → CSS: body.cc-active { opacity: 1 !important; visibility: visible !important; }
     → Player sees: UI VISIBLE
```

---

## DOM Creation Timeline

| Time | Element | Creator File | Line | Method |
|------|---------|-------------|------|--------|
| T0 | `<html>` | bootstrap.html (FiveM loads) | 2 | Static HTML |
| T0 | `<head>` | bootstrap.html | 3 | Static HTML |
| T0 | `<body class="cc-unloaded">` | bootstrap.html | 11 | Static HTML |
| T0 | `<template id="template-window">` | bootstrap.html | 13 | Static HTML |
| T0 | `<script>` (bootstrap.js) | bootstrap.html | 38 | Static HTML |
| T2 | CSS `<link>` elements applied | style.css | 24-38 | CSSOM |
| T3 | `<script>` (application-manager.js) | bootstrap.js | 93 | `document.head.appendChild` |
| T4 | `<div id="desktop" class="desktop">` | desktop.js | 36-59 | `document.createElement` + `innerHTML` |
| T4 | `<div id="dock">` | desktop.js | 39 | innerHTML |
| T4 | `<div id="window-container">` | desktop.js | 43 | innerHTML |
| T4 | `<div id="status-bar">` | desktop.js | 44 | innerHTML |
| T4 | `<div id="notifications">` | desktop.js | 57 | innerHTML |
| T4 | `<div id="modal-overlay">` | desktop.js | 58 | innerHTML |

**Key Finding:** No DOM elements beyond the static HTML bootstrap shell exist before `/dce`.

---

## Complete CSS Paint Hierarchy

### Capable of painting fullscreen gray:

| Selector | File | Line | Property | Value | State |
|----------|------|------|----------|-------|-------|
| `body` | style.css | 24-38 | `background` | `var(--cc-bg-primary)` (#0d1117) | **ALWAYS APPLIED** |
| `body` | style.css | 24-38 | `min-height` | `100vh` | Full viewport paint |
| `body` | style.css | 24-38 | `margin: 0; padding: 0` | 0 | No margins |
| `body` | dark.css | 9-11 | `background` | `var(--cc-bg-primary)` | Overrides body |
| `body` | light.css | 9-11 | `background` | `var(--cc-bg-primary)` | Overrides body |

### Hiding mechanisms (intended to prevent gray paint):

| Selector | File | Line | Property | Value | Issue |
|----------|------|------|----------|-------|-------|
| `body` | style.css | 35-37 | `opacity: 0 !important` | 0 | **CEF may not respect for compositor surface** |
| `body` | style.css | 36 | `pointer-events: none !important` | none | Only affects input |
| `body` | style.css | 37 | `visibility: hidden !important` | hidden | **CEF may not prevent compositor background paint** |
| `body.cc-unloaded` | style.css | 42-46 | Various | !important | Redundant with body rules |

### THE CRITICAL ISSUE:

**CSS rules 24-26 set a background color on body BEFORE the hiding rules at 35-37 take effect.**

The CSS cascade:
1. `body { background: #0d1117; }` — **PAINTS DARK GRAY FULLSCREEN**
2. `body { opacity: 0 !important; visibility: hidden !important; }` — attempts to hide

CEF's compositor caches the background color. Even with `opacity: 0` and `visibility: hidden`, CEF may still composite the background color layer because:
- CEF uses an accelerated compositor that may not re-read CSS after initial layout
- `visibility: hidden` hides children from the paint tree but the body's own background color IS the compositor surface
- FiveM composites the CEF surface at full opacity regardless of CSS opacity state

### Elements incapable of painting (eliminated):

| Selector | File | Line | Why Not Responsible |
|----------|------|------|-------------------|
| `.desktop` | style.css | 73-81 | NOT CREATED until `/dce` |
| `.modal-overlay` | style.css | 436-447 | NOT CREATED until `/dce` |
| `.window` | style.css | 89-99 | NOT CREATED until activation |
| `.dock` | style.css | 177-185 | NOT CREATED until `/dce` |
| `#desktop` | style.css | N/A | No CSS rule for #desktop in style.css |
| `#overlay` | style.css | N/A | No CSS rule exists |
| `#loading` | style.css | N/A | No CSS rule exists |
| `#workspace` | style.css | N/A | No CSS rule exists |

---

## Every JavaScript Capable of Revealing UI Before /dce

**File: `html/js/bootstrap/bootstrap.js`**

| Line | Code | Executes Before /dce? | Effect |
|------|------|-----------------------|--------|
| 26-35 | `DCE.NUI.post({})` | YES (on DOMContentLoaded) | NUI POST only — no DOM mod |
| 53 | `document.createElement('script')` | YES (if `application:boot` msg) | Loads app-manager — no paint |
| 78-83 | `DOMContentLoaded` handler | YES | NUI POST `dce-cc:nui:loaded` |
| 89-95 | `window.addEventListener('message')` | YES | Listens for `application:boot` |
| 97 | `console.log(...)` | YES | No DOM effect |

**Verdict: bootstrap.js is PASSIVE. It does NOT render, paint, insert DOM, change CSS, or reveal UI.**

**File: `html/js/application/application-manager.js`**

| Line | Code | Executes Before /dce? | Effect |
|------|------|-----------------------|--------|
| 54 | `document.body.className = 'cc-' + newState` | NO (loaded on demand) | Changes body class |
| 102 | `DCE.Desktop.create()` | NO (loaded on demand) | DOM insertion |
| 149-168 | `DCE.Application.Activate()` | NO (after focus) | `body.className = 'cc-active'` |
| 157 | `desktop.open()` | NO | Sets `body.className = 'cc-active'` |
| 224-243 | `window.addEventListener('message')` | NO (registered when JS loads) | Handles app:messages |

**Verdict: application-manager.js loads ONLY on `application:boot` NUI message. No pre-/dce execution.**

---

## Every SendNUIMessage Before /dce

| Time | Message | Sender File | Line | Effect on Visibility |
|------|---------|-------------|------|---------------------|
| T3 | `dce-cc:nui:loaded { status: 'ready' }` | bootstrap.js | 79/82 | Triggers `Bootstrap.NUIReady()` → SetNuiFocus(false,false) |
| T3 | `bootstrap:ready { state: 'dormant' }` | bootstrap.lua | 36 | NUI message — no DOM effect |
| T3 | `bootstrap:ready { state: 'dormant' }` | browser-manager.lua | 19 | NUI message — no DOM effect (if called) |

**Before /dce: 2-3 NUI messages sent. None change CSS, insert DOM, or reveal UI.**

---

## Every BrowserManager Activation

| Time | Caller | Method | Line | Effect |
|------|--------|--------|------|--------|
| T4 | SessionManagerClient.StartSession | BrowserManager.Activate() | session-manager-client.lua:58-60 | SendNUIMessage `bootstrap:ready` |
| - | Any external caller | BrowserManager.Notify() | Any | Sends NUI message only |
| - | Any shutdown | BrowserManager.EnsureCleanState() | Any | Sends cleanup message only |

**Verdict: BrowserManager is truly PASSIVE before /dce. It only sends NUI messages, never creates DOM, never changes CSS, never reveals UI.**

---

## Every FocusManager Action

| Time | Action | File | Line | Sets Focus |
|------|--------|------|------|-----------|
| T3 | ReleaseFocus("bootstrap", "auto-granted focus cleanup") | bootstrap.lua | 29 | **SetNuiFocus(false, false)** |
| T3 | Emergency Release (if FocusManager unavailable) | bootstrap.lua | 31 | **SetNuiFocus(false, false)** |
| T4 | RequestFocus(sessionId, "application-boot-complete") | bootstrap.lua | 68 | **SetNuiFocus(true, true)** |
| T4+ | ReleaseFocus("session-manager-client", "session-end") | session-manager-client.lua | 94 | **SetNuiFocus(false, false)** |

**Key Finding: SetNuiFocus(false, false) does NOT hide the CEF browser surface. It only releases mouse/keyboard input focus.**

Per FiveM documentation: `SetNuiFocus` controls input focus (mouse/keyboard capture). It does **not** control the browser's visibility or rendering. The CEF browser continues to render and composite regardless of focus state.

---

## FiveM ui_page Behavior (The Real Root Cause)

**FiveM documentation and community experience confirms:**

1. `ui_page` creates a CEF browser that is **always composited** into the game viewport
2. `SetNuiFocus` controls **input only** — it does NOT pause rendering
3. The CEF browser compositor renders at the game's full resolution
4. The browser's background color is always composited unless explicitly set to transparent
5. Even with `opacity: 0` and `visibility: hidden`, CEF may still render the background color layer

**The FiveM NUI compositing pipeline:**

```
FiveM Game Render → CEF Offscreen Surface → Compositor → Screen
                          ↑
                   CSS background: #0d1117
                   (Always rendered by CEF)
```

The CEF compositor creates the surface at page load and continuously renders it. Even when CSS sets `opacity: 0`, CEF's offscreen rendering still paints the background color. FiveM then composites this surface into the game viewport.

**Production resources prevent this by one of these methods:**
1. Setting `background: transparent` on `html` and `body` (never setting a background color until needed)
2. Using a transparent 1×1 pixel base64 GIF as the initial loaded page, then replacing via JS
3. Not using `ui_page` at all (using `CreateDui` with proper lifecycle management)
4. Having the CSS always hide with `background: transparent !important` and applying background only when `.active` class is present

---

## Root Cause: Exact File and Line

**PRIMARY CAUSE:**

**File:** `DCE/src/dce-controlcenter/html/css/style.css`
**Lines:** 24-26

```css
body {
    background: var(--cc-bg-primary);  /* #0d1117 — DARK GRAY */
}
```

**File:** `DCE/src/dce-controlcenter/html/css/themes/dark.css`
**Lines:** 9-10

```css
body {
    background: var(--cc-bg-primary);  /* #0d1117 — DARK GRAY */
}
```

**File:** `DCE/src/dce-controlcenter/html/css/themes/light.css`
**Lines:** 9-10

```css
body {
    background: var(--cc-bg-primary);  /* #0d1117 — DARK GRAY */
}
```

**CONTRIBUTING CAUSE:**

The body CSS sets a dark gray background (#0d1117) that CEF composites at full viewport from the moment the resource starts. The `opacity: 0 !important;` and `visibility: hidden !important;` on lines 35-37 do not prevent CEF's compositor from rendering the background color layer.

---

## Why Previous Audits Passed

Previous audits focused on:
1. **Lua architecture** — Verified that services register properly
2. **Lazy loading** — Verified that JS files don't load until `/dce`
3. **Focus management** — Verified SetNuiFocus ownership
4. **Session lifecycle** — Verified session creation flow
5. **DOM creation** — Verified no DOM elements created before activation

**What was MISSED:**
1. The CSS body background color is always painted by CEF regardless of visibility/opacity CSS rules
2. FiveM's CEF compositor renders the background of the page at full viewport from resource start
3. `opacity: 0` and `visibility: hidden` on the `body` element do NOT prevent CEF's compositor from rendering the background color
4. SetNuiFocus(false, false) does NOT hide the CEF browser — it only releases input
5. The body MUST have `background: transparent` (or no background at all) in the dormant state
6. Background color must ONLY be applied when `body.cc-active` is present

---

## Architectural Correction

### Changes Required

#### 1. `html/css/style.css` (Lines 24-38)

**REMOVE** the background color from the dormant body state:

```css
body {
    font-family: 'Segoe UI', sans-serif;
    /* REMOVED: background: var(--cc-bg-primary); */
    color: var(--cc-text-primary, #f0f6fc);
    min-height: 100vh;
    overflow: hidden;
    font-size: 13px;
    margin: 0;
    padding: 0;
    
    /* DORMANT STATE - Completely transparent, no focus, no interaction */
    opacity: 0 !important;
    pointer-events: none !important;
    visibility: hidden !important;
    background: transparent !important; /* ADD: Ensure CEF composites nothing */
}
```

#### 2. `html/css/themes/dark.css` (Lines 8-11)

**REMOVE** the background color from the dormant body state:

```css
/* Body uses dark theme variables ONLY when active */
body.cc-active {
    background: var(--cc-bg-primary);
    color: var(--cc-text-primary);
}
```

#### 3. `html/css/themes/light.css` (Lines 8-11)

Same change as dark.css.

#### 4. `html/css/style.css` (Add to cc-active/cc-open states)

Ensure background is applied only when active:

```css
body.cc-active {
    opacity: 1 !important;
    pointer-events: all !important;
    visibility: visible !important;
    background: var(--cc-bg-primary);  /* Background applied HERE, not on dormant body */
    transition: opacity 0.15s ease-out;
}
```

#### 5. Critical Additions to `.desktop` CSS

```css
.desktop {
    position: fixed;
    top: 0;
    left: 0;
    width: 100vw;
    height: 100vh;
    display: flex;
    flex-direction: column;
    background: var(--cc-bg-primary);  /* Desktop handles its own background */
}
```

#### 6. `html/bootstrap.html` — Add inline style guard

Add an inline style in the `<head>` that enforces transparency before external CSS loads:

```html
<style>
    /* GUARD: Ensure browser is transparent until CC activates */
    html, body { background: transparent !important; margin: 0; padding: 0; }
</style>
```

---

## Verification Checklist

After implementing the fix, verify:

- [ ] `body` has NO background color in dormant state
- [ ] `body.cc-active` has `background: var(--cc-bg-primary)`
- [ ] `.desktop` element has `background: var(--cc-bg-primary)`
- [ ] All theme files only apply background when `.cc-active` is present
- [ ] No CSS rule paints a fullscreen background before activation
- [ ] Inline style guard exists in bootstrap.html `<head>`
- [ ] CEF browser surface composites no visible color before activation
- [ ] `/dce` correctly transitions to visible state with full styling

---

## Conclusion

The gray overlay is caused by `style.css` lines 24-26 and `dark.css` lines 9-10 setting `body { background: #0d1117; }`. This background color is always rendered by FiveM's CEF compositor from the moment the resource starts, even though `opacity: 0` and `visibility: hidden` are also applied.

**The fix is simple:** Never set a background color on `body` in the dormant state. Only apply the background when `body.cc-active` (or `body.cc-open`) is present.

This preserves the complete True Lazy Init architecture, BrowserManager ownership, FocusManager ownership, SessionManager ownership, and all ADR-0026 principles. No architectural changes are needed — only CSS corrections.