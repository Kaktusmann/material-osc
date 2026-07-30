local indicator = {}

local STEP_MS = 650
local FULL_ROTATION_MS = 4666
local QUARTER_ROTATION = 90
local TOTAL_POINTS = 144
local REST_SHAPE_INDEX = 6
local SETTLE_MS = 360
local MINIMUM_SETTLE_ROTATION = 60
local ROTATION_SPRING_STIFFNESS = 400
local ROTATION_SPRING_DAMPING = 0.7

local function shape(points, outer_radius, inner_radius, outer_roundness, inner_roundness)
  return {
    points = points,
    outer_radius = outer_radius,
    inner_radius = inner_radius,
    outer_roundness = outer_roundness,
    inner_roundness = inner_roundness
  }
end

local SEQUENCE = {
  shape(10, 0.85, 0.67, 0.75, 0.5),
  shape(9, 0.85, 0.755, 0.8, 0.5),
  shape(5, 0.85, 0.731, 0.45, 1),
  shape(2, 0.85, 0.67, 0.8, 0.95),
  shape(8, 0.85, 0.731, 0.6, 0.45),
  shape(4, 0.875, 0.635, 1, 0.4),
  shape(2, 0.85, 0.535, 0.8, 0.6)
}

local function lerp(a, b, t) return a + (b - a) * t end
local function distance(a, b) return math.sqrt((a.x - b.x)^2 + (a.y - b.y)^2) end
local function normalize(x, y)
  local length = math.sqrt(x * x + y * y)
  return length < 1e-6 and {x = 1, y = 0} or {x = x / length, y = y / length}
end
local function smoothstep(p) return p * p * (3 - 2 * p) end
local function out_cubic(p) return 1 - (1 - p)^3 end

local function spring_value(ms, stiffness, damping)
  local t = ms / 1000
  stiffness, damping = stiffness or 200, damping or 0.6
  local omega0 = math.sqrt(stiffness)
  local omega_d = omega0 * math.sqrt(1 - damping * damping)
  local displacement = math.exp(-damping * omega0 * t) *
    (-math.cos(omega_d * t) - damping * omega0 / omega_d * math.sin(omega_d * t))
  return 1 + displacement
end

local function spring_progress(ms)
  return math.max(0, math.min(1, spring_value(ms)))
end

local function scale_pulse(ms)
  local t = ms / STEP_MS
  for _, segment in ipairs({
    {0, 0.14, 1, 0.985, smoothstep},
    {0.14, 0.46, 0.985, 1.04, out_cubic},
    {0.46, 0.76, 1.04, 1, smoothstep}
  }) do
    local start_at, finish_at, from, to, ease =
      segment[1], segment[2], segment[3], segment[4], segment[5]
    if t >= start_at and t < finish_at then
      return lerp(from, to, ease((t - start_at) / (finish_at - start_at)))
    end
  end
  return 1
end

