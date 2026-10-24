extends Resource
## One authored sound identity per creature. Streaming belongs to WorldAudio.
@export var presence: AudioStream
@export_range(-50.0, 0.0) var volume_db := -18.0
@export_range(4.0, 60.0) var audible_distance := 26.0
@export var caption := "[Una presencia retumba cerca]"
## Its dread aura (dread_aura.use_profile()): from how far it starts and where
## it is full, whether it breathes, its clicks (empty: the aura's own) and how
## far over the point it is felt from the ear sits. The defaults are The
## Locust's aura as it always was.
@export var aura_start := 30.0
@export var aura_full := 4.0
@export var aura_breath := true
@export var aura_clicks: Array[AudioStream] = []
@export var aura_rise := 1.5
