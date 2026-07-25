local temporary_speed_indicator = {}

function temporary_speed_indicator.new(args)
  local state, ui = args.state, args.ui
  local node = {}

  local function speed_label()
    return string.format("%gx", tonumber(args.value()) or 2)
  end

  function node:draw(ass, bounds)
    if not state.active then return end
    local dp = ui.dp
    local label, text_size = speed_label(), 22
    local icon_size, gap = dp(22), dp(8)
    local pad_x, pill_h = dp(18), dp(42)
    local label_w = ui.text_width(label, text_size)
    local pill_w = pad_x * 2 + label_w + gap + icon_size
    local center_x = bounds.x + bounds.w / 2
    local center_y = bounds.y + bounds.h * 0.10
    local x1, x2 = center_x - pill_w / 2, center_x + pill_w / 2
    local y1, y2 = center_y - pill_h / 2, center_y + pill_h / 2
    ui.draw_box(ass, x1, y1, x2, y2, pill_h / 2,
      "#050708", ui.alpha(0.94), true)
    local text_x = x1 + pad_x
    ui.draw_text(ass, text_x, y1 + pill_h / 2, label, text_size,
      "#FFFFFF", "00", ui.default_text_font, 4, true, true)
    local icon_x = text_x + label_w + gap + icon_size / 2
    ui.draw_icon(ass, icon_x, center_y, "bolt_boost",
      "#FFFFFF", 22, "00", true)
  end

  return node
end

return temporary_speed_indicator
