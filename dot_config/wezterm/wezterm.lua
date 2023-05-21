local wezterm = require 'wezterm'
local act = wezterm.action

local LEFT_ARROW = utf8.char(0xff0b3)
local SOLID_LEFT_ARROW = utf8.char(0xff0b2)
local SOLID_RIGHT_ARROW = utf8.char(0xff0b0)
local scrollback_lines = 200000;

return {
  check_for_updates = false,
  ssh_backend = "LibSsh",

  color_scheme = "s3r0 modified (terminal.sexy)", 
  -- color_scheme = "Gruvbox dark, soft (base16)",
  window_background_opacity = 0.95,

  window_decorations = 'TITLE|RESIZE',
  window_padding = {
    left = 7,
    right = 7,
    top = 7,
    bottom = 7,
  },
  inactive_pane_hsb = {
    hue = 1,
    saturation = .6,
    brightness = .4,
  },

  font = wezterm.font("Recursive Mono Casual Static", {weight="Light", stretch="Normal", style="Normal"}),
  font_size = 18,
  -- font_antialias = "Greyscale", -- None, Greyscale, Subpixel
  -- font_hinting = "Full",  -- None, Vertical, VerticalSubpixel, Full
  -- harfbuzz_features = {"kern", "liga", "clig", "calt"},

  -- disable_default_key_bindings = true,
  keys = {
    { key = 'LeftArrow',  mods = 'OPT|SHIFT', action = act.RotatePanes 'CounterClockwise', },
    { key = 'RightArrow', mods = 'OPT|SHIFT', action = act.RotatePanes 'Clockwise' },
    -- { key = '8', mods = 'OPT', action = act.PaneSelect },
    -- { key = '9', mods = 'OPT', action = act.PaneSelect { alphabet = '1234567890', }, },
    -- { key = '0', mods = 'OPT', action = act.PaneSelect { mode = 'SwapWithActive', }, },
    { key = "-", mods = "OPT",                action=wezterm.action{SplitVertical={domain="CurrentPaneDomain"}}},
    { key = "=", mods = "OPT",                action=wezterm.action{SplitHorizontal={domain="CurrentPaneDomain"}}},
    { key = ".", mods = "OPT",                action="TogglePaneZoomState" },
    { key = "LeftArrow",  mods = "OPT",       action=wezterm.action{AdjustPaneSize={"Left", 5}}},
    { key = "RightArrow", mods = "OPT",       action=wezterm.action{AdjustPaneSize={"Right", 5}}},
    { key = "UpArrow",    mods = "OPT",       action=wezterm.action{AdjustPaneSize={"Up", 5}}},
    { key = "DownArrow",  mods = "OPT",       action=wezterm.action{AdjustPaneSize={"Down", 5}}},
    { key = 'UpArrow',    mods = 'SHIFT',     action = act.ScrollToPrompt(-1) },
    { key = 'DownArrow',  mods = 'SHIFT',     action = act.ScrollToPrompt(1) },
  },

  use_fancy_tab_bar = true,

  -- tab_bar_style = {
  --   active_tab_left = wezterm.format(
  --     {
  --       { Background = { Color = "#0b0022" } },
  --       { Foreground = { Color = "#3c1361" } },
  --       { Text = SOLID_LEFT_ARROW }
  --     }
  --   ),
  --   active_tab_right = wezterm.format(
  --     {
  --       { Background = { Color = "#0b0022" } },
  --       { Foreground = { Color = "#3c1361" } },
  --       { Text = SOLID_RIGHT_ARROW }
  --     }
  --   ),
  --   inactive_tab_left = wezterm.format(
  --     {
  --       { Background = { Color = "#0b0022" } },
  --       { Foreground = { Color = "#1b1032" } },
  --       { Text = SOLID_LEFT_ARROW }
  --     }
  --   ),
  --   inactive_tab_right = wezterm.format(
  --     {
  --       { Background = { Color = "#0b0022" } },
  --       { Foreground = { Color = "#1b1032" } },
  --       { Text = SOLID_RIGHT_ARROW }
  --     }
  --   )
  -- },

  -- colors = {
  --   tab_bar = {
  --       background = "#282828",
  --       active_tab = {
  --           bg_color = "#282828",
  --           fg_color = "#fe8019",
  --           intensity = "Normal",
  --           underline = "None",
  --           italic = false,
  --           strikethrough = false,
  --       },
  --       inactive_tab = {
  --           bg_color = "#282828",
  --           fg_color = "#a89984",
  --       },
  --       inactive_tab_hover = {
  --           bg_color = "#282828",
  --           fg_color = "#a89984",
  --       },

  --       new_tab = {
  --           bg_color = "#282828",
  --           fg_color = "#458588",
  --       },
  --       new_tab_hover = {
  --           bg_color = "#282828",
  --           fg_color = "#808080",
  --       },
  --   },
  -- },
}
