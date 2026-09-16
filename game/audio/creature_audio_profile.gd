extends Resource
## One authored sound identity per creature. Streaming belongs to WorldAudio.
@export var presence: AudioStream
@export_range(-50.0, 0.0) var volume_db := -18.0
@export_range(4.0, 60.0) var audible_distance := 26.0
@export var caption := "[Una presencia retumba cerca]"
