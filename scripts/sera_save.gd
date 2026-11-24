extends Node
## v171: local, per-device SERA profiles. Stored separately from the GitSync source.
const SLOT_COUNT: int = 3
const ARCHIVE_DIR: String = "user://sera_archive"
const INDEX_PATH: String = ARCHIVE_DIR + "/index.json"
const EQUIPMENT_SLOTS = ["head", "torso", "legs", "arms", "booster", "weapon_r", "weapon_l"]
const SCHEMA_VERSION: int = 2
const HANGER_LIMIT: int = 999
const BaseMaterials = preload("res://scripts/sera_base_materials.gd")
const PrototypeCatalog = preload("res://scripts/sera_prototype_catalog.gd")
const Affixes = preload("res://scripts/sera_craft_affixes.gd")

var active_slot: int = 0
var active_data: Dictionary = {}
var working_equipment: Dictionary = {}
# Transient route request; never written to profile JSON.
var requested_nexus_target: String = ""

func _ready() -> void:
    var err: Error = DirAccess.make_dir_recursive_absolute(
        ProjectSettings.globalize_path(ARCHIVE_DIR))
    if err != OK:
        push_error("SERA: cannot create save directory (%d)" % err)
        return
    var index: Dictionary = _read_json(INDEX_PATH)
    var requested_slot: int = int(index.get("active_slot", 0))
    if _valid_slot(requested_slot):
        var restored: Dictionary = _read_slot(requested_slot)
        if not restored.is_empty():
            active_slot = requested_slot
            active_data = restored
            working_equipment = _sanitize_equipment(restored.get("equipment", {}))

func _valid_slot(slot: int) -> bool:
    return slot >= 1 and slot <= SLOT_COUNT

func _slot_path(slot: int) -> String:
    return "%s/slot_%02d.json" % [ARCHIVE_DIR, slot]

func _read_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Dictionary else {}

func _read_slot(slot: int) -> Dictionary:
    if not _valid_slot(slot):
        return {}
    var data: Dictionary = _read_json(_slot_path(slot))
    var stored_version: int = int(data.get("schema_version", -1))
    if data.is_empty() or stored_version not in [1, SCHEMA_VERSION]:
        return {}
    if int(data.get("slot", -1)) != slot or not (data.get("equipment") is Dictionary):
        return {}
    if not (data.get("training_seconds") is float or data.get("training_seconds") is int):
        return {}
    data["training_seconds"] = maxf(0.0, float(data["training_seconds"]))
    data["equipment"] = _sanitize_equipment(data["equipment"], stored_version == 1)
    data["schema_version"] = SCHEMA_VERSION
    # v171 profile compatibility: absent statistics are introduced as zeroes.
    data["play_seconds"] = maxf(float(data["training_seconds"]),
        float(data.get("play_seconds", 0.0)))
    data["training_visited"] = bool(data.get("training_visited",
        float(data["training_seconds"]) > 0.0))
    data["stats"] = _sanitize_stats(data.get("stats", {}))
    # v508 adds an optional inventory without invalidating old profile files.
    data["materials"] = BaseMaterials.sanitize_inventory(
        data.get("materials", {}))
    data["trial_materials_claimed"] = bool(data.get("trial_materials_claimed", false))
    # Optional v511 crafted inventory: preserve legacy schema v2 and gear.
    data["crafted_items"] = _sanitize_crafted_items(
        data.get("crafted_items", []))
    data["craft_serials"] = _sanitize_craft_serials(
        data.get("craft_serials", {}), data["crafted_items"])
    data["equipped_crafted"] = _sanitize_crafted_selection(
        data.get("equipped_crafted", {}), data["crafted_items"])
    return data

func _sanitize_equipment(candidate: Variant, legacy: bool = false) -> Dictionary:
    var clean: Dictionary = {}
    for part in EQUIPMENT_SLOTS:
        var set_id: String = "A"
        if candidate is Dictionary:
            set_id = str(candidate.get(part, "A")).strip_edges().to_upper()
        if set_id.is_empty() or set_id.length() > 4:
            set_id = "A"
        clean[part] = set_id
    # v1 (v191/v192): D=bird; C/FEET C=standard legs.
    # v2 (v193+): C=bird, D=standard legs. Never remap v2 values.
    if legacy and candidate is Dictionary:
        var old_legs: String = str(candidate.get("legs", "A")).strip_edges().to_upper()
        var old_feet: String = str(candidate.get("feet", "A")).strip_edges().to_upper()
        if old_legs == "D":
            clean["legs"] = "C"
        elif old_legs == "C" or old_feet == "C":
            clean["legs"] = "D"
    return clean

