local history = {}

local MINUTE, HOUR, DAY, WEEK = 60, 3600, 86400, 604800

local function relative_time(seconds_ago)
  seconds_ago = math.max(0, seconds_ago)
  if seconds_ago < MINUTE then return "Just now" end
  if seconds_ago < HOUR then
    local minutes = math.floor(seconds_ago / MINUTE)
    return minutes .. (minutes == 1 and " minute ago" or " minutes ago")
  end
  if seconds_ago < DAY then
    local hours = math.floor(seconds_ago / HOUR)
    return hours .. (hours == 1 and " hour ago" or " hours ago")
  end
  if seconds_ago < WEEK then
    local days = math.floor(seconds_ago / DAY)
    if days == 1 then return "Yesterday" end
    return days .. " days ago"
  end
  if seconds_ago < WEEK * 5 then
    local weeks = math.floor(seconds_ago / WEEK)
    return weeks .. (weeks == 1 and " week ago" or " weeks ago")
  end
  return os.date("%b %d, %Y", os.time() - seconds_ago)
end

function history.new(args)
  local mp = args.mp
  local service = {}
  local database_path = mp.command_native({"expand-path",
    "~~home/material-osc-history.json"})
  local database = args.persistence:json(database_path, {
    default = function() return {} end
  })

  local function write_database(entries)
    return database:save(entries)
  end

  function service:record()
    if not args.enabled() then return end
    local path = mp.get_property("path", "") or ""
    if path == "" or path == "-" then return end
    local key = mp.command_native({"normalize-path", path}) or path
    local title = mp.get_property("media-title", "") or ""
    if title == "" then title = path:match("([^/\\]+)$") or path end
    local entries = {}
    for _, entry in ipairs(self.data) do
      if entry.key ~= key then entries[#entries + 1] = entry end
    end
    table.insert(entries, 1,
      {key = key, path = path, title = title, time = os.time()})
    local max_entries = math.max(1, math.floor(tonumber(args.max_entries()) or 50))
    while #entries > max_entries do table.remove(entries) end
    self.data = entries
    write_database(self.data)
  end

  function service:items()
    local now, items = os.time(), {}
    for _, entry in ipairs(self.data) do
      items[#items + 1] = {
        id = entry.key,
        path = entry.path,
        label = entry.title,
        details = relative_time(now - (tonumber(entry.time) or now)),
        action_icon = "delete"
      }
    end
    return items
  end

  function service:count() return #self.data end

  function service:remove(key)
    local entries, removed = {}, false
    for _, entry in ipairs(self.data) do
      if entry.key == key then removed = true
      else entries[#entries + 1] = entry end
    end
    if not removed then return false end
    self.data = entries
    write_database(self.data)
    args.render()
    return true
  end

  function service:clear()
    if #self.data == 0 then return end
    self.data = {}
    write_database(self.data)
    args.render()
  end

  service.data = database:load()
  if type(service.data) ~= "table" then service.data = {} end
  return service
end

return history
