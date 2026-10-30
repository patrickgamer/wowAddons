# wowAddons

Five independent addons for Retail Midnight, supporting Evoker and Demon Hunter solo or duo play from each class's first playable level. Both players can install the same suite: DuoSupport detects the player's class automatically, with separate class modules; DuoUI works on either class. There is no minimum-level gate or third-party runtime dependency. Companion identity and Havoc/Vengeance planning priorities are configured locally. No ordinary chat messages are sent; DuoAdventure has optional, explicitly enabled party-addon progress reports. They are separate from WoW's own Party Sync, which no addon in this suite starts, joins, answers or stops.

| Addon | Start here | Initial functionality |
| --- | --- | --- |
| [DuoBags](DuoBags/README.md) | `/duobags` | Free-space badge, searchable inventory/categories, keep and Companion notes, session item loot, native auto-loot toggle, one-stack vendor sale after preview |
| [DuoUI](DuoUI/README.md) | `/duoui` | Compact passive player/partner health bars, solo/duo positions and scale, fonts, combat deferral |
| [DuoSupport](DuoSupport/README.md) | `/duosupport setup` | Class-aware learned-spell reference from the first playable level, secure self/partner/selected-target buttons, class-specific static planning profiles |
| [DuoSocial](DuoSocial/README.md) | `/duosocial` | Party/guild roster, search, private notes/favourites, explicit invite/ready check, session checklist |
| [DuoAdventure](DuoAdventure/README.md) | `/duoadventure` | Immersion/speed modes, accepted-quest planning, share/catch-up advice, optional addon progress sharing (not WoW Party Sync), read-only Party Sync status and local DuoSocial activity |

Each folder is directly inside this repository and has a matching `.toc`. Enable any combination independently. DuoAdventure declares DuoSocial only as an optional load-order dependency; quest planning works without it. `Common.lua` is deliberately copied inside each addon for independent loading; update all five copies together.

## Operating reference page

Open [the five-addon operating guide](docs/index.html) directly in a browser, including offline. It covers installation, commands, configuration, safe use, resets and the difference between DuoAdventure progress sharing and native Party Sync. `/duoui` prints help; its passive bars appear when the addon is enabled.

For a local web preview from the project root, run `python3 -m http.server 8000` (or `py -3 -m http.server 8000` on Windows), then open `http://localhost:8000/docs/`. Stop the server when finished.

`docs/index.html` is a plain static entry point suitable for a GitHub Pages branch source using `/docs`; it also works at `/docs/` if a future site serves the project root. No build, external assets or runtime dependencies are needed. Pages is **not enabled or deployed by this change**. Enabling public hosting requires separate authorization; a future authorized setup can select the default branch and `/docs` as its Pages source. Online source links leave the offline guide and open GitHub or Blizzard.

