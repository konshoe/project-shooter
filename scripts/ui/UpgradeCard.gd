class_name UpgradeCard
extends Button
## One selectable upgrade card. Emits card_selected(upgrade_id) when pressed.

signal card_selected(upgrade_id: String)

@export var upgrade_id: String = ""

@onready var _title_label: Label = $VBox/TitleLabel
@onready var _desc_label: Label = $VBox/DescLabel


func _ready() -> void:
	var bold := FontVariation.new()
	bold.base_font = ThemeDB.fallback_font
	bold.variation_embolden = 0.8
	_title_label.add_theme_font_override("font", bold)
	pressed.connect(func(): card_selected.emit(upgrade_id))


func setup(id: String, label_text: String, desc_text: String) -> void:
	upgrade_id = id
	_title_label.text = label_text
	_desc_label.text = desc_text
