class_name TrackJunction extends Area2D

@export var parent: NodePath
@export var side: Track.Directions
@export var enabled := true

@onready var track = self.get_node(parent)

func _on_TrackJunction_area_entered(area: Area2D) -> void:
	if !self.enabled || !area.is_in_group("track_junctions"): return
	# we know this is a junction because of the group
	var junction := area as TrackJunction
	if !junction.enabled: return
	self.track.link_track(junction.track, self.side, junction.side)
	self.enabled = false
	junction.enabled = false
