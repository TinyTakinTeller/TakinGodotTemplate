extends Node
## The MusicManager is responsible for all music in your game.
##
## It manages the playback of music tracks, which are constructed with one or more
## stems. Each stem can be independently enabled or disabled, allowing for more dynamic
## playback. Music tracks can also be crossfaded when switching from one to another.
##
## @tutorial(View example scenes): https://github.com/hugemenace/resonate/tree/main/examples


const ResonateSettings = preload("../shared/resonate_settings.gd")
var _settings = ResonateSettings.new()

## Emitted only once when the MusicManager has finished setting up and 
## is ready to play music tracks and enable and disable stems.
signal loaded

## Emitted every time the MusicManager detects that a MusicBank has
## been added or removed from the scene tree.
signal banks_updated

## Emitted whenever [signal MusicManager.loaded] or 
## [signal MusicManager.pools_updated] is emitted.
signal updated

## Whether the MusicManager has completed setup and is ready to
## play music tracks and enable and disable stems.
var has_loaded: bool = false

var _music_table: Dictionary = {}
var _music_table_hash: int
var _music_streams: Array[StemmedMusicStreamPlayer] = []
var _volume: float


# ------------------------------------------------------------------------------
# Lifecycle methods
# ------------------------------------------------------------------------------


func _init():
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_auto_add_music()
	
	var scene_root = get_tree().root.get_tree()
	scene_root.node_added.connect(_on_scene_node_added)
	scene_root.node_removed.connect(_on_scene_node_removed)


func _process(_p_delta) -> void:
	if _music_table_hash != _music_table.hash():
		_music_table_hash = _music_table.hash()
		banks_updated.emit()
		updated.emit()
		
	if has_loaded:
		return
		
	has_loaded = true
	loaded.emit()
	updated.emit()


# ------------------------------------------------------------------------------
# Public methods
# ------------------------------------------------------------------------------


## Play a music track from a SoundBank, and optionally fade-in or crossfade over
## the provided [b]p_crossfade_time[/b]. If [b]p_auto_loop[/b] is set, the track 
## will be automatically played again once its longest stem is about to finish playing,
## taking into account the amount of time required to crossfade into the next loop.
func play(p_bank_label: String, p_track_name: String, p_crossfade_time: float = 5.0, p_auto_loop: bool = false) -> bool:
	if not has_loaded:
		push_error("Resonate - The music track [%s] on bank [%s] can't be played as the MusicManager has not loaded yet. Use the [loaded] signal/event to determine when it is ready." % [p_track_name, p_bank_label])
		return false
		
	if not _music_table.has(p_bank_label):
		push_error("Resonate - Tried to play the music track [%s] from an unknown bank [%s]." % [p_track_name, p_bank_label])
		return false
		
	if not _music_table[p_bank_label]["tracks"].has(p_track_name):
		push_error("Resonate - Tried to play an unknown music track [%s] from the bank [%s]." % [p_track_name, p_bank_label])
		return false
	
	var bank = _music_table[p_bank_label] as Dictionary
	var track = bank["tracks"][p_track_name] as Dictionary
	var stems = track["stems"] as Array
	
	if stems.size() == 0:
		push_error("Resonate - The music track [%s] on bank [%s] has no stems, you'll need to add one at minimum." % [p_track_name, p_bank_label])
		return false
		
	for stem in stems:
		if stem.stream == null:
			push_error("Resonate - The stem [%s] on the music track [%s] on bank [%s] does not have an audio stream, you'll need to add one." % [stem.name, p_track_name, p_bank_label])
			return false
			
		if not p_auto_loop and not ResonateUtils.is_stream_looped(stem.stream):
			push_warning("Resonate - The stem [%s] on the music track [%s] on bank [%s] is not set to loop, which will cause it to work incorrectly." % [stem.name, p_track_name, p_bank_label])
	
	var bus = _get_bus(bank.bus, track.bus)
	var player = StemmedMusicStreamPlayer.create(p_bank_label, p_track_name, bus, bank.mode, _volume, p_auto_loop)

	if _music_streams.size() > 0:
		for stream in _music_streams:
			stream.stop_stems(p_crossfade_time)
	
	_music_streams.append(player)
	
	add_child(player)
	
	player.start_stems(stems, p_crossfade_time)
	player.stopped.connect(_on_player_stopped.bind(player))
	
	if p_auto_loop:
		player.auto_loop_completed.connect(_on_auto_loop_completed, CONNECT_REFERENCE_COUNTED)
	
	return true


