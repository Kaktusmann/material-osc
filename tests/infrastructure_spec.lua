package.path = "./?.lua;" .. package.path

local function equal(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected " ..
      tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local windows_command = require "src.platform.windows_command"
local command = windows_command.powershell(
  "[Console]::Write($argument1)", {"C:\\Users\\O'Brien\\file.conf"})
equal(command[1], "powershell")
assert(command[5]:find("param($argument1)", 1, true))
assert(command[5]:find("O''Brien", 1, true))
assert(not command[5]:find("$args", 1, true))

local schema = require "src.config.schema"
local options = schema.defaults()
options.window_controls = "INVALID"
options.seeking_zone_percentage = 80
options.youtube_quality = "1080p"
options.sponsorblock_auto_skip_categories = "Sponsor,sponsor,Intro"
schema.normalize(options)
equal(options.window_controls, "auto")
equal(options.seeking_zone_percentage, 50)
equal(options.youtube_quality, "1080")
equal(options.sponsorblock_auto_skip_categories, "sponsor,intro")
local rendered, changed = schema.render_configuration(
  "accent_color=\"#123456\"\nremoved_option=yes\n", options)
assert(changed)
assert(rendered:find('accent_color="#123456"', 1, true))
assert(not rendered:find("removed_option", 1, true))
for _, definition in ipairs(schema.definitions) do
  assert(rendered:find(definition.name .. "=", 1, true))
end

local files = {}
local fake_filesystem = {}
function fake_filesystem:read(path) return files[path] end
function fake_filesystem:ensure_parent() return true end
function fake_filesystem:write(path, contents)
  files[path] = contents
  return true
end
function fake_filesystem:write_atomic(path, contents)
  files[path] = contents
  return true
end
local persistence = require("src.platform.persistence").new({
  filesystem = fake_filesystem,
  utils = {
    parse_json = function(contents)
      local value = contents:match('"value"%s*:%s*"(.-)"')
      return value and {value = value} or nil
    end,
    format_json = function(value)
      return value.value and ('{"value":"' .. value.value .. '"}') or nil
    end
  }
})
local preferences = persistence:key_value("preferences.conf", {
  order = {"mode", "last_check"}
})
assert(preferences:save({last_check = "12", mode = "auto"}))
equal(files["preferences.conf"], "mode=auto\nlast_check=12\n")
equal(preferences:load().mode, "auto")
local json = persistence:json("state.json")
assert(json:save({value = "stored"}))
equal(json:load().value, "stored")

local pending = {}
local timer_mp = {}
function timer_mp.add_timeout(delay, callback)
  local timer = {delay = delay, callback = callback, killed = false}
  function timer:kill() self.killed = true end
  pending[#pending + 1] = timer
  return timer
end
function timer_mp.add_periodic_timer(interval, callback)
  return timer_mp.add_timeout(interval, callback)
end
local timers = require("src.core.timers").new({mp = timer_mp})
local owner, fired = {}, 0
local first = timers:after(owner, "refresh", 1, function() fired = fired + 1 end)
local second = timers:after(owner, "refresh", 2, function() fired = fired + 1 end)
assert(first.killed)
equal(owner.refresh, second)
second.callback()
equal(fired, 1)
equal(owner.refresh, nil)
timers:every(owner, "repeat_timer", 0.1, function() end)
assert(timers:cancel(owner, "repeat_timer"))

local native_request, async_callback, aborted
local process_mp = {
  command_native = function(request)
    native_request = request
    return {status = 0, stdout = "ok"}
  end,
  command_native_async = function(request, callback)
    native_request, async_callback = request, callback
    return 44
  end,
  abort_async_command = function(id) aborted = id end
}
local process = require("src.platform.process").new({mp = process_mp})
local ok, result = process:run({"tool", "argument"})
assert(ok and result.stdout == "ok")
equal(native_request.args[2], "argument")
local async_ok
local operation = process:run_async({"tool"}, nil,
  function(success) async_ok = success end)
async_callback(true, {status = 0})
assert(async_ok)
local cancelled = process:run_async({"tool"})
cancelled:cancel()
equal(aborted, 44)

local dialog_request
local dialog_process = {}
function dialog_process:run_async(command_value, _, callback)
  dialog_request = command_value
  callback(true, {status = 0, stdout = "C:\\media\\video.mp4"})
  return {cancel = function() end}
end
local dialogs = require("src.platform.dialogs").new({
  process = dialog_process,
  runtime = {is_windows = true}
})
local picked
dialogs:pick_files({title = "Open", filters = {
  {label = "Video", patterns = {"*.mp4"}}
}}, function(value) picked = value end)
equal(picked, "C:\\media\\video.mp4")
equal(dialog_request[1], "powershell")
assert(dialog_request[5]:find("OpenFileDialog", 1, true))

local requests = {}
local http_process = {}
function http_process:run_async(command_value, _, callback)
  requests[#requests + 1] = {command = command_value, callback = callback}
  return {cancel = function() end}
end
local http = require("src.platform.http").new({
  process = http_process,
  runtime = {is_windows = false, is_macos = false}
})
local response
http:get("https://example.test/resource", {
  headers = {"Accept: application/json"}
}, function(success, value)
  assert(success)
  response = value
end)
equal(requests[1].command[1], "curl")
equal(requests[1].command[#requests[1].command],
  "https://example.test/resource")
requests[1].callback(true, {status = 0, stdout = "payload\n200"})
equal(response.status, 200)
equal(response.body, "payload")

requests = {}
local windows_http = require("src.platform.http").new({
  process = http_process,
  runtime = {is_windows = true, is_macos = false}
})
local fallback_status
windows_http:get("https://example.test/fallback", nil,
  function(success, value)
    assert(success)
    fallback_status = value.status
  end)
requests[1].callback(false, {status = 127, stderr = "curl unavailable"})
equal(requests[2].command[1], "powershell")
requests[2].callback(true, {status = 0, stdout = "fallback\n200"})
equal(fallback_status, 200)

print("infrastructure specs passed")
