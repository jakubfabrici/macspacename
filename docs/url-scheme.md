# URL scheme

MacSpaceName registers the `macspacename://` scheme so you can drive it from the Shortcuts app, Raycast, Alfred, Keyboard Maestro, Hammerspoon or a plain shell:

```sh
open "macspacename://switch?name=Work"
```

Names are matched case- and accent-insensitively; if there is no exact match the best fuzzy match wins.

| URL | Effect |
|---|---|
| `macspacename://switch?name=Work` | switch to the Space named *Work* (custom or default name) |
| `macspacename://switch?number=3` or `macspacename://switch/3` | switch to Desktop 3 |
| `macspacename://switch?key=<uuid>` | switch by Space UUID (see `config.json`) |
| `macspacename://back` | jump back to the previous Space |
| `macspacename://next` / `macspacename://previous` | cycle on the current display |
| `macspacename://rename?name=Focus` | rename the current Space |
| `macspacename://rename?number=3&name=Focus` | rename Desktop 3 |
| `macspacename://rename` | open the rename prompt |
| `macspacename://switcher` | open the Quick Switcher |
| `macspacename://switcher/move` | open it in *move window* mode |
| `macspacename://notes` | open notes for the current Space |
| `macspacename://settings` | open Settings |
| `macspacename://tracking/pause` · `/resume` · `/toggle` · `/export` · `/show` | control time tracking |
| `macspacename://run?group=Meetings` or `macspacename://run/Meetings` | run an action group |

`jump` and `goto` are accepted as aliases of `switch`; `prev` of `previous`.

Remember to percent-encode spaces and non-ASCII characters when calling from code (`Práca` → `Pr%C3%A1ca`); the Shortcuts "Open URLs" action does that for you.