func _sanitize_crafted_items(raw: Variant) -> Array:
    var clean: Array = []
    var found: Dictionary = {}
    if not (raw is Array):
        return clean
    for item in raw:
        if not (item is Dictionary):
            continue
        var blueprint: String = str(item.get("blueprint", ""))
        var uid: String = str(item.get("uid", ""))
        if not PrototypeCatalog.valid_uid(uid, blueprint) or found.has(uid):
            continue
        found[uid] = true
        var cleaned: Dictionary = {"uid": uid, "blueprint": blueprint,
            "slot": str(PrototypeCatalog.spec(blueprint)["slot"])}
        # Preserve validated new affixes; never randomly change older saves.
        # Legacy items without affixes keep an empty array and their original UID.
        cleaned["affixes"] = Affixes.sanitize(item.get("affixes", []))
        cleaned["favorite"] = bool(item.get("favorite", false))
        cleaned["junk"] = bool(item.get("junk", false)) and not cleaned["favorite"]
        clean.append(cleaned)
    return clean

func _sanitize_craft_serials(raw: Variant, items: Array) -> Dictionary:
    var serials: Dictionary = {}
    for blueprint in PrototypeCatalog.ORDER:
        serials[blueprint] = maxi(0, int(raw.get(blueprint, 0))) \
            if raw is Dictionary else 0
    for item in items:
        var bp: String = str(item["blueprint"])
        var uid: String = str(item["uid"])
        serials[bp] = maxi(int(serials[bp]),
            int(uid.substr(bp.length() + 1)))
    return serials

func _sanitize_crafted_selection(raw: Variant, items: Array) -> Dictionary:
    var selected: Dictionary = {}
    if not (raw is Dictionary):
        return selected
    for slot in EQUIPMENT_SLOTS:
        var uid: String = str(raw.get(slot, ""))
        for item in items:
            if str(item["uid"]) == uid and str(item["slot"]) == slot:
                selected[slot] = uid
                break
    return selected

func _default_stats() -> Dictionary:
    return {
        "target_destroys": 0, "melee_hits": 0, "bash_hits": 0,
        "damage_dealt": 0, "guarded_hits": 0, "received_hits": 0
    }

func _sanitize_stats(raw: Variant) -> Dictionary:
    var stats: Dictionary = _default_stats()
    if raw is Dictionary:
        for key in stats.keys():
            stats[key] = maxi(0, int(raw.get(key, 0)))
    return stats

func _write_json(path: String, data: Dictionary) -> bool:
    var temp: String = path + ".tmp"
    var file := FileAccess.open(temp, FileAccess.WRITE)
    if file == null:
        push_warning("SERA: save write failed: " + path)
        return false
    # Compact JSON preserves the same schema and atomic replacement, with
    # less formatting allocation and write volume for large hangars.
    file.store_string(JSON.stringify(data) + "\n")
    file.flush()
    file.close()
    var result: Error = DirAccess.rename_absolute(
        ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(path))
    if result != OK:
        push_warning("SERA: save replace failed (%d): %s" % [result, path])
        return false
    return true

func _write_index(slot: int) -> bool:
    return _write_json(INDEX_PATH, {"active_slot": slot})

func _timestamp() -> String:
    return Time.get_datetime_string_from_system(false, true)

func _new_document(slot: int) -> Dictionary:
    var now: String = _timestamp()
    var gear: Dictionary = {}
    for part in EQUIPMENT_SLOTS:
        gear[part] = "A"
    return {
        "schema_version": SCHEMA_VERSION, "slot": slot,
        "created_at": now, "updated_at": now, "training_seconds": 0.0,
        "last_location": "NEXUS", "tutorial_completed": false,
        "training_visited": false, "play_seconds": 0.0,
        "stats": _default_stats(), "equipment": gear,
        "materials": BaseMaterials.starter_inventory(),
        "trial_materials_claimed": false,
        "crafted_items": [], "craft_serials": {},
        "equipped_crafted": {}
    }

func get_slot(slot: int) -> Dictionary:
    return _read_slot(slot).duplicate(true)

func get_active_data() -> Dictionary:
    return active_data.duplicate(true)

func get_working_equipment() -> Dictionary:
    return working_equipment.duplicate(true)

