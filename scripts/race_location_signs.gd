extends RefCounted
const Data=preload("res://scripts/race_level_data.gd")
const NAMES := Data.SECTOR_NAMES
const NOTICE_BEFORE := 300.0
const NOTICE_AFTER := 110.0

static func notice(z: float) -> Dictionary:
    for sector in range(1,Data.SECTOR_STARTS.size()):
        var remaining: float=Data.SECTOR_STARTS[sector]-z
        if remaining<=NOTICE_BEFORE and remaining>=-NOTICE_AFTER:
            return {"sector":sector,"name":NAMES[sector],"distance":maxi(0,roundi(remaining/10)*10)}
    return {}

static func board_z(sector: int) -> float:
    # The city board stands outside the tunnel wall, after the exit.
    return Data.SECTOR_STARTS[sector]+40 if sector in [5,6] else Data.SECTOR_STARTS[sector]-140
