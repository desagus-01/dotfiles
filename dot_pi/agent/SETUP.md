# Pi coding-agent setup (CachyOS / Hyprland / Ghostty / Neovim)

Setup recorded 2026-10-02. This is a user-level setup; projects inherit general guidance and can add their own instructions.

## Recommendation and choices

Use Pi's native terminal UI for standalone work and **alex35mil/pi.nvim** for the editor: it speaks Pi's native JSONL RPC, gives a Neovim chat/session/model UI, and can review proposed `edit`/`write` changes before applying them. Keep CodeCompanion for the workflows you already use there. Pi itself exposes RPC, not ACP, but community `pi-acp` bridges do exist. I inspected both the published `svkozak/pi-acp` bridge and the newer unpublished `regadas/pi-acp` fork; they translate ACP clients (including CodeCompanion) to Pi RPC rather than being built-in Pi/CodeCompanion adapters. I did not add this extra bridge: pi.nvim uses Pi's protocol directly, is better integrated for Pi-specific model/session/context/image/review controls, and avoids another independently versioned process/protocol layer. If you specifically prefer CodeCompanion's chat buffer, a separate Pi ACP adapter remains a viable optional alternative. `carderne/pi-nvim` is a lighter Unix-socket/message bridge, but lacks pi.nvim's integrated history/status, model/thinking controls, image attachments, and pre-apply diff UI.

Pi stays on the providers already authenticated on this machine: **OpenAI** and **GitHub Copilot**. Existing startup selection (`openai` / `gpt-5.5`) is deliberately preserved. For coding, choose **GitHub Copilot `gpt-5.3-codex`** as the recommended primary; use **`gpt-5.4-mini`** for quicker/less involved turns, and `openai/gpt-5.5` remains in the cycling list. The first two were listed with usable Copilot auth; a live `gpt-5.3-codex` request succeeded. This adds no provider or new subscription. Usage, quota, and any provider-plan charges remain subject to your existing account terms; compare your plan before using a model heavily. The installed model catalog lists the preserved OpenAI `gpt-5.5` at **$5/M input, $30/M output, $0.50/M cached input** (higher tiers above its context threshold), so that existing default may incur API charges. GitHub Copilot model access uses your Copilot plan/quota and is not priced in this local catalog as ordinary API billing; confirm its current terms. `gpt-5.4-mini` is the faster/less involved alternative, not a claim of equivalent coding quality. The default thinking level remains **medium**; change per task/model rather than paying extra latency/token cost for high reasoning on every prompt.

## What is installed

