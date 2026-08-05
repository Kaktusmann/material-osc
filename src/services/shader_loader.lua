local shader_loader = {}

local SHADER_EXTENSIONS = {"glsl", "hook"}
local SHADER_PATTERNS = {"*.glsl", "*.hook"}

function shader_loader.new(args)
  local mp, msg = args.mp, args.msg
  local filesystem, http = args.filesystem, args.http
  local dialogs = args.dialogs
  local render = args.render

  local function add_shader(path)
    path = tostring(path or ""):match("^%s*(.-)%s*$")
    if path == "" then return end
    mp.commandv("change-list", "glsl-shaders", "append", path)
  end

  local function attach_files(output)
    local added = false
    for path in tostring(output or ""):gmatch("[^\r\n]+") do
      add_shader(path)
      added = true
    end
    if added then render() end
  end

  local function open_file_picker()
    local title = "Add video shaders"
    dialogs:pick_files({
      title = title,
      multiple = true,
      filters = {{
        label = "Shader files",
        patterns = SHADER_PATTERNS,
        extensions = SHADER_EXTENSIONS
      }}
    }, attach_files)
  end

  local function download_shader(url)
    url = tostring(url or ""):match("^%s*(.-)%s*$")
    if url == "" then return end
    local directory = mp.command_native({
      "expand-path", "~~/cache/material-osc/shaders"
    })
    if not directory or directory == "" or
      not filesystem:ensure_directory(directory) then
      args.toast:error(
        "Could not create the shader cache directory", {duration = 3})
      return
    end
    local filename = url:gsub("[?#].*$", ""):match("([^/\\]+)$") or "shader.glsl"
    filename = filename:gsub("[^%w%._%-]", "_")
    if not filename:match("%.[%w]+$") then filename = filename .. ".glsl" end
    filename = tostring(os.time()) .. "-" .. filename
    local output = filesystem:join(directory, filename)
    http:download(url, output, {
      connect_timeout = 10,
      max_time = 60
    }, function(ok, response)
      if ok then
        add_shader(output)
        render()
      else
        msg.error("shader download failed: " ..
          tostring(response.stderr or "unknown error"))
        args.toast:error("Shader download failed", {duration = 3})
      end
    end)
  end

  local function open_link_picker()
    local title = "Add video shader link"
    dialogs:prompt_text({
      title = title,
      message = "Enter a shader URL:",
      prefill_clipboard_link = true
    }, download_shader)
  end

  return {
    open_file_picker = open_file_picker,
    open_link_picker = open_link_picker,
    remove = function(path)
      mp.commandv("change-list", "glsl-shaders", "remove", path)
      render()
    end,
    clear = function()
      mp.commandv("change-list", "glsl-shaders", "clr", "")
      render()
    end
  }
end

return shader_loader