local function star_geometry(shape)
  local point_count = shape.points
  local count, anchors = point_count * 2, {}
  for i = 0, count - 1 do
    local outer = i % 2 == 0
    local radius = (outer and shape.outer_radius or shape.inner_radius) * 0.5
    local angle = i * math.pi / point_count
    anchors[#anchors + 1] = {x = math.cos(angle) * radius, y = math.sin(angle) * radius, outer = outer}
  end

  local tangents, lengths, handles = {}, {}, {}
  for i, anchor in ipairs(anchors) do
    local previous, next_anchor = anchors[(i - 2 + count) % count + 1], anchors[i % count + 1]
    tangents[i] = normalize(next_anchor.x - previous.x, next_anchor.y - previous.y)
    local roundness = anchor.outer and shape.outer_roundness or shape.inner_roundness
    lengths[i] = math.max(0, roundness) * math.min(distance(anchor, previous), distance(anchor, next_anchor)) * 0.5
  end
  for i, anchor in ipairs(anchors) do
    local tangent, length = tangents[i], lengths[i]
    handles[i] = {
      incoming = {x = anchor.x - tangent.x * length, y = anchor.y - tangent.y * length},
      outgoing = {x = anchor.x + tangent.x * length, y = anchor.y + tangent.y * length}
    }
  end
  return anchors, handles
end

local function cubic(p0, c1, c2, p1, t)
  local inverse = 1 - t
  return {
    x = inverse^3 * p0.x + 3 * inverse^2 * t * c1.x + 3 * inverse * t^2 * c2.x + t^3 * p1.x,
    y = inverse^3 * p0.y + 3 * inverse^2 * t * c1.y + 3 * inverse * t^2 * c2.y + t^3 * p1.y
  }
end

local function resample(points)
  local lengths, perimeter = {}, 0
  for i, point in ipairs(points) do
    lengths[i] = distance(point, points[i % #points + 1])
    perimeter = perimeter + lengths[i]
  end
  local sampled, edge, consumed = {}, 1, 0
  for i = 0, TOTAL_POINTS - 1 do
    local target = perimeter * i / TOTAL_POINTS
    while edge < #lengths and consumed + lengths[edge] < target do
      consumed, edge = consumed + lengths[edge], edge + 1
    end
    local point, next_point = points[edge], points[edge % #points + 1]
    local progress = (target - consumed) / (lengths[edge] ~= 0 and lengths[edge] or 1)
    sampled[#sampled + 1] = {x = lerp(point.x, next_point.x, progress), y = lerp(point.y, next_point.y, progress)}
  end
  return sampled
end

local function sample_shape(shape)
  local anchors, handles = star_geometry(shape)
  local dense = {}
  for i, anchor in ipairs(anchors) do
    local next_i = i % #anchors + 1
    for step = 0, 17 do
      dense[#dense + 1] = cubic(anchor, handles[i].outgoing, handles[next_i].incoming, anchors[next_i], step / 18)
    end
  end
  return resample(dense)
end

local function align_to(from, target)
  local best_offset, best_score = 0, math.huge
  for offset = 0, #target - 1 do
    local score = 0
    for i = 1, #from, 4 do
      local point = target[(i + offset - 1) % #target + 1]
      score = score + (from[i].x - point.x)^2 + (from[i].y - point.y)^2
    end
    if score < best_score then best_offset, best_score = offset, score end
  end
  local aligned = {}
  for i = 1, #target do aligned[i] = target[(i + best_offset - 1) % #target + 1] end
  return aligned
end

local shapes = {}
for _, definition in ipairs(SEQUENCE) do
  local shape = sample_shape(definition)
  shapes[#shapes + 1] = #shapes > 0 and align_to(shapes[#shapes], shape) or shape
end

local function animation_frame(elapsed, first_shape)
  elapsed = math.max(0, elapsed or 0)
  local step, morph_elapsed = math.floor(elapsed / STEP_MS),
    elapsed % STEP_MS
  local shape_step = step + (first_shape or 1) - 1
  local progress = spring_progress(morph_elapsed)
  return {
    from = shapes[shape_step % #shapes + 1],
    target = shapes[(shape_step + 1) % #shapes + 1],
    progress = progress,
    pulse = scale_pulse(morph_elapsed),
    rotation = (step * QUARTER_ROTATION + progress * QUARTER_ROTATION +
      (elapsed % FULL_ROTATION_MS) / FULL_ROTATION_MS * 360) *
      math.pi / 180
  }
end

local function rest_frame()
  return {
    from = shapes[REST_SHAPE_INDEX],
    target = shapes[REST_SHAPE_INDEX],
    progress = 0,
    pulse = 1,
    rotation = 0
  }
end

local function point_at(frame, index)
  local from, target = frame.from[index], frame.target[index]
  local progress, pulse = frame.progress or 0, frame.pulse or 1
  return lerp(from.x, target.x, progress) * pulse,
    lerp(from.y, target.y, progress) * pulse
end

local function sample_frame(frame)
  local points = {}
  for index = 1, TOTAL_POINTS do
    local x, y = point_at(frame, index)
    points[index] = {x = x, y = y}
  end
  return points
end

function indicator.draw_frame(ass, args)
  local frame, size = args.frame or rest_frame(), args.size
  local cx, cy = size / 2, size / 2
  local cos_r, sin_r = math.cos(frame.rotation), math.sin(frame.rotation)

  ass:new_event()
  ass:pos(args.center_x - size / 2, args.center_y - size / 2)
  ass:an(7)
  ass:append(string.format(
    "{\\1c&H%s&\\1a&H%s&\\bord0\\shad0}", args.color, args.alpha))
  ass:draw_start()
  local first_x, first_y
  for index = 1, TOTAL_POINTS do
    local x, y = point_at(frame, index)
    x, y = x * size, y * size
    local rx, ry =
      cx + x * cos_r - y * sin_r, cy + x * sin_r + y * cos_r
    if index == 1 then
      first_x, first_y = rx, ry
      ass:move_to(rx, ry)
    else
      ass:line_to(rx, ry)
    end
  end
  if first_x then ass:line_to(first_x, first_y) end
  ass:draw_stop()
end

function indicator.toggle_animation(args)
  local state = {
    mode = "idle",
    started_ms = 0,
    settle_started_ms = 0,
    settle_from = nil,
    settle_rotation = 0
  }
  local service = {}

  local function now_ms()
    return args.now_ms and args.now_ms() or mp.get_time() * 1000
  end

  function service:frame(now)
    now = now or now_ms()
    if state.mode == "running" then
      return animation_frame(now - state.started_ms, REST_SHAPE_INDEX)
    end
    if state.mode == "settling" then
      local elapsed = math.max(0, now - state.settle_started_ms)
      if elapsed >= SETTLE_MS then
        state.mode, state.settle_from = "idle", nil
        return rest_frame()
      end
      local progress = spring_progress(elapsed)
      local rotation_progress = spring_value(
        elapsed, ROTATION_SPRING_STIFFNESS, ROTATION_SPRING_DAMPING)
      return {
        from = state.settle_from,
        target = shapes[REST_SHAPE_INDEX],
        progress = progress,
        pulse = 1,
        rotation = lerp(
          state.settle_rotation, state.settle_target_rotation,
          rotation_progress)
      }
    end
    return rest_frame()
  end

  function service:toggle()
    local now = now_ms()
    if state.mode == "running" then
      local frame = self:frame(now)
      state.mode = "settling"
      state.settle_started_ms = now
      state.settle_from = sample_frame(frame)
      state.settle_rotation = frame.rotation
      local quarter = math.pi / 2
      local minimum_rotation = math.rad(MINIMUM_SETTLE_ROTATION)
      state.settle_target_rotation =
        math.ceil((frame.rotation + minimum_rotation) / quarter) * quarter
      return false
    end
    if state.mode == "settling" then return false end
    state.mode = "running"
    state.started_ms = now
    state.settle_from = nil
    return true
  end

  function service:is_running()
    return state.mode ~= "idle"
  end

  return service
end

function indicator.new(args)
  return function(ass, center_x, center_y, requested_size)
    local elapsed = mp.get_time() * 1000 - args.started_ms()
    local size = requested_size or args.dp(72)
    center_x, center_y = center_x or args.viewport().w / 2,
      center_y or args.viewport().h / 2
    indicator.draw_frame(ass, {
      center_x = center_x,
      center_y = center_y,
      size = size,
      color = args.color(),
      alpha = args.alpha(0.95),
      frame = animation_frame(elapsed)
    })
  end
end

return indicator
