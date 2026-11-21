extends RefCounted
## Stable blueprint IDs are independent of localized display names.
## Each minted copy has a never-reused item UID "H01-0001", "H01-0002" etc.
## One blueprint per real, independently equipable SeraRig part.
## The manufacturing letters are mesh reference keys, never equipment sets.
## Existing H01/H02/T01/A01/L01/B01/WR01/WL01 IDs and UIDs are preserved;
## obsolete image-only prototype records have been replaced by real parts.
const ORDER = ["H01", "H02", "H03", "H04", "T01", "T02", "A01", "A02", "L01", "L02", "L03", "L04", "B01", "B02", "WR01", "WR02", "WR03", "WL01", "WL02"]
const MAX_SERIAL: int = 2147483646
const PROTOTYPES = {
    "H01": {"name": "標準頭部", "slot": "head",
        "rig_set": "A", "source_model": "models/core/Standard.bbmodel",
        "description": "実装済み頭部モデル"},
    "H02": {"name": "アイリス", "slot": "head",
        "rig_set": "D", "source_model": "models/storage/カメラアイ頭部.bbmodel",
        "description": "実装済み頭部モデル"},
    "H03": {"name": "重装頭部", "slot": "head",
        "rig_set": "B", "source_model": "models/core/Equipment.bbmodel",
        "description": "実装済み頭部モデル"},
    "H04": {"name": "軽量頭部", "slot": "head",
        "rig_set": "C", "source_model": "models/storage/Head_C.bbmodel",
        "description": "実装済み頭部モデル"},
    "T01": {"name": "標準胴体", "slot": "torso",
        "rig_set": "A", "source_model": "models/core/Standard.bbmodel",
        "description": "実装済み胴体モデル"},
    "T02": {"name": "重装胴体", "slot": "torso",
        "rig_set": "B", "source_model": "models/core/Equipment.bbmodel",
        "description": "実装済み胴体モデル"},
    "A01": {"name": "標準腕部", "slot": "arms",
        "rig_set": "A", "source_model": "models/core/Standard.bbmodel",
        "description": "実装済み腕部モデル"},
    "A02": {"name": "重装腕部", "slot": "arms",
        "rig_set": "B", "source_model": "models/core/Equipment.bbmodel",
        "description": "実装済み腕部モデル"},
    "L01": {"name": "標準脚部", "slot": "legs",
        "rig_set": "A", "source_model": "models/core/Standard.bbmodel",
        "description": "実装済み脚部モデル"},
    "L02": {"name": "重装脚部B", "slot": "legs",
        "rig_set": "B", "source_model": "models/core/Equipment.bbmodel",
        "description": "実装済み脚部モデル"},
    "L03": {"name": "鳥脚", "slot": "legs",
        "rig_set": "C", "source_model": "models/core/BirdLeg.bbmodel",
        "description": "実装済み脚部モデル"},
    "L04": {"name": "重装脚部D", "slot": "legs",
        "rig_set": "D", "source_model": "models/storage/LowerBody_D.bbmodel",
        "description": "実装済み脚部モデル"},
    "B01": {"name": "標準ブースター", "slot": "booster",
        "rig_set": "A", "source_model": "models/core/Equipment.bbmodel",
        "description": "実装済み推進器モデル"},
    "B02": {"name": "重装ブースター", "slot": "booster",
        "rig_set": "B", "source_model": "models/core/Equipment.bbmodel",
        "description": "実装済み推進器モデル"},
    "WR01": {"name": "標準ブレード", "slot": "weapon_r",
        "rig_set": "A", "source_model": "models/core/Standard.bbmodel",
        "description": "実装済み右手武器モデル"},
    "WR02": {"name": "重装ブレード", "slot": "weapon_r",
        "rig_set": "B", "source_model": "models/core/Equipment.bbmodel",
        "description": "実装済み右手武器モデル"},
    "WR03": {"name": "カタナ", "slot": "weapon_r",
        "rig_set": "K", "source_model": "models/core/Katana.bbmodel",
        "description": "実装済み右手武器モデル"},
    "WL01": {"name": "標準シールド", "slot": "weapon_l",
        "rig_set": "A", "source_model": "models/core/Standard.bbmodel",
        "description": "実装済み左手武器モデル"},
    "WL02": {"name": "強化シールド", "slot": "weapon_l",
        "rig_set": "B", "source_model": "models/core/Equipment.bbmodel",
        "description": "実装済み左手武器モデル"}
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
