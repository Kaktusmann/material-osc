local media_loader = {}

function media_loader.new(args)
  local render = args.render
  local dialogs = args.dialogs

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

  local function open_file_picker(mode)
    local title = mode == "append" and "Add files to playlist" or "Open files"
    dialogs:pick_files({title = title, multiple = true},
      function(output) load_sources(output, mode) end)
  end

  local function open_link_picker(mode)
    local title = mode == "append" and "Add link to playlist" or "Open link"
    local prompt = mode == "append" and
      "Enter a media URL to add to the playlist:" or "Enter a media URL:"
    dialogs:prompt_text({
      title = title, message = prompt, prefill_clipboard_link = true
    },
      function(output) load_sources(output, mode) end)
  end

  return {
    open_files = function() open_file_picker("replace") end,
    open_link = function() open_link_picker("replace") end,
    append_files = function() open_file_picker("append") end,
    append_link = function() open_link_picker("append") end
  }
end

return media_loader
