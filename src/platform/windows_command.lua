local windows_command = {}

local function powershell_literal(value)
  return "'" .. tostring(value or ""):gsub("'", "''") .. "'"
end

function windows_command.powershell(script, arguments)
  arguments = arguments or {}
  -- Windows PowerShell defaults console output to the legacy ANSI/OEM
  -- codepage, which mangles non-ASCII text captured as subprocess stdout.
  local preamble = "$ErrorActionPreference='Stop'; " ..
    "[Console]::OutputEncoding=[Text.Encoding]::UTF8; "
  if #arguments > 0 then
    local parameters, values = {}, {}
    for index, value in ipairs(arguments) do
      parameters[index] = "$argument" .. tostring(index)
      values[index] = powershell_literal(value)
    end
    script = "& { param(" .. table.concat(parameters, ",") .. ") " ..
      preamble .. script .. " } " ..
      table.concat(values, " ")
  else
    script = preamble .. script
  end
  return {
    "powershell", "-NoProfile", "-NonInteractive", "-Command", script
  }
end

return windows_command
