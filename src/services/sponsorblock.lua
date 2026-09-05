local sponsorblock = {}

local SERVER = "https://sponsor.ajay.app"
local USER_AGENT =
  "material-osc/1.0 (https://github.com/Kaktusmann/material-osc)"
local SUBMISSION_CATEGORIES = {
  "sponsor", "intro", "outro", "interaction", "selfpromo", "preview",
  "hook", "music_offtopic", "filler"
}
local SPONSORBLOCK_CATEGORIES = {
  "sponsor", "selfpromo", "exclusive_access", "interaction", "intro",
  "outro", "preview", "hook", "music_offtopic", "poi_highlight", "filler"
}
local SPONSORBLOCK_CATEGORY_SET = {}
for _, category in ipairs(SPONSORBLOCK_CATEGORIES) do
  SPONSORBLOCK_CATEGORY_SET[category] = true
end
local CATEGORY_LABELS = {
  sponsor = "Sponsor",
  intro = "Intro",
  outro = "Outro",
  interaction = "Interaction reminder",
  selfpromo = "Self promotion",
  exclusive_access = "Exclusive access",
  preview = "Preview",
  hook = "Hook / greeting",
  music_offtopic = "Off-topic music",
  poi_highlight = "Highlight",
  filler = "Filler"
}
local SEGMENT_ALPHA = "80"
local CATEGORY_STYLES = {
  sponsor = {color = "#00d400", text_color = "#050708", alpha = SEGMENT_ALPHA},
  selfpromo = {color = "#ffff00", text_color = "#050708", alpha = SEGMENT_ALPHA},
  exclusive_access =
    {color = "#008a5c", text_color = "#050708", alpha = SEGMENT_ALPHA},
  interaction =
    {color = "#cc00ff", text_color = "#050708", alpha = SEGMENT_ALPHA},
  intro = {color = "#00ffff", text_color = "#050708", alpha = SEGMENT_ALPHA},
  outro = {color = "#0202ed", text_color = "#FFFFFF", alpha = SEGMENT_ALPHA},
  preview = {color = "#008fd6", text_color = "#050708", alpha = SEGMENT_ALPHA},
  hook = {color = "#395699", text_color = "#FFFFFF", alpha = SEGMENT_ALPHA},
  music_offtopic =
    {color = "#ff9900", text_color = "#050708", alpha = SEGMENT_ALPHA},
  poi_highlight =
    {color = "#ff1684", text_color = "#050708", alpha = SEGMENT_ALPHA},
  filler = {color = "#7300ff", text_color = "#FFFFFF", alpha = SEGMENT_ALPHA}
}
local DEFAULT_CATEGORY_STYLE = {
  color = "#ffffff", text_color = "#050708", alpha = SEGMENT_ALPHA
}

local function youtube_id_from_url(url)
  if type(url) ~= "string" then return nil end
  url = url:gsub("^ytdl://", "")
  local patterns = {
    "[?&]v=([%w_-]+)",
    "youtu%.be/([%w_-]+)",
    "youtube%.com/embed/([%w_-]+)",
    "youtube%.com/v/([%w_-]+)",
    "youtube%.com/shorts/([%w_-]+)",
    "youtube%.com/live/([%w_-]+)",
    "^([%w_-]+)$"
  }
  for _, pattern in ipairs(patterns) do
    local id = url:match(pattern)
    if id and #id >= 11 then return id:sub(1, 11) end
  end
  return nil
end

local function category_label(category)
  return CATEGORY_LABELS[category] or
    tostring(category or "segment"):gsub("_", " "):gsub("^%l", string.upper)
end

local function category_style(category)
  return CATEGORY_STYLES[category] or DEFAULT_CATEGORY_STYLE
end

local function same_prompt(a, b)
  if a == b then return true end
  return a and b and a.id == b.id and a.end_time == b.end_time
end

