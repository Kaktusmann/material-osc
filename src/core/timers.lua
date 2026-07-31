local timers = {}

function timers.new(args)
  local mp = args.mp
  local service = {}

  function service:cancel(owner, key)
    if not owner or not key then return false end
    local timer = owner[key]
    if not timer then return false end
    timer:kill()
    if owner[key] == timer then owner[key] = nil end
    return true
  end

  function service:after(owner, key, delay, callback)
    self:cancel(owner, key)
    local timer
    timer = mp.add_timeout(delay, function()
      if owner[key] ~= timer then return end
      owner[key] = nil
      callback()
    end)
    owner[key] = timer
    return timer
  end

  function service:every(owner, key, interval, callback)
    self:cancel(owner, key)
    local timer = mp.add_periodic_timer(interval, callback)
    owner[key] = timer
    return timer
  end

  function service:cancel_all(owner, keys)
    for _, key in ipairs(keys or {}) do self:cancel(owner, key) end
  end

  return service
end

return timers
