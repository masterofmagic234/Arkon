extends SceneTree
## Isolated save/migration fixtures. Scene/input progression is tested separately.
const State=preload("res://scripts/botanical_state.gd")
var failures: Array[String]=[]
var cases: Array[String]=[]
var output:=""
var original_save: PackedByteArray
var original_tmp: PackedByteArray
var had_save:=false
var had_tmp:=false

func _init() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
    call_deferred("run")

func check(ok: bool,why: String) -> void:
    if not ok:failures.append(why);push_error("BOTANICAL STATE149: "+why)

func fixture(raw: Variant):
    var file=FileAccess.open(State.PATH,FileAccess.WRITE)
    check(file!=null,"fixture save could not be written")
    if file!=null:file.store_string(JSON.stringify(raw));file.close()
    var state=State.new();state.load_save()
    return state

func chapters(state,last: String) -> bool:
    for id in State.CHAPTERS:
        if not state.encounters_completed.has(id):return false
        if id==last:return true
    return false

func legacy_migration() -> void:
    var unfinished=fixture({"version":1,"guardian":true,"reward":false,"water":true,"seeds":[true,true,true],"mirrors":[1,2],"guide_step":5,"position":[0,7.65,-36],"hp":31,"ammo":2,"defeated":[0,1,2,3,4,5,0]})
    check(not unfinished.guardian and not unfinished.reward and not unfinished.gate_unlatched,"v1 peaceful guardian flag earned a combat victory")
    check(not unfinished.installed and not unfinished.water and unfinished.parts.count(true)==0,"v1 specimens/old water earned the new pump repair")
    check(unfinished.defeated==[0,1,2],"v1 migration lost earned scout IDs or invented guardian/new IDs")
    check(unfinished.position==Vector3(0,7.7,-20) and unfinished.checkpoint_position==unfinished.position,"unfinished v1 save remained inside the newly locked conservatory")
    check(unfinished.hp==31 and unfinished.ammo==2 and unfinished.checkpoint_hp==31 and unfinished.checkpoint_ammo==2,"legacy resume silently refilled low resources")
    check(unfinished.checkpoint_id=="legacy_resume" and unfinished.checkpoint_defeated==[0,1,2],"v1 retry did not inherit its migrated safe checkpoint")
    var completed=fixture({"version":1,"guardian":false,"reward":true,"position":[0,7.65,-36],"defeated":[0,2,3,5],"hp":28,"ammo":1})
    check(completed.reward and completed.guardian and completed.gate_unlatched and completed.installed and completed.water,"v1 earned reward lost its guardian/open latch/powered route")
    check(completed.parts[0] and completed.defeated==[0,2] and chapters(completed,"escape"),"v1 earned reward failed to earn the new chapters or invented new defeats")
    check(completed.position==Vector3(0,7.7,-31.5) and completed.checkpoint_position==completed.position,"earned v1 reward resumed inside the now-solid pedestal")
    check(completed.hp==28 and completed.ammo==1 and completed.checkpoint_hp==28 and completed.checkpoint_ammo==1,"pedestal position repair changed earned legacy resources")
    var partial=fixture({"version":2,"parts":[false,true,false],"installed":false,"gate_unlatched":false,"guardian":false,"reward":false,"defeated":[0,4,5,5,6,-1]})
    check(partial.parts==[false,true,false] and not partial.installed and not partial.water,"v2 partial hardware became an installed pump")
    check(chapters(partial,"pump_repair") and not partial.encounters_completed.has("pump"),"v2 earned partial work was discarded or advanced beyond the repair")
    check(partial.defeated==[0,4,5],"v2 appended scout IDs were lost or out-of-range IDs were accepted")
    var installed=fixture({"version":2,"parts":[true,true,true],"installed":true,"water":false,"valves":[false,true,false],"guardian":false,"reward":false,"defeated":[1,4]})
    check(installed.installed and installed.water and chapters(installed,"pump") and not installed.gate_unlatched,"v2 installed pump still requires obsolete valve chores or earned gallery access")
    var opened=fixture({"version":2,"parts":[true,true,true],"installed":true,"gate_unlatched":true,"guardian":false,"reward":false,"position":[0,7.7,-31],"defeated":[0,1,4,5]})
    check(opened.gate_unlatched and opened.water and chapters(opened,"gallery") and not opened.guardian,"v2 earned open latch was lost or invented a guardian victory")
    var guardian=fixture({"version":2,"guardian":true,"reward":false,"position":[0,7.7,-36],"defeated":[0,3,4,5]})
    check(guardian.guardian and not guardian.reward and guardian.gate_unlatched and guardian.installed and chapters(guardian,"guardian"),"v2 earned combat guardian was lost or acorns were granted early")
    check(guardian.defeated==[0,3,4,5] and not guardian.encounters_completed.has("escape"),"v2 guardian migration lost actor IDs or finished escape before the acorns")
    var reward=fixture({"version":2,"guardian":true,"reward":true,"gate_unlatched":true,"defeated":[0,3,4,5]})
    check(reward.reward and reward.guardian and reward.gate_unlatched and chapters(reward,"escape"),"v2 earned six-acorn reward became locked behind new encounters")
    check(reward.defeated==[0,3,4,5] and reward.checkpoint_defeated==reward.defeated,"completed v2 migration fabricated new actor defeat IDs")
    cases.append("v1/v2 earned facts, partial repairs, stable legacy IDs and safe relocation")

