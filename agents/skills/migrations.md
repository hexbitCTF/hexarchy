# Hexarchy migrations

Read this before creating or changing migrations under `migrations/`.

Hexarchy migrations are one-time repair scripts for existing installs. They are
used when a package update needs to change state that pacman cannot safely own by
itself.

## Migration model

Migrations live in:

```text
migrations/*.sh
```

They run as the current Hexarchy user through `hexarchy-migrate`, normally during
`hexarchy update`. A migration may touch user/session state (`~/.config`,
`~/.local`, user systemd, browser/editor prefs, DBus/session state), and may also
perform machine-wide repairs when needed.

Completion state is per-user:

```text
~/.local/state/hexarchy/migrations/<migration filename>
```

That means every user gets a chance to run every migration. Migrations run as the
user; privileged operations should invoke the appropriate helper or privilege
prompt themselves. Migrations must be idempotent: if one user already applied a
machine-wide repair, the same migration running for another user should detect
that and no-op.

## When migrations run

### During `hexarchy update`

`hexarchy update` is the normal update path. It runs package updates, then:

```bash
hexarchy-migrate
hexarchy-hook post-update
```

`hexarchy-migrate` waits for any active pacman transaction to finish, then runs
all pending migrations for the current user in the visible update terminal.

### At login

Every graphical login starts `hexarchy-migrate-notify.service` after
`graphical-session.target`. The notifier checks:

```bash
hexarchy-migrate --pending
```

It stays silent while `hexarchy update` holds its lock, since that update applies
the pending migrations itself.

If that user has pending migrations, it shows a notification that opens a
terminal for:

```bash
hexarchy-migrate
```

The notifier never runs migrations silently in the background.

This is what covers users who did not run the update themselves: someone who
bypassed the pacman guard with `sudo env HEXARCHY_ALLOW_DIRECT_PACMAN=1 pacman
-Syu`, and any second user on the machine, whose migration markers are per-user
and therefore still missing after another user updated.

Login is the only trigger on purpose. Watching the packaged migration directory
also fires during a normal `hexarchy update`, which prompts for migrations that
`hexarchy-migrate` is about to run in the visible update terminal.

### Manually

Users can safely run:

```bash
hexarchy-migrate
```

at any time. Already-completed migrations are skipped.

## Inspecting pending migrations

Use:

```bash
hexarchy-migrate --pending
```

Exit behavior:

- `0` — one or more migrations are pending
- non-zero — no migrations are pending

Output is one pending migration per line:

```text
1781158082.sh
```

## Creating a migration

Use the helper:

```bash
hexarchy-dev-add-migration --no-edit
```

This creates:

```text
migrations/<unix timestamp>.sh
```

New migration format:

- File permissions must be `0644` (`-rw-r--r--`). Migration runners execute them
  with `bash -euo pipefail`, not through executable bits.
- No shebang line.
- Start with an `echo` describing what the migration does.
- Use `$HEXARCHY_PATH` to reference the Hexarchy directory.
- Be idempotent. Check existing state before changing it.
- Use helper commands such as `hexarchy-cmd-present`, `hexarchy-cmd-missing`,
  `hexarchy-pkg-add`, `hexarchy-pkg-drop`, `hexarchy-pkg-present`, and
  `hexarchy-pkg-missing` when appropriate.
- Never restart the Hexarchy shell. `hexarchy update` restarts it unconditionally
  after migrations run, and the login-time shell already runs current code and
  hot-reloads `shell.json` edits.
- Raw `pacman`, `command -v`, and direct config edits are acceptable when
  needed for one-off repair work.

Example:

```bash
echo "Relink Neovim theme to Hexarchy current state"

theme_link="$HOME/.config/nvim/lua/plugins/theme.lua"
current_relative_target="../../../../.local/state/hexarchy/current/theme/neovim.lua"

[[ -L $theme_link ]] || exit 0
ln -sfn "$current_relative_target" "$theme_link"
```

## Testing migrations

Run a migration against a temporary home when possible:

```bash
HOME=$(mktemp -d) bash -euo pipefail migrations/<timestamp>.sh
```

To rerun a migration locally, remove its marker and run the migrator:

```bash
rm ~/.local/state/hexarchy/migrations/<migration>.sh
hexarchy-migrate
```

Hexarchy 4.0 is upgraded through `bin/hexarchy-upgrade-to-quattro`, not through the
normal migration runner. Do not add compatibility migrations for old installer
layouts; put pre-4 package-layout transition work in the upgrade command instead.
