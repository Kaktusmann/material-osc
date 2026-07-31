local config_watcher = {}

local function decode(value, default)
  value = tostring(value or ""):match("^%s*(.-)%s*$") or ""
  local quote = value:sub(1, 1)
  if (quote == '"' or quote == "'") and value:sub(-1) == quote then
    value = value:sub(2, -2)
  end
  if type(default) == "boolean" then
    local normalized = value:lower()
    if normalized == "yes" or normalized == "true" or normalized == "1" then
      return true
    end
    if normalized == "no" or normalized == "false" or normalized == "0" then
      return false
    end
    return default
  end
  if type(default) == "number" then return tonumber(value) or default end
  return value
end

function config_watcher.parse(contents, defaults)
  local values = {}
  for name, value in pairs(defaults) do values[name] = value end
  for line in (tostring(contents or "") .. "\n"):gmatch("(.-)\n") do
    local name, value = line:match("^%s*([%w_-]+)%s*=%s*(.-)%s*$")
    if name and defaults[name] ~= nil then
      values[name] = decode(value, defaults[name])
    end
  end
  return values
end

function config_watcher.new(args)
  local filesystem = args.filesystem
  local service = {
    contents = filesystem:read(args.path) or "",
    preserved = {},
    watch_id = nil,
    reload_timer = nil,
    stopped = true
  }
  local initial = config_watcher.parse(service.contents, args.defaults)
  if args.normalize then initial = args.normalize(initial) end
  for name, value in pairs(initial) do
    if args.options[name] ~= value then service.preserved[name] = true end
  end

  function service:preserve(changed)
    for name in pairs(changed or {}) do self.preserved[name] = true end
  end

  function service:reload()
    local contents = filesystem:read(args.path) or ""
    if contents == self.contents then return end
    self.contents = contents
    local values = config_watcher.parse(contents, args.defaults)
    if args.normalize then values = args.normalize(values) end
    local changed = {}
    for name, value in pairs(values) do
      if not self.preserved[name] and args.options[name] ~= value then
        args.options[name] = value
        changed[name] = true
      end
    end
    if next(changed) then args.on_update(changed) end
  end

  function service:schedule_reload()
    args.timers:after(self, "reload_timer", args.reload_delay or 0.1, function()
      self:reload()
    end)
  end

  function service:arm()
    if self.stopped or self.watch_id then return end
    local directory = filesystem:existing_directory(args.directory)
    self.watch_id = filesystem:watch(directory, function(success, result)
      self.watch_id = nil
      if self.stopped then return end
      if not success then
        self.stopped = true
        if args.on_error then args.on_error(result and result.stderr or "") end
        return
      end
      self:schedule_reload()
      self:arm()
    end)
  end

  function service:start()
    if not self.stopped then return end
    self.stopped = false
    self:arm()
  end

  function service:stop()
    self.stopped = true
    if self.watch_id then self.watch_id:cancel() end
    self.watch_id = nil
    args.timers:cancel(self, "reload_timer")
  end

  return service
end

return config_watcher