local function random_user_id()
  local alphabet =
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  local seed = os.time() + math.floor((mp.get_time() or 0) * 1000000)
  for digit in tostring({}):gmatch("%x") do
    seed = (seed * 33 + tonumber(digit, 16)) % 2147483647
  end
  math.randomseed(seed)
  local value = {}
  for index = 1, 36 do
    local offset = math.random(1, #alphabet)
    value[index] = alphabet:sub(offset, offset)
  end
  return table.concat(value)
end

function sponsorblock.new(args)
  local state = args.runtime.sponsorblock
  local opts, utils = args.opts, args.utils
  local http = args.http
  local timers = args.timers
  local user_id_path = args.mp.command_native(
    {"expand-path", "~~/script-opts/material-osc-sponsorblock-id"})
  local user_id_store = args.persistence:text(user_id_path)
  local service = {
    request_id = 0,
    command_ids = {},
    feedback_timer = nil,
    category_policies = {},
    requested_categories = {},
    requested_category_set = {},
    intro_detection_texts = {},
    outro_detection_texts = {}
  }

  local function notify(message, duration, source)
    if not args.toast then return end
    local label = source == "chapter" and tostring(message) or
      ("SponsorBlock · " .. tostring(message))
    args.toast:show(label, {
      icon = "skip_next",
      duration = duration or 2
    })
  end

  local function categories_from(value)
    local categories, seen = {}, {}
    for category in tostring(value or ""):lower():gmatch("[%w_]+") do
      if SPONSORBLOCK_CATEGORY_SET[category] and not seen[category] then
        seen[category] = true
        categories[#categories + 1] = category
      end
    end
    return categories
  end

  local function refresh_category_policies()
    local policies = {}
    for _, category in ipairs(SPONSORBLOCK_CATEGORIES) do
      policies[category] = "ask"
    end
    for _, category in ipairs(categories_from(
      opts.sponsorblock_auto_skip_categories)) do
      policies[category] = "yes"
    end
    for _, category in ipairs(categories_from(
      opts.sponsorblock_ignore_categories)) do
      policies[category] = "no"
    end

    local requested, requested_set = {}, {}
    for _, category in ipairs(SPONSORBLOCK_CATEGORIES) do
      if policies[category] == "yes" or policies[category] == "ask" then
        requested[#requested + 1] = category
        requested_set[category] = true
      end
    end
    service.category_policies = policies
    service.requested_categories = requested
    service.requested_category_set = requested_set
  end
  refresh_category_policies()

  local function detection_texts_from(value)
    local texts, seen = {}, {}
    for raw_text in tostring(value or ""):gmatch("[^,]+") do
      local text = raw_text:lower():match("^%s*(.-)%s*$")
      if text ~= "" and not seen[text] then
        seen[text] = true
        texts[#texts + 1] = text
      end
    end
    return texts
  end

  local function refresh_detection_texts()
    service.intro_detection_texts =
      detection_texts_from(opts.skip_intro_detection_texts)
    service.outro_detection_texts =
      detection_texts_from(opts.skip_outro_detection_texts)
  end
  refresh_detection_texts()

  local function render()
    if args.render then args.render() end
  end

  local function set_prompt(prompt)
    if same_prompt(state.prompt, prompt) then return false end
    state.prompt = prompt
    render()
    return true
  end

  local function user_id()
    if state.user_id then return state.user_id end
    local stored = user_id_path and user_id_store:load()
    stored = stored and stored:match("^%s*([%w]+)%s*$") or nil
    if stored and #stored >= 32 then
      state.user_id = stored
      return stored
    end
    state.user_id = random_user_id()
    if user_id_path then user_id_store:save(state.user_id) end
    return state.user_id
  end

  local function request(request_args, callback)
    local operation
    operation = http:request(SERVER .. request_args.path, {
      method = request_args.method,
      query = request_args.query,
      headers = request_args.headers,
      form = request_args.form,
      body = request_args.body,
      connect_timeout = 5,
      max_time = 20,
      user_agent = USER_AGENT
    }, function(success, response)
      service.command_ids[operation] = nil
      callback(success, response.status, response.body, response.stderr)
    end)
    if operation then
      service.command_ids[operation] = request_args.cancel_on_reset ~= false
    end
  end

  local function report_view(segment)
    if not segment or not segment.uuid then return end
    request({
      method = "POST",
      path = "/api/viewedVideoSponsorTime",
      query = true,
      cancel_on_reset = false,
      form = {UUID = segment.uuid}
    }, function() end)
  end

  local function clear_feedback_timer()
    timers:cancel(service, "feedback_timer")
  end

  local function clear_feedback()
    clear_feedback_timer()
    state.feedback = nil
  end

  local function feedback_for(segment, skipped_from)
    clear_feedback_timer()
    local feedback = {
      segment = segment,
      skipped_from = skipped_from,
      vote = nil
    }
    state.feedback = feedback
    timers:after(service, "feedback_timer", 5, function()
      if state.feedback ~= feedback then return end
      state.feedback = nil
      render()
    end)
  end

  local function skip(segment)
    if not segment then return end
    local position = mp.get_property_number("time-pos", segment.start_time) or
      segment.start_time
    segment.skipped = true
    state.last_segment = segment.uuid and segment or state.last_segment
    set_prompt(nil)
    feedback_for(segment, position)
    mp.commandv("seek", tostring(segment.end_time), "absolute+exact")
    if segment.uuid then report_view(segment) end
    notify(category_label(segment.category) .. " skipped", nil, segment.source)
    render()
  end

  local function policy_for(category)
    return service.category_policies[category] or "ask"
  end

  function service:should_render_segment(category)
    return policy_for(category) ~= "no"
  end

  local function active_api_segment(position)
    for _, segment in ipairs(state.segments) do
      if segment.start_time <= position and segment.end_time > position and
        not segment.skipped and not segment.dismissed and
        policy_for(segment.category) ~= "no" then
        return segment
      end
    end
    return nil
  end

  local function detection_text_matches(title, text)
    if title:sub(1, #text) ~= text then return false end
    local remainder = title:sub(#text + 1)
    if remainder == "" or remainder:match("^[%s:%-]") then return true end
    return remainder:sub(1, #"–") == "–" or
      remainder:sub(1, #"—") == "—"
  end

  local function chapter_category(title)
    title = tostring(title or ""):lower():match("^%s*(.-)%s*$")
    for _, text in ipairs(service.intro_detection_texts) do
      if detection_text_matches(title, text) then return "intro" end
    end
    for _, text in ipairs(service.outro_detection_texts) do
      if detection_text_matches(title, text) then return "outro" end
    end
    return nil
  end

  local function active_chapter_segment(position)
    local chapters = mp.get_property_native("chapter-list") or {}
    local duration = mp.get_property_number("duration", 0) or 0
    local active_index
    for index, chapter in ipairs(chapters) do
      local chapter_time = tonumber(chapter.time) or 0
      if chapter_time <= position then active_index = index else break end
    end
    if not active_index then return nil end
    local chapter = chapters[active_index]
    local category = chapter_category(chapter.title)
    if not category then return nil end
    local start_time = tonumber(chapter.time) or 0
    local next_chapter = chapters[active_index + 1]
    local end_time = next_chapter and tonumber(next_chapter.time) or duration
    if not end_time or end_time <= position or end_time <= start_time then return nil end
    return {
      id = "chapter:" .. tostring(active_index) .. ":" .. tostring(start_time),
      source = "chapter",
      start_time = start_time,
      end_time = end_time,
      category = category,
      title = chapter.title
    }
  end

  function service:on_time_pos(value)
    local position = tonumber(value)
    if not position then
      set_prompt(nil)
      return
    end

    -- A skipped marker only prevents duplicate handling while mpv is completing
    -- the seek to the segment's end. Rearm the segment after the playhead has
    -- left it so seeking back offers the skip action again.
    for _, segment in ipairs(state.segments) do
      if segment.skipped and
        not (segment.start_time <= position and segment.end_time > position) then
        segment.skipped = false
      end
    end

    local chapter = active_chapter_segment(position)
    for id in pairs(state.skipped_chapters) do
      if not chapter or chapter.id ~= id then
        state.skipped_chapters[id] = nil
      end
    end

    if state.active then
      local segment = active_api_segment(position)
      if segment then
        local policy = policy_for(segment.category)
        if policy == "yes" then
          skip(segment)
          return
        elseif policy == "ask" then
          set_prompt(segment)
          return
        end
      end
    end

    if opts.skip_intro_outro_chapters ~= "no" then
      if chapter and not state.skipped_chapters[chapter.id] and
        not state.dismissed_chapters[chapter.id] then
        if opts.skip_intro_outro_chapters == "yes" then
          state.skipped_chapters[chapter.id] = true
          skip(chapter)
          return
        elseif opts.skip_intro_outro_chapters == "ask" then
          set_prompt(chapter)
          return
        end
      end
    end
    set_prompt(nil)
  end

  function service:skip_prompt()
    local prompt = state.prompt
    if not prompt then return end
    if prompt.source == "chapter" then
      state.skipped_chapters[prompt.id] = true
    end
    skip(prompt)
  end

  function service:dismiss_prompt()
    local prompt = state.prompt
    if not prompt then return end
    if prompt.source == "chapter" then
      state.dismissed_chapters[prompt.id] = true
    else
      prompt.dismissed = true
    end
    set_prompt(nil)
  end

  function service:undo()
    local feedback = state.feedback
    if not feedback or not feedback.segment then return end
    local segment = feedback.segment
    if segment.source == "chapter" then
      state.skipped_chapters[segment.id] = nil
      state.dismissed_chapters[segment.id] = nil
    else
      segment.skipped = false
      segment.dismissed = false
    end
    clear_feedback()
    mp.commandv("seek", tostring(feedback.skipped_from or segment.start_time),
      "absolute+exact")
    notify("Skip undone", nil, segment.source)
    render()
  end

  function service:vote(direction)
    if not opts.sponsorblock_should_use then return end
    local segment = state.feedback and state.feedback.segment or
      state.last_segment
    if not segment or not segment.uuid then
      notify("No SponsorBlock segment is available to vote on", 3, true)
      return
    end
    direction = tonumber(direction) == 1 and 1 or 0
    local request_id = self.request_id
    request({
      method = "POST",
      path = "/api/voteOnSponsorTime",
      query = true,
      cancel_on_reset = false,
      form = {
        UUID = segment.uuid,
        videoID = state.video_id,
        userID = user_id(),
        type = direction
      }
    }, function(success, status)
      if request_id ~= self.request_id then return end
      if success and status >= 200 and status < 300 then
        if state.feedback then state.feedback.vote = direction end
        notify(direction == 1 and "Upvote submitted" or "Downvote submitted",
          2, true)
      else
        notify("Vote failed (HTTP " .. tostring(status) .. ")", 3, true)
      end
      render()
    end)
  end

  function service:set_segment_boundary()
    if not opts.sponsorblock_should_use then return end
    if not state.video_id then
      notify("Open a YouTube video before marking a segment", 3, true)
      return
    end
    local position = mp.get_property_number("time-pos")
    if not position then return end
    if not state.draft or state.draft.b then
      state.draft = {a = position, category = "sponsor"}
      notify("Segment start set", 2, true)
    else
      state.draft.b = position
      if state.draft.b < state.draft.a then
        state.draft.a, state.draft.b = state.draft.b, state.draft.a
      end
      notify("Segment end set", 2, true)
    end
    render()
  end

  function service:cycle_submission_category()
    if not state.draft then return end
    local current = 1
    for index, category in ipairs(SUBMISSION_CATEGORIES) do
      if category == state.draft.category then current = index break end
    end
    state.draft.category =
      SUBMISSION_CATEGORIES[current % #SUBMISSION_CATEGORIES + 1]
    render()
  end

  function service:cancel_submission()
    state.draft = nil
    render()
  end

  function service:submit_segment(category)
    if not opts.sponsorblock_should_use then return end
    local draft = state.draft
    if not state.video_id or not draft or not draft.a or not draft.b or
      draft.b - draft.a <= 0 then
      notify("Set both segment boundaries before submitting", 3, true)
      return
    end
    category = category or draft.category or "sponsor"
    state.submitting = true
    local request_id = self.request_id
    render()
    local body = utils.format_json({
      videoID = state.video_id,
      userID = user_id(),
      userAgent = USER_AGENT,
      service = "YouTube",
      videoDuration = mp.get_property_number("duration", 0) or 0,
      segments = {{
        segment = {draft.a, draft.b},
        category = category,
        actionType = "skip"
      }}
    })
    request({
      method = "POST",
      path = "/api/skipSegments",
      cancel_on_reset = false,
      headers = {"Content-Type: application/json"},
      body = body
    }, function(success, status, response)
      if request_id ~= self.request_id then return end
      state.submitting = false
      if success and status >= 200 and status < 300 then
        local submitted = utils.parse_json(response or "")
        local result = type(submitted) == "table" and submitted[1] or nil
        local segment = {
          id = result and result.UUID or
            ("submitted:" .. tostring(draft.a) .. ":" .. tostring(draft.b)),
          uuid = result and result.UUID or nil,
          source = "sponsorblock",
          start_time = draft.a,
          end_time = draft.b,
          category = category,
          skipped = true
        }
        state.segments[#state.segments + 1] = segment
        table.sort(state.segments,
          function(a, b) return a.start_time < b.start_time end)
        state.last_segment = segment.uuid and segment or state.last_segment
        state.draft = nil
        notify(category_label(category) .. " segment submitted", 3, true)
      else
        local detail = response and response:match("^%s*(.-)%s*$") or ""
        if #detail > 100 then detail = detail:sub(1, 100) .. "…" end
        notify("Submission failed (HTTP " .. tostring(status) .. ")" ..
          (detail ~= "" and (": " .. detail) or ""), 5, true)
      end
      render()
    end)
  end

  function service:reset()
    self.request_id = self.request_id + 1
    clear_feedback_timer()
    for operation, cancel_on_reset in pairs(self.command_ids) do
      if cancel_on_reset then
        operation:cancel()
        self.command_ids[operation] = nil
      end
    end
    state.active, state.loading, state.video_id = false, false, nil
    state.segments, state.prompt, state.feedback = {}, nil, nil
    state.last_segment, state.draft, state.submitting = nil, nil, false
    state.skipped_chapters, state.dismissed_chapters = {}, {}
    render()
  end

  function service:load()
    self:reset()
    refresh_category_policies()
    refresh_detection_texts()
    local path = mp.get_property("path", "") or ""
    local referer = mp.get_property("http-header-fields", "") or ""
    local retained_url = args.youtube_url and args.youtube_url() or nil
    local video_id = youtube_id_from_url(path) or
      youtube_id_from_url(retained_url) or youtube_id_from_url(referer)
    if not video_id then
      self:on_time_pos(mp.get_property_number("time-pos"))
      return
    end
    state.video_id = video_id
    state.active = opts.sponsorblock_should_use == true
    if not state.active then
      self:on_time_pos(mp.get_property_number("time-pos"))
      render()
      return
    end

    local categories = self.requested_categories
    if #categories == 0 then
      self:on_time_pos(mp.get_property_number("time-pos"))
      render()
      return
    end
    state.loading = true
    self.request_id = self.request_id + 1
    local request_id = self.request_id
    request({
      method = "GET",
      path = "/api/skipSegments",
      form = {
        videoID = video_id,
        categories = utils.format_json(categories),
        actionTypes = utils.format_json({"skip"})
      }
    }, function(success, status, body, stderr)
      if request_id ~= self.request_id or video_id ~= state.video_id then return end
      state.loading = false
      if status == 404 then
        state.segments = {}
        render()
        return
      end
      local data = success and status >= 200 and status < 300 and
        utils.parse_json(body or "") or nil
      if type(data) ~= "table" then
        state.segments = {}
        local detail = stderr and stderr:match("^%s*(.-)%s*$") or ""
        notify("Could not load segments" ..
          (detail ~= "" and (": " .. detail) or ""), 3)
        render()
        return
      end
      local segments = {}
      for _, item in ipairs(data) do
        local times = type(item.segment) == "table" and item.segment or {}
        local start_time, end_time = tonumber(times[1]), tonumber(times[2])
        if start_time and end_time and end_time > start_time and
          self.requested_category_set[item.category] then
          segments[#segments + 1] = {
            id = item.UUID,
            uuid = item.UUID,
            source = "sponsorblock",
            start_time = start_time,
            end_time = end_time,
            category = item.category,
            votes = tonumber(item.votes) or 0,
            skipped = false,
            dismissed = false
          }
        end
      end
      table.sort(segments, function(a, b)
        if a.start_time == b.start_time then return a.end_time < b.end_time end
        return a.start_time < b.start_time
      end)
      state.segments = segments
      self:on_time_pos(mp.get_property_number("time-pos"))
      render()
    end)
    render()
  end

  function service:on_options_changed(changed)
    refresh_category_policies()
    refresh_detection_texts()
    if changed.sponsorblock_should_use or
      changed.sponsorblock_auto_skip_categories or
      changed.sponsorblock_ignore_categories then
      self:load()
    else
      self:on_time_pos(mp.get_property_number("time-pos"))
      render()
    end
  end

  function service:preview_at(position)
    position = tonumber(position)
    if not position then return nil end
    for _, segment in ipairs(state.segments) do
      if segment.start_time <= position and segment.end_time > position and
        self:should_render_segment(segment.category) then
        local style = category_style(segment.category)
        return {
          text = category_label(segment.category),
          color = style.color,
          text_color = style.text_color
        }
      end
    end
    return nil
  end

  function service:prompt_actions()
    local actions = {}
    local prompt = state.prompt
    if prompt then
      actions[#actions + 1] = {
        name = "youtube-skip-segment",
        icon = "skip_next",
        label = "Skip " .. category_label(prompt.category),
        tooltip = prompt.source == "chapter" and
          ("Skip chapter: " .. tostring(prompt.title or "")) or
          ("Skip SponsorBlock " .. category_label(prompt.category):lower()),
        on_click = function() self:skip_prompt() end
      }
      actions[#actions + 1] = {
        name = "youtube-dismiss-segment",
        icon = "close",
        label = "",
        tooltip = "Do not skip this segment",
        compact = true,
        on_click = function() self:dismiss_prompt() end
      }
    end
    local feedback = state.feedback
    if opts.sponsorblock_show_voting and feedback and feedback.segment and
      feedback.segment.uuid then
      actions[#actions + 1] = {
        name = "youtube-upvote-segment",
        icon = "thumb_up",
        label = "",
        tooltip = "Upvote this segment",
        compact = true,
        selected = feedback.vote == 1,
        on_click = function() self:vote(1) end
      }
      actions[#actions + 1] = {
        name = "youtube-downvote-segment",
        icon = "thumb_down",
        label = "",
        tooltip = "Downvote this segment",
        compact = true,
        selected = feedback.vote == 0,
        on_click = function() self:vote(0) end
      }
    end
    if feedback then
      actions[#actions + 1] = {
        name = "youtube-undo-skip",
        icon = "undo",
        label = "Undo",
        tooltip = "Undo the last skip",
        on_click = function() self:undo() end
      }
    end
    return actions
  end

  function service:tool_actions()
    local actions = {}
    if not opts.sponsorblock_show_submit or not state.active then
      return actions
    end

    local draft = state.draft
    if not draft then
      actions[#actions + 1] = {
        name = "youtube-mark-segment", icon = "flag", label = "",
        tooltip = "Set the start of a SponsorBlock segment",
        compact = true,
        on_click = function() self:set_segment_boundary() end
      }
    elseif not draft.b then
      actions[#actions + 1] = {
        name = "youtube-mark-segment-end", icon = "flag", label = "Set end",
        tooltip = "Set the end of the SponsorBlock segment",
        on_click = function() self:set_segment_boundary() end
      }
      actions[#actions + 1] = {
        name = "youtube-cancel-segment", icon = "close", label = "",
        tooltip = "Cancel segment", compact = true,
        on_click = function() self:cancel_submission() end
      }
    else
      actions[#actions + 1] = {
        name = "youtube-segment-category", icon = "category",
        label = category_label(draft.category),
        tooltip = "Change segment category",
        on_click = function() self:cycle_submission_category() end
      }
      actions[#actions + 1] = {
        name = "youtube-submit-segment",
        icon = state.submitting and "progress_activity" or "upload",
        label = state.submitting and "Submitting" or "Submit",
        tooltip = "Submit this segment to SponsorBlock",
        enabled = not state.submitting,
        on_click = function() self:submit_segment() end
      }
      actions[#actions + 1] = {
        name = "youtube-cancel-segment", icon = "close", label = "",
        tooltip = "Cancel segment", compact = true,
        on_click = function() self:cancel_submission() end
      }
    end
    return actions
  end

  function service:register_bindings()
    local set_segment = function() self:set_segment_boundary() end
    local submit_segment = function() self:submit_segment() end
    local upvote = function() self:vote(1) end
    local downvote = function() self:vote(0) end
    mp.add_key_binding(nil, "sponsorblock-set-segment", set_segment)
    mp.add_key_binding(nil, "sponsorblock-submit-segment", submit_segment)
    mp.add_key_binding(nil, "sponsorblock-upvote", upvote)
    mp.add_key_binding(nil, "sponsorblock-downvote", downvote)
    mp.add_key_binding(nil, "sponsorblock-skip",
      function() self:skip_prompt() end)
    -- Familiar aliases for users coming from po5/mpv_sponsorblock.
    mp.add_key_binding(nil, "set_segment", set_segment)
    mp.add_key_binding(nil, "submit_segment", submit_segment)
    mp.add_key_binding(nil, "upvote_segment", upvote)
    mp.add_key_binding(nil, "downvote_segment", downvote)
  end

  function service:dispose()
    self.request_id = self.request_id + 1
    clear_feedback_timer()
    for operation in pairs(self.command_ids) do
      operation:cancel()
    end
    self.command_ids = {}
  end

  return service
end

sponsorblock.youtube_id_from_url = youtube_id_from_url
sponsorblock.category_label = category_label
sponsorblock.category_style = category_style

return sponsorblock
