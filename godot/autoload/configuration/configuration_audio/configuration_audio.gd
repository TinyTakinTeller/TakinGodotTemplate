## Original File MIT License Copyright (c) 2024 TinyTakinTeller
##
## Tracks volume on the scale from 0 to 100.
##
## MusicBank holds references to music tracks that can be played by MusicManager.
class_name ConfigurationAudio
extends Node

const AUDIO_BUS_MASTER_NAME: String = "Master"
const AUDIO_BUS_MUSIC_NAME: String = "Music"
const AUDIO_BUS_SFX_NAME: String = "SFX"

var audio_bus_master_index: int = AudioServer.get_bus_index(AUDIO_BUS_MASTER_NAME)
var audio_bus_music_index: int = AudioServer.get_bus_index(AUDIO_BUS_MUSIC_NAME)
var audio_bus_sfx_index: int = AudioServer.get_bus_index(AUDIO_BUS_SFX_NAME)


func _ready() -> void:
	_load_audio_server()


func get_master_volume() -> float:
	return _get_audio_server_volume(audio_bus_master_index)


func get_music_volume() -> float:
	return _get_audio_server_volume(audio_bus_music_index)


func get_sfx_volume() -> float:
	return _get_audio_server_volume(audio_bus_sfx_index)


func get_audio_enabled() -> bool:
	return _get_audio_server_audio_enabled(audio_bus_master_index)


func set_master_volume(volume: float) -> void:
	_set_audio_server_volume(volume, audio_bus_master_index)
	ConfigStorageSettingsAudio.set_master_volume(volume)


func set_music_volume(volume: float) -> void:
	_set_audio_server_volume(volume, audio_bus_music_index)
	ConfigStorageSettingsAudio.set_music_volume(volume)


func set_sfx_volume(volume: float) -> void:
	_set_audio_server_volume(volume, audio_bus_sfx_index)
	ConfigStorageSettingsAudio.set_sfx_volume(volume)


func set_audio_enabled(enabled: bool) -> void:
	_set_audio_server_audio_enabled(enabled, audio_bus_master_index)
	ConfigStorageSettingsAudio.set_audio_enabled(enabled)


func reset() -> void:
	ConfigStorageSettingsAudio.delete()
	_load_audio_server()


func _get_audio_server_volume(bus_index: int) -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(bus_index)) * 100


func _get_audio_server_audio_enabled(bus_index: int) -> bool:
	return not AudioServer.is_bus_mute(bus_index)


func _set_audio_server_volume(volume: float, bus_index: int) -> void:
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(volume / 100))


func _set_audio_server_audio_enabled(enabled: bool, bus_index: int) -> void:
	AudioServer.set_bus_mute(bus_index, not enabled)


func _load_audio_server() -> void:
	var master_volume: float = ConfigStorageSettingsAudio.get_master_volume()
	var music_volume: float = ConfigStorageSettingsAudio.get_music_volume()
	var sfx_volume: float = ConfigStorageSettingsAudio.get_sfx_volume()
	var audio_enabled: bool = ConfigStorageSettingsAudio.get_audio_enabled()

	AudioServer.set_bus_volume_db(audio_bus_master_index, linear_to_db(master_volume / 100))
	AudioServer.set_bus_volume_db(audio_bus_music_index, linear_to_db(music_volume / 100))
	AudioServer.set_bus_volume_db(audio_bus_sfx_index, linear_to_db(sfx_volume / 100))
	AudioServer.set_bus_mute(audio_bus_master_index, not audio_enabled)
