-- ============================================================================
-- nvimpire/colors.lua
-- ----------------------------------------------------------------------------
-- Colors are produced by the gradient engine (nvimpire.gradient). The table is
-- refreshed IN PLACE so every highlight group that cached
-- `require("nvimpire.colors").colors` keeps seeing the active palette when the
-- gradient style changes.
-- ============================================================================

local gradient = require("nvimpire.gradient")

local M = {}

-- Seeded with the default style so `require(...).colors` is never empty.
M.colors = gradient.build("dracula", 11)

function M.background(transparent, ifTransparentColor, ifNotColor)
  return transparent and ifTransparentColor or ifNotColor
end

--- Rebuild the color table in place for a given gradient style / step count.
function M.refresh(style_name, steps)
  if not gradient.is_valid_style(style_name) then
    vim.notify(
      string.format("nvimpire: unknown gradient style '%s', falling back to 'dracula'",
        tostring(style_name)),
      vim.log.levels.WARN
    )
    style_name = "dracula"
  end

  local built = gradient.build(style_name, steps)

  -- keep the original table reference alive for cached `local c = ...colors`
  for k in pairs(M.colors) do
    M.colors[k] = nil
  end
  for k, v in pairs(built) do
    M.colors[k] = v
  end

  return M.colors
end

return M
