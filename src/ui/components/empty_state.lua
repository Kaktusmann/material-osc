local empty_state = {}

function empty_state.new(services)
  local background_color = "#111318"
  local ui = services.ui
  local dp, alpha = ui.dp, ui.alpha
  local Modifier, apply_modifier_size = ui.Modifier, ui.apply_modifier_size
  local draw_box, draw_icon, draw_text = ui.draw_box, ui.draw_icon, ui.draw_text
  local draw_brand_logo = ui.draw_brand_logo
  local default_text_font = ui.default_text_font
  local current_version = tostring(services.updater.current_version or "")
    :gsub("^[vV]", "")
  if current_version == "__MATERIAL_OSC_VERSION__" then
    current_version = "dev-build"
  end
  local version_label = current_version == "dev-build" and "dev-build" or
    (current_version ~= "" and "v" .. current_version or "")

  local easter_eggs = {
    "404", "418 i'm a teapot", "hello, world", "all your base",
    "the cake is a lie", "do a barrel roll", "up up down down",
    "works on my machine", "sudo make me a sandwich", "one does not simply",
    "this is fine", "i can haz cheezburger", "doge wow", "nyan nyan",
    "keyboard cat", "rickroll incoming", "42", "1337", "ship it",
    "foo bar baz", "it works!", "enhance!", "hack the planet",
    "no place like 127.0.0.1", "localhost", "view source",
    "under construction", "best viewed in netscape", "sign my guestbook",
    "join the webring", "blink blink", "marquee forever", "alt+f4",
    "konami code", "touch grass", "main character energy", "skill issue",
    "press f", "loss.jpg", "badger badger", "dramatic chipmunk",
    "double rainbow", "leeroy jenkins", "it's over 9000",
    "the narwhal bacons at midnight", "reddit hug of death",
    "404 sleep not found", "there are 10 types of people", "ඞ"
  }
  local marquee_color = "#E2E2E6"
  local marquee_shears = {0, -0.035, -0.070, -0.105, -0.141, -0.176}
  local marquee_weights = {
    {value = 250, advance_scale = 1.02},
    {value = 300, advance_scale = 1.02},
    {value = 500, advance_scale = 1.05},
    {value = 600, advance_scale = 1.08},
    {value = 700, advance_scale = 1.11},
    {value = 800, advance_scale = 1.14},
    {value = 900, advance_scale = 1.16}
  }
  local marquee_widths = {62, 70, 78, 88, 100, 112, 124, 138}
  local marquee_layout_cache
  local marquee_rotation = -12
  local marquee_radians = math.rad(marquee_rotation)
  local marquee_cos = math.cos(marquee_radians)
  local marquee_sin = math.sin(marquee_radians)
  local marquee_seed = (os.time() * 1000 +
    math.floor((ui.now() % 1) * 1000)) % 1000003

  local function hashed_index(index, salt, count)
    local value = (index * 1103515245 + salt * 12345 +
      index * index * 2654435761 + marquee_seed * 69069) % 2147483647
    return (math.floor(value) % count) + 1
  end

  local function marquee_item(index, font_size)
    local weight = marquee_weights[
      hashed_index(index, 5, #marquee_weights)]
    local use_mpv = hashed_index(index, 1, 5) <= 2
    return {
      text = use_mpv and "mpv" or
        easter_eggs[hashed_index(index, 2, #easter_eggs)],
      font_size = font_size,
      x_scale = marquee_widths[
        hashed_index(index, 3, #marquee_widths)],
      shear = marquee_shears[
        hashed_index(index, 4, #marquee_shears)],
      weight = weight.value,
      advance_scale = weight.advance_scale
    }
  end

  local function build_marquee_layout(bounds)
    local viewport_scale = math.min(
      bounds.w / math.max(dp(1280), 1),
      bounds.h / math.max(dp(720), 1))
    local pattern_scale = math.max(0.58, math.min(1.2, viewport_scale))
    local key = string.format("%d:%d:%.3f",
      math.floor(bounds.w + 0.5), math.floor(bounds.h + 0.5), pattern_scale)
    if marquee_layout_cache and marquee_layout_cache.key == key then
      return marquee_layout_cache
    end

    local font_size = 124 * pattern_scale
    local row_height = dp(font_size) * 0.625
    local row_count = math.ceil(bounds.h / row_height) + 1
    local target_width = math.max(bounds.w * 1.35, dp(1720) * pattern_scale)
    local gutter = math.max(dp(5), dp(font_size) * 0.035)
    local rows, item_index = {}, 0

    for row_index = 1, row_count do
      local row = {items = {}}
      local cursor = 0
      while cursor < target_width do
        item_index = item_index + 1
        local item = marquee_item(item_index + row_index * 997, font_size)
        local advance = ui.text_width(item.text, font_size) *
          item.x_scale / 100 * item.advance_scale
        if item.text == "ඞ" then
          advance = advance * 1.65
        end
        local slant_budget = -item.shear * row_height
        local left_slant = slant_budget * 0.28
        local right_slant = slant_budget - left_slant
        item.x = cursor + left_slant
        item.x2 = item.x + advance + right_slant
        row.items[#row.items + 1] = item
        cursor = item.x2 + gutter
      end
      row.width = cursor
      row.y = (row_index - 0.5) * row_height
      row.speed = dp(11 + ((row_index * 7) % 5))
      row.direction = row_index % 2 == 1 and -1 or 1
      row.phase = (hashed_index(row_index, 8, 1000) - 1) / 1000
      rows[#rows + 1] = row
    end

    marquee_layout_cache = {
      key = key,
      rows = rows
    }
    return marquee_layout_cache
  end

  local function draw_marquee(ass, bounds, opacity)
    local center_x = bounds.x + bounds.w / 2
    local center_y = bounds.y + bounds.h / 2
    local rotated_width = math.abs(bounds.w * marquee_cos) +
      math.abs(bounds.h * marquee_sin)
    local rotated_height = math.abs(bounds.w * marquee_sin) +
      math.abs(bounds.h * marquee_cos)
    local pattern_bounds = {
      x = center_x - rotated_width / 2,
      y = center_y - rotated_height / 2,
      x2 = center_x + rotated_width / 2,
      y2 = center_y + rotated_height / 2,
      w = rotated_width,
      h = rotated_height
    }
    local layout = build_marquee_layout(pattern_bounds)
    for _, row in ipairs(layout.rows) do
      local travel = (ui.now() * row.speed + row.phase * row.width) % row.width
      local start_x
      if row.direction < 0 then
        start_x = pattern_bounds.x - travel
      else
        start_x = pattern_bounds.x - row.width + travel
      end
      for copy = 0, 1 do
        local copy_x = start_x + copy * row.width
        for _, item in ipairs(row.items) do
          if copy_x + item.x2 >= pattern_bounds.x and
              copy_x + item.x <= pattern_bounds.x2 then
            local item_x = copy_x + item.x
            local item_y = pattern_bounds.y + row.y
            local relative_x = item_x - center_x
            local relative_y = item_y - center_y
            local rotated_x = center_x + relative_x * marquee_cos -
              relative_y * marquee_sin
            local rotated_y = center_y + relative_x * marquee_sin +
              relative_y * marquee_cos
            draw_text(ass, rotated_x, rotated_y,
              item.text, item.font_size, marquee_color,
              alpha(opacity * 0.030), default_text_font, 4, false, true,
              bounds, {
                no_wrap = true,
                weight = item.weight,
                x_scale = item.x_scale,
                shear = item.shear,
                -- ASS positive rotation is counter-clockwise, while our
                -- screen-space transform uses positive angles clockwise.
                rotation = -marquee_rotation
              })
          end
        end
      end
    end
  end

  local function ActionButton(args)
    local node = {
      icon = args.icon,
      label = args.label,
      on_click = args.on_click,
      visible = false,
      interactive = false,
      modifier = Modifier():pointerArea({
        name = args.name,
        enabled = false,
        on_keyboard = args.on_click,
        on_click = args.on_click
      })
    }

    function node:update(visible, interactive)
      self.visible = visible
      self.interactive = interactive
      self.modifier.pointer_enabled = visible and interactive
    end

    function node:measure(parent)
      return apply_modifier_size(self.modifier, {w = parent.w, h = parent.h}, parent)
    end

    function node:draw(ass, bounds)
      if not self.visible or not ui.is_render_pass("interaction") then return end
      local hovered = self.interactive and ui.mouse_in(bounds)
      draw_box(ass, bounds.x, bounds.y, bounds.x2, bounds.y2, bounds.h / 2,
        "#44474E", "00", true)
      if hovered then
        draw_box(ass, bounds.x, bounds.y, bounds.x2, bounds.y2,
          bounds.h / 2, "#E2E2E6", "E5", true)
      end
      local content_scale = math.min(1, bounds.h / math.max(dp(52), 1))
      local label_size, icon_size = 22 * content_scale, 24 * content_scale
      local content_gap = dp(4) * content_scale
      local label_width = ui.text_width(self.label, label_size)
      local content_width = dp(icon_size) + content_gap + label_width
      local icon_x = bounds.x + (bounds.w - content_width) / 2 +
        dp(icon_size) / 2
      draw_icon(ass, icon_x, bounds.y + bounds.h / 2,
        self.icon, "#E2E2E6", icon_size, "00", true)
      draw_text(ass, icon_x + dp(icon_size) / 2 + content_gap,
        bounds.y + bounds.h / 2, self.label, label_size,
        "#E2E2E6", "00", default_text_font, 4, false, true)
    end

    return node
  end

  local function VersionLink(args)
    local node = {
      label = args.label,
      visible = false,
      interactive = false,
      modifier = Modifier():pointerArea({
        name = "empty-state-version",
        enabled = false,
        on_keyboard = args.on_click,
        on_click = args.on_click
      })
    }

    function node:update(visible, interactive)
      self.visible = visible
      self.interactive = interactive
      self.modifier.pointer_enabled = visible and interactive
    end

    function node:measure(parent)
      return apply_modifier_size(
        self.modifier, {w = parent.w, h = parent.h}, parent)
    end

    function node:draw(ass, bounds)
      if not self.visible or not ui.is_render_pass("interaction") then return end
      local hovered = self.interactive and ui.mouse_in(bounds)
      draw_text(ass, bounds.x + bounds.w / 2, bounds.y + bounds.h / 2,
        self.label, 30 * (bounds.h / math.max(dp(44), 1)),
        hovered and "#FFFFFF" or "#CAC4D0", alpha(node.opacity or 1),
        default_text_font, 5, 200, true)
    end

    return node
  end

  local function RepositoryLogo(args)
    local node = {
      visible = false,
      interactive = false,
      modifier = Modifier():pointerArea({
        name = "empty-state-repository-logo",
        enabled = false,
        on_keyboard = args.on_click,
        on_click = args.on_click
      })
    }

    function node:update(visible, interactive)
      self.visible = visible
      self.interactive = interactive
      self.modifier.pointer_enabled = visible and interactive
    end

    function node:measure(parent)
      return apply_modifier_size(
        self.modifier, {w = parent.w, h = parent.h}, parent)
    end

    function node:draw(ass, bounds)
      if not self.visible or not ui.is_render_pass("interaction") then return end
      local source_width, source_height = 447.29825, 854.513
      local scale = math.min(
        bounds.w / source_width, bounds.h / source_height)
      local origin_x = bounds.x + (bounds.w - source_width * scale) / 2
      local origin_y = bounds.y + (bounds.h - source_height * scale) / 2
      local hovered = self.interactive and ui.mouse_in(bounds)

      ass:new_event()
      ass:pos(origin_x, origin_y)
      ass:an(7)
      ass:append(string.format(
        "{\\1c&H%s&\\1a&H%s&\\bord0\\shad0}",
        hovered and "FFFFFF" or "D0C4CA", alpha(self.opacity or 1)))
      ass:draw_start()

      local function point1(x, y)
        return (1.3333333 * x + 434.83653 - 258.32187) * scale,
          (-1.3333333 * y + 532.53907 - 52.995083) * scale
      end
      local function point2(x, y)
        return (1.3333333 * x + 529.10547 - 258.32187) * scale,
          (-1.3333333 * y + 427.96413 - 52.995083) * scale
      end
      local function move(point, x, y)
        local px, py = point(x, y)
        ass:move_to(px, py)
      end
      local function curve(point, x1, y1, x2, y2, x3, y3)
        local px1, py1 = point(x1, y1)
        local px2, py2 = point(x2, y2)
        local px3, py3 = point(x3, y3)
        ass:bezier_curve(px1, py1, px2, py2, px3, py3)
      end

      move(point1, 0, 0)
      curve(point1, -44.128, 0.029, -88.257, 0.059, -132.386, 0.089)
      curve(point1, -38.949, 119.945, 54.488, 239.802, 147.924, 359.658)
      curve(point1, 98.617, 239.772, 49.308, 119.886, 0, 0)

      move(point2, 0, 0)
      curve(point2, 44.129, -0.029, 88.257, -0.059, 132.386, -0.088)
      curve(point2, 38.949, -119.945, -54.487, -239.801,
        -147.924, -359.658)
      curve(point2, -98.616, -239.772, -49.308, -119.886, 0, 0)
      ass:draw_stop()
    end

    return node
  end

  local node = {
    visible = false,
    interactive = false,
    opacity = 0,
    modifier = Modifier():fillMaxWidth():fillMaxHeight()
  }
  node.files = ActionButton({
    name = "empty-state-files",
    icon = "folder_open",
    label = "File(s)",
    on_click = services.player.open_media_files
  })
  node.link = ActionButton({
    name = "empty-state-link",
    icon = "link",
    label = "Link",
    on_click = services.player.open_media_link
  })
  local function open_repository()
    services.updater:open_repository()
  end
  node.repository_logo = RepositoryLogo({on_click = open_repository})
  node.version = VersionLink({label = version_label, on_click = open_repository})

  function node:update(visible, interactive, opacity)
    self.visible = visible
    self.interactive = interactive
    self.opacity = opacity or (visible and 1 or 0)
    self.files:update(visible, interactive)
    self.link:update(visible, interactive)
    self.repository_logo.opacity = self.opacity
    self.repository_logo:update(visible and version_label ~= "", interactive)
    self.version.opacity = self.opacity
    self.version:update(visible and version_label ~= "", interactive)
  end

  function node:measure(parent)
    return apply_modifier_size(self.modifier, {w = 0, h = 0}, parent)
  end

  function node:draw(ass, bounds)
    if self.visible and ui.is_render_pass("base") then
      draw_box(ass, bounds.x, bounds.y, bounds.x2, bounds.y2,
        0, background_color, "00", true)
    end
    if self.visible and ui.is_render_pass("dynamic") then
      draw_marquee(ass, bounds, self.opacity)
      return
    end
    local layout_scale = math.min(1,
      bounds.w / math.max(dp(360), 1),
      bounds.h / math.max(dp(390), 1))
    local logo_size = dp(128) * layout_scale
    local logo_gap = dp(24) * layout_scale
    local mpv_size = 156 * layout_scale
    local mpv_x_scale = 108
    local title_size = 58 * layout_scale
    local title = "material-osc"
    local text_column_width = dp(190) * layout_scale
    local lockup_width = logo_size + logo_gap + text_column_width
    local identity_h = logo_size
    local identity_actions_gap = dp(44) * layout_scale
    local button_h = dp(52) * layout_scale
    local button_w = dp(148) * layout_scale
    local gap = dp(8) * layout_scale
    local total_w = button_w * 2 + gap
    local hint_h = dp(26) * layout_scale
    local actions_hint_gap = dp(28) * layout_scale
    local version_gap = dp(40) * layout_scale
    local repository_logo_h =
      version_label ~= "" and dp(54) * layout_scale or 0
    local repository_logo_w = dp(44) * layout_scale
    local repository_logo_gap = dp(8) * layout_scale
    local version_h = version_label ~= "" and dp(44) * layout_scale or 0
    local content_h = identity_h + identity_actions_gap + button_h +
      actions_hint_gap + hint_h / 2 +
      (version_label ~= "" and version_gap + repository_logo_h +
        repository_logo_gap + version_h or 0)
    local top = bounds.y + (bounds.h - content_h) / 2
    local center_x = bounds.x + bounds.w / 2
    local content_alpha = alpha(self.opacity)

    if self.visible and ui.is_render_pass("interaction") then
      local lockup_x = center_x - lockup_width / 2
      draw_brand_logo(ass, lockup_x + logo_size / 2, top + logo_size / 2,
        logo_size, content_alpha, true)
      local text_x = lockup_x + logo_size + logo_gap
      draw_text(ass, text_x,
        top + logo_size / 2 - dp(30) * layout_scale,
        "mpv", mpv_size, "#FFFFFF", content_alpha,
        default_text_font, 4, false, true, nil,
        {weight = 200, x_scale = mpv_x_scale})
      draw_text(ass, text_x,
        top + logo_size / 2 + dp(30) * layout_scale,
        title, title_size, "#ffffff", alpha(self.opacity * 0.66),
        default_text_font, 4, false, true)
    end

    local button_y = top + identity_h + identity_actions_gap
    local files_bounds = ui.Rect({
      x = center_x - total_w / 2, y = button_y,
      w = button_w, h = button_h
    })
    local link_bounds = ui.Rect({
      x = files_bounds.x2 + gap, y = button_y,
      w = button_w, h = button_h
    })
    ui.draw_node(self.files, ass, files_bounds)
    ui.draw_node(self.link, ass, link_bounds)

    local hint_y = button_y + button_h + actions_hint_gap
    local hint = "...or just drag and drop stuff here"
    local hint_size = 22 * layout_scale
    local hint_width = ui.text_width(hint, hint_size)
    local hint_x = center_x - (hint_width + dp(26) * layout_scale) / 2
    if version_label ~= "" then
      local repository_logo_bounds = ui.Rect({
        x = center_x - repository_logo_w / 2,
        y = hint_y + hint_h / 2 + version_gap,
        w = repository_logo_w,
        h = repository_logo_h
      })
      ui.draw_node(self.repository_logo, ass, repository_logo_bounds)
      local version_width = math.max(dp(96) * layout_scale,
        ui.text_width(version_label, 30 * layout_scale) +
          dp(24) * layout_scale)
      local version_bounds = ui.Rect({
        x = center_x - version_width / 2,
        y = repository_logo_bounds.y2 + repository_logo_gap,
        w = version_width,
        h = version_h
      })
      ui.draw_node(self.version, ass, version_bounds)
    end

    if not self.visible or not ui.is_render_pass("interaction") then return end
    draw_text(ass, hint_x, hint_y, hint, hint_size, "#CAC4D0",
      content_alpha, default_text_font, 4, false, true)
    draw_icon(ass, hint_x + hint_width + dp(14) * layout_scale, hint_y,
      "move_to_inbox", "#CAC4D0", 24 * layout_scale, content_alpha, true)
  end

  return node
end

return empty_state