Keep the guide aligned with manifests and actual handlers in the same change as affected addon behaviour; see [AGENTS.md](AGENTS.md#documentation). To validate edits, run `tidy -errors -quiet docs/index.html` with an HTML5-capable HTML Tidy if available, check section/source links, and inspect wide/narrow screens and direct-file offline loading. This documentation check supplements the development checks below, not in-game verification.

## Installation and first use

The intended Windows setup uses one **whole-folder junction**:

```text
<RETAIL_ADDONS_PATH> -> <REPOSITORY_PATH>
```

Replace these placeholders with your local paths. Source edits become live installation edits when linked. Do not create another `addons/` or `src/` level. Inspect existing directories/links before making installation changes:

```powershell
Get-Item -LiteralPath '<RETAIL_ADDONS_PATH>' -Force |
    Format-List FullName,Attributes,LinkType,Target
```

For a different Windows installation, close WoW, inspect and back up any existing AddOns directory and preserve unrelated addons first. Only if the intended AddOns path is absent, create the equivalent junction with `New-Item -ItemType Junction -Path '<live AddOns path>' -Target '<repository path>'`. Never overwrite an existing directory or link.

On macOS use your actual local repository and Retail installation, without copying Windows paths. For example, after substituting both paths:

```sh
repo="<LOCAL_REPOSITORY_PATH>"                 # replace with your checkout
interface="<RETAIL_INTERFACE_PATH>" # replace with the real folder
ls -ld "$interface/AddOns"                     # inspect any existing directory/link
readlink "$interface/AddOns"                   # inspect any existing link target
# Close WoW; back up/preserve an existing AddOns directory first.
# Run only when AddOns is absent (and not a dangling link):
if [ ! -e "$interface/AddOns" ] && [ ! -L "$interface/AddOns" ]; then
    ln -s "$repo" "$interface/AddOns"
fi
```

The whole AddOns folder points at the repository on either platform, so future addon folders appear automatically. Do not remove unrelated addons to achieve this. Root documentation and `tools/` have no `.toc` and are not runtime addons.

Launch WoW and enable the five addons in the character-selection AddOns list. A full client restart is safest after adding new addon folders; `/reload` applies Lua/settings changes to already discovered addons. Solo: DuoUI shows the player; DuoSupport needs no partner configuration and offers only learned class abilities, including before specialisation unlock. In a duo, configure your companion's actual `Name-Realm` in `/duoui partner`, `/duosupport partner` and `/duosocial partner`, or target the party member and run each addon's `select` command outside combat. Each player configures the other player's name on their own installation. Settings are independent. Pick `/duosupport spec havoc` or `vengeance` as a manual planning profile and edit the class-specific static agreement. This setting does not choose or change your actual character specialisation.

Use `/duoadventure mode adventure` for native quest order/objective reading or `mode speed` for an accepted-quest sorting heuristic. **Social plan** copies your manual focus only into local DuoSocial activity. Sharing advice checks native overlap/share availability and catch-up before turn-ins. For addon progress sharing, each player applies the opt-in toggle prompted on party join (or `/duoadventure share on`; `sync on` still works). Quest pickups, turn-ins/completion and incremental counts such as kills then broadcast automatically, with a 30-second refresh. Combat/chat restrictions defer updates. Only numeric quest progress travels over the party addon channel; private notes/settings remain local. The panel shows WoW's own Party Sync state on a separate read-only line and warns once when WoW reports it active, because native Party Sync can put quests on hold; `/duoadventure native` prints the same status. See the [DuoAdventure guide](DuoAdventure/README.md) for session consent, V2 protocol limits and two-client tests.

## Client evidence and verification

Target: Retail Midnight **12.1.5.70575**, interface **120105**. Evidence: the installed client's executable version and build metadata agree on the build, and its patch marker reports 120105. This patch marker supports the TOC target; confirm the definitive runtime interface with `/dump select(4, GetBuildInfo())` (expected 120105). No account data or config file was copied into the repository.

The inspected [Blizzard UI source build marker](https://github.com/Gethe/wow-ui-source/blob/live/version.txt) matches the installed client's build. See [API evidence and limits](docs/API-NOTES.md) and [verification/progress](docs/VERIFICATION.md). This is a source-reviewed initial release, **not yet tested in WoW or on macOS**. Load success, restricted-instance combat, secure button behavior and UI appearance require the documented in-game checks. Updating only a TOC is never evidence of compatibility.

Keep Blizzard's unit frames, action bars and cooldown displays enabled. DuoUI adds passive bars without moving protected frames or modifying Edit Mode. DuoSupport does not interpret cooldown, aura or health data or generate decision prompts. Use native Edit Mode to arrange native frames. All gameplay actions are your own clicks; native confirmation/restriction handling remains in control.

## SavedVariables and backups

Each addon declares its own account-wide table: `DuoBagsDB`, `DuoUIDB`, `DuoSupportDB`, `DuoSocialDB`, `DuoAdventureDB`. WoW writes these under its normal `WTF/Account/<account>/SavedVariables/` directory, with `.lua` and possibly `.lua.bak` files. Different WoW installations/accounts do not automatically share settings. Partner identities, personal notes and preferences live there, never in source control. Session loot and checkmarks reset on reload/login. DuoSupport's schema-2 migration preserves existing Evoker planning text while adding separate class plans. DuoAdventure pins/notes are by quest ID, shared across characters on that account; they do not abandon, accept or complete quests. Its explicit progress-sharing opt-in preference is saved, but received peer snapshots are memory-only and expire/clear as documented.

Back up **WTF separately**, with WoW closed; never junction/symlink WTF into this repository. Back up native Edit Mode/settings separately too. For a clean addon reset, exit WoW completely, back up then remove only that addon's two SavedVariables files; restart. Do not edit/remove those files while logged in because WoW can overwrite your changes. DuoUI also has `/duoui reset` to restore its own layout without losing the partner name. Resetting DuoBags does not change Blizzard's native auto-loot setting.

## License

The project's original code and documentation use the [MIT License](LICENSE), with **Duo contributors** attribution for new work and existing copyright notices preserved. Include `LICENSE` when redistributing the suite or an individual addon. Blizzard client resources and linked third-party works retain their own rights and terms; see [licensing and third-party boundaries](docs/LICENSING.md).

## Git workflow and development checks

Use `git status` and `git diff` before/after changes; normally work on a branch, test in WoW, then commit source and documentation together. Review tracked files before committing. Never commit WTF, notes, account data, credentials or local logs; `.gitignore` excludes common data locations. Keep unrelated addons/user changes intact and avoid destructive Git commands. Commit/push directly to main only when explicitly requested by the user, as authorized for this initial delivery.

Runtime files are UTF-8/LF with exact path case and no machine-specific paths. Development helpers are not in any `.toc`:

```sh
python tools/check-repository.py
lua5.1 tools/verify.lua
```

`tools/verify.lua` also runs the two-client progress-sharing model and the native Party Sync model (`tools/verify-native.lua`); `check-repository.py` rejects native Party Sync start, answer, stop and confirmation calls in every addon. Use an available Python 3 and Lua 5.1 interpreter; no packages are required. Windows users can optionally run the helper with an existing 32-bit Lua 5.1 library, substituting its local path:

```powershell
& "$env:WINDIR\SysWOW64\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File tools/check-lua.ps1 -LuaLibrary '<LUA51_LIBRARY_PATH>'
```

The execution-policy override applies only to that helper process. Elsewhere prefer `lua5.1 tools/verify.lua`; a DLL is an optional local verification tool, never an addon dependency. Mock checks cannot reproduce taint or secure WoW execution. See [public-repository privacy guidance](docs/PRIVACY.md) before committing examples or local setup information.

For cross-platform release checks: run the structural/Lua checks on both systems; enable each addon alone, then the suite; follow each manual checklist at native resolution and adjusted UI scale; test freshly created Evoker and Demon Hunter characters at their actual first playable levels, then learned/talent changes and higher-level group play. Verify reload persistence, filename case, available fonts and modifier bindings. Record actual build/OS/results in `docs/VERIFICATION.md`. macOS validation is outstanding.

## Developer testing

`devkit/` holds a developer-only test recorder (not an addon of the suite); see `devkit/README.md`, `docs/TESTING.md` and the guided `docs/run-sheets/`. Development tools (Lua 5.1, luacheck, lua-language-server) are never required to play.
