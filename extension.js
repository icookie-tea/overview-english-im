/* Overview English Input
 *
 * Switches to an English input source while the overview is open and restores
 * the source that was active before, so that search in the overview never
 * starts with the IME in Chinese mode.
 *
 * Only the global input source mode is handled: when
 * org.gnome.desktop.input-sources per-window is enabled, GNOME Shell already
 * keeps a separate source per window (and for the overview), so this extension
 * stays out of the way.
 */

import Gio from 'gi://Gio';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import {getInputSourceManager} from 'resource:///org/gnome/shell/ui/status/keyboard.js';

const INPUT_SOURCES_SCHEMA = 'org.gnome.desktop.input-sources';

export default class OverviewEnglishInput extends Extension {
    enable() {
        this._settings = this.getSettings();
        this._perWindowSettings = new Gio.Settings({schema_id: INPUT_SOURCES_SCHEMA});

        /* The source the user was on when the overview opened, and the one we
         * switched to. Both null means "nothing to undo". */
        this._savedSource = null;
        this._englishSource = null;

        this._signalIds = [
            Main.overview.connect('showing', () => this._switchToEnglish()),
            Main.overview.connect('hidden', () => this._restoreSource()),
        ];
    }

    disable() {
        for (const id of this._signalIds ?? [])
            Main.overview.disconnect(id);
        this._signalIds = null;

        /* Disabling while the overview is open would otherwise leave the
         * session on the English source. */
        this._restoreSource();

        this._settings = null;
        this._perWindowSettings = null;
    }

    _switchToEnglish() {
        if (this._savedSource)
            return;
        if (this._perWindowSettings.get_boolean('per-window')) {
            this._log('per-window sources are enabled, not switching');
            return;
        }

        const manager = getInputSourceManager();
        const current = manager.currentSource;
        if (!current)
            return;

        const english = this._findEnglishSource(manager);
        if (!english || english === current) {
            this._log(`no English source to switch to (current: ${current.id})`);
            return;
        }

        this._savedSource = current;
        this._englishSource = english;
        manager.activateInputSource(english, false);
        this._log(`${current.id} -> ${english.id}`);
    }

    _restoreSource() {
        if (!this._savedSource)
            return;

        const saved = this._savedSource;
        const english = this._englishSource;
        this._savedSource = null;
        this._englishSource = null;

        /* A manual switch while the overview was open wins: only undo our own
         * switch, otherwise the user's choice would be reverted. */
        const manager = getInputSourceManager();
        if (manager.currentSource !== english)
            return;
        if (!this._settings.get_boolean('restore')) {
            this._log('restore is disabled, staying on the English source');
            return;
        }

        manager.activateInputSource(saved, false);
        this._log(`restored ${saved.id}`);
    }

    _findEnglishSource(manager) {
        const sources = Object.values(manager.inputSources ?? {});
        const wanted = this._settings.get_string('english-source');

        return sources.find(s => s.type === 'xkb' && s.xkbId === wanted) ??
            sources.find(s => s.type === 'xkb') ?? null;
    }

    _log(message) {
        if (this._settings.get_boolean('debug'))
            console.log(`[overview-english-im] ${message}`);
    }
}
