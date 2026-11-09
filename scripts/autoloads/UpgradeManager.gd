extends Node
## Stores the active upgrades for the current run. Upgrade effects are plain
## stat values (multiplier deltas or flags); consumers read them with get_stat().

signal upgrade_applied(upgrade_id: String)

const POOL_PATH := "res://resources/upgrades/upgrade_pool.json"

## upgrade id -> definition (id, label, description, stat, delta, max_stacks).
var _pool: Dictionary = {}
## stat name -> accumulated delta (not including any base value).
var _active: Dictionary = {}


func _ready() -> void:
	_load_pool()


## Returns the stat's accumulated value, or `default` if no upgrade has touched it.
func get_stat(stat_name: String, default: float) -> float:
	return _active.get(stat_name, default)


## Adds the upgrade's delta to its stat, capped at max_stacks * delta.
## Does nothing (and emits nothing) for unknown ids or already-maxed upgrades.
func apply_upgrade(upgrade_id: String) -> void:
	if not _pool.has(upgrade_id):
		push_error("UpgradeManager: unknown upgrade '%s'." % upgrade_id)
		return
	var def: Dictionary = _pool[upgrade_id]
	var stat: String = def["stat"]
	var delta: float = def["delta"]
	var cap: float = int(def["max_stacks"]) * delta
	var current: float = _active.get(stat, 0.0)
	if current >= cap:
		return
	_active[stat] = minf(current + delta, cap)
	upgrade_applied.emit(upgrade_id)


## Clears all active upgrades. Call at run start.
func reset() -> void:
	_active.clear()


func _load_pool() -> void:
	var file := FileAccess.open(POOL_PATH, FileAccess.READ)
	if file == null:
		push_error("UpgradeManager: cannot open '%s' (error %d)." % [POOL_PATH, FileAccess.get_open_error()])
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Array:
		push_error("UpgradeManager: '%s' is not a JSON array." % POOL_PATH)
		return
	for entry: Variant in data:
		if entry is Dictionary and entry.has_all(["id", "stat", "delta", "max_stacks"]):
			_pool[entry["id"]] = entry
		else:
			push_error("UpgradeManager: skipping malformed upgrade entry %s." % str(entry))
