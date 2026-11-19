# Enfocao!! — agent guide

World of Warcraft addon: a personal coach. **Stop planning. Start playing.** The player sets goals and Enfocao follows
them by itself: reach a level, raise a profession, a reputation standing, save gold, gather items, complete a quest,
or something else ticked by hand (once, daily or weekly). Progress bars, a chat line, a sound and a message in the
middle of the screen when one is reached, the "Today" window with the playing character's goals. Suggested goals from what is known of the character
("te aconsejaría invertir tu tiempo en..."), weighed by the player's style (a short "Your style" form: chill / balanced /
min-maxer, what they enjoy, how long they play). Today's plan: a stretch of the closest goals sized to the session,
the manual goals to tick and the account's chores (cooldowns, mail), shown in the Today view and the "Today" window.
Templates of goals that go together ("Ready for Molten Core"). Optional entries for Completao (a quest's chain) and
Fabrikao (how to craft an item, the recipes using it) in a goal's menu. Only WoW Forever for now
(`## Interface: 16001`). Magenta in the family's colors.

Siblings with the same conventions under `D:\Source\WowAddons\`: `Alterao` (the template this repo was cloned from,
2026-11-19), `BakalaoStudios_DataStore`, `Emboscao`, `Aggreao`, `Completao`, `Embolsao`, `Fabrikao`.

## How to work with the maintainer

- **Chat in Spanish from Spain** ("tú", never voseo). **Everything committed is in English**; Spanish only in the esES/esMX
  table of `Localization/Locale.lua` and the esES/esMX TOC notes.
- Windows machine. Multi-line commit messages: write a file and use `git commit -F <file>`.
- Merging to `master` and releasing only happen when the maintainer asks.
- **Everything optional, always**: BakalaoStudios DataStore (then the other characters of the account are known and
  can have goals), Completao, Fabrikao. Only `Modules/Data/Character.lua` names the store; tests run both with and
  without it (`LoadAddon({ store = true })`).

## Layout

- `Enfocao.toc`, `Enfocao.lua` (entry: load, enter world, `/enfocao`, `/enf`)
- `Localization/Locale.lua` — English text is the key, with the Spanish table (a test checks every key has one)
- `Modules/Core/` — `Util` (print, `ns.On`, `ns.SafeCall`, `ns.Debounce`, formatting, secret values), `Compat` (game API
  reads: C_* first, old global as fallback)
- `Modules/Settings/Settings.lua` — account-wide settings with defaults (`ns.settings`)
- `Modules/Data/Character.lua` — what is known of a character, the same shape from the store or live from the game
  (`ns.GetChar`, `ns.Reputation`, `ns.ItemCount`, `ns.QuestDone`, `ns.Factions`, the character the window shows);
  `Addons.lua` is the only file that names Completao and Fabrikao (`ns.Goals_AddonOptions(goal)`: menu entries)
- `Modules/Goals/Templates.lua` — sets of goals (`ns.GOAL_TEMPLATES`); only what the character still needs is set,
  each goal keeps `goal.group` (loaded after `Advice/`: it reuses the attunements and battlegrounds tables)
- `Modules/Plan/Plan.lua` — today's plan in `EnfocaoDB.plan[key]`: made once per daily reset, sized by the profile's
  session (45 / 60 / 120 min); a goal step is a stretch from where the goal was (`from`, `amount` in the goal's own
  units, rough rates per hour); goals newer than the plan (`lastGoal`) join it
- `Modules/Goals/` — `Types` (each kind: title, position on the way to its target, target, status, validity),
  `Goals` (saved in `EnfocaoDB.goals`; progress from where the character was when set, reached → done + announced,
  manual ticks and their daily / weekly resets, the events and store callbacks that check them)
- `Modules/Advice/` — `Profile` (the player's style in `EnfocaoDB.profile`: style, likes, session; `ns.Profile_Weight(tags)`
  turns it into a factor), `Advisors` (each advisor reads a character and returns suggestions: id, goal, why, score,
  tags; `ns.Advice_For` drops kinds already set as goals, dismissed and postponed ones, weighs by the profile, sorts;
  accept / later (3 days) / dismiss in `EnfocaoDB.advice[key]`). Texts the code passes through `L` at run time
  (milestones, ranks, slots, attunements, profile options) are exposed on `ns` for the translations test.
- `Modules/UI/` — `Widgets` (from Alterao, magenta), `Main` (window, view registry, bar of views, character picker),
  `Today` (the plan view), `Goals` (the Goals and Achieved views), `Suggestions` (the view; asks the style the first time),
  `Templates`,
  `ProfileForm` (the "Your style" form), `NewGoal` (the form; shift-click links into its boxes), `Hud` (the "Today"
  window), `Preferences`, `MinimapButton`, `About`
- `Media/` — art, never edited by hand: `images/art/emblems.ps1` cuts the Gemini pictures in `images/ai/` (the icon:
  `Icons/Enfocao.png`, `images/curseforge-icon.png`, and the views' stand-in `Emblem/Icon/Back_main.png`; a view's own
  picture `images/ai/<view>.jpg` gives `Emblem/Icon/Back_<view>.png`); `images/art/render.ps1` draws `Banner.png` and
  `Window.png` from `images/art/backdrop.html`. `images/art/recolor.ps1` turned the purple icon magenta (the original is
  in `images/originals/`).
- `test/` (WoW API mock, game mock, local runner that behaves like Lua 5.1), `setupTests.lua`

## Commands (repo root)

```powershell
lua test/busted.lua
luacheck -q -- Enfocao.lua Enfocao.test.lua Localization Modules test setupTests.lua
```

Tests that use the store load it from `../BakalaoStudios_DataStore` (CI checks it out there).

Deploy to the Forever client (PowerShell; robocopy exit codes 0-7 are success):
`robocopy . "D:\Games\World of Warcraft\_forever_\Interface\AddOns\Enfocao" *.lua *.toc *.png /S /PURGE /XD test images .github .git .claude /XF *.test.lua setupTests.lua`

## Code conventions

As in the siblings: Lua 5.1, `local ADDON, ns = ...` in every file, no new globals (`.luacheckrc`), every game read
checked for secret values (`ns.Num`), optional events through `ns.On`, `%d` gets whole numbers. Commit style:
`feat(scope):`, `fix(scope):`, `release: X.Y.Z -- short summary`.
