# A set of wheels that follow along Tracks
#
# TrainVehicles generally have two of these
class_name TrainWheel
extends PathFollow2D

signal at_track_head(wheel: TrainWheel, extra: float, is_forward: bool)
signal at_track_tail(wheel: TrainWheel, extra: float, is_forward: bool)
signal moved(distance: float, leader_offset: float, leader_direction: Directions, leader_track: Track, leader_track_length: float)

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
	self._disconnect_from_track()
	self.get_parent().remove_child(self)
	track.add_child(self)
	self.current_track = track
	self.current_track_length = track.curve.get_baked_length()
	self.at_track_head.connect(track.emit_wheel_at_head)
	self.at_track_tail.connect(track.emit_wheel_at_tail)

# Set the direction of "forward travel" along the track to be towards the tail
func head_to_tail() -> void:
	self.direction = Directions.TAILWARD
	self.sprite.flip_v = false

# Set the direction of "forward travel" along the track to be towards the head
func tail_to_head() -> void:
	self.direction = Directions.HEADWARD
	self.sprite.flip_v = true

# Place this wheel a specific distance behind another one
func follow(leader: TrainWheel, distance: float) -> void:
	self.follow_distance = distance
	self.direction = leader.direction
	self.set_track(leader.current_track)
	self.progress = leader.progress
	self.move_as_follower(-distance, leader.progress, leader.direction, leader.current_track, leader.current_track_length)

# Move by some distance
func move(distance: float) -> void:
	if !self.current_track: return
	var original_offset := self.progress
	self.progress += distance if direction == Directions.TAILWARD else -distance
	self._change_track_if_end(original_offset, distance)
	self.moved.emit(distance, self.progress, self.direction, self.current_track, self.current_track_length)

# Jump to the predefined follow distance if there's room, or else just move the specified distance
func move_as_follower(distance: float, leader_offset: float, leader_direction: Directions, leader_track: Track, leader_track_length: float) -> void:
	if leader_offset > self.follow_distance && leader_offset < leader_track_length - self.follow_distance:
		if leader_track != self.current_track:
			self._put_on_leader_track(leader_track, leader_direction)
		self._set_at_distance_from_leader(distance, leader_offset, leader_direction)
	else:
		self.move(distance)

# Put on the same track, with same orientation, as the wheel it's following
func _put_on_leader_track(leader_track: Track, leader_direction: Directions) -> void:
	if leader_track != self.current_track:
		self.set_track(leader_track)
		self.head_to_tail() if leader_direction == Directions.TAILWARD else self.tail_to_head()

# Position exactly at predetermined distance from the wheel it's following
func _set_at_distance_from_leader(distance: float, leader_offset: float, leader_direction: Directions) -> void:
	var original_offset = self.progress
	self.progress = leader_offset + (-self.follow_distance if leader_direction == Directions.TAILWARD else follow_distance)
	self._change_track_if_end(original_offset, distance)
	self.moved.emit(distance, progress, direction, current_track, self.current_track_length)

# Signal that the wheel has reached the end of the segment
func _change_track_if_end(original_offset: float, distance_moved: float) -> void:
	if !self.current_track: return
	if self.progress_ratio <= 0:
		self.at_track_head.emit(self, abs(original_offset - abs(distance_moved)), distance_moved > 0)
	elif self.progress_ratio >= 1:
		self.at_track_tail.emit(self, original_offset + abs(distance_moved) - self.current_track_length, distance_moved > 0)

# Disconnect signals
func _disconnect_from_track() -> void:
	if self.current_track:
		self.at_track_head.disconnect(self.current_track.emit_wheel_at_head)
		self.at_track_tail.disconnect(self.current_track.emit_wheel_at_tail)
