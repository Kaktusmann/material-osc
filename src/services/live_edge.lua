local live_edge = {}

local function cache_edge(cache_state)
  if type(cache_state) ~= "table" then return nil end
  local edge = tonumber(cache_state["cache-end"])
  for _, range in ipairs(cache_state["seekable-ranges"] or {}) do
    local range_end = tonumber(range["end"])
    if range_end and (not edge or range_end > edge) then edge = range_end end
  end
  return edge
end

live_edge.cache_edge = cache_edge

function live_edge.new(args)
  local mp = args.mp
  local service = {catch_up_pending = false, catch_up_in_progress = false}

  local function offset()
    local value = tonumber(args.offset()) or 2
    return value < 0 and -1 or value
  end

  local function is_live_stream()
    if mp.get_property_native("demuxer-via-network") ~= true then return false end
    if args.known_live and args.known_live() then return true end
    local duration = mp.get_property_number("duration")
    return not duration or duration <= 0
  end

  function service:reset()
    self.catch_up_pending, self.catch_up_in_progress = false, false
  end

  function service:on_property_changed(name, value)
    local buffering = name == "paused-for-cache" and value == true
    local resumed = name == "paused-for-cache" and value == false
    if name == "cache-buffering-state" then
      local state = tonumber(value)
      buffering = state ~= nil and state >= 0 and state < 100
      resumed = state ~= nil and state >= 100
    end
    if (name == "pause" and value == true) or buffering then
      if name == "pause" then self.catch_up_in_progress = false end
      self.catch_up_pending = true
      return false
    end
    if name == "pause" and value == false then resumed = true end
    if resumed then return self:on_playback_restart() end
    return false
  end

  function service:on_playback_restart()
    if self.catch_up_in_progress then
      self.catch_up_pending, self.catch_up_in_progress = false, false
      return false
    end
    if not self.catch_up_pending then return false end
    if mp.get_property_native("pause") == true or
      mp.get_property_native("paused-for-cache") == true then return false end
    self.catch_up_pending = false

    local live_offset = offset()
    if live_offset < 0 or not is_live_stream() then return false end
    if mp.get_property_native("seekable") == false then return false end

    local position = mp.get_property_number("time-pos")
    local edge = cache_edge(mp.get_property_native("demuxer-cache-state"))
    if position and edge and position >= edge - live_offset - 0.25 then
      return false
    end

    -- mpv interprets a negative absolute target relative to the current end
    -- of the stream. Keep the target negative when the configured offset is
    -- zero as an absolute zero would seek to the beginning instead.
    self.catch_up_in_progress = true
    mp.commandv("seek", -math.max(live_offset, 0.001), "absolute")
    return true
  end

  return service
end

return live_edge
