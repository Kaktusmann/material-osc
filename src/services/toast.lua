local toast = {}

local DEFAULT_ICONS = {
  info = "info",
  success = "check_circle",
  warning = "warning",
  error = "error"
}

function toast.new(args)
  local mp = args.mp
  local service = {
    presenter = nil,
    pending = nil
  }

  local function present(item)
    if not service.presenter then
      service.pending = item
      return
    end
    service.pending = nil
    service.presenter:show_pill(
      item.icon,
      item.message,
      mp.get_time(),
      {
        duration = item.duration,
        show_on_empty = item.show_on_empty,
        label_color = item.label_color
      })
    if args.render then args.render() end
  end

  function service:bind(presenter)
    self.presenter = presenter
    if self.pending then present(self.pending) end
  end

  function service:show(message, options)
    options = options or {}
    local kind = options.kind or "info"
    present({
      message = tostring(message or ""),
      icon = options.icon or DEFAULT_ICONS[kind] or DEFAULT_ICONS.info,
      duration = math.max(0, tonumber(options.duration) or 1.4),
      show_on_empty = options.show_on_empty == true,
      label_color = options.label_color
    })
  end

  local function kind_method(kind)
    return function(self, message, options)
      local values = {kind = kind}
      for key, value in pairs(options or {}) do values[key] = value end
      self:show(message, values)
    end
  end
  for _, kind in ipairs({"info", "success", "warning", "error"}) do
    service[kind] = kind_method(kind)
  end

  return service
end

return toast
