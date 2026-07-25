local tooltip_service = {}

function tooltip_service.new(args)
  local state = args.runtime.tooltip
  local delay = args.delay or 0.4
  local fade_duration = args.fade_duration or 0.14

  local service = {slide_distance = args.slide_distance or 18}

  function service:current_delay()
    local value = type(delay) == "function" and delay() or delay
    return math.max(0, tonumber(value) or 0.4)
  end

  function service:reset_hover()
    state.requested = false
    state.allow_when_suppressed = false
    state.hover_key, state.hover_start, state.visual = nil, 0, nil
    state.opacity:snap(0)
    state.slide:snap(0)
  end

  function service:request(text, bounds, allow_when_suppressed, shortcut,
      shortcut_before)
    if not args.enabled() or not text then return end
    state.requested = true
    state.allow_when_suppressed = allow_when_suppressed == true
    local hint_keys = {}
    local function resolve_hints(actions)
      actions = type(actions) == "table" and actions or {actions}
      local hints = {}
      for _, action in ipairs(actions) do
        local hint = action and args.keybinding_hints:for_action(action) or nil
        if hint then
          hints[#hints + 1] = hint
          hint_keys[#hint_keys + 1] = hint.key
        end
      end
      return hints
    end
    local leading_hints = resolve_hints(shortcut_before)
    local trailing_hints = resolve_hints(shortcut)
    local hover_key = text .. "\0" .. table.concat(hint_keys, "\0")
    if state.hover_key ~= hover_key then
      state.hover_key = hover_key
      state.hover_start = mp.get_time()
      state.opacity:snap(0)
      state.slide:snap(0)
    end

    local text_size, pad_x, pad_y = 18, args.dp(12), args.dp(6)
    local text_w = args.text_width(text, text_size)
    local key_size, key_pad_x = 15, args.dp(6)
    local function build_keycaps(hints, group_gap)
      local keycaps, width = {}, 0
      for group_index, hint in ipairs(hints) do
        for label_index, label in ipairs(hint.labels) do
          local gap = 0
          if #keycaps > 0 then
            gap = args.dp(label_index == 1 and group_index > 1 and
              group_gap or 4)
          end
          local key_w = args.text_width(label, key_size) + key_pad_x * 2
          keycaps[#keycaps + 1] = {label = label, w = key_w, gap = gap}
          width = width + gap + key_w
        end
      end
      return keycaps, width
    end
    local leading_keycaps, leading_w = build_keycaps(leading_hints, 4)
    local trailing_keycaps, trailing_w = build_keycaps(trailing_hints, 8)
    local has_text = text ~= ""
    local leading_gap = has_text and #leading_keycaps > 0 and args.dp(10) or 0
    local trailing_gap
    if has_text then
      trailing_gap = #trailing_keycaps > 0 and args.dp(10) or 0
    else
      trailing_gap = #leading_keycaps > 0 and
        #trailing_keycaps > 0 and args.dp(4) or 0
    end
    local width = leading_w + leading_gap + text_w + trailing_gap +
      trailing_w + pad_x * 2
    local height = args.dp(text_size) + pad_y * 2
    local x = args.clamp(bounds.x + bounds.w / 2 - width / 2,
      args.dp(8), args.runtime.viewport.w - args.dp(8) - width)
    local gap = args.dp(6)
    local space_above = bounds.y - args.dp(8)
    local space_below = args.runtime.viewport.h - bounds.y2 - args.dp(8)
    local above = space_above >= height + gap or space_above >= space_below
    local y = above and (bounds.y - gap - height) or (bounds.y2 + gap)
    local keycaps, cursor_x = {}, x + pad_x
    for _, keycap in ipairs(leading_keycaps) do
      cursor_x = cursor_x + keycap.gap
      keycap.x1 = cursor_x
      cursor_x = cursor_x + keycap.w
      keycaps[#keycaps + 1] = keycap
    end
    cursor_x = cursor_x + leading_gap
    local text_x = cursor_x + text_w / 2
    cursor_x = cursor_x + text_w + trailing_gap
    for _, keycap in ipairs(trailing_keycaps) do
      cursor_x = cursor_x + keycap.gap
      keycap.x1 = cursor_x
      cursor_x = cursor_x + keycap.w
      keycaps[#keycaps + 1] = keycap
    end
    state.visual = {
      text = text, text_size = text_size, x1 = x, y1 = y,
      x2 = x + width, y2 = y + height, w = width, h = height,
      text_x = text_x,
      keycaps = keycaps, key_size = key_size,
      allow_when_suppressed = allow_when_suppressed == true,
      slide_direction_y = above and 1 or -1
    }
  end

  function service:begin_frame()
    state.requested = false
    state.allow_when_suppressed = false
  end

  function service:update(now)
    state.opacity:update(now)
    state.slide:update(now)
  end

  function service:needs_frames(now)
    if state.opacity:is_running() or state.slide:is_running() then return true end
    return state.requested and state.hover_key and
      now - state.hover_start < self:current_delay()
  end

  function service:finalize(now, suppressed)
    local ready = (not suppressed or state.allow_when_suppressed) and
      state.requested and state.hover_key and
      now - state.hover_start >= self:current_delay()
    state.opacity:set_target(ready and 1 or 0, now, fade_duration)
    state.slide:set_target(ready and 1 or 0)
    if not state.requested and state.opacity.value <= 0.001 then
      state.hover_key, state.hover_start, state.visual = nil, 0, nil
    end
  end

  return service
end

return tooltip_service