func get_material_inventory() -> Dictionary:
    # A missing legacy field is treated as an empty bag, never free supplies.
    return BaseMaterials.sanitize_inventory(active_data.get("materials", {}))


func claim_trial_materials() -> bool:
    # Optional, explicit one-time test stock for exercising refinement UI.
    # Separate from real boss drops, and never repeated within this profile.
    if not _valid_slot(active_slot) or active_data.is_empty() or (
            bool(active_data.get("trial_materials_claimed", false))):
        return false
    var stock: Dictionary = get_material_inventory()
    for material_id in BaseMaterials.all_ids():
        if int(stock[material_id]) > 2147483641:
            return false
        stock[material_id] = int(stock[material_id]) + 6
    var updated: Dictionary = active_data.duplicate(true)
    updated["materials"] = stock
    updated["trial_materials_claimed"] = true
    updated["updated_at"] = _timestamp()
    if not _write_json(_slot_path(active_slot), updated):
        return false
    active_data = updated
    return true

func can_convert_material(family: String, rank: int,
        direction: int, batches: int = 1) -> bool:
    if active_slot <= 0:
        return false
    var conversion: Dictionary = BaseMaterials.convert(
        get_material_inventory(), family, rank, direction, batches)
    return bool(conversion.get("ok", false))

func convert_material(family: String, rank: int,
        direction: int, batches: int = 1) -> bool:
    # Atomic transaction: reject an empty slot, invalid recipe, shortage or
    # failed file write without mutating in-memory resources. Save first.
    if not _valid_slot(active_slot) or active_data.is_empty():
        return false
    var conversion: Dictionary = BaseMaterials.convert(
        get_material_inventory(), family, rank, direction, batches)
    if not bool(conversion.get("ok", false)):
        return false
    var updated: Dictionary = active_data.duplicate(true)
    updated["materials"] = conversion["inventory"]
    updated["updated_at"] = _timestamp()
    if not _write_json(_slot_path(active_slot), updated):
        return false
    active_data = updated
    return true

func award_materials(rewards: Dictionary) -> bool:
    # Explicit future boss-reward integration point; does not mint rewards
    # on a timer, at boot or from tapping equipment. Quality IDs are fixed.
    if not _valid_slot(active_slot) or active_data.is_empty() or rewards.is_empty():
        return false
    var inventory: Dictionary = get_material_inventory()
    for raw_id in rewards.keys():
        var material_id: String = str(raw_id)
        var amount: Variant = rewards[raw_id]
        if not BaseMaterials.MATERIAL_NAMES.has(material_id) or (
                not (amount is int)) or amount <= 0:
            return false
        if int(inventory[material_id]) > 2147483647 - int(amount):
            return false
        inventory[material_id] = int(inventory[material_id]) + int(amount)
    var updated: Dictionary = active_data.duplicate(true)
    updated["materials"] = inventory
    updated["updated_at"] = _timestamp()
    if not _write_json(_slot_path(active_slot), updated):
        return false
    active_data = updated
    return true

func get_owned_prototypes(slot: String = "") -> Array:
    # Documents are sanitized when loaded and on every transaction; each
    # item returned to a caller is still a defensive deep copy.
    var all_items: Array = active_data.get("crafted_items", [])
    if slot.is_empty():
        return all_items.duplicate(true)
    var result: Array = []
    for item in all_items:
        if str(item["slot"]) == slot:
            result.append(item.duplicate(true))
    return result

func set_prototype_mark(uid: String, mark: String, enabled: bool) -> bool:
    # Per-instance, per-save marks. Favorite and junk are mutually exclusive;
    # a failed disk commit must never alter the in-memory inventory.
    if not _valid_slot(active_slot) or active_data.is_empty() or (
            mark not in ["favorite", "junk"]):
        return false
    var items: Array = get_owned_prototypes()
    var found: bool = false
    for item in items:
        if str(item["uid"]) != uid:
            continue
        item[mark] = enabled
        if enabled:
            item["junk" if mark == "favorite" else "favorite"] = false
        found = true
        break
    if not found:
        return false
    var updated: Dictionary = active_data.duplicate(true)
    updated["crafted_items"] = items
    updated["updated_at"] = _timestamp()
    if not _write_json(_slot_path(active_slot), updated):
        return false
    active_data = updated
    return true

