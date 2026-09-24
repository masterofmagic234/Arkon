extends RefCounted
class_name RaceAiAssist

static func effective_skill(base_skill: float, ai_progress: float, player_progress: float, track_size: int) -> float:
    if track_size <= 0 or not is_finite(player_progress):
        return clampf(base_skill, 0.62, 0.98)
    var delta := ai_progress - player_progress
    var half_track := float(track_size) * 0.5
    while delta > half_track:
        delta -= float(track_size)
    while delta < -half_track:
        delta += float(track_size)

    var modifier := 0.0
    if delta < 0.0:
        modifier = clampf(-delta * 0.012, 0.0, 0.12)
    elif delta > 0.0:
        modifier = -clampf(delta * 0.004, 0.0, 0.06)
    return clampf(base_skill + modifier, 0.62, 0.98)