## Check whether the MusicManager is playing from a specific bank, or any track
## with the given name, or more specifically a certain track from a certain bank.
func is_playing(p_bank_label: String = "", p_track_name: String = "") -> bool:
	if not has_loaded:
		return false
	
	if _music_streams.size() == 0:
		return false
		
	var current_player = _get_current_player()
	var is_playing = not current_player.is_stopping
	var bank_label = current_player.bank_label
	var track_name = current_player.track_name
	
	if p_bank_label == "" and p_track_name == "":
		return is_playing
		
	if p_bank_label != "" and p_track_name == "":
		return bank_label == p_bank_label and is_playing
		
	if p_bank_label == "" and p_track_name != "":
		return track_name == p_track_name and is_playing
		
	return bank_label == p_bank_label and track_name == p_track_name and is_playing


## Stop the playback of all music.
func stop(p_fade_time: float = 5.0) -> void:
	if not _is_playing_music():
		push_warning("Resonate - Cannot stop the music track as there is no music currently playing.")
		return
		
	var current_player = _get_current_player()
	
	current_player.stop_stems(p_fade_time)


## Check whether the MusicManager should skip playing a new track. It will return true if the 
## MusicManager has not loaded yet, or if the flag you provide is not [b]false[/b] or [b]null[/b].
func should_skip_playing(p_flag) -> bool:
	return not has_loaded or (p_flag != false and p_flag != null)


## Set the volume of the current music track (if playing) and all future tracks to be played.
func set_volume(p_volume: float) -> void:
	_volume = p_volume
	
	if not _is_playing_music():
		return
		
	var current_player = _get_current_player()
	
	current_player.set_volume(_volume)


## Enable the specified stem on the currently playing music track.
func enable_stem(p_name: String, p_fade_time: float = 2.0) -> void:
	_set_stem(p_name, true, p_fade_time)


## Disable the specified stem on the currently playing music track.
func disable_stem(p_name: String, p_fade_time: float = 2.0) -> void:
	_set_stem(p_name, false, p_fade_time)


## Set the volume for the specified stem on the currently playing music track.
func set_stem_volume(p_name: String, p_volume: float) -> void:
	if not _is_playing_music():
		push_warning("Resonate - Cannot set the volume of stem [%s] as there is no music currently playing." % p_name)
		return
		
	var current_player = _get_current_player()
	
	current_player.set_stem_volume(p_name, p_volume)


## Get the underlying details of the provided stem for the currently playing music track.
func get_stem_details(p_name: String) -> Variant:
	if not _is_playing_music():
		push_warning("Resonate - Cannot get the details for stem [%s] as there is no music currently playing." % p_name)
		return
		
	var current_player = _get_current_player()
	
	return current_player.get_stem_details(p_name)


## Will automatically stop the provided music track when the provided 
## [b]p_base[/b] is removed from the scene tree.
func stop_on_exit(p_base: Node, p_bank_label: String, p_track_name: String, p_fade_time: float = 5.0) -> void:
	p_base.tree_exiting.connect(_on_music_player_exiting.bind(p_bank_label, p_track_name, p_fade_time))


## Will automatically stop the provided music track when the provided 
## [b]p_base[/b] is removed from the scene tree.[br][br]
## [b]Note:[/b] This method has been deprecated, please use [method MusicManager.stop_on_exit] instead.
## @deprecated
func auto_stop(p_base: Node, p_bank_label: String, p_track_name: String, p_fade_time: float = 5.0) -> void:
	push_warning("Resonate - auto_stop has been deprecated, please use stop_on_exit instead.")
	stop_on_exit(p_base, p_bank_label, p_track_name, p_fade_time)


