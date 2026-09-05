local dialogs = {}
local windows_command = require "src.platform.windows_command"

local function filter_values(filters)
  local windows, unix, extensions = {}, {}, {}
  for _, filter in ipairs(filters or {}) do
    local patterns = filter.patterns or {"*.*"}
    windows[#windows + 1] = tostring(filter.label or "Files") .. "|" ..
      table.concat(patterns, ";")
    unix[#unix + 1] = tostring(filter.label or "Files") .. " | " ..
      table.concat(patterns, " ")
    for _, extension in ipairs(filter.extensions or {}) do
      if tostring(extension):match("^[%w]+$") then
        extensions[#extensions + 1] = tostring(extension)
      end
    end
  end
  windows[#windows + 1] = "All files|*.*"
  unix[#unix + 1] = "All files | *"
  return table.concat(windows, "|"), unix, extensions
end

local function applescript_string(value)
  return '"' .. tostring(value):gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

local function clipboard_link(value)
  local link = tostring(value or ""):match("^%s*(.-)%s*$")
  if link == "" or link:find("[%c%s]") then return "" end
  if link:match("^[%a][%w+%.%-]*://.+$") or
    link:match("^magnet:%?.+$") then
    return link
  end
  return ""
end

function dialogs.new(args)
  local process, runtime = args.process, args.runtime
  local service = {}

  local function handle_result(callback, fallback)
    return function(ok, result)
      local output = result and result.stdout or ""
      if ok and output:match("%S") then
        callback(output)
      elseif fallback and (not result or tonumber(result.status) == 127) then
        fallback()
      end
    end
  end

  local function read_clipboard(callback)
    local commands
    if runtime.is_windows then
      commands = {windows_command.powershell(
        "[Console]::Write((Get-Clipboard -Raw))")}
    elseif runtime.is_macos then
      commands = {{"pbpaste"}}
    else
      commands = {
        {"wl-paste", "--no-newline"},
        {"xclip", "-selection", "clipboard", "-out"},
        {"xsel", "--clipboard", "--output"}
      }
    end

    local index = 0
    local function try_next()
      index = index + 1
      local command = commands[index]
      if not command then
        callback("")
        return
      end
      process:run_async(command, nil, function(ok, result)
        local output = result and result.stdout or ""
        if ok then callback(output) else try_next() end
      end)
    end
    return try_next()
  end

  function service:pick_files(options, callback)
    options = options or {}
    local title = tostring(options.title or "Choose files")
    local multiple = options.multiple ~= false
    local windows_filter, unix_filters, extensions =
      filter_values(options.filters)
    if runtime.is_windows then
      local script = table.concat({
        "Add-Type -AssemblyName System.Windows.Forms;",
        "$dialog=New-Object System.Windows.Forms.OpenFileDialog;",
        "$dialog.Title=$argument1;",
        "$dialog.Multiselect=" .. (multiple and "$true;" or "$false;"),
        "$dialog.Filter=$argument2;",
        "if($dialog.ShowDialog() -eq 'OK'){",
        "[Console]::Write(($dialog.FileNames -join \"`n\"))}"
      }, " ")
      return process:run_async(windows_command.powershell(
        script, {title, windows_filter}), nil, handle_result(callback))
    end
    if runtime.is_macos then
      local types = ""
      if #extensions > 0 then
        local quoted = {}
        for index, extension in ipairs(extensions) do
          quoted[index] = applescript_string(extension)
        end
        types = " of type {" .. table.concat(quoted, ",") .. "}"
      end
      local choose = "choose file with prompt (item 1 of argv)" .. types
      local picked = multiple and
        (choose .. " with multiple selections allowed") or ("{" .. choose .. "}")
      local script = table.concat({
        "on run argv",
        "set picked to " .. picked,
        "set output to \"\"",
        "repeat with selectedFile in picked",
        "set output to output & POSIX path of selectedFile & linefeed",
        "end repeat",
        "return output",
        "end run"
      }, "\n")
      return process:run_async({"osascript", "-e", script, "--", title}, nil,
        handle_result(callback))
    end

    local zenity = {"zenity", "--file-selection"}
    if multiple then
      zenity[#zenity + 1] = "--multiple"
      zenity[#zenity + 1] = "--separator=\n"
    end
    zenity[#zenity + 1] = "--title=" .. title
    for _, filter in ipairs(unix_filters) do
      zenity[#zenity + 1] = "--file-filter=" .. filter
    end
    local function kdialog()
      local command = {"kdialog", "--getopenfilename", "~",
        unix_filters[1] or "All files (*)"}
      if multiple then
        command[#command + 1] = "--multiple"
        command[#command + 1] = "--separate-output"
      end
      command[#command + 1] = "--title"
      command[#command + 1] = title
      return process:run_async(command, nil, handle_result(callback))
    end
    return process:run_async(zenity, nil, handle_result(callback, kdialog))
  end

  function service:prompt_text(options, callback)
    options = options or {}
    local title = tostring(options.title or "Input")
    local message = tostring(options.message or "")
    local fallback_default = tostring(options.default or "")

    local function show(default)
      if runtime.is_windows then
        local script = table.concat({
          "Add-Type -AssemblyName Microsoft.VisualBasic;",
          "$value=[Microsoft.VisualBasic.Interaction]::InputBox(",
          "$argument1,$argument2,$argument3);",
          "[Console]::Write($value)"
        }, " ")
        return process:run_async(windows_command.powershell(
          script, {message, title, default}), nil, handle_result(callback))
      end
      if runtime.is_macos then
        local script = table.concat({
          "on run argv",
          "return text returned of (display dialog (item 1 of argv) " ..
            "default answer (item 3 of argv) with title (item 2 of argv))",
          "end run"
        }, "\n")
        return process:run_async(
          {"osascript", "-e", script, "--", message, title, default}, nil,
          handle_result(callback))
      end
      local zenity = {"zenity", "--entry", "--title=" .. title,
        "--text=" .. message, "--entry-text=" .. default}
      local function kdialog()
        return process:run_async({"kdialog", "--inputbox", message, default,
          "--title", title}, nil, handle_result(callback))
      end
      return process:run_async(zenity, nil, handle_result(callback, kdialog))
    end

    if options.prefill_clipboard_link then
      return read_clipboard(function(value)
        local link = clipboard_link(value)
        show(link ~= "" and link or fallback_default)
      end)
    end
    return show(fallback_default)
  end

  return service
end

return dialogs