func count_junk_prototypes(slot: String = "") -> int:
    # Keep equipped UIDs out of deletion counts.
    var equipped: Dictionary = active_data.get("equipped_crafted", {})
    var count: int = 0
    var equipped_ids: Array = equipped.values()
    for item in active_data.get("crafted_items", []):
        if (slot.is_empty() or str(item.get("slot", "")) == slot) and bool(item.get("junk", false)) and (
                not equipped_ids.has(str(item.get("uid", "")))):
            count += 1
    return count

func delete_junk_prototypes(slot: String = "") -> int:
    if not _valid_slot(active_slot) or active_data.is_empty() or (
            not slot.is_empty() and not EQUIPMENT_SLOTS.has(slot)):
        return 0
    var items: Array = get_owned_prototypes()
    var equipped: Dictionary = active_data.get("equipped_crafted", {})
    var kept: Array = []
    var deleted: int = 0
    for item in items:
        if (bool(item.get("junk", false)) and (
                slot.is_empty() or str(item["slot"]) == slot) and
                not equipped.values().has(str(item["uid"]))):
            deleted += 1
        else:
            kept.append(item)
    if deleted == 0:
        return 0
    var updated: Dictionary = active_data.duplicate(true)
    updated["crafted_items"] = kept
    updated["updated_at"] = _timestamp()
    # craft_serials must NOT reset: deleted identities cannot be minted again.
    if not _write_json(_slot_path(active_slot), updated):
        return 0
    active_data = updated
    return deleted

func get_equipped_prototype(slot: String) -> String:
    if not EQUIPMENT_SLOTS.has(slot):
        return ""
    var chosen: Dictionary = _sanitize_crafted_selection(
        active_data.get("equipped_crafted", {}), get_owned_prototypes())
    return str(chosen.get(slot, ""))

func craft_prototype(blueprint: String) -> String:
    # v511 is a testing-only, clearly marked no-material-cost craft. This
    # never grants materials or invents permanent economic recipes.
    if not _valid_slot(active_slot) or active_data.is_empty() or (
            not PrototypeCatalog.valid(blueprint)):
        return ""
    var items: Array = get_owned_prototypes()
    var slot_name: String = str(PrototypeCatalog.spec(blueprint)["slot"])
    var hanger_count: int = 0
    for item in items:
        if str(item.get("slot", "")) == slot_name:
            hanger_count += 1
    if hanger_count >= HANGER_LIMIT:
        return ""  # No UID / affixes minted when the category is full.
    var serials: Dictionary = _sanitize_craft_serials(
        active_data.get("craft_serials", {}), items)
    var number: int = int(serials.get(blueprint, 0)) + 1
    var uid: String = PrototypeCatalog.uid_for(blueprint, number)
    if uid.is_empty():
        return ""
    for item in items:
        if str(item["uid"]) == uid:
            return ""
    var rolled_affixes: Array = Affixes.roll_five()
    if not Affixes.valid(rolled_affixes):
        return ""
    items.append({"uid": uid, "blueprint": blueprint,
        "slot": slot_name, "affixes": rolled_affixes})
    serials[blueprint] = number
    var updated: Dictionary = active_data.duplicate(true)
    updated["crafted_items"] = items
    updated["craft_serials"] = serials
    updated["updated_at"] = _timestamp()
    if not _write_json(_slot_path(active_slot), updated):
        return ""
    active_data = updated
    return uid

func equip_prototype(slot: String, uid: String) -> bool:
    if not _valid_slot(active_slot) or active_data.is_empty() or (
            not EQUIPMENT_SLOTS.has(slot)):
        return false
    var owned: Array = get_owned_prototypes(slot)
    if not owned.any(func(item: Dictionary) -> bool:
            return str(item["uid"]) == uid):
        return false
    var updated: Dictionary = active_data.duplicate(true)
    var equipped: Dictionary = _sanitize_crafted_selection(
        updated.get("equipped_crafted", {}), get_owned_prototypes())
    equipped[slot] = uid
    updated["equipped_crafted"] = equipped
    # Until a unique authored 3D part exists, use its declared real rig set.
    # Persist the same selection for NEXUS and for the playable SERA rig.
    var blueprint: String = uid.get_slice("-", 0)
    var rig_set: String = str(PrototypeCatalog.spec(blueprint).get("rig_set", "A"))
    var gear: Dictionary = _sanitize_equipment(updated.get("equipment", {}))
    gear[slot] = rig_set
    updated["equipment"] = gear
    updated["updated_at"] = _timestamp()
    if not _write_json(_slot_path(active_slot), updated):
        return false
    active_data = updated
    working_equipment[slot] = rig_set
    return true

