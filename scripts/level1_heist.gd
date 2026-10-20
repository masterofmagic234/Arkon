extends Node3D
# Owns the heist, perception and local commands. Existing campaign facts,
# pickups, physical doors, combat and the exit trigger retain their owners.
const Data = preload("res://scripts/level_data.gd")
const HeistData = preload("res://scripts/level1_heist_data.gd")
const Device = preload("res://scripts/level1_heist_device.gd")
const Sight = preload("res://scripts/squirrel_queries.gd")
const INTERACTION_REACH := 2.65
const ESCAPE_BONUS_TIME := 65.0
var game: Node3D
var devices: Array[Node3D] = []
var guards: Array[Node3D] = []
var focus: Node3D
var action: Node3D
var action_progress := 0.0
var action_duration := 1.0
var action_hp := 100
var alarm := 0.0
var peak_alarm := 0.0
var alert_raised := false
var last_noise := -20.0
var clock := 0.0
var tick := 0.0
var radio_cooldown := 0.0
var moon_solved := false
var gallery_disabled := false
var oak_open := false
var escape_started := false
var escape_elapsed := 0.0
var run_elapsed := 0.0
var shots := 0
var notes_found := 0
var distractions := 0
var damage_taken := 0
var discovered_notes: Dictionary = {}
var locked_acorns: Dictionary = {}
var cages: Dictionary = {}
var scanners: Array[Node3D] = []
var scan_exposure := 0.0
var scanner_heading: Array[float] = [0.0, 0.0]
var ui: Control

func setup(owner_: Node3D) -> void:
    game = owner_
    game.player.heist = self
    for enemy in get_tree().get_nodes_in_group("level1_enemy"):
        enemy.heist = self
        guards.append(enemy)
    for id in ["Acorn03","Acorn04","Acorn06"]:
        var acorn := game.get_node(id) as Node3D
        acorn.set_meta("heist_locked",true)
        locked_acorns[id] = acorn
    for spec: Dictionary in HeistData.DEVICES:
        var device := Device.new()
        device.name = spec.id
        device.kind = spec.kind
        device.index = spec.index
        device.position = Data.cell_center_world(spec.cell)
        add_child(device)
        devices.append(device)
    preload("res://scripts/level1_heist_art.gd").new().build(self)
    ui = preload("res://scripts/level1_heist_hud.gd").new()
    ui.name = "HeistHUD"
    ui.director = self
    game.get_node("HUD").add_child(ui)
    SignalBus.audio_event.connect(_on_audio)
    SignalBus.entity_damaged.connect(_on_damage)
    SignalBus.item_collected.connect(_on_pickup)

func _exit_tree() -> void:
    if SignalBus.audio_event.is_connected(_on_audio): SignalBus.audio_event.disconnect(_on_audio)
    if SignalBus.entity_damaged.is_connected(_on_damage): SignalBus.entity_damaged.disconnect(_on_damage)
    if SignalBus.item_collected.is_connected(_on_pickup): SignalBus.item_collected.disconnect(_on_pickup)

func available() -> bool:
    return is_instance_valid(game) and not game.mission_failed and not game.mission_complete and game.player.input_enabled and not PauseManager.is_paused

func _physics_process(delta: float) -> void:
    if not available():
        focus = null
        action = null
        if is_instance_valid(ui): ui.visible = false
        return
    clock += delta
    run_elapsed += delta
    radio_cooldown = maxf(0.0,radio_cooldown-delta)
    if escape_started: escape_elapsed += delta
    for device in devices: device.cooldown = maxf(0.0,device.cooldown-delta)
    _update_action(delta)
    tick -= delta
    if tick > 0.0: return
    tick = .10
    focus = find_focus()
    _update_scanners(.10)
    if not escape_started and clock-last_noise>4.0: alarm = maxf(0.0,alarm-.65)
    peak_alarm = maxf(peak_alarm,alarm)
    if alarm>=70.0 and not alert_raised:
        alert_raised = true
        _radio("ДОЗОР: «Чужая в парке! Проверить дорожки!»",3.0)
        SignalBus.emit_audio_event(&"heist_alarm",game.player.global_position)
        _call_guards(game.player.global_position,24.0)
    elif alarm<25.0: alert_raised = false

func find_focus() -> Node3D:
    if not available(): return null
    var best: Node3D
    var best_distance := INTERACTION_REACH
    var eye: Vector3 = game.camera.global_position
    for device in devices:
        if device.used or (device.kind=="dial" and moon_solved): continue
        var at := interaction_point(device)
        var distance: float = game.player.global_position.distance_to(at)
        if distance>=best_distance: continue
        if (-game.camera.global_basis.z).dot((at-eye).normalized()) < .55: continue
        if not Sight.visible_from(eye,at,game.player.get_world_3d(),Data.WORLD_LAYER): continue
        best = device
        best_distance = distance
    return best

