/**
 * DCE Control Center v2 - Bootstrap.js (MINIMAL)
 * 
 * TRUE MINIMAL BOOTSTRAP - Per ADR-0026 and CC-v2-COMPLETE-ARCHITECTURE.md
 * This file ONLY provides DCE.NUI.post and the lazy loader.
 * NO application logic exists here.
 * NO DCE.Bus, NO DCE.Workspace, NO boot data storage, NO message routing for DCE subsystems.
 * Exactly ~50 lines.
 * 
 * Lazy Loading Contract:
 * - bootstrap.js loads at resource start (unavoidable FiveM constraint)
 * - NO other JS files load until /dce command
 * - DCE.Loader provides lazy script injection
 * - ApplicationManager loads on /dce, then loads everything else
 */

(function() {
    'use strict';
    
    window.DCE = window.DCE || {};
    
    // ===========================================================================
    // NUI Helper - Bootstrap only (minimal)
    // ===========================================================================
    
    DCE.NUI = {
        post: function(action, data) {
            return fetch('https://' + GetParentResourceName() + '/' + action, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(data || {})
            })
            .then(function(response) { return response.ok ? response.json() : null; })
            .catch(function() { return null; });
        }
    };
    
    // ===========================================================================
    // Lazy Script Loader - Loads JS files on demand
    // ===========================================================================
    
    DCE.Loader = {
        _loaded: new Set(),
        _pending: {},
        
        loadScript: function(path) {
            var self = this;
            if (self._loaded.has(path)) return Promise.resolve();
            if (self._pending[path]) return self._pending[path];
            
            var promise = new Promise(function(resolve, reject) {
                var script = document.createElement('script');
                script.src = path;
                script.onload = function() { self._loaded.add(path); delete self._pending[path]; resolve(); };
                script.onerror = function() { delete self._pending[path]; reject(new Error('Script load error: ' + path)); };
                document.head.appendChild(script);
            });
            
            self._pending[path] = promise;
            return promise;
        },
        
        loadScripts: function(paths) {
            var self = this;
            var promise = Promise.resolve();
            paths.forEach(function(path) { promise = promise.then(function() { return self.loadScript(path); }); });
            return promise;
        },
        
        isLoaded: function(path) { return this._loaded.has(path); }
    };
    
    // ===========================================================================
    // Notify Lua that NUI is loaded - CRITICAL for focus release
    // ===========================================================================
    
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', function() {
            DCE.NUI.post('dce-cc:nui:loaded', { status: 'ready' });
        });
    } else {
        DCE.NUI.post('dce-cc:nui:loaded', { status: 'ready' });
    }
    
    // ===========================================================================
    // Message Handler - ONLY handles application:boot to trigger lazy load
    // ===========================================================================
    
    window.addEventListener('message', function(event) {
        var data = event.data;
        if (!data || !data.action) return;
        if (data.action === 'application:boot') {
            DCE.Loader.loadScript('js/application/application-manager.js');
        }
    });
    
    console.log('[DCE Bootstrap] Loaded - waiting for /dce command');
})();