- Pi **1.0.0** managed install (`~/.pi/agent/bin/pi`, exposed as `pi`). Auth is already configured for OpenAI and GitHub Copilot; credential files are intentionally not copied or documented here.
- Global instructions: `~/.pi/agent/AGENTS.md`.
- Pi settings: `~/.pi/agent/settings.json`: preserved default provider/model; medium thinking; useful built-in `grep`, `find`, and `ls` enabled along with read/bash/edit/write; cycling curated to Copilot Codex, Copilot mini, and OpenAI GPT-5.5; project trust stays `ask`.
- Official Pi **plan-mode** example, copied from the installed Pi 1.0.0 distribution: `~/.pi/agent/extensions/plan-mode/` (`/plan`, `/todos`, optional `--plan`).
- Neovim-compatible pre-apply diff-review extension: `~/.pi/agent/extensions/nvim-diff-review.ts`. File `edit`/`write` calls open pi.nvim's two-pane proposal review; accept/reject there. In Pi's terminal TUI it uses the ordinary accept/reject selector. This does **not** intercept shell commands, so the global instructions tell Pi to use file tools for source changes and reserve bash for inspection/tests. Pi is not a sandbox or a complete permission boundary. Verified 2026-10-03: Pi 1.0.0 auto-loads this user extension from `~/.pi/agent/extensions/`; `pi config` lists it enabled; a disposable headless Neovim diff-review accepted an edit and wrote the proposed file; and a direct extension harness confirmed native-TUI `Accept` returns control to the built-in tool while pi.nvim JSON accept blocks the tool to avoid double-writing.
- Dedicated code review extension: `~/.pi/agent/extensions/review.ts` from `mitsuhiko/agent-stuff` 1.6.0. Use `/review uncommitted`, `/review branch main`, `/review commit <sha>`, or `/review folder <paths>`; `/end-review` returns from the review branch and can hand off findings. Local reviews need no GitHub auth; `/review pr` uses `gh` and currently needs GitHub re-authentication.
- Wayland desktop notification extension: `~/.pi/agent/extensions/desktop-notify.ts`; uses `notify-send` only for settled native-TUI turns. It avoids writing OSC notification bytes to stdout, which would corrupt RPC JSONL for editor clients. Neovim has its own completion notification.
- `/discuss` planning prompt: `~/.pi/agent/prompts/discuss.md`, adapted from mitsuhiko/agent-stuff; it investigates first and does not implement until asked.
- Context7 remote MCP for current library documentation: `~/.pi/agent/mcp.json`. Pi connected successfully and discovered `resolve-library-id` and `query-docs`; it is deferred to keep routine prompts/tool lists lean. Use it with the exact package/version from the project, then check official docs/release notes for consequential questions.
- Microsoft Playwright CLI **0.1.22** installed in `~/.local/npm-global` (already on PATH), plus its `playwright-cli` skill at `~/.pi/agent/skills/playwright-cli/SKILL.md`. Playwright's Firefox **156.0** browser and FFmpeg were downloaded to `~/.cache/ms-playwright`. CachyOS is not officially identified by Playwright's installer; it selected its Ubuntu 24.04 fallback. Firefox launched successfully in headless mode. No persistent personal Firefox profile is used by default.
- Neovim plugin `alex35mil/pi.nvim`, pinned at commit `0f9f015433404da949c2e8388842c1449e88f793`, installed through the existing lazy.nvim setup. It reuses the already-installed `img-clip.nvim` and Wayland `wl-paste` for clipboard images. No additional image dependency was needed.

## Start here

**Standalone (Ghostty):**

```sh
cd /path/to/project
pi
```

Use `/plan` before a substantial change; it starts read-only and asks before switching to execution. Use `/discuss` when you want a planning conversation that ends without implementing. `Ctrl+P` cycles the configured models; `/model` and `/thinking` select models/levels; `Ctrl+C` stops a turn. Sessions are saved automatically per working directory: `pi --continue` continues the most recent one, `pi --resume` opens the picker, and `/new`, `/tree`, `/fork`, `/compact`, `/session`, and `/name` manage sessions/context. Automatic compaction is enabled by Pi's default and original transcripts remain saved.

**From Neovim:** restart/reload Neovim after installation, open the project, then:

| Mapping | Action |
|---|---|
| `<leader>aa` | Open/focus the active Pi side chat (reuse the same session; create one only if needed) |
| `<leader>ah` | Hide the active Pi chat and return to editing; the session/turn keeps running |
| `<leader>ac` | Continue latest session for this working directory |
| `<leader>ar` | Pick a session to resume |
| `<leader>af` | Insert current-file reference in the Pi prompt |
| Visual `<leader>as` | Insert selected-line reference in the Pi prompt |
| `<leader>am` / `<leader>aM` | Choose a curated model / any model |
| `<leader>at` | Choose thinking level |
| `<leader>ax` | Abort active turn |
| `<leader>al` | Toggle side/float layout |
| `<leader>av` | Attach clipboard image |

Pi's prompt buffer submits with `<CR>`; `<A-CR>` queues a follow-up; `<S-CR>` inserts a newline in insert mode. In the prompt, `<M-m>` / `<M-M>` cycle/select models and `<M-t>` / `<M-T>` cycle/select thinking. `:PiAttachImage path/to/image.png` attaches a screenshot from disk; `:PiPasteImage` uses the Wayland clipboard. `:PiAbort`, `:PiContinue`, `:PiResume`, `:PiCompact`, `:PiStop`, `:checkhealth pi`, and `:PiToggleDebug` are also available.