func pedestal_repair() -> void:
    var state=fixture({"version":3,"guardian":true,"reward":true,"position":[0,7.65,-36],"hp":7,"ammo":0,"defeated":[0,3,24],"used_supplies":[1,5],"checkpoint_id":"pump","checkpoint_position":[23,3.7,21],"checkpoint_hp":23,"checkpoint_ammo":4,"checkpoint_defeated":[0,3],"checkpoint_supplies":[1]})
    check(state.position==Vector3(0,7.7,-31.5),"earned v3 position remained inside the physical pedestal")
    check(state.reward and state.guardian and state.gate_unlatched and not state.encounters_completed.has("escape"),"load-only pedestal repair changed earned facts or skipped mandatory escape")
    check(state.hp==7 and state.ammo==0 and state.defeated==[0,3,24] and state.used_supplies==[1,5],"load-only position repair changed current resources or actor/supply facts")
    check(state.checkpoint_position==Vector3(23,3.7,21) and state.checkpoint_id=="pump" and state.checkpoint_hp==23 and state.checkpoint_ammo==4 and state.checkpoint_defeated==[0,3] and state.checkpoint_supplies==[1],"repairing the live position overwrote an independent valid retry snapshot")
    cases.append("v3 pedestal relocation preserves low live resources and independent valid retry snapshot")

func conservatory_access151() -> void:
    var closed=fixture({"version":3,"parts":[true,false,false],"installed":true,"gate_unlatched":false,"encounters_completed":["entry","pump_repair","pump","gallery"],"position":[5,7.7,-27],"hp":19,"ammo":2,"defeated":[0,1,4,10,11,16,17,18],"used_supplies":[1,3],"checkpoint_id":"pump","checkpoint_position":[23,3.7,21],"checkpoint_hp":44,"checkpoint_ammo":9,"checkpoint_defeated":[0,4],"checkpoint_supplies":[1]})
    check(closed.service_key and not closed.gate_unlatched and not closed.guardian_started,"legacy gallery key opened the new lever without an action")
    check(closed.position==Vector3(0,7.7,-20),"legacy bypass save remained locked inside the dormant guardian dome")
    check(closed.hp==19 and closed.ammo==2 and closed.used_supplies==[1,3] and closed.defeated==[0,1,4,10,11,16,17,18],"closed-dome load repair changed live resources or earned actors/supplies")
    check(closed.checkpoint_id=="pump" and closed.checkpoint_position==Vector3(23,3.7,21) and closed.checkpoint_hp==44 and closed.checkpoint_ammo==9 and closed.checkpoint_defeated==[0,4] and closed.checkpoint_supplies==[1],"closed-dome repair overwrote an independent valid retry")
    var vestibule=fixture({"version":3,"position":[1.35,7.7,-22.5],"hp":9,"ammo":1,"checkpoint_position":[0,.7,65]})
    check(vestibule.position==Vector3(0,7.7,-20) and vestibule.hp==9 and vestibule.ammo==1 and vestibule.checkpoint_position==Vector3(0,.7,65),"closed legacy front vestibule save remained trapped behind the new gate or changed resources")
    var exterior=fixture({"version":3,"position":[1.35,7.7,-21.7],"hp":9,"ammo":1})
    check(exterior.position==Vector3(1.35,7.7,-21.7),"safe exterior save was moved by the vestibule repair")
    var opened=fixture({"version":3,"parts":[true,false,false],"installed":true,"gate_unlatched":true,"position":[5,7.7,-27],"hp":19,"ammo":2})
    check(opened.service_key and opened.gate_unlatched and opened.position==Vector3(5,7.7,-27),"legacy earned opening was relocked or relocated")
    opened.guardian_started=true;check(opened.save(),"keyed-gate state save failed")
    var reloaded=State.new();reloaded.load_save()
    check(reloaded.service_key and reloaded.gate_unlatched and reloaded.guardian_started and reloaded.hp==19 and reloaded.ammo==2,"new additive key/lever/guardian facts failed version3 roundtrip")
    var invalid=fixture({"version":3,"service_key":"true","guardian_started":1,"position":[0,.7,65]})
    check(not invalid.service_key and not invalid.guardian_started and not invalid.gate_unlatched,"malformed additive access flags granted a key or battle")
    cases.append("151 additive key/lever facts, legacy locked-dome repair and independent retry preservation")

