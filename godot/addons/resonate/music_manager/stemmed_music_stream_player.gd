class_name StemmedMusicStreamPlayer
extends AudioStreamPlayer
## An extended AudioStreamPlayer capable of managing and playing a 
## collection of stems that make up a music track.


## Emitted when this player has completely stopped playing a track.
signal stopped

## Emitted when this player has finished the current auto-loop and should begin playback again.
signal auto_loop_completed(p_bank_label: String, p_track_name: String, p_crossfade_time: float)

## True when this player is in the process of shutting down and stopping a track.
var is_stopping: bool

## The label of the bank that this player's track came from.
var bank_label: String

## The name of the track associated with this player.
var track_name: String

const _DISABLED_VOLUME: float = -80
const _START_TRANS: Tween.TransitionType = Tween.TRANS_QUART
const _START_EASE: Tween.EaseType = Tween.EASE_OUT
const _STOP_TRANS: Tween.TransitionType = Tween.TRANS_QUART
const _STOP_EASE: Tween.EaseType = Tween.EASE_IN

var _fade_tween: Tween
var _stem_table: Dictionary
var _max_volume: float
var _crossfade_time: float
var _auto_loop: bool
var _track_length: float
var _current_play_time: float
var _loop_endpoint_reached_emitted: bool


# ------------------------------------------------------------------------------
# Public methods
# ------------------------------------------------------------------------------


func _process(p_delta):
	if is_stopping:
		return
	
	if not _auto_loop:
		return
	
	if _loop_endpoint_reached_emitted:
		return
	
	_current_play_time += p_delta
	if _current_play_time >= (_track_length - _crossfade_time):
		auto_loop_completed.emit(bank_label, track_name, _crossfade_time)
		_loop_endpoint_reached_emitted = true


# ------------------------------------------------------------------------------
# Public methods
# ------------------------------------------------------------------------------


## Create a new player associated with a given bank and track.
static func create(p_bank_label: String, p_track_name: String, p_bus: String, p_mode: Node.ProcessMode, p_max_volume: float, p_auto_loop: bool) -> StemmedMusicStreamPlayer:
	var player = StemmedMusicStreamPlayer.new()
	var stream = AudioStreamPolyphonic.new()
	
	player.bank_label = p_bank_label
	player.track_name = p_track_name
	player.stream = stream
	player.process_mode = p_mode
	player.bus = p_bus
	player.volume_db = _DISABLED_VOLUME
	player.is_stopping = false
	player._max_volume = p_max_volume
	player._auto_loop = p_auto_loop
	
	return player


## Start the collection of stems associated with the track on this player.
## This is what fundamentally starts the music track.[br][br]
## [b]Note:[/b] this should only be called once.
func start_stems(p_stems: Array, p_crossfade_time: float) -> void:
	if playing:
		return
		
	stream.polyphony = p_stems.size()
	max_polyphony = p_stems.size()
	
	play()
	
	var playback = get_stream_playback() as AudioStreamPlaybackPolyphonic
	var max_length = 0
	
	for stem in p_stems:
		var stream = stem.stream as AudioStream
		var length = stream.get_length()
		if length > max_length:
			max_length = length
		
		var stream_id = playback.play_stream(stem.stream, 0, 1.0, pitch_scale, playback_type, bus)
		var max_volume = stem.volume
		var volume = max_volume if stem.enabled else _DISABLED_VOLUME
		
		playback.set_stream_volume(stream_id, volume)
		
		_stem_table[stem.name] = {
			"name": stem.name,
			"enabled": stem.enabled,
			"stream_id": stream_id,
			"volume": volume,
			"max_volume": max_volume,
			"tween": null,
		}
	
	_track_length = max_length
	_crossfade_time = p_crossfade_time
	
	_fade_tween = create_tween()
	_fade_tween \
			.tween_property(self, "volume_db", _max_volume, p_crossfade_time) \
			.set_trans(_START_TRANS) \
			.set_ease(_START_EASE)
	

## Toggle (enable or disable) the specified stem associated with the track on this player.
func toggle_stem(p_name: String, p_enabled: bool, p_fade_time: float) -> void:
	if not _stem_table.has(p_name):
		push_warning("Resonate - Cannot toggle the stem [%s] on music track [%s] from bank [%s] as it does not exist." % [p_name, track_name, bank_label])
		return
		
	var playback = get_stream_playback() as AudioStreamPlaybackPolyphonic
	var stem = _stem_table[p_name]
	var old_tween = stem.tween as Tween
	var new_tween = create_tween()
	var target_volume = stem.max_volume if p_enabled else _DISABLED_VOLUME
	
	if old_tween != null:
		old_tween.kill()
	
	_stem_table[p_name]["tween"] = new_tween
	_stem_table[p_name]["enabled"] = p_enabled
	
	var transition = _START_TRANS if p_enabled else _STOP_TRANS
	var easing = _START_EASE if p_enabled else _STOP_EASE
	
	new_tween \
			.tween_method(_tween_stem_volume.bind(p_name), stem.volume, target_volume, p_fade_time) \
			.set_trans(transition) \
			.set_ease(easing)


## Set the volume of this player.[br][br]
## [b]Note:[/b] if called when the player is still fading in or out, it will 
## immediately cancel the fade and set the volume at specified level.
func set_volume(p_volume: float) -> void:
	if _fade_tween != null and _fade_tween.is_running():
		_fade_tween.kill()
		
	_max_volume = p_volume
	volume_db = p_volume
	

## Set the volume of a specific stem associated with this track.[br][br]
## [b]Note:[/b] if called when the stem is still fading in or out, it will 
## immediately cancel the fade and set the volume at specified level.
func set_stem_volume(p_name: String, p_volume: float) -> void:
	var playback = get_stream_playback() as AudioStreamPlaybackPolyphonic
	var stem = _stem_table[p_name]
	
	if stem["tween"] != null and stem["tween"].is_running():
		stem["tween"].kill()
	
	playback.set_stream_volume(stem.stream_id, p_volume)
	
	_stem_table[p_name]["volume"] = p_volume
	_stem_table[p_name]["max_volume"] = p_volume


## This will stop all stems associated with this player, causing it to shut-down and stop.
func stop_stems(p_fade_time: float) -> void:
	if is_stopping:
		return
		
	is_stopping = true
	
	var tween = create_tween()
	tween \
			.tween_property(self, "volume_db", _DISABLED_VOLUME, p_fade_time) \
			.set_trans(_STOP_TRANS) \
			.set_ease(_STOP_EASE)
	
	tween.finished.connect(_on_stop_stems_tween_finished)


## Get the underlying details of the provided stem for the currently playing music track.
func get_stem_details(p_name: String) -> Variant:
	if not _stem_table.has(p_name):
		push_warning("Resonate - Cannot get the details for stem [%s] on music track [%s] from bank [%s] as it does not exist." % [p_name, track_name, bank_label])
		return null
		
	var stem = _stem_table[p_name]
	
	return {
		"name": stem.name,
		"enabled": stem.enabled,
		"volume": stem.volume,
	}


# ------------------------------------------------------------------------------
# Private methods
# ------------------------------------------------------------------------------


func _tween_stem_volume(p_target_volume: float, p_name: String) -> void:
	var playback = get_stream_playback() as AudioStreamPlaybackPolyphonic
	var stem = _stem_table[p_name]
	
	playback.set_stream_volume(stem.stream_id, p_target_volume)
	
	_stem_table[p_name]["volume"] = p_target_volume


func _on_stop_stems_tween_finished() -> void:
	stopped.emit()
