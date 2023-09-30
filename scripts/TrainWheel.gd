# A set of wheels that follow along Tracks
#
# TrainVehicles generally have two of these
class_name TrainWheel
extends PathFollow2D

signal at_track_head
signal at_track_tail
signal moved

enum Directions {
	HEADWARD,
	TAILWARD,
}

var direction := Directions.TAILWARD
var follow_distance: float
var current_track: Track
var current_track_length: float
@onready var sprite := $Sprite2D

# Put the wheel on a track
func set_track(track: Path2D) -> void:
	_disconnect_from_track()
	get_parent().remove_child(self)
	track.add_child(self)
	current_track = track
	current_track_length = track.curve.get_baked_length()
	connect("at_track_head", Callable(track, "emit_wheel_at_head"))
	connect("at_track_tail", Callable(track, "emit_wheel_at_tail"))

# Set the direction of "forward travel" along the track to be towards the tail
func head_to_tail() -> void:
	direction = Directions.TAILWARD
	sprite.flip_v = false

# Set the direction of "forward travel" along the track to be towards the head
func tail_to_head() -> void:
	direction = Directions.HEADWARD
	sprite.flip_v = true

# Place this wheel a specific distance behind another one
func follow(leader, distance: float) -> void:
	follow_distance = distance
	direction = leader.direction
	set_track(leader.current_track)
	progress = leader.progress
	move_as_follower(-distance, leader.progress, leader.direction, leader.current_track, leader.current_track_length)

# Move by some distance
func move(distance: float) -> void:
	if !current_track: return
	var original_offset = progress
	progress += distance if direction == Directions.TAILWARD else -distance
	_change_track_if_end(original_offset, distance)
	emit_signal("moved", distance, progress, direction, current_track, current_track_length)

# Jump to the predefined follow distance if there's room, or else just move the specified distance
func move_as_follower(distance: float, leader_offset, leader_direction, leader_track, leader_track_length) -> void:
	if leader_offset > follow_distance && leader_offset < leader_track_length - follow_distance:
		if leader_track != current_track:
			_put_on_leader_track(leader_track, leader_direction)
		_set_at_distance_from_leader(distance, leader_offset, leader_direction)
	else:
		move(distance)

# Put on the same track, with same orientation, as the wheel it's following
func _put_on_leader_track(leader_track: Track, leader_direction: Directions) -> void:
	if leader_track != current_track:
		set_track(leader_track)
		head_to_tail() if leader_direction == Directions.TAILWARD else tail_to_head()

# Position exactly at predetermined distance from the wheel it's following
func _set_at_distance_from_leader(distance: float, leader_offset: float, leader_direction: Directions) -> void:
	var original_offset = progress
	progress = leader_offset + (-follow_distance if leader_direction == Directions.TAILWARD else follow_distance)
	_change_track_if_end(original_offset, distance)
	emit_signal("moved", distance, progress, direction, current_track, current_track_length)

# Signal that the wheel has reached the end of the segment
func _change_track_if_end(original_offset: float, distance_moved: float) -> void:
	if !current_track: return
	if progress_ratio <= 0:
		emit_signal("at_track_head", self, abs(original_offset - abs(distance_moved)), distance_moved > 0)
	elif progress_ratio >= 1:
		emit_signal("at_track_tail", self, original_offset + abs(distance_moved) - current_track_length, distance_moved > 0)

# Disconnect signals
func _disconnect_from_track() -> void:
	if current_track:
		disconnect("at_track_head", Callable(current_track, "emit_wheel_at_head"))
		disconnect("at_track_tail", Callable(current_track, "emit_wheel_at_tail"))
