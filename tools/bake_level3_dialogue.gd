extends SceneTree
## Technical atlas compilation only. Source art is made by ImageGen.
## Crop the authored 4x2 grid, nearest-sample to 96px, share a 32-colour palette.

const SIZE := 96
var root_path: String

func _init() -> void:
    root_path = ProjectSettings.globalize_path("res://")
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--project-root="): root_path = arg.trim_prefix("--project-root=")
    call_deferred("run")

func run() -> void:
    var base := root_path.path_join("assets/level3/dialogue")
    var main := Image.load_from_file(base.path_join("source/talking-portraits.png"))
    var shocked := Image.load_from_file(base.path_join("source/shocked-cook.png"))
    if main == null or shocked == null:
        push_error("DIALOGUE BAKE: missing generated source sheets");quit(1);return
    main.convert(Image.FORMAT_RGBA8)
    shocked.convert(Image.FORMAT_RGBA8)
    var strips: Dictionary = {}
    var hist: Dictionary = {}
    for item in [["carolina", main, 0], ["chef", main, 1], ["chef_shocked", shocked, 0]]:
        var strip := Image.create(SIZE * 4, SIZE, false, Image.FORMAT_RGBA8)
        var source: Image = item[1]
        for column in range(4):
            var x0 := roundi(column * source.get_width() / 4.0)
            var x1 := roundi((column + 1) * source.get_width() / 4.0)
            var y0 := roundi(int(item[2]) * source.get_height() / 2.0)
            var y1 := roundi((int(item[2]) + 1) * source.get_height() / 2.0)
            var crop := source.get_region(Rect2i(x0, y0, x1 - x0, y1 - y0))
            crop.resize(SIZE, SIZE, Image.INTERPOLATE_NEAREST)
            strip.blit_rect(crop, Rect2i(0, 0, SIZE, SIZE), Vector2i(column * SIZE, 0))
        for y in range(SIZE):
            for x in range(SIZE * 4):
                var color := strip.get_pixel(x, y)
                var key := (roundi(color.r * 31) << 10) | (roundi(color.g * 31) << 5) | roundi(color.b * 31)
                hist[key] = int(hist.get(key, 0)) + 1
        strips[item[0]] = strip
    var bins: Array = [hist.keys()]
    while bins.size() < 32:
        var selected := -1
        var best_range := -1
        var axis := 0
        for index in range(bins.size()):
            if bins[index].size() < 2: continue
            for channel in range(3):
                var low := 31;var high := 0
                for key in bins[index]:
                    var value := component(key, channel)
                    low = mini(low, value);high = maxi(high, value)
                if high - low > best_range:
                    selected = index;best_range = high - low;axis = channel
        if selected < 0: break
        var values: Array = bins.pop_at(selected)
        values.sort_custom(func(a, b):
            var ca := component(a, axis);var cb := component(b, axis)
            return ca < cb if ca != cb else a < b)
        var weight := 0
        for key in values: weight += int(hist[key])
        var running := 0;var cut := 1
        for index in range(values.size() - 1):
            running += int(hist[values[index]])
            cut = index + 1
            if running >= weight / 2: break
        bins.append(values.slice(0, cut));bins.append(values.slice(cut))
    var palette: Array[Color] = []
    for values in bins:
        var sum := Vector3.ZERO;var weight := 0
        for key in values:
            var count := int(hist[key]);weight += count
            sum += Vector3(component(key, 0), component(key, 1), component(key, 2)) * count
        sum /= maxf(weight, 1) * 31.0
        palette.append(Color(sum.x, sum.y, sum.z, 1))
    var lookup: Dictionary = {}
    for key in hist:
        var value := Vector3(component(key, 0), component(key, 1), component(key, 2)) / 31.0
        var nearest := palette[0];var distance := INF
        for color in palette:
            var next := value.distance_squared_to(Vector3(color.r, color.g, color.b))
            if next < distance: nearest = color;distance = next
        lookup[key] = nearest
    for key in strips:
        var strip: Image = strips[key]
        var colours: Dictionary = {}
        for y in range(SIZE):
            for x in range(SIZE * 4):
                var color := strip.get_pixel(x, y)
                var bin := (roundi(color.r * 31) << 10) | (roundi(color.g * 31) << 5) | roundi(color.b * 31)
                strip.set_pixel(x, y, lookup[bin])
                colours[strip.get_pixel(x, y).to_rgba32()] = true
        if colours.size() < 16 or colours.size() > 32:
            push_error("DIALOGUE BAKE: blank or unquantized strip " + key);quit(1);return
        if strip.save_png(base.path_join(key + ".png")) != OK:
            push_error("DIALOGUE BAKE: cannot save " + key);quit(1);return
    print("DIALOGUE BAKE: PASS — 3 strips, 12 poses, 96px, shared32colour palette")
    quit(0)

func component(value: int, channel: int) -> int:
    return (value >> ((2 - channel) * 5)) & 31