`<leader>a` is an intentionally separate group: your existing `<leader>c` CodeCompanion mappings and `<leader>p` Python/Quench mappings remain unchanged. Pi.nvim keeps one live session per Neovim tab and stores transcripts in the same Pi per-project session directory. `:PiStop` stops that tab's RPC process; simply hiding the chat does not.

**Context and unsaved buffers:** `PiSendMention` sends a file/line reference, not a buffer snapshot. Pi reads the on-disk file, so save with `:update` yourself before sharing an unsaved file/selection; nothing auto-saves. Unsaved selections likewise refer to the saved disk version. Paste relevant unsaved text into the prompt if you do not want to save. After an agent changes files, `autoread` plus `checktime` on focus/buffer/cursor-hold refreshes unchanged buffers. A locally modified buffer is protected; Neovim may ask how to handle an external change, so reconcile it rather than discard edits.

The agent sees your unsaved work only if you explicitly provide it. The prompt editor's mention completion/context is convenient, but always review staged and unstaged diffs yourself.

## Research, browser, Git, and trust

- **Docs:** Context7 is ready immediately (`pi mcp list` showed it connected). Use its lookup tools for current library docs. Pi has native MCP support; project MCP config/resources load only after project trust. Do not copy credentials from CodeCompanion's MCPHub JSON into Pi. The existing Brave/GitHub/Memory/sequential-thinking servers belong to CodeCompanion's MCPHub; they are not automatically shared with Pi. `gh auth status` currently reports the saved GitHub token invalid, so GitHub CLI PR/API review needs `gh auth refresh` before it will work. Local `git status`, `git diff`, existing Neovim GitSigns/Diffview, and Pi's review instructions work without that login.
- **Browser:** install prerequisites are ready. From a project with a running local server: `playwright-cli open http://127.0.0.1:PORT --browser=firefox`, `snapshot`, `console error`, and `screenshot --filename=/tmp/app.png`; use `goto`, `click`/`fill`, and `eval` as needed, then `close`. It uses an isolated headless profile. The skill teaches the agent to inspect snapshots, console errors, and screenshots. Headed mode is optional (`--headed`); no live personal browser profile is attached. On CachyOS the tested Firefox build was Playwright's Ubuntu fallback; if a future upgrade reports missing shared libraries, install the missing Arch/CachyOS runtime packages (do not run Playwright's apt-based `--with-deps` blindly).
- **GitHub/web:** no new Brave secret was copied. General web research is possible with available shell/network tools and cited URLs, but Context7 is the immediately configured structured web-doc lookup. GitHub remote API operations require refreshing the invalid `gh` token.
- **Project trust:** Pi keeps `defaultProjectTrust: ask`. Native `pi` can prompt; accept only repositories whose `.pi` settings/extensions/MCP/skills you trust. pi.nvim's RPC UI does not implement Pi's interactive project-trust prompt, so untrusted project `.pi` resources are skipped there until trust is saved from the native Pi UI (`/trust`). Do **not** add `--approve` globally: it would trust every project's executable extensions/packages. General `AGENTS.md` context files load without that trust prompt; they are guidance, not a security boundary.
- Pi runs as your user and has no built-in OS sandbox. Review changes, be cautious with untrusted repositories and shell commands, and use an OS/container boundary for genuinely hostile code.

## Environment findings

