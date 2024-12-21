## Original File MIT License Copyright (c) 2024 TinyTakinTeller
##
## Holds menu scenes and manages their transitions (listens to menu button pressed signal).
extends Control

var _current_menu: Control = null
var _action_handler: ActionHandler = ActionHandler.new()

@onready var main_menu: Control = %MainMenu
@onready var options_menu: Control = %OptionsMenu
@onready var credits_menu: Control = %CreditsMenu
@onready var save_files_menu: Control = %SaveFilesMenu


func _ready() -> void:
	_connect_signals()
	_toggle_menu(main_menu)
	_init_action_handler()

	MusicManager.play("music", "menu_doodle_2_loop", 1.0)


func _init_action_handler() -> void:
	_action_handler.set_register_type("MenuButton")
	_action_handler.register_actions(
		{
			MenuButtonEnum.ID.MAIN_MENU_PLAY: _action_main_menu_play,
			MenuButtonEnum.ID.MAIN_MENU_OPTIONS: _action_main_menu_options,
			MenuButtonEnum.ID.MAIN_MENU_CREDITS: _action_main_menu_credits,
			MenuButtonEnum.ID.MAIN_MENU_QUIT: _action_main_menu_quit
		}
	)
	_action_handler.register_same_action(
		[
			MenuButtonEnum.ID.OPTIONS_MENU_BACK,
			MenuButtonEnum.ID.CREDITS_MENU_BACK,
			MenuButtonEnum.ID.SAVE_FILES_MENU_BACK
		],
		_action_main_menu_back
	)


func _action_main_menu_play() -> void:
	_toggle_menu(save_files_menu)


func _action_main_menu_options() -> void:
	_toggle_menu(options_menu)


func _action_main_menu_credits() -> void:
	_toggle_menu(credits_menu)


func _action_main_menu_quit() -> void:
	get_tree().quit()


func _action_main_menu_back() -> void:
	_toggle_menu(main_menu)


func _toggle_menu(menu: Control) -> void:
	menu.visible = true
	if _current_menu != null:
		_current_menu.visible = false
	_current_menu = menu


func _connect_signals() -> void:
	SignalBus.menu_button_pressed.connect(_on_menu_button_pressed)


func _on_menu_button_pressed(id: MenuButtonEnum.ID, _source: MenuButtonClass) -> void:
	_action_handler.handle_action("MenuButton", id, self)