func current_roundtrip() -> void:
    var ids=[]
    for id in range(25):ids.append(id)
    ids.append(24);ids.append(-1);ids.append(25);ids.append(999)
    var state=fixture({"version":3,"journal":true,"parts":[true,false,false],"installed":true,"gate_unlatched":true,"guardian":true,"reward":true,"position":[0,.7,60],"hp":7,"ammo":0,"defeated":ids,"used_supplies":[0,3,15,15,-1,16],"encounters_completed":["entry","pump_repair","pump","gallery","guardian","grove","pavilion","guardian","unknown",25],"checkpoint_id":"guardian","checkpoint_position":[0,7.7,-31],"checkpoint_hp":23,"checkpoint_ammo":4,"checkpoint_defeated":[0,3,20,24,24,-1,25],"checkpoint_supplies":[1,3,15,15,-1,16]})
    check(state.loaded_version==3 and state.defeated.size()==25 and state.defeated[0]==0 and state.defeated[-1]==24,"v3 stable ID range/dedup discarded new encounter actors")
    check(state.used_supplies==[0,3,15] and state.checkpoint_supplies==[1,3,15],"v3 supply IDs are duplicated or out of range")
    check(state.checkpoint_defeated==[0,3,20,24],"v3 retry IDs did not preserve distinct appended actors")
    check(state.encounters_completed.size()==7 and not state.encounters_completed.has("unknown") and not state.encounters_completed.has("25"),"unknown or duplicate encounter IDs entered the save")
    check(state.reward and state.guardian and state.gate_unlatched and not state.encounters_completed.has("escape"),"new six-acorn pickup bypassed the mandatory escape encounter")
    check(state.hp==7 and state.ammo==0 and state.checkpoint_hp==23 and state.checkpoint_ammo==4,"v3 load refilled ordinary low health/ammo")
    check(state.save(),"v3 roundtrip save failed")
    var raw=JSON.parse_string(FileAccess.get_file_as_string(State.PATH))
    check(raw is Dictionary and int(raw.get("version",0))==3 and int(raw.get("hp",0))==7 and int(raw.get("ammo",-1))==0,"ordinary save did not encode exact live resources and v3")
    check(not FileAccess.file_exists(State.PATH+".tmp"),"successful atomic save left its temporary checkpoint behind")
    var restored=State.new();restored.load_save()
    check(restored.defeated==state.defeated and restored.used_supplies==state.used_supplies and restored.encounters_completed==state.encounters_completed,"v3 save/reload changed earned actor/supply/chapter progress")
    check(restored.hp==7 and restored.ammo==0 and restored.position==state.position and restored.reward,"v3 roundtrip changed low resources, position or earned acorns")
    check(restored.checkpoint_id=="guardian" and restored.checkpoint_position==Vector3(0,7.7,-31) and restored.checkpoint_hp==23 and restored.checkpoint_ammo==4,"v3 roundtrip changed the retry checkpoint")
    cases.append("v3 appended IDs, chapter allowlist, exact resources, atomic save and mandatory escape")

func checkpoint_rollback() -> void:
    var state=State.new();state.hp=63;state.ammo=17
    state.defeated.assign([0,6,7,8,9]);state.used_supplies.assign([0,2]);state.encounters_completed.assign(["entry","pump_repair"])
    state.journal=true;state.parts[0]=true
    state.capture_checkpoint("pump_repair",Vector3(26,3.7,8))
    state.hp=9;state.ammo=1;state.position=Vector3(15,3.7,20)
    state.defeated.append(12);state.used_supplies.append(3)
    state.encounters_completed.append("pump");state.installed=true;state.water=true
    check(state.checkpoint_defeated==[0,6,7,8,9] and state.checkpoint_supplies==[0,2],"checkpoint arrays alias later combat/supply mutations")
    state.restore_checkpoint()
    check(state.hp==63 and state.ammo==17 and state.position==Vector3(26,3.7,8),"retry restored live resources/position instead of its captured checkpoint")
    check(state.defeated==[0,6,7,8,9] and state.used_supplies==[0,2],"retry did not roll back current-fight defeats and consumed supplies")
    check(state.encounters_completed==["entry","pump_repair","pump"] and state.journal and state.parts[0] and state.installed and state.water,"retry discarded already earned chapter/objective facts")
    state.defeated.append(13);state.used_supplies.append(4)
    state.restore_checkpoint()
    check(state.defeated==[0,6,7,8,9] and state.used_supplies==[0,2] and state.ammo==17,"repeated retry mutated its snapshot or created resource refills")
    check(state.save(),"checkpoint rollback save failed")
    var restored=State.new();restored.load_save();restored.hp=2;restored.ammo=0;restored.restore_checkpoint()
    check(restored.hp==63 and restored.ammo==17 and restored.defeated==[0,6,7,8,9] and restored.used_supplies==[0,2],"cold reload lost retry snapshot resource/defeat/supply ownership")
    cases.append("checkpoint snapshot copies, current-fight rollback, earned facts and repeated cold retries")