- CachyOS Linux, Hyprland/Wayland, **Ghostty** (`TERM=xterm-ghostty`), zsh, Neovim 0.12.5, Node 22.23.3/npm 12.2.0, Python 3.14.7, `uv` 0.7.3/pytest, R 4.6.1, Git 2.56, Cargo/Rust, Go, `wl-paste`/`wl-copy`, `notify-send`, `gh`, and Firefox are present. A global `tsc`/`tsx` is **not** installed; use each TypeScript project's declared package scripts/dev dependencies (or its package runner) rather than assuming a global compiler. The environment's `EDITOR` is `nvim`.
- Active Neovim config is a real directory at `~/.config/nvim` (not a symlink), a Git checkout of `kickstart-modular.nvim`; lazy.nvim is the plugin manager. ChezMoi manages other dotfiles, but does not manage this Neovim tree. Its own `.gitignore` ignores `lazy-lock.json`; the Pi plugin is consequently pinned directly by commit in `lua/kickstart/plugins/pi.lua`.
- Existing CodeCompanion, MCPHub and their mappings/configuration were preserved. The `~/.local/share/chezmoi` status already showed unrelated staged/unstaged changes in `.config/.oh-my-zsh/oh-my-zsh.sh` and `.config/.oh-my-zsh/templates/zshrc.zsh-template`; these remain untouched. Existing `otter.nvim` has a local edit in its installed plugin directory; the lazy sync warned and deliberately did not overwrite it. CodeCompanion and `mini.nvim` installed revisions were restored to the pre-setup lockfile commits after sync; the ignored lockfile now also records the pinned pi.nvim commit.
- Pi auth/settings/session data are under `~/.pi/agent`. Session transcripts can contain source, prompts, tool output, and secrets; don't share/export without inspection.

## Research record (versions/commits inspected)

