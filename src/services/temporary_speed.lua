local temporary_speed = {}

function temporary_speed.new(args)
  local state = args.state
  local service = {}

  local function target_speed()
    return math.max(0.01, tonumber(args.value()) or 2)
  end

  function service:activate()
    if state.active then return end
    state.previous = args.mp.get_property_number("speed", 1)
    state.active = true
    args.mp.set_property_number("speed", target_speed())
    args.render()
  end

  function service:deactivate()
    if not state.active then return end
    local previous = state.previous or 1
    state.active, state.previous = false, nil
    args.mp.set_property_number("speed", previous)
    args.render()
  end

  function service:handle(event)
    local kind = event and event.event
    if kind == "down" then self:activate()
    elseif kind == "up" then self:deactivate() end
  end

  function service:update_target()
    if state.active then
      args.mp.set_property_number("speed", target_speed())
      args.render()
    end
  end

  return service
end

return temporary_speed
