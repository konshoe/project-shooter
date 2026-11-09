class_name UpgradePicker
extends CanvasLayer
## Pauses the game and offers 3 random, not-yet-maxed upgrades. GameWorld decides
## when to call show_picker() (every `waves_between_picks` waves).
##
## process_mode is ALWAYS (set in UpgradePicker.tscn) so the cards still work
## while the tree is paused.

const CARD_COUNT := 3

## Emitted when the picker is done (card picked, or nothing left to offer).
signal picker_closed

## Read by GameWorld: show the picker after this many completed waves.
@export var waves_between_picks: int = 2

@onready var _cards: Array[UpgradeCard] = [
	$Root/Cards/UpgradeCard1, $Root/Cards/UpgradeCard2, $Root/Cards/UpgradeCard3,
]


func _ready() -> void:
	hide()
	for card in _cards:
		card.card_selected.connect(_on_card_selected)


func show_picker() -> void:
	var available := UpgradeManager.get_available_upgrades()
	if available.is_empty():
		picker_closed.emit()  # Everything is maxed - nothing to offer, don't pause.
		return
	available.shuffle()

	for i in _cards.size():
		var card := _cards[i]
		card.visible = i < available.size()
		if card.visible:
			var def: Dictionary = available[i]
			card.setup(def["id"], def.get("label", def["id"]), def.get("description", ""))

	get_tree().paused = true
	show()
	_cards[0].grab_focus()  # So keyboard users can pick too.


func hide_picker() -> void:
	hide()
	get_tree().paused = false
	picker_closed.emit()


func _on_card_selected(upgrade_id: String) -> void:
	UpgradeManager.apply_upgrade(upgrade_id)
	hide_picker()
