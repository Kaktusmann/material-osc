local http = {}
local windows_command = require "src.platform.windows_command"

local function status_result(success, result, output_file)
  result = result or {}
  local output = result.stdout or ""
  local status = tonumber(output:match("\n(%d%d%d)%s*$")) or 0
  local body = output:gsub("\n%d%d%d%s*$", "")
  local process_ok = success and tonumber(result.status) == 0
  if status == 0 and process_ok and output_file then status = 200 end
  return process_ok, {
    status = status,
    body = body,
    stderr = result.stderr or "",
    result = result
  }
end

local function sorted_keys(values)
  local keys = {}
  for key in pairs(values or {}) do keys[#keys + 1] = key end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  return keys
end

function http.new(args)
  local process, runtime = args.process, args.runtime
  local service = {}

  local function copy_options(options)
    local copy = {}
    for key, value in pairs(options or {}) do copy[key] = value end
    return copy
  end

  local function curl_command(url, options)
    local command = {"curl", "--location", "--silent", "--show-error"}
    if options.fail then command[#command + 1] = "--fail" end
    if options.connect_timeout then
      command[#command + 1] = "--connect-timeout"
      command[#command + 1] = tostring(options.connect_timeout)
    end
    if options.max_time then
      command[#command + 1] = "--max-time"
      command[#command + 1] = tostring(options.max_time)
    end
    if options.user_agent then
      command[#command + 1] = "--user-agent"
      command[#command + 1] = options.user_agent
    end
    local method = tostring(options.method or "GET"):upper()
    if method == "GET" or options.query then
      command[#command + 1] = "--get"
    end
    if method ~= "GET" then
      command[#command + 1] = "--request"
      command[#command + 1] = method
    end
    for _, header in ipairs(options.headers or {}) do
      command[#command + 1] = "--header"
      command[#command + 1] = header
    end
    for _, key in ipairs(sorted_keys(options.form)) do
      command[#command + 1] = "--data-urlencode"
      command[#command + 1] = tostring(key) .. "=" ..
        tostring(options.form[key])
    end
    if options.body then
      command[#command + 1] = "--data-binary"
      command[#command + 1] = options.body
    end
    if options.output then
      command[#command + 1] = "--output"
      command[#command + 1] = options.output
    end
    command[#command + 1] = "--write-out"
    command[#command + 1] = "\n%{http_code}"
    command[#command + 1] = url
    return command
  end

  local function powershell_command(url, options)
    local method = tostring(options.method or "GET"):upper()
    if method ~= "GET" or options.query or options.form or options.body then
      return nil
    end
    local values, statements = {url}, {"$headers=@{};"}
    for _, header in ipairs(options.headers or {}) do
      local name, value = tostring(header):match("^%s*([^:]+):%s*(.*)$")
      if name then
        values[#values + 1] = name
        local name_index = #values
        values[#values + 1] = value
        statements[#statements + 1] = "$headers[$argument" ..
          tostring(name_index) .. "]=$argument" .. tostring(#values) .. ";"
      end
    end
    local invoke = "$response=Invoke-WebRequest -UseBasicParsing " ..
      "-Uri $argument1 -Headers $headers"
    if options.user_agent then
      values[#values + 1] = options.user_agent
      invoke = invoke .. " -UserAgent $argument" .. tostring(#values)
    end
    if options.max_time then
      invoke = invoke .. " -TimeoutSec " ..
        tostring(math.max(1, math.floor(tonumber(options.max_time) or 1)))
    end
    if options.output then
      values[#values + 1] = options.output
      invoke = invoke .. " -OutFile $argument" .. tostring(#values)
    end
    statements[#statements + 1] = invoke .. ";"
    if not options.output then
      statements[#statements + 1] = "[Console]::Write($response.Content);"
    end
    statements[#statements + 1] =
      "[Console]::Write(\"`n\"+[int]$response.StatusCode)"
    return windows_command.powershell(table.concat(statements, " "), values)
  end

  function service:request(url, options, callback)
    options = options or {}
    callback = callback or function() end
    local operation = {current = nil, cancelled = false}

    function operation:cancel()
      self.cancelled = true
      if self.current then self.current:cancel() end
      self.current = nil
    end

    local function run(command, allow_fallback)
      operation.current = process:run_async(command, nil, function(success, result)
        operation.current = nil
        if operation.cancelled then return end
        local ok, response = status_result(success, result, options.output)
        if not ok and allow_fallback and runtime.is_windows and
          options.windows_fallback ~= false then
          local fallback = powershell_command(url, options)
          if fallback then run(fallback, false); return end
        end
        callback(ok, response)
      end)
    end

    run(curl_command(url, options), true)
    return operation
  end

  function service:get(url, options, callback)
    options = copy_options(options)
    options.method = "GET"
    return self:request(url, options, callback)
  end

  function service:download(url, path, options, callback)
    options = copy_options(options)
    options.method = "GET"
    options.output = path
    if options.fail == nil then options.fail = true end
    return self:request(url, options, callback)
  end

  function service:open(url, callback)
    local command
    if runtime.is_windows then
      command = {"rundll32", "url.dll,FileProtocolHandler", url}
    elseif runtime.is_macos then
      command = {"open", url}
    else
      command = {"xdg-open", url}
    end
    return process:run_async(command, nil, function(ok, result)
      if callback then callback(ok, result) end
    end)
  end

  return service
end

return http
