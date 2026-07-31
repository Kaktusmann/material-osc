local popup_factories = {}

local function new_chapter_popup(deps)
  local pointer, chapter_state = deps.pointer, deps.state
  local opts, dp, clamp = deps.opts, deps.dp, deps.clamp
  local ass_alpha_for_opacity = deps.ass_alpha_for_opacity
  local truncate_to_width, format_time = deps.truncate_to_width, deps.format_time
  local text_width = deps.text_width
  local draw_box, draw_icon, draw_text = deps.draw_box, deps.draw_icon,
    deps.draw_text
  local default_text_font, render = deps.default_text_font, deps.render
  local Modifier, Rect = deps.Modifier, deps.Rect
  local apply_modifier_size, draw_node = deps.apply_modifier_size, deps.draw_node
  local mouse_in, ChapterHeader = deps.mouse_in, deps.ChapterHeader
  local update_fields = deps.update_fields
  local function ChapterRow(slot, on_selected)
    local node = {
      slot = slot,
      chapter = nil,
      chapter_index = 0,
      selected = false,
      interactive = false,
      text_alpha = "00",
      secondary_alpha = "00",
      hover_alpha = "00",
      selected_alpha = "00",
      modifier = Modifier():fillMaxWidth():height(dp(44))
    }
    node.remove = {
      modifier = Modifier():width(dp(34)):height(dp(34)):clickable({
        name = "bookmark-remove-slot-" .. tostring(slot),
        enabled = false,
        on_click = function()
          if node.chapter and deps.bookmarks:is_bookmark(node.chapter) then
            deps.bookmarks:remove(node.chapter)
          end
        end
      })
    }
    node.edit = {
      modifier = Modifier():width(dp(34)):height(dp(34)):clickable({
        name = "bookmark-edit-slot-" .. tostring(slot),
        enabled = false,
        on_click = function()
          if node.chapter and deps.bookmarks:is_bookmark(node.chapter) then
            deps.bookmarks:prompt_rename(node.chapter)
          end
        end
      })
    }
    function node.edit:measure(parent)
      return apply_modifier_size(self.modifier, {w = dp(34), h = dp(34)}, parent)
    end
    function node.edit:draw(ass, bounds)
      if node.interactive and mouse_in(bounds) then
        draw_box(ass, bounds.x, bounds.y, bounds.x2, bounds.y2,
          bounds.h / 2, "#FFFFFF", node.hover_alpha)
      end
      draw_icon(ass, bounds.x + bounds.w / 2, bounds.y + bounds.h / 2,
        "edit", "#CAC4D0", 20, node.secondary_alpha)
    end
    function node.remove:measure(parent)
      return apply_modifier_size(self.modifier, {w = dp(34), h = dp(34)}, parent)
    end
    function node.remove:draw(ass, bounds)
      if node.interactive and mouse_in(bounds) then
        draw_box(ass, bounds.x, bounds.y, bounds.x2, bounds.y2,
          bounds.h / 2, "#FFFFFF", node.hover_alpha)
      end
      draw_icon(ass, bounds.x + bounds.w / 2, bounds.y + bounds.h / 2,
        "delete", "#CAC4D0", 20, node.secondary_alpha)
    end
    node.modifier:clickable({
      name = "chapter-row-slot-" .. tostring(slot),
      enabled = false,
      on_click = function()
        if not node.chapter then return end
        mp.commandv("seek", tonumber(node.chapter.time) or 0, "absolute+exact")
        on_selected()
      end
    })
    function node:update(props)
      self.chapter = props.chapter
      self.chapter_index = props.chapter_index or 0
      self.selected = props.selected == true
      self.interactive = props.interactive == true and props.chapter ~= nil
      self.text_alpha = props.text_alpha
      self.secondary_alpha = props.secondary_alpha
      self.hover_alpha = props.hover_alpha
      self.selected_alpha = props.selected_alpha
      self.modifier.pointer_enabled = self.interactive
      self.removable = deps.bookmarks:is_bookmark(self.chapter)
      self.remove.modifier.pointer_enabled = self.interactive and self.removable
      self.edit.modifier.pointer_enabled = self.interactive and self.removable
    end
    function node:measure(parent)
      if not self.chapter then return {w = 0, h = 0} end
      return apply_modifier_size(self.modifier, {w = 0, h = dp(44)}, parent)
    end
    function node:draw(ass, bounds)
      if not self.chapter then return end
      local hovered = self.interactive and mouse_in(bounds)
      if self.selected then
        draw_box(ass, bounds.x, bounds.y, bounds.x2, bounds.y2,
             bounds.h / 2, opts.accent_color, self.selected_alpha)
        local indicator_size = dp(6)
        local indicator_x = bounds.x + dp(self.removable and 48 or 14)
        draw_box(ass, indicator_x - indicator_size / 2,
             bounds.y + bounds.h / 2 - indicator_size / 2,
             indicator_x + indicator_size / 2,
             bounds.y + bounds.h / 2 + indicator_size / 2,
             indicator_size / 2,
             opts.accent_color, self.text_alpha)
      elseif hovered then
        draw_box(ass, bounds.x, bounds.y, bounds.x2, bounds.y2,
             bounds.h / 2, "#FFFFFF", self.hover_alpha)
      end
      local seek_time = tonumber(self.chapter.time) or 0
      local time_text = format_time(seek_time)
      local title_size = 24
      local title_x = bounds.x + dp(self.removable and
        (self.selected and 60 or 48) or (self.selected and 28 or 16))
      local time_right = bounds.x2 - dp(self.removable and 52 or 16)
      local time_left = time_right - text_width(time_text, title_size)
      local title_available_w = math.max(0, time_left - dp(16) - title_x)
      local title = self.chapter.title
      if type(title) ~= "string" or title:match("^%s*$") then
        title = "Chapter " .. tostring(self.chapter_index)
      end
      title = truncate_to_width(title, title_available_w, title_size)
      draw_text(ass, title_x, bounds.y + bounds.h / 2,
            title, title_size, "#FFFFFF", self.text_alpha,
            default_text_font, 4)
      draw_text(ass, time_right, bounds.y + bounds.h / 2, time_text, 24,
            self.selected and opts.accent_color or "#CAC4D0",
            self.selected and self.text_alpha or self.secondary_alpha,
            default_text_font, 6)
      if self.removable then
        local remove_size = dp(34)
        local remove_x = bounds.x2 - dp(6) - remove_size
        draw_node(self.edit, ass, Rect({
          x = bounds.x + dp(4),
          y = bounds.y + (bounds.h - remove_size) / 2,
          w = remove_size, h = remove_size
        }))
        draw_node(self.remove, ass, Rect({
          x = remove_x,
          y = bounds.y + (bounds.h - remove_size) / 2,
          w = remove_size, h = remove_size
        }))
      end
    end
    return node
  end

  local function LazyChapterColumn(on_selected)
    local node = {
      rows = {}, items = {}, first_visible_index = 0, visible_count = 1,
      selected_index = -1, row_gap = dp(4), row_height = dp(44),
      interactive = false, text_alpha = "00", secondary_alpha = "00",
      hover_alpha = "00", selected_alpha = "00",
      modifier = Modifier():fillMaxWidth():fillMaxHeight()
    }
    for slot = 1, 16 do node.rows[slot] = ChapterRow(slot, on_selected) end
    function node:update(props)
      update_fields(self, props)
      for slot, row in ipairs(self.rows) do
        local item_index = self.first_visible_index + slot
        local chapter = slot <= self.visible_count and self.items[item_index] or nil
        row:update({
          chapter = chapter,
          chapter_index = item_index,
          selected = item_index - 1 == self.selected_index,
          interactive = self.interactive,
          text_alpha = self.text_alpha,
          secondary_alpha = self.secondary_alpha,
          hover_alpha = self.hover_alpha,
          selected_alpha = self.selected_alpha
        })
      end
    end
    function node:measure(parent)
      return apply_modifier_size(self.modifier, {w = 0, h = 0}, parent)
    end
    function node:draw(ass, bounds)
      local slot_count = math.min(self.visible_count, #self.rows,
        math.max(0, #self.items - self.first_visible_index))
      if slot_count <= 0 or bounds.h <= 0 then return end
      local natural_height = slot_count * self.row_height +
        math.max(0, slot_count - 1) * self.row_gap
      local scale = math.min(1, bounds.h / math.max(1, natural_height))
      local row_height = self.row_height * scale
      local row_gap = self.row_gap * scale
      local stride = row_height + row_gap
      for slot = 1, slot_count do
        local row = self.rows[slot]
        if not row.chapter then break end
        local y = bounds.y + (slot - 1) * stride
        row.modifier.fixed_height = row_height
        draw_node(row, ass, Rect({
          x = bounds.x, y = y, w = bounds.w, h = row_height
        }))
      end
    end
    return node
  end

  local function VerticalScrollbar(on_scroll)
    local node = {
      item_count = 0, visible_count = 1, scroll_index = 0,
      dragging = false,
      interactive = false, opacity = 0,
      modifier = Modifier():fillMaxWidth():fillMaxHeight()
    }
    local function max_scroll() return math.max(0, node.item_count - node.visible_count) end
    local function metrics(bounds)
      local maximum = max_scroll()
      local thumb_h, thumb_y = bounds.h, bounds.y
      if maximum > 0 then
        thumb_h = math.max(dp(32), bounds.h * node.visible_count / node.item_count)
        thumb_y = bounds.y + (bounds.h - thumb_h) * node.scroll_index / maximum
      end
      return thumb_h, thumb_y
    end
    local function update_from_mouse(box)
      local maximum = max_scroll()
      if maximum <= 0 then return end
      local thumb_h = metrics(box)
      local travel = math.max(1, box.h - thumb_h)
      local ratio = clamp((pointer.y - box.y1 - thumb_h / 2) / travel, 0, 1)
      on_scroll(math.floor(ratio * maximum + 0.5))
    end
    node.modifier:pointerArea({
      name = "chapter-dialog-scrollbar",
      enabled = false,
      on_press = function(box)
        node.dragging = true
        update_from_mouse(box)
      end,
      on_move = function(box)
        if node.dragging then update_from_mouse(box) end
      end,
      on_release = function(box)
        update_from_mouse(box)
        node.dragging = false
      end
    })
    function node:update(props)
      update_fields(self, props)
      self.modifier.pointer_enabled = self.interactive and max_scroll() > 0
    end
    function node:measure(parent)
      return apply_modifier_size(self.modifier, {w = 0, h = 0}, parent)
    end
    function node:draw(ass, bounds)
      if max_scroll() <= 0 then return end
      local hovered = self.interactive and mouse_in(bounds)
      local track_w = dp(4)
      local thumb_w = (hovered or self.dragging) and dp(7) or dp(6)
      local center_x = bounds.x + bounds.w / 2
      local thumb_h, thumb_y = metrics(bounds)
      draw_box(ass, center_x - track_w / 2, bounds.y,
        center_x + track_w / 2, bounds.y2, track_w / 2,
        "#FFFFFF", ass_alpha_for_opacity(self.opacity * 0.14))
      draw_box(ass, center_x - thumb_w / 2, thumb_y,
        center_x + thumb_w / 2, thumb_y + thumb_h, thumb_w / 2,
        "#FFFFFF", ass_alpha_for_opacity(
          self.opacity * (hovered and 0.82 or 0.58)))
    end
    return node
  end

  local function ChapterList(on_selected)
    local node = {
      chapters = {}, interactive = false, text_alpha = "00",
      secondary_alpha = "00", hover_alpha = "00", selected_alpha = "00",
      layout_height = nil,
      modifier = Modifier():fillMaxWidth():fillMaxHeight()
    }
    node.column = LazyChapterColumn(on_selected)
    node.scrollbar = VerticalScrollbar(function(index)
      chapter_state.scroll_index = index
      render()
    end)
    function node:update(props)
      update_fields(self, props)
    end
    function node:measure(parent)
      return apply_modifier_size(self.modifier, {w = 0, h = 0}, parent)
    end
    function node:draw(ass, bounds)
      local row_height, row_gap = dp(44), dp(4)
      -- Capacity follows the settled layout, not the temporarily undersized
      -- morph bounds. Otherwise crossing a row boundary during the spring can
      -- make a scrollbar flash for one or two frames.
      local capacity_height = self.layout_height or bounds.h
      local visible_count = math.max(1,
        math.floor((capacity_height + row_gap) / (row_height + row_gap)))
      local max_scroll = math.max(0, #self.chapters - visible_count)
      chapter_state.scroll_index = clamp(chapter_state.scroll_index, 0, max_scroll)
      local horizontal_padding = dp(8)
      local scrollbar_touch_w = dp(20)
      local scrollbar_gutter = max_scroll > 0 and scrollbar_touch_w or 0
      local list_x = bounds.x + horizontal_padding
      local list_w = math.max(dp(80), bounds.w - horizontal_padding * 2 -
        scrollbar_gutter)
      self.column:update({
        items = self.chapters,
        first_visible_index = chapter_state.scroll_index,
        visible_count = visible_count,
        selected_index = self.selected_index or -1,
        row_height = row_height,
        row_gap = row_gap,
        interactive = self.interactive,
        text_alpha = self.text_alpha,
        secondary_alpha = self.secondary_alpha,
        hover_alpha = self.hover_alpha,
        selected_alpha = self.selected_alpha
      })
      self.scrollbar:update({
        item_count = #self.chapters,
        visible_count = visible_count,
        scroll_index = chapter_state.scroll_index,
        interactive = self.interactive,
        opacity = self.opacity
      })
      draw_node(self.column, ass, Rect({x = list_x, y = bounds.y, w = list_w, h = bounds.h}))
      -- Draw the scrollbar after the rows so it stays above the right padding.
      if max_scroll > 0 then
        draw_node(self.scrollbar, ass, Rect({
          x = bounds.x2 - horizontal_padding - scrollbar_touch_w,
          y = bounds.y, w = scrollbar_touch_w, h = bounds.h
        }))
      end
    end
    return node
  end

  local function ChapterPopup(on_close)
    local node = {
      width = dp(320), height = dp(400), chapters = {}, interactive = false,
      panel_alpha = "00", text_alpha = "00", secondary_alpha = "00",
      hover_alpha = "00", selected_alpha = "00",
      modifier = Modifier():clickable({
        name = "chapter-dialog-panel", enabled = false, on_click = function() end
      })
    }
    node.header = ChapterHeader(on_close)
    node.list = ChapterList(on_close)
    function node:update(props)
      update_fields(self, props)
      self.modifier.fixed_width = self.width
      self.modifier.fixed_height = self.height
      self.modifier.pointer_enabled = self.interactive
      local text_opacity = 1 - (tonumber(self.text_alpha, 16) or 255) / 255
      self.header:update({
        alpha = self.text_alpha,
        title_alpha = ass_alpha_for_opacity(text_opacity * 0.70),
        hover_alpha = self.hover_alpha,
        interactive = self.interactive
      })
      self.list:update({
        chapters = self.chapters,
        interactive = self.interactive,
        opacity = self.scrollbar_opacity ~= nil and
          self.scrollbar_opacity or self.opacity,
        layout_height = self.layout_height and
          math.max(0, self.layout_height - dp(72)) or nil,
        text_alpha = self.text_alpha,
        secondary_alpha = self.secondary_alpha,
        hover_alpha = self.hover_alpha,
        selected_alpha = self.selected_alpha
      })
    end
    function node:measure(parent)
      return apply_modifier_size(self.modifier, {w = self.width, h = self.height}, parent)
    end
    function node:draw(ass, bounds)
      draw_box(ass, bounds.x, bounds.y, bounds.x2, bounds.y2,
           dp(30), "#050708", self.panel_alpha)
      local header_h = dp(56)
      draw_node(self.header, ass, Rect({x = bounds.x, y = bounds.y, w = bounds.w, h = header_h}))
      draw_node(self.list, ass, Rect({
        x = bounds.x, y = bounds.y + header_h + dp(8),
        w = bounds.w,
        h = math.max(0, bounds.h - header_h - dp(16))
      }))
    end
    return node
  end


  return {ChapterPopup = ChapterPopup, VerticalScrollbar = VerticalScrollbar}
end

local function new_track_popup(deps)
  local opts, dp, clamp = deps.opts, deps.dp, deps.clamp
  local truncate_to_width, text_width = deps.truncate_to_width, deps.text_width
  local draw_box, draw_rect = deps.draw_box, deps.draw_rect
  local draw_icon = deps.draw_icon
  local draw_text = deps.draw_text
  local draw_loading_shape_morph = deps.draw_loading_shape_morph
  local default_text_font, render = deps.default_text_font, deps.render
  local Modifier, Rect = deps.Modifier, deps.Rect
  local apply_modifier_size, draw_node = deps.apply_modifier_size, deps.draw_node
  local mouse_in, ChapterHeader = deps.mouse_in, deps.ChapterHeader
  local VerticalScrollbar, update_fields = deps.VerticalScrollbar, deps.update_fields
  local subtitle_state, audio_state = deps.subtitle_state, deps.audio_state
  local function TrackRow(slot, on_selected, name_prefix, on_action)
    local node = {
      item = nil, active = false, interactive = false,
      text_alpha = "00", secondary_alpha = "00",
      hover_alpha = "00", selected_alpha = "00",
      modifier = Modifier():fillMaxWidth():height(dp(44))
    }
    node.modifier:clickable({
      name = name_prefix .. "-row-slot-" .. tostring(slot), enabled = false,
      on_click = function()
        if node.item then on_selected(node.item) end
      end
    })
    node.action = {
      modifier = Modifier():width(dp(34)):height(dp(34)):clickable({
        name = name_prefix .. "-action-slot-" .. tostring(slot),
        enabled = false,
        on_click = function()
          if node.item and node.item.action_icon and on_action then
            on_action(node.item)
          end
        end
      })
    }
    function node.action:measure(parent)
      return apply_modifier_size(self.modifier, {w = dp(34), h = dp(34)}, parent)
    end
    function node.action:draw(ass, bounds)
      if node.interactive and mouse_in(bounds) then
        draw_box(ass, bounds.x, bounds.y, bounds.x2, bounds.y2,
          bounds.h / 2, "#FFFFFF", node.hover_alpha)
      end
      draw_icon(ass, bounds.x + bounds.w / 2, bounds.y + bounds.h / 2,
        node.item.action_icon, "#CAC4D0", 20, node.secondary_alpha)
    end
    function node:update(props)
      self.item = props.item
      update_fields(self, props)
      self.modifier.pointer_enabled = self.interactive and self.item ~= nil and
        not self.item.separator
      self.action.modifier.pointer_enabled = self.interactive and self.item ~= nil and
        self.item.action_icon ~= nil and not self.item.loading
    end
    function node:measure(parent)
      if not self.item then return {w = 0, h = 0} end
      return apply_modifier_size(self.modifier, {w = 0, h = dp(44)}, parent)
    end
    function node:draw(ass, bounds)
      if not self.item then return end
      if self.item.separator then
        local center_y = bounds.y + bounds.h / 2
        local label = self.item.label or "Images"
        local line_gap, label_width = dp(10), dp(82)
        draw_rect(ass, bounds.x + dp(12), center_y,
          bounds.x + (bounds.w - label_width) / 2 - line_gap, center_y + dp(1),
          "#CAC4D0", self.secondary_alpha)
        draw_text(ass, bounds.x + bounds.w / 2, center_y,
          label, 22, "#CAC4D0", self.secondary_alpha, default_text_font)
        draw_rect(ass, bounds.x + (bounds.w + label_width) / 2 + line_gap,
          center_y, bounds.x2 - dp(12), center_y + dp(1),
          "#CAC4D0", self.secondary_alpha)
        return
      end
      local hovered = self.interactive and mouse_in(bounds)
      if self.active or hovered then
        draw_box(ass, bounds.x, bounds.y, bounds.x2, bounds.y2,
          bounds.h / 2, self.active and opts.accent_color or "#FFFFFF",
          self.active and self.selected_alpha or self.hover_alpha)
      end
      if self.active then
        local dot = dp(6)
        draw_box(ass, bounds.x + dp(14) - dot / 2,
          bounds.y + bounds.h / 2 - dot / 2,
          bounds.x + dp(14) + dot / 2,
          bounds.y + bounds.h / 2 + dot / 2, dot / 2,
          opts.accent_color, self.text_alpha)
      end
      local text_x = bounds.x + dp(self.active and 28 or 16)
      local has_details = type(self.item.details) == "string" and
        self.item.details ~= ""
      local text_right = bounds.x2 - dp(16)
      if self.item.loading then
        text_right = bounds.x2 - dp(40)
      elseif self.item.action_icon then
        text_right = text_right - dp(40)
      elseif self.item.language then
        text_right = text_right - text_width(self.item.language, 24) - dp(16)
      end
      local text_available_w = math.max(0, text_right - text_x)
      draw_text(ass, text_x,
        bounds.y + bounds.h / 2 - (has_details and dp(7) or 0),
        truncate_to_width(self.item.label, text_available_w,
          has_details and 20 or 24),
        has_details and 20 or 24, "#FFFFFF", self.text_alpha,
        default_text_font, 4)
      if has_details then
        draw_text(ass, text_x, bounds.y + bounds.h / 2 + dp(9),
          truncate_to_width(self.item.details, text_available_w, 17),
          17, "#CAC4D0", self.secondary_alpha, default_text_font, 4)
      end
      if self.item.loading then
        draw_loading_shape_morph(ass, bounds.x2 - dp(20),
          bounds.y + bounds.h / 2, dp(22))
      elseif self.item.action_icon then
        draw_node(self.action, ass, Rect({
          x = bounds.x2 - dp(40), y = bounds.y + (bounds.h - dp(34)) / 2,
          w = dp(34), h = dp(34)
        }))
      elseif self.item.language then
        draw_text(ass, bounds.x2 - dp(16), bounds.y + bounds.h / 2,
          self.item.language, 24,
          self.active and opts.accent_color or "#CAC4D0",
          self.active and self.text_alpha or self.secondary_alpha,
          default_text_font, 6)
      end
    end
    return node
  end

  local function TrackFooterButton(name, label, icon, on_click)
    local node = {
      label = label, interactive = false, text_alpha = "00", hover_alpha = "00",
      modifier = Modifier():fillMaxWidth():height(dp(44)):clickable({
        name = name, enabled = false, on_click = on_click
      })
    }
    function node:update(props)
      update_fields(self, props)
      self.modifier.pointer_enabled = self.interactive
    end
    function node:measure(parent)
      return apply_modifier_size(self.modifier, {w = parent.w, h = dp(44)}, parent)
    end
    function node:draw(ass, bounds)
      if self.interactive and mouse_in(bounds) then
        draw_box(ass, bounds.x, bounds.y, bounds.x2, bounds.y2,
          bounds.h / 2, "#FFFFFF", self.hover_alpha)
      end
      local center_x = bounds.x + bounds.w / 2
      draw_icon(ass, center_x - dp(26), bounds.y + bounds.h / 2,
        icon, "#FFFFFF", 24, self.text_alpha)
      draw_text(ass, center_x + dp(10), bounds.y + bounds.h / 2,
        self.label, 22, "#FFFFFF", self.text_alpha, default_text_font)
    end
    return node
  end

  local function TrackPopup(on_close, config)
    local node = {
      width = dp(360), height = dp(300), items = {}, active_id = 0,
      layout_height = nil,
      interactive = false, panel_alpha = "00", text_alpha = "00",
      secondary_alpha = "00", hover_alpha = "00", selected_alpha = "00",
      modifier = Modifier():clickable({
        name = config.name .. "-panel", enabled = false, on_click = function() end
      })
    }
    node.header = ChapterHeader(on_close, config.title, config.action_icon,
      config.right_action)
    if config.footer then
      node.footer = TrackFooterButton(config.name .. "-footer",
        config.footer.label, config.footer.icon or "add", config.footer.on_click)
    end
    if config.secondary_footer then
      node.secondary_footer = TrackFooterButton(config.name .. "-secondary-footer",
        config.secondary_footer.label, config.secondary_footer.icon or "link",
        config.secondary_footer.on_click)
    end
    node.rows = {}
    node.visible_count = 1
    node.max_scroll = 0
    node.scrollbar = VerticalScrollbar(function(index)
      config.state.scroll_index = index
      render()
    end)
    local function select(item)
      local should_close = config.on_select(item)
      if should_close ~= false then on_close() end
    end
    for slot = 1, 16 do
      node.rows[slot] = TrackRow(slot, select, config.name, config.on_action)
    end
    function node:update(props)
      update_fields(self, props)
      self.modifier.fixed_width, self.modifier.fixed_height = self.width, self.height
      self.modifier.pointer_enabled = self.interactive
      self.header:update({alpha = self.text_alpha, hover_alpha = self.hover_alpha,
        interactive = self.interactive})
      local list_height = self.layout_height or self.height
      local footer_height = self.footer and dp(48) or 0
      local visible_count = math.max(1,
        math.floor((list_height - dp(68) - footer_height) / dp(48)))
      local max_scroll = math.max(0, #self.items - visible_count)
      self.visible_count, self.max_scroll = visible_count, max_scroll
      config.state.scroll_index = clamp(config.state.scroll_index, 0, max_scroll)
      for slot, row in ipairs(self.rows) do
        local item = slot <= visible_count and
          self.items[config.state.scroll_index + slot] or nil
        local active = item and (config.is_selected and config.is_selected(item) or
          item.id == self.active_id)
        row:update({item = item, active = active,
          interactive = self.interactive, text_alpha = self.text_alpha,
          secondary_alpha = self.secondary_alpha, hover_alpha = self.hover_alpha,
          selected_alpha = self.selected_alpha})
      end
      self.scrollbar:update({
        item_count = #self.items,
        visible_count = visible_count,
        scroll_index = config.state.scroll_index,
        interactive = self.interactive,
        opacity = self.scrollbar_opacity or self.opacity
      })
      if self.footer then
        self.footer:update({interactive = self.interactive,
          text_alpha = self.text_alpha, hover_alpha = self.hover_alpha})
      end
      if self.secondary_footer then
        self.secondary_footer:update({interactive = self.interactive,
          text_alpha = self.text_alpha, hover_alpha = self.hover_alpha})
      end
    end
    function node:measure(parent)
      return apply_modifier_size(self.modifier, {w = self.width, h = self.height}, parent)
    end
    function node:draw(ass, bounds)
      draw_box(ass, bounds.x, bounds.y, bounds.x2, bounds.y2,
        dp(30), "#050708", self.panel_alpha)
      local header_h = dp(56)
      draw_node(self.header, ass, Rect({x = bounds.x, y = bounds.y,
        w = bounds.w, h = header_h}))
      local layout_height = self.layout_height or bounds.h
      local footer_height = self.footer and dp(48) or 0
      local list = Rect({x = bounds.x + dp(8), y = bounds.y + header_h + dp(8),
        w = bounds.w - dp(16) - (self.max_scroll > 0 and dp(20) or 0),
        h = math.max(0, layout_height - header_h - dp(16) - footer_height)})
      for slot, row in ipairs(self.rows) do
        if not row.item then break end
        local y = list.y + (slot - 1) * dp(48)
        if y + dp(44) > list.y2 then break end
        draw_node(row, ass, Rect({x = list.x, y = y, w = list.w, h = dp(44)}))
      end
      if self.max_scroll > 0 then
        draw_node(self.scrollbar, ass, Rect({
          x = list.x2, y = list.y, w = dp(20), h = list.h
        }))
      end
      if self.footer then
        local footer_x = bounds.x + dp(8)
        local footer_w = bounds.w - dp(16)
        if self.secondary_footer then footer_w = (footer_w - dp(8)) / 2 end
        local footer_y = bounds.y + layout_height - dp(52)
        draw_node(self.footer, ass, Rect({x = footer_x, y = footer_y,
          w = footer_w, h = dp(44)}))
        if self.secondary_footer then
          draw_node(self.secondary_footer, ass, Rect({
            x = footer_x + footer_w + dp(8), y = footer_y,
            w = footer_w, h = dp(44)
          }))
        end
      end
    end
    return node
  end

  local function SubtitlePopup(on_close)
    return TrackPopup(on_close, {
      name = "subtitle-dialog", title = "Subtitles", state = subtitle_state,
      on_select = function(item)
        if item.id == 0 then
          mp.set_property("sid", "no")
        else
          mp.set_property_number("sid", tonumber(item.id))
          mp.set_property_native("sub-visibility", true)
        end
      end
    })
  end

  local function AudioPopup(on_close)
    return TrackPopup(on_close, {
      name = "audio-dialog", title = "Audio", state = audio_state,
      on_select = function(item)
        if item.id == 0 then mp.set_property("aid", "no")
        else mp.set_property_number("aid", tonumber(item.id)) end
      end
    })
  end


  return {TrackPopup = TrackPopup, SubtitlePopup = SubtitlePopup, AudioPopup = AudioPopup}
end

popup_factories.new_chapter_popup = new_chapter_popup
popup_factories.new_track_popup = new_track_popup

return popup_factories
