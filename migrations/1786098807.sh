echo "Relink agent skill symlinks to default/agents/skills/hexarchy"

mkdir -p ~/.agents/skills ~/.claude/skills ~/.codex/skills ~/.pi/agent/skills
ln -sfn "$HEXARCHY_PATH/default/agents/skills/hexarchy" ~/.agents/skills/hexarchy
ln -sfn "$HEXARCHY_PATH/default/agents/skills/hexarchy" ~/.claude/skills/hexarchy
ln -sfn "$HEXARCHY_PATH/default/agents/skills/hexarchy" ~/.codex/skills/hexarchy
ln -sfn "$HEXARCHY_PATH/default/agents/skills/hexarchy" ~/.pi/agent/skills/hexarchy
