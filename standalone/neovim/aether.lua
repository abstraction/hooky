-- Hooky - Neovim theme using aether.nvim
-- https://github.com/abstraction/hooky
--
-- For LazyVim / lazy.nvim: save to ~/.config/nvim/lua/plugins/theme.lua

return {
  {
    "bjarneo/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = {
      colors = {
        bg = "#191716",
        dark_bg = "#141312",
        darker_bg = "#0f0e0d",
        lighter_bg = "#221f1d",

        fg = "#cfc6b8",
        dark_fg = "#7d766d",
        light_fg = "#b5ada3",
        bright_fg = "#cfc6b8",
        muted = "#9b948a",

        red = "#dc7468",
        yellow = "#d8a657",
        orange = "#e59458",
        green = "#a3b26c",
        cyan = "#88b29e",
        blue = "#6eb3c2",
        magenta = "#cc8292",
        brown = "#825d43",

        bright_red = "#dc7468",
        bright_yellow = "#d8a657",
        bright_green = "#a3b26c",
        bright_cyan = "#88b29e",
        bright_blue = "#6eb3c2",
        bright_magenta = "#cc8292",

        accent = "#e59458",
        cursor = "#cfc6b8",
        foreground = "#cfc6b8",
        background = "#191716",
        selection = "#3a3430",
        selection_foreground = "#cfc6b8",
        selection_background = "#3a3430",
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "aether",
    },
  },
}
