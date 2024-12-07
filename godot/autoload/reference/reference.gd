## Preloads all resources (.tres files) in /resources.
## Holds references to resources in dictionary by name as key.
## The key also holds a prefix to avoid conflicts of equal names across different resources types.
extends Node

const RESOURCE_EXTENSION = ".tres"

var _resource_references: Dictionary = {}


func _ready() -> void:
	Log.debug("AUTOLOAD READY: ", name)

	var paths: Array[String] = FileSystemUtils.get_paths(PathConsts.RESOURCES, RESOURCE_EXTENSION)
	_resource_references = _load_resources(paths)


func get_scene_manager_options(resource_id: String) -> SceneManagerOptions:
	return get_resource(resource_id, SceneManagerOptions)


func get_resource(resource_id: String, type: Variant) -> Resource:
	var key: String = _get_key(resource_id, type)
	return _resource_references[key]


static func _load_resources(paths: Array[String]) -> Dictionary:
	var resource_references: Dictionary = {}
	for path: String in paths:
		var resource: Resource = load(path) as Resource
		if resource != null:
			var resource_id: String = FileSystemUtils.get_file_name(path)
			var key: String = _get_key(resource_id, _get_type(resource))
			if resource_references.has(key):
				Log.warn("Duplicate resource reference key: ", key)
				continue
			resource_references[key] = resource
			Log.debug("Success to load resource reference key: ", key)
		else:
			Log.warn("Failed to load resource reference at: ", path)
	return resource_references


static func _get_type(resource: Resource) -> Variant:
	return resource.get_script()


static func _get_key(resource_id: String, type: Variant) -> String:
	return type.get_global_name() + "-" + resource_id
