extends RefCounted
## Stable blueprint IDs are independent of localized display names.
## Each minted copy has a never-reused item UID "H01-0001", "H01-0002" etc.
## Current preview equipment uses existing real rig "A" until a new matching
## Blockbench model is authored. Do not imply these images are 3D mesh assets.
const ORDER = ["H01", "T01", "A01", "L01", "B01", "WR01", "WL01"]
const PROTOTYPES = {
    "H01": {"name": "スカウトバイザー", "slot": "head",
        "rig_set": "A", "description": "偵察用の試作頭部装備"},
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

static func display_instance(uid: String) -> String:
    var prefix: String = uid.get_slice("-", 0)
    if not valid(prefix):
        return ""
    return display_name(prefix) + " #" + uid.get_slice("-", 1)
