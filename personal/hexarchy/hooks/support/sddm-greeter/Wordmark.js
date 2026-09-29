// Hexarchy block-wordmark: the same art `hexarchy ascii hexarchy` renders in
// the terminal, using the Delta Corps Priest 1 FIGlet font. Kept as a plain
// multi-line string here so the QML binding parses it as ordinary JavaScript
// rather than relying on backtick literals inside a QML property binding.
//
// Rendered in the lock screen with a monospace face so the block glyphs stay
// aligned; coloured via the active theme's lock text colour instead of being a
// static bitmap.

var wordmark = "   ▄█    █▄       ▄████████ ▀████    ▐████▀    ▄████████    ▄████████  ▄████████    ▄█    █▄    ▄██   ▄\n" +
"  ███    ███     ███    ███   ███▌   ████▀    ███    ███   ███    ███ ███    ███   ███    ███   ███   ██▄\n" +
"  ███    ███     ███    █▀     ███  ▐███      ███    ███   ███    ███ ███    █▀    ███    ███   ███▄▄▄███\n" +
" ▄███▄▄▄▄███▄▄  ▄███▄▄▄        ▀███▄███▀      ███    ███  ▄███▄▄▄▄██▀ ███         ▄███▄▄▄▄███▄▄ ▀▀▀▀▀▀███\n" +
"▀▀███▀▀▀▀███▀  ▀▀███▀▀▀        ████▀██▄     ▀███████████ ▀▀███▀▀▀▀▀   ███        ▀▀███▀▀▀▀███▀  ▄██   ███\n" +
"  ███    ███     ███    █▄    ▐███  ▀███      ███    ███ ▀███████████ ███    █▄    ███    ███   ███   ███\n" +
"  ███    ███     ███    ███  ▄███     ███▄    ███    ███   ███    ███ ███    ███   ███    ███   ███   ███\n" +
"  ███    █▀      ██████████ ████       ███▄   ███    █▀    ███    ███ ████████▀    ███    █▀     ▀█████▀";

var wordmarkLines = 8;
var wordmarkColumns = 108;
