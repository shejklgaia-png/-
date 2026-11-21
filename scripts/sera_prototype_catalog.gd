extends RefCounted
## Stable blueprint IDs are independent of localized display names.
## Each minted copy has a never-reused item UID "H01-0001", "H01-0002" etc.
## Legacy preview equipment uses real rig "A"; H02 uses the authored camera-eye
## HEAD D model. A screenshot becomes final only when approved PNG is supplied.
const ORDER = ["H01", "H02", "T01", "A01", "L01", "B01", "WR01", "WL01"]
const MAX_SERIAL: int = 2147483646
const PROTOTYPES = {
    "H01": {"name": "スカウトバイザー", "slot": "head",
        "rig_set": "A", "description": "偵察用の試作頭部装備"},
    "H02": {"name": "アイリス", "slot": "head",
        "rig_set": "D", "description": "カメラアイ型の頭部装備"},
    "T01": {"name": "コアシャーシ", "slot": "torso",
        "rig_set": "A", "description": "機体の基礎となる試作胴体"},
    "A01": {"name": "サーボアーム", "slot": "arms",
        "rig_set": "A", "description": "駆動補助を持つ試作アーム"},
    "L01": {"name": "ランナーレッグ", "slot": "legs",
        "rig_set": "A", "description": "機動性を想定した試作脚部"},
    "B01": {"name": "ベクターブースター", "slot": "booster",
        "rig_set": "A", "description": "推力制御を想定した試作ブースター"},
    "WR01": {"name": "エッジブレード", "slot": "weapon_r",
        "rig_set": "A", "description": "近接戦闘用の試作ブレード"},
    "WL01": {"name": "バリアユニット", "slot": "weapon_l",
        "rig_set": "A", "description": "展開式防御用の試作左手装備"}
}

static func valid(id: String) -> bool:
    return PROTOTYPES.has(id)

static func spec(id: String) -> Dictionary:
    return PROTOTYPES.get(id, {}).duplicate(true)

static func display_name(id: String) -> String:
    var record: Dictionary = spec(id)
    if record.is_empty():
        return ""
    return id + " " + str(record["name"])

## Canonical, per-save-profile item identity: BLUEPRINT-0001, -0002, ...
## Blueprint IDs are fixed even when translated display names change.
## Serial numbers are never reused, including after future item dismantling.
static func uid_for(blueprint: String, serial: int) -> String:
    if not valid(blueprint) or serial <= 0 or serial > MAX_SERIAL:
        return ""
    return "%s-%04d" % [blueprint, serial]


static func valid_uid(uid: String, expected_blueprint: String = "") -> bool:
    var blueprint: String = uid.get_slice("-", 0)
    if not valid(blueprint) or (
            not expected_blueprint.is_empty() and expected_blueprint != blueprint):
        return false
    if not uid.begins_with(blueprint + "-"):
        return false
    var number_text: String = uid.substr(blueprint.length() + 1)
    if not number_text.is_valid_int():
        return false
    return uid == uid_for(blueprint, int(number_text))


static func display_instance(uid: String) -> String:
    if not valid_uid(uid):
        return ""
    var blueprint: String = uid.get_slice("-", 0)
    return str(PROTOTYPES[blueprint]["name"]) + "  " + uid
