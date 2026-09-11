# Command Metadata

Read this before adding or changing commands in `bin/`.

Commands in `bin/` can declare CLI metadata in comments near the top of the
file. `bin/hexarchy` scans the first 80 lines, and tests expect command metadata
to remain valid.

Supported metadata keys:

- `# hexarchy:group=...` - override the command group inferred from the filename
- `# hexarchy:name=...` - override the command name inferred from the filename
- `# hexarchy:summary=...` - short help text
- `# hexarchy:args=...` - usage arguments
- `# hexarchy:examples=...` - examples separated with ` | `
- `# hexarchy:alias=...` / `# hexarchy:aliases=...` - alternate routes
- `# hexarchy:hidden=true` - hide from default command listings
- `# hexarchy:requires-sudo=true` - mark commands that require sudo

Only use `hexarchy:examples` where there are args that need explaining.

Prefer explicit metadata for user-facing commands. Keep routes consistent with
the filename unless there is a deliberate alias or compatibility route.

Example:

```bash
# hexarchy:summary=Take a screenshot
# hexarchy:args=[smart|region|windows|fullscreen] [slurp|copy]
# hexarchy:examples=hexarchy screenshot | hexarchy capture screenshot region
```
