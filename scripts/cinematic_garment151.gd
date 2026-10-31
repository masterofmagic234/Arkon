extends RefCounted
## Measured garment outlines follow the selected, unchanged takes. These are
## cloth envelopes, not whole-character rectangles; room/pillows stay outside.
const SLEEP := [Vector2(251,326),Vector2(280,326),Vector2(310,340),Vector2(333,359),Vector2(306,369),Vector2(281,385),Vector2(258,399),Vector2(225,414),Vector2(205,420),Vector2(194,409),Vector2(225,388),Vector2(245,361)]
const RISE := [Vector2(179,320),Vector2(225,300),Vector2(269,288),Vector2(312,284),Vector2(344,291),Vector2(378,342),Vector2(354,368),Vector2(302,397),Vector2(245,409),Vector2(201,399),Vector2(175,375),Vector2(167,349)]
const RECLINE := [Vector2(177,338),Vector2(223,321),Vector2(253,303),Vector2(281,291),Vector2(308,300),Vector2(351,343),Vector2(333,382),Vector2(286,419),Vector2(241,425),Vector2(201,422),Vector2(153,388),Vector2(151,357)]
const KNEES := [Vector2(126,250),Vector2(173,235),Vector2(221,224),Vector2(270,211),Vector2(301,226),Vector2(328,272),Vector2(309,354),Vector2(368,441),Vector2(284,447),Vector2(177,448),Vector2(115,374),Vector2(106,331)]
const SEATED := [Vector2(178,251),Vector2(228,239),Vector2(291,238),Vector2(346,248),Vector2(376,321),Vector2(348,401),Vector2(417,478),Vector2(335,494),Vector2(225,487),Vector2(171,432),Vector2(170,380),Vector2(173,329)]

static func outline(clip: int, at: float) -> PackedVector2Array:
    var a: Array=SLEEP;var b: Array=SLEEP;var blend:=0.0
    if clip==0:
        if at<2.05:a=SLEEP;b=RISE;blend=smoothstep(.55,2.05,at)
        else:a=RISE;b=RECLINE;blend=smoothstep(2.05,3.9,at)
    elif clip==1:a=RECLINE;b=RECLINE
    elif clip==2:
        if at<1.7:a=RECLINE;b=KNEES;blend=smoothstep(.4,1.7,at)
        else:a=KNEES;b=SEATED;blend=smoothstep(1.7,3.6,at)
    else:a=SEATED;b=SEATED
    var result:=PackedVector2Array()
    for index in range(12):result.append((a[index] as Vector2).lerp(b[index],blend)/Vector2(1280,720))
    return result

static func cuff(clip: int, at: float) -> PackedVector2Array:
    var sleeping: Array=[Vector2(308,336),Vector2(336,353),Vector2(319,366),Vector2(300,351)]
    var rising: Array=[Vector2(349,323),Vector2(380,342),Vector2(360,357),Vector2(340,338)]
    var reclining: Array=[Vector2(325,330),Vector2(354,345),Vector2(337,362),Vector2(316,346)]
    var upright: Array=[Vector2(298,246),Vector2(330,269),Vector2(315,285),Vector2(289,261)]
    var seated_cuff: Array=[Vector2(347,297),Vector2(375,313),Vector2(357,327),Vector2(338,309)]
    var a: Array=sleeping;var b: Array=sleeping;var blend:=0.0
    if clip==0:
        if at<1.5:a=sleeping;b=sleeping
        elif at<2.05:a=sleeping;b=rising;blend=smoothstep(1.5,2.05,at)
        else:a=rising;b=reclining;blend=smoothstep(2.05,3.2,at)
    elif clip==1:a=reclining;b=reclining
    elif clip==2:
        if at<1.5:a=reclining;b=upright;blend=smoothstep(.4,1.5,at)
        else:a=upright;b=seated_cuff;blend=smoothstep(1.5,3.3,at)
    else:a=seated_cuff;b=seated_cuff
    var result:=PackedVector2Array()
    for index in range(4):result.append((a[index] as Vector2).lerp(b[index],blend)/Vector2(1280,720))
    return result

static func face_guard(clip: int, at: float) -> Vector4:
    var a:=Vector2(174,351);var b:=a;var blend:=0.0
    if clip==0:
        if at<1.5:a=Vector2(174,351);b=Vector2(192,330);blend=smoothstep(.7,1.5,at)
        elif at<2.05:a=Vector2(192,330);b=Vector2(245,270);blend=smoothstep(1.5,2.05,at)
        else:a=Vector2(245,270);b=Vector2(226,311);blend=smoothstep(2.05,3.2,at)
    elif clip==1:a=Vector2(226,311);b=a
    elif clip==2:
        if at<1.5:a=Vector2(226,311);b=Vector2(205,204);blend=smoothstep(.4,1.5,at)
        elif at<2.1:a=Vector2(205,204);b=Vector2(257,220);blend=smoothstep(1.5,2.1,at)
        else:a=Vector2(257,220);b=Vector2(286,214);blend=smoothstep(2.1,3.3,at)
    else:a=Vector2(286,214);b=a
    var centre:=a.lerp(b,blend)/Vector2(1280,720)
    return Vector4(centre.x,centre.y,35.0/1280.0,38.0/720.0)

static func arm_guard(clip: int, at: float) -> Vector4:
    var sleep_arm:=Vector4(318,375,315,382)
    var rise_arm:=Vector4(350,364,338,374)
    var recline_arm:=Vector4(333,369,328,381)
    var up_arm:=Vector4(324,296,356,394)
    var seated_arm:=Vector4(352,341,341,404)
    var a:=sleep_arm;var b:=a;var blend:=0.0
    if clip==0:
        if at<1.5:a=sleep_arm;b=sleep_arm
        elif at<2.05:a=sleep_arm;b=rise_arm;blend=smoothstep(1.5,2.05,at)
        else:a=rise_arm;b=recline_arm;blend=smoothstep(2.05,3.2,at)
    elif clip==1:a=recline_arm;b=a
    elif clip==2:
        if at<1.5:a=recline_arm;b=up_arm;blend=smoothstep(.4,1.5,at)
        else:a=up_arm;b=seated_arm;blend=smoothstep(1.5,3.3,at)
    else:a=seated_arm;b=a
    var result:=a.lerp(b,blend)
    return result/Vector4(1280,720,1280,720)

static func apply(material: ShaderMaterial, clip: int, at: float) -> void:
    material.set_shader_parameter("garment_outline",outline(clip,at))
    material.set_shader_parameter("cuff_outline",cuff(clip,at))
    material.set_shader_parameter("face_guard",face_guard(clip,at))
    material.set_shader_parameter("arm_guard",arm_guard(clip,at))