func clear_equipped_prototype(slot: String) -> bool:
    if not _valid_slot(active_slot) or active_data.is_empty() or (
            not EQUIPMENT_SLOTS.has(slot)):
        return false
    var updated: Dictionary = active_data.duplicate(true)
    var equipped: Dictionary = _sanitize_crafted_selection(
        updated.get("equipped_crafted", {}), get_owned_prototypes())
    equipped.erase(slot)
    updated["equipped_crafted"] = equipped
    updated["updated_at"] = _timestamp()
    if not _write_json(_slot_path(active_slot), updated):
        return false
    active_data = updated
    return true

func get_active_stats() -> Dictionary:
    return _sanitize_stats(active_data.get("stats", {}))

func record_game_time(delta: float) -> void:
    if active_slot == 0 or delta <= 0.0:
        return
    active_data["play_seconds"] = float(active_data.get("play_seconds", 0.0)) + delta

func mark_location(location: String) -> void:
    if active_slot > 0 and location in ["BASE", "NEXUS", "TRAINING"]:
        active_data["last_location"] = location

func record_target_hit(kind: String, damage: int, destroyed: bool) -> void:
    if active_slot == 0 or not (kind == "melee" or kind == "bash"):
        return
    var stats: Dictionary = get_active_stats()
    if kind == "melee":
        stats["melee_hits"] += 1
    else:
        stats["bash_hits"] += 1
    stats["damage_dealt"] += maxi(0, damage)
    if destroyed:
        stats["target_destroys"] += 1
    active_data["stats"] = stats

func record_defensive_impact(guarded: bool) -> void:
    if active_slot == 0:
        return
    var stats: Dictionary = get_active_stats()
    if guarded:
        stats["guarded_hits"] += 1
    else:
        stats["received_hits"] += 1
    active_data["stats"] = stats

func update_working_equipment(part: String, set_id: String) -> void:
    if EQUIPMENT_SLOTS.has(part):
        working_equipment[part] = set_id

func record_training_time(delta: float) -> void:
    if active_slot == 0 or delta <= 0.0:
        return
    active_data["training_seconds"] = float(active_data.get("training_seconds", 0.0)) + delta
    active_data["last_location"] = "TRAINING"
    active_data["training_visited"] = true

func create_data(slot: int) -> bool:
    if not _valid_slot(slot):
        return false
    var fresh: Dictionary = _new_document(slot)
    if not _write_json(_slot_path(slot), fresh):
        return false
    if not _write_index(slot):
        return false
    active_slot = slot
    active_data = fresh
    working_equipment = fresh["equipment"].duplicate(true)
    return true

func save_data(slot: int, equipment: Dictionary) -> bool:
    if not _valid_slot(slot):
        return false
    var current: Dictionary = active_data.duplicate(true)
    if current.is_empty():
        current = _new_document(slot)
    var destination: Dictionary = _read_slot(slot)
    if not destination.is_empty():
        current["created_at"] = destination["created_at"]
    current["schema_version"] = SCHEMA_VERSION
    current["slot"] = slot
    current["updated_at"] = _timestamp()
    current["equipment"] = _sanitize_equipment(equipment)
    current["materials"] = BaseMaterials.sanitize_inventory(
        current.get("materials", {}))
    current["crafted_items"] = _sanitize_crafted_items(
        current.get("crafted_items", []))
    current["craft_serials"] = _sanitize_craft_serials(
        current.get("craft_serials", {}), current["crafted_items"])
    current["equipped_crafted"] = _sanitize_crafted_selection(
        current.get("equipped_crafted", {}), current["crafted_items"])
    if not _write_json(_slot_path(slot), current):
        return false
    if not _write_index(slot):
        return false
    active_slot = slot
    active_data = current
    working_equipment = current["equipment"].duplicate(true)
    return true

func load_data(slot: int) -> bool:
    var stored: Dictionary = _read_slot(slot)
    if stored.is_empty() or not _write_index(slot):
        return false
    active_slot = slot
    active_data = stored
    working_equipment = stored["equipment"].duplicate(true)
    return true

func delete_data(slot: int) -> bool:
    if not _valid_slot(slot) or _read_slot(slot).is_empty():
        return false
    var err: Error = DirAccess.remove_absolute(
        ProjectSettings.globalize_path(_slot_path(slot)))
    if err != OK:
        return false
    if slot == active_slot:
        active_slot = 0
        active_data = {}
        working_equipment = {}
        _write_index(0)
    return true