- Installed Pi distribution: **1.0.0**, source commit `a13d35a742c6ef8462812a28fbe1d8c8b7431c32`. Its bundled `docs/` and `examples/` were checked for settings/models, trust/security, MCP/OAuth, sessions/compaction, extension API, and RPC. Key references: [configuration](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/configuration.md), [settings](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/settings.md), [models](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/models.md), [RPC](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/rpc.md), [MCP](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/mcp.md), [trust/security](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/security.md), and [compaction](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/compaction.md).
- Official Pi extension examples shipped with 1.0.0: `plan-mode` selected; notification example inspected but its OSC-on-stdout approach was not used for RPC. Local source reference: `~/.pi/agent/install/releases/1.0.0/node_modules/@earendil-works/pi-coding-agent/examples/extensions/`.
- `mitsuhiko/agent-stuff` **1.6.0**, commit `0865c84` (2026-09-27): its manifest broadly installs personal extensions/skills (including macOS/tmux/uv assumptions), so the package was **not** installed wholesale. Its `/discuss` prompt was adapted and its focused `extensions/review.ts` was copied after source review; this extension has no third-party npm imports. [Source](https://github.com/mitsuhiko/agent-stuff).
- `alex35mil/pi.nvim` commit `0f9f015` (2026-07-08): inspected RPC implementation, requirements, trust limitation, keymaps, model/session controls, image support, and pre-apply diff protocol; selected. [Source/docs](https://github.com/alex35mil/pi.nvim).
- `carderne/pi-nvim` commit `3efbe67` (2026-09-02): inspected its Unix-socket extension/plugin bridge; not selected (less integrated RPC/session/UI features). [Source/docs](https://github.com/carderne/pi-nvim).
- Microsoft `playwright-cli` commit `b85c7a7`, npm version **0.1.22** (2026-09-28), Playwright dependency **1.64.0-alpha-1790635538000**: CLI/source and skill inspected. CLI's token-efficient skill approach was preferred over a browser MCP. [Source/docs](https://github.com/microsoft/playwright-cli).
- Context7's remote MCP endpoint was live-tested at `https://mcp.context7.com/mcp`; official service docs: [Context7 docs](https://context7.com/docs).
- CodeCompanion v19 source/docs (installed commit `9af12c15`) show ACP support and the existing OpenCode default. Pi does not speak ACP natively. Two community bridges were inspected: published [`svkozak/pi-acp`](https://github.com/svkozak/pi-acp) npm **0.0.34**, source commit `b0581c9` (2026-09-24, Node >=20, Pi >=0.81.0), and [`regadas/pi-acp`](https://github.com/regadas/pi-acp) **0.1.0** source commit `6e20d70` (2026-09-30, Node >=22.19, Pi >=0.80.4). The latter is a more extensively validated, actively developed fork, but npm reported `@regadas/pi-acp` is not published; it requires a source build. Its README/source disclose ACP gaps (e.g. no client-supplied MCP, FS/terminal delegation, additional workspace dirs, fork/steering, or sandbox/approval protocol). The published original is easier to invoke with `npx` but its README says Pi extension commands are not exposed and MCP is not actually wired through. Either is technically Pi 1.0/RPC-compatible by its declared minimum, but CodeCompanion-specific compatibility was not exercised. Neither was installed because native pi.nvim is the chosen primary and the bridges add a second independently maintained integration. Existing CodeCompanion settings and locked commit were preserved.

## Verification and limitations

Passed: Pi 1.0.0 and settings/MCP JSON validation; both existing providers report ready; live GitHub Copilot `gpt-5.3-codex` request returned `MODEL_OK`; Context7 connected with two tools; Pi RPC `get_commands` confirmed `/plan`, `/discuss`, `/review`, `/end-review`, and `/skill:playwright-cli` are loaded; headless Neovim loaded `require('pi')`, registered the mappings/commands, and set `autoread`; invoking the new hide/open mappings hid and reopened Pi while preserving the exact same session and live RPC process; pi.nvim inserted both a current-file `@probe.py` and selected-line `@probe.py#L1-2` reference into its prompt without sending a request; its RPC process started, answered initial state, and stopped cleanly; direct Pi RPC `get_state` returned the expected `openai/gpt-5.5` default; pi.nvim is installed at its pinned commit.

The disposable Python counter task reproduced two failing unit tests, corrected the subtraction bug, passed both tests and `py_compile`, and passed `git diff --check`. The browser test served a local page in Playwright Firefox: its initial button click produced a `ReferenceError`, the console identified the undefined name, the fix made the counter increment to `1`, and a second console check had zero errors; a screenshot was captured and inspected. The disposable project, browser session, and generated test files were removed.

Not interactively exercised: accepting/rejecting a Pi edit in pi.nvim's two-pane UI, clipboard image insertion, project-trust prompts, and a full model-driven prompt submitted from the Neovim UI. Start with `<leader>aa` and test a harmless request/edit in a disposable project; the RPC process and protocol were verified separately.

## Upgrade, backup, removal

- Backup before this setup: `~/.pi/agent/backups/20261002-113614/`; pointer: `~/.pi/agent/backups/LATEST`. Pi settings were merged, not replaced. Neovim changes are in its Git tree; unrelated working edits were not reverted.
- Pi upgrades: `pi update self`; refresh model catalog with `pi update --models`. Read release notes and re-check extension/plugin compatibility before major updates.
- Neovim: `:Lazy update` only after choosing to update; pi.nvim is currently commit-pinned. To upgrade it deliberately, update the pin in `lua/kickstart/plugins/pi.lua` and run `:Lazy sync`. Avoid `Lazy! sync` as a casual upgrade command; it tries to sync other plugins too.
- Playwright CLI: `npm update --global --prefix ~/.local/npm-global @playwright/cli`; install a matching browser after package upgrades with the Playwright CLI's bundled `playwright/cli.js install firefox` if needed.
- Remove the Neovim entry `require 'kickstart.plugins.pi'` from `lua/lazy-plugins.lua`, remove `lua/kickstart/plugins/pi.lua` and the `<leader>a` WhichKey group, then `:Lazy sync` and remove `~/.local/share/nvim/lazy/pi.nvim` if it remains. Delete only Pi files listed above if you no longer want those features; keep auth, sessions, and user data unless intentionally removing them.
- Remove browser CLI with `npm uninstall --global --prefix ~/.local/npm-global @playwright/cli`; optional browser binaries are under `~/.cache/ms-playwright`.
- To restore Pi's original settings, copy the backup back only if you want to undo these defaults; manually preserve any later settings you have added. `~/.pi/agent/auth.json`, `mcp-auth.json`, sessions, and project files were not included in the backup or overwritten.

## Project-specific instructions later

Keep this global `AGENTS.md` generic. In each repository, use its `AGENTS.md` (or an appropriate nested `AGENTS.md`) for that project's build/test commands, architecture, conventions, environment setup, and acceptance criteria. Put trusted Pi-specific project settings/extensions/skills/MCP in `.pi/` only when needed; review the trust prompt first. Project instructions should complement, not duplicate or contradict, global behavior.
