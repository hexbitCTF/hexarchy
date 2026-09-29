-- Firefox translucent (terminal-style glass), overrides the opaque browser default.
-- 0.65 focused / 0.55 inactive, matched on the firefox-based-browser tag.
o.window({ tag = "firefox-based-browser" }, { opacity = "0.65 0.55" })