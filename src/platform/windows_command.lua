local windows_command = {}

local function powershell_literal(value)
  return "'" .. tostring(value or ""):gsub("'", "''") .. "'"
end

function windows_command.powershell(script, arguments)
  arguments = arguments or {}
  if #arguments > 0 then
    local parameters, values = {}, {}
    for index, value in ipairs(arguments) do
      parameters[index] = "$argument" .. tostring(index)
      values[index] = powershell_literal(value)
    end
    script = "& { param(" .. table.concat(parameters, ",") .. ") " ..
      "$ErrorActionPreference='Stop'; " .. script .. " } " ..
      table.concat(values, " ")
  else
    script = "$ErrorActionPreference='Stop'; " .. script
  end
  return {
    "powershell", "-NoProfile", "-NonInteractive", "-Command", script
  }
end

return windows_command
