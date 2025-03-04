## Original File MIT License Copyright (c) 2024 TinyTakinTeller
## [br][br]
## Provides locales sorted by their english name text.
class_name ConfigurationLocale
extends Node

const LOCALE_TEXT_KEY: String = "STRING_ID"

var _locale_text_linked_map: LinkedMap = LinkedMap.new()


func _ready() -> void:
	_load_locale()
	_init_locales()


func get_options() -> Array[String]:
	return _locale_text_linked_map.get_values()


func get_locale_option_index() -> int:
	var locale: String = TranslationServer.get_locale()
	return _locale_text_linked_map.get_keys().find(locale)


func get_locale_text() -> LinkedMap:
	return _locale_text_linked_map


func set_locale_option_index(index: int) -> void:
	var locale: String = _locale_text_linked_map.get_key_at(index)
	set_locale(locale)


func set_locale(locale: String) -> void:
	LogWrapper.debug(self, "Language changed: ", locale)

	ConfigStorageSettingsLocale.set_locale(locale)
	TranslationServer.set_locale(locale)
	SignalBus.language_changed.emit(locale)


func reset() -> void:
	ConfigStorageSettingsLocale.delete()
	var locale: String = _load_locale()
	SignalBus.language_changed.emit(locale)


func _load_locale() -> String:
	var app_locale: String = ConfigStorageSettingsLocale.get_locale()
	TranslationServer.set_locale(app_locale)
	return app_locale


func _init_locales() -> void:
	var current_locale: String = TranslationServer.get_locale()
	for locale: String in TranslationServer.get_loaded_locales():
		TranslationServer.set_locale(locale)
		var text: String = TranslationServer.translate(LOCALE_TEXT_KEY)
		_locale_text_linked_map.add(locale, text)
	TranslationServer.set_locale(current_locale)
	_locale_text_linked_map.sort_by_values()
