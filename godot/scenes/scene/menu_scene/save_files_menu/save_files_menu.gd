## Original File MIT License Copyright (c) 2024 TinyTakinTeller
class_name SaveFilesMenu
extends Control

const METADATA_CATEGORY: String = "meta"

@export var menu_save_file_pck: PackedScene

var _menu_save_files: Array[MenuSaveFile] = []

var _action_handler: ActionHandler = ActionHandler.new()

@onready var save_files_v_box_container: VBoxContainer = %SaveFilesVBoxContainer
@onready var control_grab_focus: ControlGrabFocus = %ControlGrabFocus


func _ready() -> void:
	if not menu_save_file_pck:
		Log.warn("Save File UI packed scene not set.")
		return

	_init_menu_save_files()
	_connect_signals()
	_init_action_handler()


func _init_action_handler() -> void:
	_action_handler.set_register_type("MenuButton")
	_action_handler.register_actions(
		{
			MenuButtonEnum.ID.SAVE_FILES_MENU_PLAY: _action_play_save_file_menu_button,
			MenuButtonEnum.ID.SAVE_FILES_MENU_EXPORT: _action_export_save_file_menu_button,
			MenuButtonEnum.ID.SAVE_FILES_MENU_IMPORT: _action_import_save_file_menu_button,
			MenuButtonEnum.ID.SAVE_FILES_MENU_DELETE: _action_delete_save_file_menu_button,
			MenuButtonEnum.ID.SAVE_FILES_MENU_RENAME: _action_rename_save_file_menu_button
		}
	)


func _action_play_save_file_menu_button() -> void:
	Log.info("PLAY SAVE FILE")  #TODO


func _action_export_save_file_menu_button() -> void:
	Log.info("EXPORT SAVE FILE")  #TODO


func _action_import_save_file_menu_button() -> void:
	Log.info("IMPORT SAVE FILE")  #TODO


func _action_delete_save_file_menu_button() -> void:
	Log.info("DELETE SAVE FILE")  #TODO


func _action_rename_save_file_menu_button() -> void:
	Log.info("RENAME SAVE FILE")  #TODO


func _init_menu_save_files() -> void:
	NodeUtils.remove_children_of(save_files_v_box_container, MenuSaveFile)

	var save_files: Array[Dictionary] = Data.get_save_files()
	for index: int in range(Data.save_file_count):
		var save_file: Dictionary = save_files[index]
		var menu_save_file: MenuSaveFile = _init_menu_save_file(save_file)
		menu_save_file.set_index(index)
		menu_save_file.save_file_button_pressed.connect(_on_save_file_button_pressed)
		_menu_save_files.append(menu_save_file)

	control_grab_focus.ready()


func _init_menu_save_file(save_file: Dictionary) -> MenuSaveFile:
	var menu_save_file: MenuSaveFile = menu_save_file_pck.instantiate()
	NodeUtils.add_child_back(menu_save_file, save_files_v_box_container)

	var save_file_meta: Dictionary = save_file.get(METADATA_CATEGORY, {})
	if save_file_meta.is_empty():
		Log.warn("Could not read save file metadata '%s': " % [METADATA_CATEGORY], save_file)
		return

	var save_file_name: String = save_file_meta["save_file_name"]
	var playtime_seconds: int = save_file_meta["playtime_seconds"]
	var modified_at: Dictionary = save_file_meta["modified_at_datetime"]
	menu_save_file.set_value_labels(save_file_name, playtime_seconds, modified_at)

	return menu_save_file


func _on_save_file_button_pressed(index: int) -> void:
	for menu_save_file: MenuSaveFile in _menu_save_files:
		if menu_save_file.index != index:
			menu_save_file.save_file_button.button_pressed = false


func _connect_signals() -> void:
	self.visibility_changed.connect(_on_visibility_changed)
	SignalBus.menu_button_pressed.connect(_on_menu_button_pressed)


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		for menu_save_file: MenuSaveFile in _menu_save_files:
			menu_save_file.save_file_button.button_pressed = false


func _on_menu_button_pressed(id: MenuButtonEnum.ID, _source: MenuButtonClass) -> void:
	_action_handler.handle_action("MenuButton", id, self)
