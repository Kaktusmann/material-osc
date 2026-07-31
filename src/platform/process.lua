local process = {}

local function command_options(command, options)
  options = options or {}
  local value = {
    name = "subprocess",
    args = command,
    playback_only = options.playback_only == true,
    capture_stdout = options.capture_stdout ~= false,
    capture_stderr = options.capture_stderr ~= false
  }
  for _, name in ipairs({
    "capture_size", "detach", "env", "stdin_data", "passthrough_stdin"
  }) do
    if options[name] ~= nil then value[name] = options[name] end
  end
  return value
end

local function normalize(success, result)
  result = result or {}
  local status = tonumber(result.status) or -1
  return success and status == 0, result
end

function process.new(args)
  local mp = args.mp
  local service = {}

  function service:run(command, options)
    local result = mp.command_native(command_options(command, options))
    return normalize(result ~= nil, result)
  end

  function service:run_async(command, options, callback)
    callback = callback or function() end
    local operation = {command_id = nil, cancelled = false}

    function operation:cancel()
      if self.cancelled then return end
      self.cancelled = true
      if self.command_id then mp.abort_async_command(self.command_id) end
      self.command_id = nil
    end

    operation.command_id = mp.command_native_async(
      command_options(command, options), function(success, result)
        operation.command_id = nil
        if operation.cancelled then return end
        local ok, normalized = normalize(success, result)
        callback(ok, normalized)
      end)
    return operation
  end

  return service
end

return process
