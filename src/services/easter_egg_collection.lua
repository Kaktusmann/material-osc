local easter_egg_collection = {}

function easter_egg_collection.new(args)
  local mp, utils = args.mp, args.utils
  local database_path = mp.command_native({
    "expand-path", "~~home/material-osc-easter-eggs.json"
  })
  local service = {counts = {}}

  local function read_database()
    if not database_path or database_path == "" then return {} end
    local file = io.open(database_path, "rb")
    if not file then return {} end
    local contents = file:read("*a")
    file:close()
    local parsed = utils.parse_json(contents or "")
    return type(parsed) == "table" and parsed or {}
  end

  local function write_database()
    if not database_path or database_path == "" then return false end
    local encoded = utils.format_json({
      version = 2,
      counts = service.counts
    })
    if not encoded then return false end

    local temporary_path = database_path .. ".tmp"
    local file = io.open(temporary_path, "wb")
    if not file then return false end
    local ok = file:write(encoded, "\n")
    file:close()
    if not ok then
      os.remove(temporary_path)
      return false
    end
    if os.rename(temporary_path, database_path) then return true end

    -- Windows cannot replace an existing file with rename. Fall back to a
    -- direct write there while retaining atomic replacement on other hosts.
    file = io.open(database_path, "wb")
    if not file then
      os.remove(temporary_path)
      return false
    end
    ok = file:write(encoded, "\n")
    file:close()
    os.remove(temporary_path)
    return not not ok
  end

  local stored = read_database()
  if type(stored.counts) == "table" then
    for text, count in pairs(stored.counts) do
      count = math.max(0, math.floor(tonumber(count) or 0))
      if type(text) == "string" and text ~= "" and count > 0 then
        service.counts[text] = count
      end
    end
  else
    -- Migrate the original unique-collection format to one collected
    -- occurrence per phrase.
    local entries = type(stored.collected) == "table" and
      stored.collected or stored
    for key, value in pairs(entries) do
      local text = type(key) == "number" and value or (value and key or nil)
      if type(text) == "string" and text ~= "" then
        service.counts[text] = math.max(1, service.counts[text] or 0)
      end
    end
  end

  function service:count(text)
    return self.counts[tostring(text or "")] or 0
  end

  function service:collect(text)
    text = tostring(text or "")
    if text == "" then return false, 0, "invalid-text" end
    local previous = self.counts[text] or 0
    self.counts[text] = previous + 1
    if write_database() then return true, self.counts[text] end
    self.counts[text] = previous > 0 and previous or nil
    return false, previous, "save-failed"
  end

  return service
end

return easter_egg_collection
