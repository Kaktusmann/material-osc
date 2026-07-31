local persistence = {}

local function fresh_default(value)
  if type(value) == "function" then return value() end
  return value
end

function persistence.new(args)
  local filesystem, utils = args.filesystem, args.utils
  local service = {}

  local function create(path, options)
    options = options or {}
    local store = {}

    function store:load()
      local contents = filesystem:read(path)
      if contents == nil then return fresh_default(options.default) end
      local ok, value = pcall(options.decode, contents)
      if not ok or value == nil then return fresh_default(options.default) end
      if options.normalize then value = options.normalize(value) end
      return value
    end

    function store:save(value)
      if options.normalize then value = options.normalize(value) end
      local ok, contents = pcall(options.encode, value)
      if not ok or type(contents) ~= "string" then return false end
      if not filesystem:ensure_parent(path) then return false end
      if options.atomic == false then return filesystem:write(path, contents) end
      return filesystem:write_atomic(path, contents)
    end

    store.path = path
    return store
  end

  function service:json(path, options)
    options = options or {}
    return create(path, {
      default = options.default or function() return {} end,
      normalize = options.normalize,
      atomic = options.atomic,
      decode = function(contents)
        local value = utils.parse_json(contents)
        if type(value) ~= "table" then return nil end
        return value
      end,
      encode = function(value)
        local encoded = utils.format_json(value)
        return encoded and (encoded .. "\n") or nil
      end
    })
  end

  function service:text(path, options)
    options = options or {}
    return create(path, {
      default = options.default or "",
      normalize = options.normalize,
      atomic = options.atomic,
      decode = function(contents) return contents end,
      encode = function(value) return tostring(value or "") end
    })
  end

  function service:key_value(path, options)
    options = options or {}
    local position = {}
    for index, name in ipairs(options.order or {}) do position[name] = index end
    return create(path, {
      default = options.default or function() return {} end,
      normalize = options.normalize,
      atomic = options.atomic,
      decode = function(contents)
        local values = {}
        for line in (contents .. "\n"):gmatch("(.-)\n") do
          local name, value = line:match("^%s*([%w_-]+)%s*=%s*(.-)%s*$")
          if name then values[name] = value end
        end
        return values
      end,
      encode = function(values)
        local names, seen = {}, {}
        for _, name in ipairs(options.order or {}) do
          if values[name] ~= nil then
            names[#names + 1], seen[name] = name, true
          end
        end
        for name in pairs(values or {}) do
          if not seen[name] then names[#names + 1] = name end
        end
        table.sort(names, function(left, right)
          local left_order, right_order = position[left], position[right]
          if left_order or right_order then
            return (left_order or math.huge) < (right_order or math.huge)
          end
          return tostring(left) < tostring(right)
        end)
        local lines = {}
        for _, name in ipairs(names) do
          lines[#lines + 1] = tostring(name) .. "=" .. tostring(values[name])
        end
        return table.concat(lines, "\n") .. "\n"
      end
    })
  end

  return service
end

return persistence
