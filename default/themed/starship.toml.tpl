add_newline = true
command_timeout = 200
format = """$username$hostname$directory$git_branch$git_status$docker_context$nodejs$python$rust$cmd_duration$line_break$character"""

palette = "hexarchy"

[palettes.hexarchy]
blue = "{{ blue }}"
cyan = "{{ cyan }}"
green = "{{ green }}"
magenta = "{{ magenta }}"
orange = "{{ orange }}"
red = "{{ red }}"
yellow = "{{ yellow }}"
fg = "{{ foreground }}"
muted = "{{ muted }}"

[character]
error_symbol = "[✗](red)"
success_symbol = "[❯](blue)"
vicmd_symbol = "[❮](magenta)"

[directory]
style = "bold blue"
truncation_length = 3
truncation_symbol = "…/"
read_only = " 🔒"
repo_root_style = "bold cyan"
repo_root_format = "[$repo_root]($repo_root_style)[$path]($style)[$read_only]($read_only_style) "

[git_branch]
format = "[$symbol$branch]($style) "
symbol = ""
style = "italic cyan"

[git_status]
format = "([$all_status]($style) )"
style = "cyan"
ahead = "⇡${count} "
diverged = "⇕⇡${ahead_count}⇣${behind_count} "
behind = "⇣${count} "
conflicted = ""
up_to_date = ""
untracked = "? "
modified = "~ "
stashed = " "
staged = "+ "
renamed = "→ "
deleted = "✘ "

[docker_context]
format = "[$symbol$context]($style) "
symbol = "🐳 "
style = "cyan"

[nodejs]
format = "[$symbol($version)]($style) "
symbol = " "
style = "green"

[python]
format = "[$symbol($version)]($style) "
symbol = " "
style = "yellow"

[rust]
format = "[$symbol($version)]($style) "
symbol = "🦀 "
style = "red"

[cmd_duration]
format = "[$duration]($style) "
style = "muted"
min_time = 2000
show_notifications = false

[os]
disabled = false
style = "bold white"

[os.symbols]
Arch = "arch "
Linux = "linux "
