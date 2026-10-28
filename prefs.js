import Gio from 'gi://Gio';
import Gtk from 'gi://Gtk?version=4.0';
import Adw from 'gi://Adw';

import {ExtensionPreferences} from 'resource:///org/gnome/Shell/Extensions/js/extensions/prefs.js';

const INPUT_SOURCES_SCHEMA = 'org.gnome.desktop.input-sources';

export default class OverviewEnglishInputPreferences extends ExtensionPreferences {
    fillPreferencesWindow(window) {
        const settings = this.getSettings();
        const inputSources = new Gio.Settings({schema_id: INPUT_SOURCES_SCHEMA});

        const page = new Adw.PreferencesPage();
        const group = new Adw.PreferencesGroup({
            title: 'Overview',
            description: 'Use an English input source while the overview is open.',
        });
        page.add(group);

        const xkbIds = inputSources.get_value('sources').deepUnpack()
            .filter(([type]) => type === 'xkb')
            .map(([, id]) => id);
        /* Always offer the configured value, even when it is not in the list. */
        const current = settings.get_string('english-source');
        if (!xkbIds.includes(current))
            xkbIds.push(current);

        const combo = new Adw.ComboRow({
            title: 'English input source',
            subtitle: 'XKB layout to switch to while the overview is open',
            model: new Gtk.StringList({strings: xkbIds}),
        });
        combo.selected = Math.max(0, xkbIds.indexOf(current));
        combo.connect('notify::selected', () => {
            settings.set_string('english-source', xkbIds[combo.selected]);
        });
        group.add(combo);

        const restore = new Adw.SwitchRow({
            title: 'Restore on exit',
            subtitle: 'Switch back to the previous source when the overview closes',
        });
        settings.bind('restore', restore, 'active', Gio.SettingsBindFlags.DEFAULT);
        group.add(restore);

        const debug = new Adw.SwitchRow({
            title: 'Debug logging',
            subtitle: 'Write switch decisions to the journal',
        });
        settings.bind('debug', debug, 'active', Gio.SettingsBindFlags.DEFAULT);
        group.add(debug);

        window.add(page);
    }
}
