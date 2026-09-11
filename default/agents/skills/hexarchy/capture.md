# Capture and Sharing

Read this before taking screenshots or screen recordings, extracting text from
the screen, or sharing files with other machines.

## Screenshots

```bash
hexarchy screenshot                            # Interactive smart-region flow
hexarchy capture screenshot region             # Select a region
hexarchy capture screenshot windows            # Pick a window
hexarchy capture screenshot fullscreen save    # Full screen, straight to disk (no editor)
```

The first argument picks the mode (`smart|region|windows|fullscreen`), the
second what happens with it (`slurp|copy|save`). `save` skips the annotation
editor and prints the saved path. Screenshots land in the configured Pictures
directory (override with `HEXARCHY_SCREENSHOT_DIR`).

## Screen Recording

```bash
hexarchy screenrecord --fullscreen             # Start recording the full screen
# ...exercise whatever you want on film...
hexarchy screenrecord --stop-recording         # Stop; prints the saved path
```

Optional flags: `--with-desktop-audio`, `--with-microphone-audio`,
`--with-webcam` (plus `--webcam-device=` and `--webcam-size=`), and
`--resolution=<size>`. Without `--fullscreen` a region picker opens first.
Recordings land in the configured Videos directory (override with
`HEXARCHY_SCREENRECORD_DIR`). Resize a live webcam overlay with
`hexarchy capture webcam resize <smaller|larger|reset|small|medium|large>`.

If recording fails to start, rerun with `HEXARCHY_SCREENRECORD_DEBUG=true` to
collect a log at `/tmp/hexarchy-screenrecord.log` worth attaching to a bug
report.

## Text Capture (OCR)

```bash
hexarchy capture text    # Select a region; extracted text goes to the clipboard
```

## Sharing Files

```bash
hexarchy share clipboard               # Share the clipboard via LocalSend
hexarchy share file <path...>          # Share files with nearby devices
hexarchy share folder <path>           # Share a folder

hexarchy tailscale send <machine> <file...>    # Taildrop to a tailnet machine
hexarchy tailscale receive [directory]         # Save incoming Taildrop files
```

Shrink large captures before sharing them:

```bash
hexarchy transcode <input> [format] [resolution]   # Re-encode pictures/videos for sharing
```