func interaction_point(device: Node3D) -> Vector3:
    # Above the prop's physical housing; the ray must not hit the mechanism
    # itself while still rejecting scenery between the player and the panel.
    return device.global_position+Vector3.UP*(1.95 if device.kind=="bell" else 1.5)

func request_interact() -> bool:
    if not available(): return false
    if is_instance_valid(action):
        _cancel_action()
        return false
    focus = find_focus()
    if not is_instance_valid(focus): return false
    match focus.kind:
        "dial":
            focus.value = (focus.value+1)%3
            focus.title.text = focus.description()
            if focus.dial:
                var tween := create_tween()
                tween.tween_property(focus.dial,"rotation:y",float(focus.value)*TAU/3.0,.22)
            SignalBus.emit_audio_event(&"heist_dial",focus.global_position)
            _check_moon()
        "relay", "seal":
            if focus.kind=="seal" and game.doors_opened.size()<3: return false
            action = focus
            action_progress = 0.0
            action_duration = 2.0 if focus.kind=="relay" else 3.0
            action_hp = game.player.get_hp()
        "bell":
            if focus.cooldown>0: return false
            focus.cooldown = 12.0
            distractions += 1
            # The bell is a false sound source. It never informs the guards
            # of the player's position or adds alarm on its own.
            _call_guards(focus.global_position,22.0)
            SignalBus.emit_audio_event(&"heist_bell",focus.global_position)
            SignalBus.show_message.emit("Дозор идёт на звон. Обходи с другой стороны.",2.7)
        "note":
            focus.used = true
            notes_found += 1
            discovered_notes[focus.index] = true
            focus.title.text = "ЗАПИСКА ПРОЧИТАНА"
            SignalBus.show_message.emit(HeistData.NOTES[focus.index],7.5)
            SignalBus.emit_audio_event(&"heist_solved",focus.global_position)
    return true

func _update_action(delta: float) -> void:
    if not is_instance_valid(action): return
    var at := interaction_point(action)
    if game.player.global_position.distance_to(at)>INTERACTION_REACH or game.player.dash_time>0 or game.player.get_hp()<action_hp or not Sight.visible_from(game.camera.global_position,at,game.player.get_world_3d(),Data.WORLD_LAYER):
        _cancel_action()
        return
    action_progress += delta
    if action_progress < action_duration: return
    var completed := action
    action = null
    completed.used = true
    if completed.kind=="relay":
        gallery_disabled = true
        alarm = maxf(0.0,alarm-35.0)
        _unlock("Acorn04")
        completed.title.text = "ЛУЧИ ОТКЛЮЧЕНЫ"
        SignalBus.show_message.emit("Галерея погасла. Дозорные лучи отключены, витрина открыта.",4.0)
    else:
        oak_open = true
        _unlock("Acorn06")
        completed.title.text = "ПЕЧАТЬ СНЯТА"
        SignalBus.show_message.emit("Печать снята. Забирай реликвию, но следи за гонцом!",4.0)
    SignalBus.emit_audio_event(&"heist_solved",completed.global_position)

func _cancel_action() -> void:
    action = null
    action_progress = 0.0
    SignalBus.show_message.emit("Действие прервано. Подойди и попробуй снова.",1.8)

func _check_moon() -> void:
    for i in range(3):
        if devices[i].value!=HeistData.DIAL_TARGET[i]: return
    moon_solved = true
    for i in range(3): devices[i].title.text = ["ЛУНА","ЛИСТ","ЛУНА"][i]+" · СОГЛАСОВАНО"
    _unlock("Acorn03")
    SignalBus.emit_audio_event(&"heist_solved",devices[1].global_position)
    SignalBus.show_message.emit("Лунный механизм ожил. Жёлудь у павильона освобождён!",4.0)

func _unlock(id: String) -> void:
    var acorn := locked_acorns.get(id) as Node3D
    if is_instance_valid(acorn): acorn.remove_meta("heist_locked")
    if cages.has(id): cages[id].visible = false

func _on_pickup(kind: StringName, id: StringName, _amount: int, collector: Node) -> void:
    if collector!=game.player or kind!=&"acorn": return
    if id==&"Acorn06":
        make_noise(game.player.global_position,28.0,35.0)
        SignalBus.emit_audio_event(&"heist_alarm",game.player.global_position)

func begin_escape() -> void:
    if escape_started: return
    escape_started = true
    escape_elapsed = 0.0
    alarm = maxf(alarm,75.0)
    _call_guards(game.player.global_position,30.0)
    SignalBus.show_message.emit("ДОЗОР: «Она взяла реликвию!» Машина у ВХОДА. Побег за 65 секунд даст бонус.",6.0)

func make_noise(at: Vector3, radius: float, amount: float) -> void:
    if not available(): return
    last_noise = clock
    alarm = clampf(alarm+amount,0.0,100.0)
    _call_guards(at,radius)

