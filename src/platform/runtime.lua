local runtime = {}

local detected = jit and jit.os or ""
if detected == "" then
  detected = package.config:sub(1, 1) == "\\" and "Windows" or "Unix"
end

runtime.os = detected
runtime.is_windows = detected == "Windows"
runtime.is_macos = detected == "OSX"
runtime.is_unix = not runtime.is_windows

return runtime
