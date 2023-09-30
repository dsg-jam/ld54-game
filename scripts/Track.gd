@tool
# A piece of track that TrainWheel nodes follow along
class_name Track extends Path2D

signal wheel_at_head(wheel: TrainWheel, extra: float, is_forward: bool)
signal wheel_at_tail(wheel: TrainWheel, extra: float, is_forward: bool)

enum Directions {
	LEFT,
	RIGHT,
	HEAD,
	TAIL,
}

const TRACK_LINE_POINTS: int = 56

@export var crosstie_distance: int = 10
@onready var _crosstie_mesh_instance: MeshInstance2D = $Crosstie
@onready var _crosstie_multimesh: MultiMeshInstance2D = $MultiMeshInstance2D
@onready var _track_line: Line2D = $TrackLine

func _ready() -> void:
	self._draw_line()
	self._update_sprites()

func _draw_line() -> void:
	for i in range(TRACK_LINE_POINTS):
		self._track_line.add_point(Vector2((256.0/float(TRACK_LINE_POINTS)) * float(i), 0.0))

func wheel_at_signal(dir: Directions) -> Signal:
	match dir:
		Directions.HEAD:
			return self.wheel_at_head
		Directions.TAIL:
			return self.wheel_at_tail
		_:
			push_error("invalid direction for track wheel")
			return Signal()

func enter_from_callable(dir: Directions) -> Callable:
	match dir:
		Directions.HEAD:
			return self.enter_from_head
		Directions.TAIL:
			return self.enter_from_tail
		_:
			push_error("invalid direction for track enter")
			return Callable()


# Connect the "from_side" of this track to the "to_side" of the other track
#
# This links both tracks to each other, so only call it once per connection
func link_track(other_track: Track, from_side: Directions, to_side: Directions) -> void:
	self.wheel_at_signal(from_side).connect(other_track.enter_from_callable(to_side))
	other_track.wheel_at_signal(to_side).connect(self.enter_from_callable(from_side))

# A wheel enters from the head side
func enter_from_head(wheel: TrainWheel, extra: float, is_forward: bool) -> void:
	wheel.set_track(self)
	wheel.progress = extra
	wheel.head_to_tail() if is_forward else wheel.tail_to_head()

# A wheel enters from the tail side
func enter_from_tail(wheel: TrainWheel, extra: float, is_forward: bool) -> void:
	wheel.set_track(self)
	wheel.progress_ratio = 1
	wheel.progress -= extra
	wheel.tail_to_head() if is_forward else wheel.head_to_tail()

# The wheel has reached the head
func emit_wheel_at_head(wheel: TrainWheel, extra: float, is_forward: bool) -> void:
	self.wheel_at_head.emit(wheel, extra, is_forward)

# The wheel has reached the tail
func emit_wheel_at_tail(wheel: TrainWheel, extra: float, is_forward: bool) -> void:
	self.wheel_at_tail.emit(wheel, extra, is_forward)

func _update_sprites() -> void:
	self._track_line.points = self.curve.get_baked_points()
	self._update_crossties()
	$HeadPoint.progress_ratio = 0
	$TailPoint.progress_ratio = 1

func _update_crossties() -> void:
	var crossties := _crosstie_multimesh.multimesh
	crossties.mesh = _crosstie_mesh_instance.mesh
	
	var curve_length := curve.get_baked_length()
	var crosstie_count: int = round(curve_length / crosstie_distance)
	crossties.instance_count = crosstie_count
	
	for i in range(crosstie_count):
		var t := Transform2D()
		var crosstie_position := curve.sample_baked((i * crosstie_distance) + crosstie_distance/2.0)
		var next_position := curve.sample_baked((i + 1) * crosstie_distance)
		t = t.rotated((next_position - crosstie_position).normalized().angle())
		t.origin = crosstie_position
		crossties.set_instance_transform_2d(i, t)