## Manually add a new SoundBank into the music track cache.
func add_bank(p_bank: MusicBank) -> void:
	_add_bank(p_bank)


## Remove the provided bank from the music track cache.
func remove_bank(p_bank_label: String) -> void:
	if not _music_table.has(p_bank_label):
		return
		
	_music_table.erase(p_bank_label)


## Clear all banks from the music track cache.
func clear_banks() -> void:
	_music_table.clear()


# ------------------------------------------------------------------------------
# Private methods
# ------------------------------------------------------------------------------


func _on_scene_node_added(p_node: Node) -> void:
	if not p_node is MusicBank:
		return
		
	_add_bank(p_node)
	
	
func _on_scene_node_removed(p_node: Node) -> void:
	if not p_node is MusicBank:
		return
		
	_remove_bank(p_node)


func _auto_add_music() -> void:
	var music_banks = ResonateUtils.find_all_nodes(self, "MusicBank")
	
	for music_bank in music_banks:
		_add_bank(music_bank)
		
	_music_table_hash = _music_table.hash()


func _add_bank(p_bank: MusicBank) -> void:
	if _music_table.has(p_bank.label):
		_music_table[p_bank.label]["ref_count"] = \
				_music_table[p_bank.label]["ref_count"] + 1
		
		return
		
	_music_table[p_bank.label] = {
		"name": p_bank.label,
		"bus": p_bank.bus,
		"mode": p_bank.mode,
		"tracks": _create_tracks(p_bank.tracks),
		"ref_count": 1,
	}


func _remove_bank(p_bank: MusicBank) -> void:
	if not _music_table.has(p_bank.label):
		return
	
	if _music_table[p_bank.label]["ref_count"] == 1:
		_music_table.erase(p_bank.label)
		return
	
	_music_table[p_bank.label]["ref_count"] = \
			_music_table[p_bank.label]["ref_count"] - 1


func _create_tracks(p_tracks: Array[MusicTrackResource]) -> Dictionary:
	var tracks = {}
	
	for track in p_tracks:
		tracks[track.name] = {
			"name": track.name,
			"bus": track.bus,
			"stems": _create_stems(track.stems),
		}

	return tracks


func _create_stems(p_stems: Array[MusicStemResource]) -> Array:
	var stems = []
	
	for stem in p_stems:
		stems.append({
			"name": stem.name,
			"enabled": stem.enabled,
			"volume": stem.volume,
			"stream": stem.stream,
		})
		
	return stems


func _get_bus(p_bank_bus: String, p_track_bus: String) -> String:
	if p_track_bus != null and p_track_bus != "":
		return p_track_bus
	
	if p_bank_bus != null and p_bank_bus != "":
		return p_bank_bus
		
	return ProjectSettings.get_setting(
		_settings.MUSIC_BANK_BUS_SETTING_NAME,
		_settings.MUSIC_BANK_BUS_SETTING_DEFAULT)


func _is_playing_music() -> bool:
	return _music_streams.size() > 0


func _get_current_player() -> StemmedMusicStreamPlayer:
	if _music_streams.size() == 0:
		return null
		
	return _music_streams.back() as StemmedMusicStreamPlayer


func _set_stem(p_name: String, p_enabled: bool, p_fade_time: float) -> void:
	if not _is_playing_music():
		push_warning("Resonate - Cannot toggle the stem [%s] as there is no music currently playing." % p_name)
		return
		
	var current_player = _get_current_player()
	
	current_player.toggle_stem(p_name, p_enabled, p_fade_time)


func _on_music_player_exiting(p_bank_label: String, p_track_name: String, p_fade_time: float) -> void:
	if not is_playing(p_bank_label, p_track_name):
		return
	
	stop(p_fade_time)


func _on_player_stopped(p_player: StemmedMusicStreamPlayer) -> void:
	if not _is_playing_music():
		return
		
	_music_streams.erase(p_player)
	remove_child(p_player)


func _on_auto_loop_completed(p_bank_label: String, p_track_name: String, p_crossfade_time: float) -> void:
	play(p_bank_label, p_track_name, p_crossfade_time, true)
