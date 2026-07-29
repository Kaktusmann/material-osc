local media_loader = {}

function media_loader.new(args)
  local render = args.render

  local function load_sources(output, mode)
    local sources = {}
    for source in tostring(output or ""):gmatch("[^\r\n]+") do
      local clean_source = source:match("^%s*(.-)%s*$")
      if clean_source ~= "" then sources[#sources + 1] = clean_source end
    end
    for index, source in ipairs(sources) do
      local load_mode = mode
      if mode == "replace" and index > 1 then load_mode = "append" end
      mp.commandv("loadfile", source, load_mode)
    end
    if #sources > 0 then render() end
  end

  local function run_picker(command, fallback, on_result)
    mp.command_native_async({
      name = "subprocess", args = command, playback_only = false,
      capture_stdout = true, capture_stderr = true
    }, function(success, result)
      if success and result and result.status == 0 and result.stdout and
        result.stdout:match("%S") then
        on_result(result.stdout)
      elseif fallback and (not success or not result or result.status == 127) then
        fallback()
      end
    end)
  end

  local function open_file_picker(mode)
    local title = mode == "append" and "Add files to playlist" or "Open files"
    local on_result = function(output) load_sources(output, mode) end
    local os_name = jit and jit.os or ""
    if os_name == "Windows" then
      local script = table.concat({
        "[Console]::OutputEncoding=[Text.Encoding]::UTF8;",
        "Add-Type -AssemblyName System.Windows.Forms;",
        "$d=New-Object System.Windows.Forms.OpenFileDialog;",
        "$d.Title='" .. title .. "';",
        "$d.Multiselect=$true;",
        "$d.Filter='All files|*.*';",
        "if($d.ShowDialog() -eq 'OK'){[Console]::Write(($d.FileNames -join \"`n\"))}"
      }, " ")
      run_picker({"powershell", "-NoProfile", "-Command", script}, nil, on_result)
    elseif os_name == "OSX" then
      local script = table.concat({
        "set picked to choose file with prompt \"" .. title ..
          "\" with multiple selections allowed",
        "set output to \"\"",
        "repeat with f in picked",
        "set output to output & POSIX path of f & linefeed",
        "end repeat",
        "return output"
      }, "\n")
      run_picker({"osascript", "-e", script}, nil, on_result)
    else
      run_picker({"zenity", "--file-selection", "--multiple",
        "--title=" .. title, "--separator=\n"}, function()
          run_picker({"kdialog", "--getopenfilename", "~", "All files (*)",
            "--multiple", "--separate-output", "--title", title}, nil, on_result)
        end, on_result)
    end
  end

  local function open_link_picker(mode)
    local title = mode == "append" and "Add link to playlist" or "Open link"
    local prompt = mode == "append" and
      "Enter a media URL to add to the playlist:" or "Enter a media URL:"
    local on_result = function(output) load_sources(output, mode) end
    local os_name = jit and jit.os or ""
    if os_name == "Windows" then
      local script = table.concat({
        "Add-Type -AssemblyName Microsoft.VisualBasic;",
        "$u=[Microsoft.VisualBasic.Interaction]::InputBox(",
        "'" .. prompt .. "','" .. title .. "','');",
        "Write-Output $u"
      }, "")
      run_picker({"powershell", "-NoProfile", "-Command", script}, nil, on_result)
    elseif os_name == "OSX" then
      local script = "text returned of (display dialog \"" .. prompt ..
        "\" default answer \"\" with title \"" .. title .. "\")"
      run_picker({"osascript", "-e", script}, nil, on_result)
    else
      run_picker({"zenity", "--entry", "--title=" .. title,
        "--text=" .. prompt}, function()
          run_picker({"kdialog", "--inputbox", prompt, "",
            "--title", title}, nil, on_result)
        end, on_result)
    end
  end

  return {
    open_files = function() open_file_picker("replace") end,
    open_link = function() open_link_picker("replace") end,
    append_files = function() open_file_picker("append") end,
    append_link = function() open_link_picker("append") end
  }
end

return media_loader
