/**
 * DCE Control Center v2 - Command Palette
 * 
 * Provides a searchable command palette (Ctrl+K / Cmd+K).
 * Lazy loaded by ApplicationManager on Boot.
 * Never exists until /dce command.
 */

(function() {
    'use strict';
    
    window.DCE = window.DCE || {};
    
    DCE.CommandPalette = {
        _overlay: null,
        _input: null,
        _results: null,
        _commands: [],
        _visible: false,
        
        init: function() {
            console.log('[DCE CommandPalette] Initializing...');
            
            var overlay = document.createElement('div');
            overlay.id = 'command-palette';
            overlay.className = 'command-palette hidden';
            overlay.innerHTML = '<div class="command-palette-input-wrapper">' +
                '<input type="text" id="command-palette-input" class="command-palette-input" placeholder="Search commands..." autofocus>' +
                '</div>' +
                '<div id="command-palette-results" class="command-palette-results"></div>';
            
            document.body.appendChild(overlay);
            
            DCE.CommandPalette._overlay = overlay;
            DCE.CommandPalette._input = document.getElementById('command-palette-input');
            DCE.CommandPalette._results = document.getElementById('command-palette-results');
            
            DCE.CommandPalette._input.addEventListener('input', function() {
                DCE.CommandPalette._search();
            });
            
            DCE.CommandPalette._input.addEventListener('keydown', function(e) {
                if (e.key === 'Escape') {
                    DCE.CommandPalette.hide();
                } else if (e.key === 'Enter') {
                    DCE.CommandPalette._executeSelected();
                } else if (e.key === 'ArrowDown') {
                    e.preventDefault();
                    DCE.CommandPalette._selectNext();
                } else if (e.key === 'ArrowUp') {
                    e.preventDefault();
                    DCE.CommandPalette._selectPrevious();
                }
            });
            
            document.addEventListener('keydown', function(e) {
                if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
                    e.preventDefault();
                    if (DCE.CommandPalette._visible) {
                        DCE.CommandPalette.hide();
                    } else {
                        DCE.CommandPalette.show();
                    }
                }
            });
            
            console.log('[DCE CommandPalette] Initialized');
            return true;
        },
        
        register: function(command) {
            if (!command || !command.id) return;
            DCE.CommandPalette._commands.push({
                id: command.id,
                title: command.title || command.id,
                description: command.description || '',
                icon: command.icon || '\u2699',
                action: command.action || function() {},
                category: command.category || 'General'
            });
        },
        
        registerAll: function(commands) {
            var self = this;
            commands.forEach(function(cmd) {
                self.register(cmd);
            });
        },
        
        show: function() {
            if (DCE.CommandPalette._visible) return;
            DCE.CommandPalette._visible = true;
            DCE.CommandPalette._overlay.classList.remove('hidden');
            DCE.CommandPalette._input.value = '';
            DCE.CommandPalette._search();
            
            setTimeout(function() {
                DCE.CommandPalette._input.focus();
            }, 100);
        },
        
        hide: function() {
            if (!DCE.CommandPalette._visible) return;
            DCE.CommandPalette._visible = false;
            DCE.CommandPalette._overlay.classList.add('hidden');
        },
        
        _search: function() {
            var query = DCE.CommandPalette._input.value.toLowerCase().trim();
            var results = DCE.CommandPalette._commands;
            
            if (query) {
                results = results.filter(function(cmd) {
                    return cmd.title.toLowerCase().includes(query) ||
                           cmd.description.toLowerCase().includes(query) ||
                           cmd.category.toLowerCase().includes(query);
                });
            }
            
            var resultsEl = DCE.CommandPalette._results;
            resultsEl.innerHTML = '';
            
            results.forEach(function(cmd, index) {
                var item = document.createElement('div');
                item.className = 'command-palette-item' + (index === 0 ? ' selected' : '');
                item.setAttribute('data-command-id', cmd.id);
                item.innerHTML = '<span class="command-item-icon">' + cmd.icon + '</span>' +
                    '<span class="command-item-title">' + cmd.title + '</span>' +
                    '<span class="command-item-description">' + cmd.description + '</span>' +
                    '<span class="command-item-category">' + cmd.category + '</span>';
                
                item.addEventListener('click', function() {
                    cmd.action();
                    DCE.CommandPalette.hide();
                });
                
                resultsEl.appendChild(item);
            });
            
            DCE.CommandPalette._selectedIndex = 0;
        },
        
        _executeSelected: function() {
            var selected = DCE.CommandPalette._results.querySelector('.selected');
            if (selected) {
                var clickEvent = new MouseEvent('click', { bubbles: true });
                selected.dispatchEvent(clickEvent);
            }
        },
        
        _selectNext: function() {
            var items = DCE.CommandPalette._results.querySelectorAll('.command-palette-item');
            if (items.length === 0) return;
            
            var current = DCE.CommandPalette._results.querySelector('.selected');
            var nextIndex = 0;
            
            if (current) {
                current.classList.remove('selected');
                nextIndex = Array.from(items).indexOf(current) + 1;
                if (nextIndex >= items.length) nextIndex = 0;
            }
            
            items[nextIndex].classList.add('selected');
            items[nextIndex].scrollIntoView({ block: 'nearest' });
        },
        
        _selectPrevious: function() {
            var items = DCE.CommandPalette._results.querySelectorAll('.command-palette-item');
            if (items.length === 0) return;
            
            var current = DCE.CommandPalette._results.querySelector('.selected');
            var prevIndex = items.length - 1;
            
            if (current) {
                current.classList.remove('selected');
                prevIndex = Array.from(items).indexOf(current) - 1;
                if (prevIndex < 0) prevIndex = items.length - 1;
            }
            
            items[prevIndex].classList.add('selected');
            items[prevIndex].scrollIntoView({ block: 'nearest' });
        },
        
        destroy: function() {
            if (DCE.CommandPalette._overlay) {
                DCE.CommandPalette._overlay.remove();
                DCE.CommandPalette._overlay = null;
            }
            DCE.CommandPalette._commands = [];
            DCE.CommandPalette._visible = false;
        }
    };
    
    console.log('[DCE CommandPalette] Loaded');
    
})();