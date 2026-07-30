<p align="center">
  <img src="assets/logo.svg" alt="material-osc logo" width="128">
</p>

# material-osc

A quality-of-life upgrade for mpv that keeps the player lightweight while
making everyday controls easier to reach and nicer to use. material-osc brings
a polished Material-style interface, smooth animated feedback, automatic
directory playlists and much more.

I would say, you should fuck around and find out!

## Showcase

https://github.com/user-attachments/assets/65046da7-7d9e-4492-9e93-47650b8fc484

## Configuration

material-osc can be customized with a `material-osc.conf` file in mpv's
`script-opts` directory. You can also open file from **Right-click → Configurations**.

<details>
<summary>Show Options</summary>

| Option | Default | Accepted values | Description |
| --- | --- | --- | --- |
| `dpi_scale` | `auto` | `auto` or `0.5`–`4` | Uses the display scale automatically or applies a fixed UI scale. |
| `accent_color` | `"#00bbff"` | Quoted six-digit RGB color | Sets the seekbar, selections, toggles, and other highlighted elements. |
| `context_menu` | `yes` | `yes`, `no` | Enables the material-osc context menu. When disabled, right-click and menu-key bindings remain available to mpv and other scripts. |
| `tooltip` | `yes` | `yes`, `no` | Enables tooltips for controls. |
| `show_mini_seekbar` | `no` | `yes`, `no` | Keeps a 1dp playback-progress line at the bottom while the main controls are hidden. |
| `screenshot_button` | `yes` | `yes`, `no` | Shows or hides the screenshot button in the playback controls. |
| `pip_button` | `yes` | `yes`, `no` | Shows or hides the Picture-in-Picture button in the playback controls. |
| `window_controls` | `auto` | `auto`, `yes`, `no` | Shows window controls automatically for borderless and fullscreen windows, always, or never. |
| `mouse_timeout` | `2` | Seconds; `0` disables timeout | Controls how long the UI remains visible after pointer activity. |
| `show_on_mouse_move` | `no` | `yes`, `no` | With `yes`, movement anywhere reveals the UI. With `no`, use the bottom edge for playback controls or the top edge for window controls. |
| `single_click_actions_enabled` | `yes` | `yes`, `no` | Enables single-click play/pause and left/right edge seeking. Double-click fullscreen remains available when disabled. |
| `seeking_zone_percentage` | `15` | `0`–`50` | Sets each fast-seek zone's width as a percentage of the window. |
| `seek_step_seconds` | `5` | Seconds; minimum `1` | Sets how far edge clicks and edge scrolling seek backward or forward. |
| `temporary_speed` | `2` | Playback rate greater than `0` | Sets the speed used while the `hold-double-speed` binding is held. |
| `max_volume_percentage` | `150` | Percentage; minimum `100` | Sets mpv's upper volume limit and the OSC volume range. |
| `force_hwdec` | `no` | `yes`, `no` | With `no`, preserves mpv's configured `hwdec` value. Set to `yes` to opt into `hwdec=auto`; this may be unstable with some live streams and hybrid-GPU systems. |
| `force_display_resample` | `yes` | `yes`, `no` | With `no`, preserves mpv's configured `video-sync` value. Set to `yes` to opt into `video-sync=display-resample`. |
| `force_force_window` | `yes` | `yes`, `no` | Keeps an mpv window open even before a file is loaded. With `no`, material-osc preserves the configured `force-window` value. |
| `directory_playlist` | `yes` | `yes`, `no` | Adds nearby video and audio files when opening a local file, unless a multi-item playlist already exists. |
| `directory_playlist_sort` | `name` | `name`, `newest`, `oldest` | Selects how automatically discovered directory entries are ordered. |
| `youtube_quality` | `auto` | `auto` or a vertical resolution such as `1080` | Sets the maximum quality used when initially loading YouTube videos. `auto` preserves mpv's configured `ytdl-format`. |

</details>

YouTube watch links containing a `list` parameter load the full playlist and
start at the linked video. To keep mpv's single-video behavior, explicitly set
`ytdl-raw-options=no-playlist=` in `mpv.conf`.

### Window controls

With `window_controls=auto`, material-osc provides minimize, maximize/restore, and
close buttons when mpv runs without native window decorations (`border=no` in
`mpv.conf`) or enters fullscreen.

The script disables automatic window resizing and starts the window at 66% of
the screen height. Its width is calculated from the video's aspect ratio.

Thumbnail previews require [Thumbfast](https://github.com/po5/thumbfast). Install
`thumbfast.lua` in mpv's `scripts` directory alongside material-osc. Thumbnail
behavior, including support for network media, is configured through Thumbfast:

```conf
# script-opts/thumbfast.conf
network=yes
```

## Building

The repository keeps the complete Material Symbols Rounded TTF for development.
Release builds automatically subset it to the icons referenced by the Lua sources.
The generated archive places renamed fonts under `fonts/` and the minified,
bundled Lua script under `scripts/`. The brand mark is implemented as a bundled
ASS drawing, so the archive is ready to extract into the mpv configuration
directory.

```bash
python -m venv .venv
.venv/bin/pip install -r requirements-build.txt
.venv/bin/python bundle.py 1.0.0
```
