-- Terra (Hooky) - Standalone Neovim Colorscheme
-- https://github.com/seren/hooky
--
-- Put this file in ~/.config/nvim/colors/terra.lua
-- and add `vim.cmd.colorscheme("terra")` in your init.lua.

local colors = {
  bg         = "#191716",
  dark_bg    = "#141312",
  lighter_bg = "#221f1d",
  selection  = "#3a3430",
  border     = "#2a2725",

  fg         = "#cfc6b8",
  bright_fg  = "#cfc6b8",
  light_fg   = "#b5ada3",
  dark_fg    = "#7d766d",
  muted      = "#9b948a",

  accent     = "#e59458",
  red        = "#dc7468",
  yellow     = "#d8a657",
  orange     = "#e59458",
  green      = "#a3b26c",
  cyan       = "#88b29e",
  blue       = "#6eb3c2",
  magenta    = "#cc8292",
  brown      = "#825d43",
}

vim.cmd("hi clear")
if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end

vim.g.colors_name = "terra"
vim.o.termguicolors = true
vim.o.background = "dark"

local hl = function(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

-- Editor UI
hl("Normal",       { fg = colors.fg, bg = colors.bg })
hl("NormalFloat",  { fg = colors.fg, bg = colors.lighter_bg })
hl("FloatBorder",  { fg = colors.accent, bg = colors.lighter_bg })
hl("ColorColumn",  { bg = colors.lighter_bg })
hl("Cursor",       { fg = colors.bg, bg = colors.bright_fg })
hl("CursorLine",   { bg = colors.lighter_bg })
hl("CursorColumn", { bg = colors.lighter_bg })
hl("LineNr",       { fg = colors.dark_fg })
hl("CursorLineNr", { fg = colors.accent, bold = true })
hl("VertSplit",    { fg = colors.border, bg = colors.bg })
hl("WinSeparator", { fg = colors.border, bg = colors.bg })
hl("Visual",       { bg = colors.selection })
hl("VisualNOS",    { bg = colors.selection })
hl("Search",       { fg = colors.bg, bg = colors.yellow })
hl("IncSearch",    { fg = colors.bg, bg = colors.accent })
hl("CurSearch",    { fg = colors.bg, bg = colors.accent })

-- Popups & Menus
hl("Pmenu",        { fg = colors.fg, bg = colors.lighter_bg })
hl("PmenuSel",     { fg = colors.accent, bg = colors.selection, bold = true })
hl("PmenuSbar",    { bg = colors.lighter_bg })
hl("PmenuThumb",   { bg = colors.muted })

-- Status & Tabline
hl("StatusLine",   { fg = colors.fg, bg = colors.dark_bg })
hl("StatusLineNC", { fg = colors.muted, bg = colors.dark_bg })
hl("TabLine",      { fg = colors.muted, bg = colors.dark_bg })
hl("TabLineFill",  { bg = colors.dark_bg })
hl("TabLineSel",   { fg = colors.accent, bg = colors.lighter_bg, bold = true })

-- Syntax Highlighting
hl("Comment",      { fg = colors.muted, italic = true })
hl("Constant",     { fg = colors.orange })
hl("String",       { fg = colors.green })
hl("Character",    { fg = colors.green })
hl("Number",       { fg = colors.orange })
hl("Boolean",      { fg = colors.orange, bold = true })
hl("Float",        { fg = colors.orange })

hl("Identifier",   { fg = colors.fg })
hl("Function",     { fg = colors.blue })
hl("Statement",    { fg = colors.magenta })
hl("Conditional",  { fg = colors.magenta })
hl("Repeat",       { fg = colors.magenta })
hl("Label",        { fg = colors.magenta })
hl("Operator",     { fg = colors.cyan })
hl("Keyword",      { fg = colors.magenta, bold = true })
hl("Exception",    { fg = colors.red })

hl("PreProc",      { fg = colors.yellow })
hl("Include",      { fg = colors.magenta })
hl("Define",       { fg = colors.magenta })
hl("Macro",        { fg = colors.cyan })
hl("PreCondit",    { fg = colors.yellow })

hl("Type",         { fg = colors.yellow })
hl("StorageClass", { fg = colors.yellow })
hl("Structure",    { fg = colors.yellow })
hl("Typedef",      { fg = colors.yellow })

hl("Special",      { fg = colors.cyan })
hl("SpecialChar",  { fg = colors.cyan })
hl("Tag",          { fg = colors.accent })
hl("Delimiter",    { fg = colors.light_fg })
hl("SpecialComment", { fg = colors.muted, bold = true })
hl("Underlined",   { underline = true })
hl("Error",        { fg = colors.red, bold = true })
hl("Todo",         { fg = colors.bg, bg = colors.yellow, bold = true })

-- Diffs
hl("DiffAdd",      { fg = colors.green, bg = colors.lighter_bg })
hl("DiffChange",   { fg = colors.yellow, bg = colors.lighter_bg })
hl("DiffDelete",   { fg = colors.red, bg = colors.lighter_bg })
hl("DiffText",     { fg = colors.accent, bg = colors.selection, bold = true })

-- Diagnostics
hl("DiagnosticError", { fg = colors.red })
hl("DiagnosticWarn",  { fg = colors.yellow })
hl("DiagnosticInfo",  { fg = colors.blue })
hl("DiagnosticHint",  { fg = colors.cyan })

-- Tree-sitter & LSP Semantics
hl("@variable",             { fg = colors.fg })
hl("@variable.builtin",     { fg = colors.red })
hl("@variable.parameter",   { fg = colors.cyan })
hl("@variable.member",      { fg = colors.cyan })
hl("@constant",             { fg = colors.orange })
hl("@constant.builtin",     { fg = colors.orange, bold = true })
hl("@module",               { fg = colors.blue })
hl("@function",             { fg = colors.blue })
hl("@function.builtin",     { fg = colors.cyan })
hl("@function.method",      { fg = colors.blue })
hl("@keyword",              { fg = colors.magenta, bold = true })
hl("@keyword.return",       { fg = colors.red, bold = true })
hl("@string",               { fg = colors.green })
hl("@type",                 { fg = colors.yellow })
hl("@property",             { fg = colors.cyan })
hl("@operator",             { fg = colors.blue })
hl("@comment",              { fg = colors.muted, italic = true })

return colors
