# WoW Addon Development Instructions

## Project purpose

Build and maintain addons for World of Warcraft on Windows and macOS.

## Public repository privacy

- This is a public repository. Never put real personal names, private character identities, account details, personal email addresses or machine-specific paths in tracked files, examples, tests, instructions or commit metadata.
- Use generic companion terminology, synthetic test identities and explicit path placeholders.
- Keep real installation paths, author identity and personal configuration outside tracked source.
- Review staged content and commit metadata for privacy before publishing.

The suite supports Evoker and Demon Hunter players, solo or as a duo. Each player's class is detected automatically; the companion's specialisation and character identity must be configurable.

## Repository layout and live deployment

- Each addon is a direct child of the repository root.
- Match each addon directory name and its primary .toc filename exactly.
- The Windows repository is <REPOSITORY_PATH>.
- The intended live junction is <RETAIL_ADDONS_PATH> -> <REPOSITORY_PATH>.
- Inspect the actual checkout and junction before changing installation configuration.
- Treat source edits as edits to the live addon installation.
- Do not delete, replace or reorganise unrelated addons or existing user work.
- Keep development tools outside addon runtime load lists.
- Keep machine paths out of runtime code and tracked personal configuration.
- SavedVariables belong in WoW's normal WTF directories.
- Do not commit WTF, account data, personal notes, credentials or local logs.

## Client and API compatibility

- Target the installed Midnight Retail build. Do not add Forever or Classic support unless requested.
- Determine the client build and interface number from reliable local evidence when available.
- If the client cannot be inspected, document the provisional target and how to verify it.
- Do not invent interface numbers or claim compatibility based only on a .toc version change.
- Check APIs against Blizzard's current UI source and generated API documentation for the target build.
- Prefer supported public APIs and native UI capabilities.
- Feature-detect APIs that vary between supported builds.
- Clearly record unverified API assumptions and avoid presenting placeholders as working features.

## Midnight combat restrictions

- Treat secret values, protected actions and combat lockdown as design constraints.
- Never compare, calculate from, serialise or branch on restricted values unless the specific operation is explicitly supported.
- Pass restricted values only through documented presentation mechanisms.
- Do not use alternate APIs, tooltip scraping or other workarounds to infer restricted combat state.
- Secure actions require the appropriate user input and supported secure mechanisms.
- Configure protected frames and attributes outside combat.
- Defer protected changes until combat ends, then revalidate the intended change.
- Do not automate casting, movement, target selection or rotation execution.
- Avoid taint: do not replace protected Blizzard functions or mutate protected UI state.
- Never start, join, answer, stop or supertrack WoW's native Party Sync (`C_QuestSession`), directly or through callbacks, hooks, programmatic clicks, invitation or confirmation answers. Read its state only through supported read-only queries in `DuoAdventure/Native.lua`, report unavailable state as unknown, and keep addon progress sharing visibly separate. `tools/check-repository.py` enforces this.
- Prefer supported hooks and extension points.
- Test combat-related features in the intended restricted contexts; open-world success alone is insufficient.

## Lua and addon architecture

- Use WoW-compatible Lua and UI facilities. Do not assume standalone Lua libraries, filesystem access, networking or package installation inside the game.
- Keep each addon independently loadable and disableable.
- Start without mandatory third-party dependencies unless a clear need justifies them.
- Use the addon namespace pattern and local variables to minimise global pollution.
- Prefix unavoidable globals, frame names, slash commands and SavedVariables.
- Declare file load order and dependencies explicitly in the .toc.
- Handle login, reload, missing data and asynchronous item or roster information correctly.
- Use events rather than continuous polling wherever possible.
- Debounce expensive inventory and roster refreshes.
- Avoid unnecessary per-frame work and repeated full scans.
- Handle nil values, unavailable spells and missing APIs without breaking unrelated features.
- Do not hide errors with blanket protected calls or silent failures.

## Cross-platform requirements

- Use one runtime codebase for Windows and macOS.
- Match filename and asset-path capitalisation exactly.
- Use UTF-8 text and consistent LF line endings.
- Do not create filenames differing only by case.
- Avoid Windows-specific executables and platform assumptions in runtime code.
- Keep bindings configurable and layouts adaptable to resolution and UI scale.
- Any development helper must support both platforms or include a documented equivalent.
- Never claim macOS testing unless it was actually performed.

## Settings and data

- Give each addon its own clearly named SavedVariables table.
- Initialise saved data after the appropriate addon-loading event.
- Use versioned, non-destructive migrations when settings change.
- Preserve existing settings and distinguish account-wide from character-specific preferences.
- Do not alter Blizzard's settings silently.
- Explain the scope of changes to native settings, including auto-loot.
- Keep personal social notes local unless the user explicitly requests sharing.
- Require an explicit user action for selling items, inviting players or sending messages.
- Protect keep-listed items from sale and clearly preview proposed sales.

## Documentation

- Every addon must have its own README.md.
- Document scope, use case, implemented features, commands, settings and limitations.
- Include Windows and macOS installation and usage instructions.
- Document SavedVariables, reset procedures and compatibility targets.
- Distinguish implemented features from planned ideas.
- Update documentation in the same change as affected behaviour.
- Include repeatable manual checks and an honest record of verification.
- Maintain a root README describing the suite and development workflow.
- Maintain `docs/index.html` as the canonical static operating reference for all five addons. In the same change as any addon commands, configuration, requirements, versions, dependencies or behaviour change, verify the reference against the actual `.toc` manifests, command handlers, button registrations and affected source, then update it and the affected READMEs together. Do not rely on an earlier guide as proof of current behaviour.
- Keep the reference self-contained, mobile-readable and usable offline, with valid HTML and working section/source links. Preserve installation/enabling, configuration/use examples, SavedVariables/reset, limitations and honest verification status for each addon. Distinguish DuoAdventure addon progress sharing from native Party Sync and keep quest sharing/acceptance manual; never imply messages bypass native eligibility or award credit.
- Validate the reference's HTML, links and narrow/wide rendering when changing it. Never publish personal identities, machine-specific paths or unverified in-game claims. Adding or updating the page does not authorize enabling GitHub Pages, changing hosting settings or deploying it.

## Verification

- Perform checks proportionate to the change.
- Check .toc references, filename case, asset paths and Lua syntax with suitable tools.
- Use focused automated tests for meaningful pure logic such as keep rules, filtering and settings migrations.
- Do not treat mocked tests as proof of in-game API compatibility.
- Check fresh settings, existing settings, reloads, individual addon loading and relevant failure cases.
- For bags, check full bags, uncached item data, protected items and loot-confirmation handling.
- For social features, check solo play, no guild, offline members and missing permissions.
- For combat UI, check entering and leaving combat, protected actions and secret-value handling.
- Verify coexistence with Blizzard's default UI.
- Clearly state when in-game or macOS checks remain outstanding.
- Do not claim a feature is tested or working without supporting evidence.

## Working approach

- Inspect existing code and instructions before editing.
- Implement small, complete features before expanding scope.
- Make reasonable routine decisions and continue work without repeated confirmation.
- Ask only when missing information materially blocks correct implementation.
- Preserve user changes and avoid destructive Git operations.
- Do not publish, push or install dependencies without task authorisation.
- Summarise delivered behaviour, verification and remaining limitations.
