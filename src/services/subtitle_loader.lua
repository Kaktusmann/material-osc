local subtitle_loader = {}

local SUBTITLE_EXTENSIONS = {"srt", "ass", "ssa", "vtt", "sub", "idx", "sup"}
local SUBTITLE_PATTERNS = {}
for index, extension in ipairs(SUBTITLE_EXTENSIONS) do
  SUBTITLE_PATTERNS[index] = "*." .. extension
end

function subtitle_loader.new(args)
  local render = args.render
  local dialogs = args.dialogs

  local function restore_primary_subtitle(id)
    if id and id ~= "" then mp.set_property("sid", id)
    else mp.set_property("sid", "no") end
  end

  local function add_secondary_subtitle(source)
    local primary_id = mp.get_property("sid", "no") or "no"
    mp.commandv("sub-add", source, "select")
    local added_id = mp.get_property_number("sid")
    restore_primary_subtitle(primary_id)
    if added_id then
      mp.set_property_number("secondary-sid", added_id)
      mp.set_property_native("secondary-sub-visibility", true)
    end
  end

  local function attach_files(output, secondary)
    local added = 0
    for path in tostring(output or ""):gmatch("[^\r\n]+") do
      local clean_path = path:match("^%s*(.-)%s*$")
      if clean_path ~= "" then
        if secondary and added == 0 then
          add_secondary_subtitle(clean_path)
        else
          mp.commandv("sub-add", clean_path, added == 0 and "select" or "auto")
        end
        added = added + 1
      end
    end
    if added > 0 then render() end
  end

  local function open_file_picker(secondary)
    local title = secondary and "Add secondary subtitle" or "Add subtitles"
    dialogs:pick_files({
      title = title,
      multiple = true,
      filters = {{
        label = "Subtitle files",
        patterns = SUBTITLE_PATTERNS,
        extensions = SUBTITLE_EXTENSIONS
      }}
    }, function(output) attach_files(output, secondary) end)
  end

  local function attach_link(output, secondary)
    local url = (output or ""):match("^%s*(.-)%s*$")
    if url == "" then return end
    if secondary then add_secondary_subtitle(url)
    else mp.commandv("sub-add", url, "select") end
    render()
  end

  local function open_link_picker(secondary)
    local title = secondary and "Add secondary subtitle link" or "Add subtitle link"
    dialogs:prompt_text({
      title = title,
      message = "Enter a subtitle URL:",
      prefill_clipboard_link = true
    }, function(output) attach_link(output, secondary) end)
  end

  return {
    open_file_picker = function() open_file_picker(false) end,
    open_link_picker = function() open_link_picker(false) end,
    open_secondary_file_picker = function() open_file_picker(true) end,
    open_secondary_link_picker = function() open_link_picker(true) end
  }
end

return subtitle_loader