func _call_guards(at: Vector3, radius: float) -> void:
    for guard in guards:
        if not is_instance_valid(guard) or guard.defeated or not guard.is_physics_processing(): continue
        if guard.global_position.distance_to(at)>radius: continue
        # A sound attracts a local patrol; it cannot order a guard through a
        # closed gate into another sector.
        if Data.episode_at(guard.global_position)!=Data.episode_at(at): continue
        guard.investigate_noise(at,7.0)

func guard_can_see(guard: Node3D, clear: bool, distance: float, dt: float) -> bool:
    if not available(): return false
    var player: Node3D = game.player
    var quiet: bool = player.quiet_mode and player.dash_time<=0
    var radius := (5.0 if quiet else 12.0)
    if quiet and not Data.on_gravel(player.global_position): radius = 3.6
    # Facing matters at a distance. Close contact and a remembered pursuit
    # remain dangerous, so crouching cannot erase an ongoing attack.
    var toward: Vector3 = guard.global_position.direction_to(player.global_position)
    var facing: Vector3 = guard.squirrel_3d_visual.global_basis.z.normalized()
    var in_view: bool = distance<2.2 or facing.dot(toward)>.20 or guard.suspicion>=.95
    var detected: bool = clear and distance<radius and in_view
    guard.suspicion = clampf(guard.suspicion+dt*(1.8 if detected else -1.0),0.0,1.0)
    if detected and guard.suspicion>=.95:
        alarm = minf(100.0,alarm+dt*3.0)
        last_noise = clock
        return true
    return false

func _on_audio(kind: StringName, at: Vector3) -> void:
    if not available(): return
    if kind==&"shoot":
        shots += 1
        make_noise(at,24.0,7.0)
        if action: _cancel_action()
    elif kind==&"footstep":
        var quiet: bool = game.player.quiet_mode
        if quiet and not Data.on_gravel(at): return
        _call_guards(at,2.8 if quiet else 6.0)

func _on_damage(entity: Node, amount: int, _source: Node) -> void:
    if entity==game.player: damage_taken += amount

func _update_scanners(dt: float) -> void:
    if scanners.is_empty(): return
    var caught := false
    for i in range(scanners.size()):
        var active_: bool = not gallery_disabled and game.doors_opened.has(&"Door02")
        scanners[i].visible = active_
        if not active_: continue
        var yaw := PI*.5+sin(clock*.48+float(i)*2.1)*1.18
        scanner_heading[i] = yaw
        scanners[i].rotation.y = yaw
        var origin: Vector3 = scanners[i].global_position
        var offset: Vector3 = game.player.global_position-origin
        offset.y = 0.0
        if offset.length()>9.0 or offset.length()<.2: continue
        var facing := Basis(Vector3.UP,yaw)*Vector3.FORWARD
        if facing.dot(offset.normalized())<cos(.25): continue
        if not Sight.visible_from(origin+Vector3.UP*2.8,game.player.global_position+Vector3.UP*.35,game.player.get_world_3d(),Data.WORLD_LAYER): continue
        caught = true
    scan_exposure = clampf(scan_exposure+dt*(1.0 if caught else -2.0),0.0,1.4)
    if caught and scan_exposure>=.8:
        make_noise(game.player.global_position,20.0,dt*17.0)
        _radio("ДОЗОР: «В луче движение! Рубильник за галереей, если успеешь». ",3.6)

func _radio(line: String, duration: float) -> void:
    if radio_cooldown>0: return
    radio_cooldown = 9.0
    SignalBus.show_message.emit(line,duration)

func objective() -> String:
    if escape_started: return "ПОБЕГ · машина у входа · %d м" % roundi(game.player.global_position.distance_to(game.exit_car.global_position))
    if not moon_solved and game.episode==1: return "ЛИНЗЫ У ПАВИЛЬОНА · ЛУНА / ЛИСТ / ЛУНА"
    if not gallery_disabled and game.episode==2: return "ОТКЛЮЧИ ЛУЧИ · рубильник за восточной галереей"
    if not oak_open and game.episode==3: return "СНИМИ ПЕЧАТЬ · тумба у легендарного дуба"
    return "НОЧНАЯ ВЫЛАЗКА · шесть жёлудей и три ключа"

func result_line() -> String:
    var rank := "ПРИЗРАК ПАРКА" if peak_alarm<45 and shots<5 else "ОРЕХОВЫЙ ПРОФЕССИОНАЛ"
    if damage_taken==0 and shots>=5: rank = "ЧИСТАЯ РАБОТА"
    var score := 1200+notes_found*150+mini(distractions,4)*50+maxi(0,300-damage_taken*3)
    if escape_started and escape_elapsed<=ESCAPE_BONUS_TIME: score += 400
    return "%s · %d очков · %d:%02d · записки %d/3" % [rank,score,int(run_elapsed)/60,int(run_elapsed)%60,notes_found]
