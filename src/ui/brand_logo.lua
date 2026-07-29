local brand_logo = {}

function brand_logo.new(args)
  return function(ass, center_x, center_y, requested_size, alpha,
      ignore_controller_fade)
    local size = requested_size or 128
    local scale = size / 128
    local origin_x, origin_y = center_x - size / 2, center_y - size / 2
    local rendered_alpha = ignore_controller_fade and (alpha or "00") or
      args.fade_alpha(alpha)

    local function begin_shape(color)
      ass:new_event()
      ass:pos(origin_x, origin_y)
      ass:an(7)
      ass:append(string.format(
        "{\\1c&H%s&\\1a&H%s&\\bord0\\shad0}",
        args.ass_color(color), rendered_alpha))
      ass:draw_start()
    end
    local function point(value) return value * scale end
    local function move(x, y) ass:move_to(point(x), point(y)) end
    local function line(x, y) ass:line_to(point(x), point(y)) end
    local function curve(x1, y1, x2, y2, x3, y3)
      ass:bezier_curve(point(x1), point(y1), point(x2), point(y2),
        point(x3), point(y3))
    end

    begin_shape("#0A0C15")
    move(72.124, 19.208); line(79.373, 17.085)
    curve(99.146, 11.294, 117.504, 29.652, 111.713, 49.425)
    line(109.590, 56.674)
    curve(108.189, 61.458, 108.189, 66.543, 109.590, 71.327)
    line(111.713, 78.576)
    curve(117.504, 98.349, 99.146, 116.707, 79.373, 110.916)
    line(72.124, 108.793)
    curve(67.340, 107.392, 62.255, 107.392, 57.471, 108.793)
    line(50.222, 110.916)
    curve(30.449, 116.707, 12.091, 98.349, 17.882, 78.576)
    line(20.005, 71.327)
    curve(21.406, 66.543, 21.406, 61.458, 20.005, 56.674)
    line(17.882, 49.425)
    curve(12.091, 29.652, 30.449, 11.294, 50.222, 17.085)
    line(57.471, 19.208)
    curve(62.255, 20.609, 67.340, 20.609, 72.124, 19.208)
    ass:draw_stop()

    begin_shape("#42B6E9")
    move(100.160000, 38.919509); line(106.433850, 42.351180)
    curve(123.548110, 51.711102, 123.548110, 76.290798,
      106.433850, 85.650719)
    line(100.160000, 89.082392)
    curve(96.020032, 91.346772, 92.615362, 94.751444,
      90.350986, 98.891409)
    line(86.919315, 105.165260)
    curve(77.559393, 122.279510, 52.979697, 122.279510,
      43.619775, 105.165260)
    line(40.188103, 98.891409)
    curve(37.923722, 94.751444, 34.519051, 91.346772,
      30.379085, 89.082392)
    line(24.105237, 85.650719)
    curve(6.990980, 76.290798, 6.990980, 51.711102,
      24.105237, 42.351180)
    line(30.379085, 38.919509)
    curve(34.519051, 36.655127, 37.923722, 33.250455,
      40.188103, 29.110490)
    line(43.619775, 22.836642)
    curve(52.979697, 5.722385, 77.559393, 5.722385,
      86.919315, 22.836642)
    line(90.350986, 29.110490)
    curve(92.615362, 33.250455, 96.020032, 36.655127,
      100.160000, 38.919509)
    ass:draw_stop()

    begin_shape("#0A0C15")
    move(64.797499, 96.400230); line(64.797499, 96.400230)
    curve(46.903847, 96.400230, 32.397768, 81.894151,
      32.397768, 64.000500)
    line(32.397768, 64.000500)
    curve(32.397768, 46.106848, 46.903847, 31.600769,
      64.797499, 31.600769)
    line(64.797499, 31.600769)
    curve(82.691150, 31.600769, 97.197232, 46.106848,
      97.197232, 64.000500)
    line(97.197232, 64.000500)
    curve(97.197232, 81.894151, 82.691150, 96.400230,
      64.797499, 96.400230)
    ass:draw_stop()

    local group_scale, group_x, group_y =
      0.89999252, 6.095888, 6.4014271
    local function transformed_x(value)
      return (value * group_scale + group_x) * scale
    end
    local function transformed_y(value)
      return (value * group_scale + group_y) * scale
    end
    local function transformed_move(x, y)
      ass:move_to(transformed_x(x), transformed_y(y))
    end
    local function transformed_line(x, y)
      ass:line_to(transformed_x(x), transformed_y(y))
    end
    local function transformed_curve(x1, y1, x2, y2, x3, y3)
      ass:bezier_curve(
        transformed_x(x1), transformed_y(y1),
        transformed_x(x2), transformed_y(y2),
        transformed_x(x3), transformed_y(y3))
    end

    begin_shape("#FFFFFF")
    transformed_move(54.239, 43.088)
    transformed_curve(52.478, 43.088, 50.862, 44.497, 50.862, 46.465)
    transformed_line(50.862, 64.000)
    transformed_line(50.862, 81.535)
    transformed_curve(50.862, 83.504, 52.478, 84.912, 54.239, 84.912)
    transformed_curve(54.800, 84.912, 55.377, 84.769, 55.920, 84.455)
    transformed_line(71.106, 75.687)
    transformed_line(86.292, 66.919)
    transformed_curve(88.540, 65.621, 88.540, 62.376, 86.292, 61.078)
    transformed_line(71.106, 52.310)
    transformed_line(55.920, 43.544)
    transformed_curve(55.376, 43.231, 54.800, 43.088, 54.239, 43.088)
    ass:draw_stop()

    begin_shape("#0A0C15")
    transformed_move(58.861, 54.481)
    transformed_line(67.105, 59.241)
    transformed_line(75.350, 64.000)
    transformed_line(67.106, 68.760)
    transformed_line(58.862, 73.520)
    transformed_line(58.862, 64.000)
    transformed_line(58.861, 54.481)
    ass:draw_stop()
  end
end

return brand_logo
