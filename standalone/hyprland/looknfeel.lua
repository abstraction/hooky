-- Hooky - Hyprland Lua Configuration (Hyprland 0.56+)
-- https://github.com/seren/hooky
--
-- Merge into ~/.config/hypr/looknfeel.lua

hl.config({
  general = {
    ["col.active_border"] = "rgb(e59458)",
    ["col.inactive_border"] = "rgb(2a2725)",
  },
  decoration = {
    -- Biophysical focus reinforcement: attenuates peripheral visual distractions
    dim_inactive = true,
    dim_strength = 0.12,
  },
})