func malformed_inputs() -> void:
    State.clear();var absent=State.new();absent.load_save()
    check(absent.hp==100 and absent.ammo==38 and absent.loaded_version==3,"missing save changed new-run defaults")
    for raw in [null,[],"not a save",{}, {"version":0}, {"version":4}]:
        var invalid=fixture(raw)
        check(invalid.loaded_version==3 and not invalid.reward and invalid.hp==100 and invalid.ammo==38 and invalid.defeated.is_empty(),"unsupported/top-level malformed save earned progress")
    var malformed=fixture({"version":3,"parts":[true],"valves":"invalid","position":[1,2],"defeated":"invalid","used_supplies":{},"checkpoint_position":[1,2],"checkpoint_defeated":null,"checkpoint_supplies":"invalid"})
    check(malformed.parts==[false,false,false] and malformed.valves==[false,false,false] and not malformed.installed,"malformed hardware arrays earned a pump repair")
    check(malformed.position==Vector3(0,.7,65) and malformed.checkpoint_position==malformed.position,"malformed position shape lost the safe spawn")
    check(malformed.defeated.is_empty() and malformed.used_supplies.is_empty() and malformed.checkpoint_defeated.is_empty() and malformed.checkpoint_supplies.is_empty(),"malformed ID containers earned combat/supply facts")
    var clamped=fixture({"version":3,"hp":-100,"ammo":999,"position":[999,-50,-999],"checkpoint_hp":999,"checkpoint_ammo":-4,"checkpoint_position":[-999,999,999]})
    check(clamped.hp==1 and clamped.ammo==38 and clamped.checkpoint_hp==100 and clamped.checkpoint_ammo==0,"invalid resource bounds escaped validation")
    check(clamped.position==Vector3(85,.6,-96) and clamped.checkpoint_position==Vector3(-85,30,73),"out-of-world live/checkpoint coordinates escaped validation")
    var source=State.new()
    check(source._read_position([NAN,1,2],Vector3(4,5,6))==Vector3(4,5,6) and source._read_position([1,INF,2],Vector3(4,5,6))==Vector3(4,5,6),"nonfinite positions bypassed the finite-position guard")
    var file=FileAccess.open(State.PATH+".tmp",FileAccess.WRITE);file.store_string("interrupted atomic write");file.close()
    State.clear()
    check(not FileAccess.file_exists(State.PATH) and not FileAccess.file_exists(State.PATH+".tmp"),"new-run clear retained live or interrupted temporary checkpoint")
    cases.append("missing/unsupported/structurally malformed saves, clamps, finite positions and clear")

func restore_original() -> void:
    State.clear()
    if had_save:
        var file=FileAccess.open(State.PATH,FileAccess.WRITE);file.store_buffer(original_save);file.close()
    if had_tmp:
        var file=FileAccess.open(State.PATH+".tmp",FileAccess.WRITE);file.store_buffer(original_tmp);file.close()

func run() -> void:
    had_save=FileAccess.file_exists(State.PATH);had_tmp=FileAccess.file_exists(State.PATH+".tmp")
    if had_save:original_save=FileAccess.get_file_as_bytes(State.PATH)
    if had_tmp:original_tmp=FileAccess.get_file_as_bytes(State.PATH+".tmp")
    legacy_migration();pedestal_repair();conservatory_access151();current_roundtrip();checkpoint_rollback();malformed_inputs();restore_original()
    if not output.is_empty():
        DirAccess.make_dir_recursive_absolute(output)
        FileAccess.open(output.path_join("state149-report.json"),FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"cases":cases,"scope":"Isolated production save/migration API fixtures; earned six-acorn scene restoration, physical checkpoints and input flow run separately."},"  "))
    if failures.is_empty():print("BOTANICAL STATE149: PASS — v1/v2 earned migration, v3 mandatory escape, 25 stable actor IDs, exact live resources, atomic saves and independent retry snapshots")
    quit(0 if failures.is_empty() else 1)
