# Similar to TrainVehicle but it applies power to its front wheel
class_name TrainEngine extends TrainVehicle

signal train_info(info: Dictionary)
signal entered_station(train: TrainEngine, station: TrainStation)
signal left_station(train: TrainEngine, station: TrainStation)

@export var color: Color
@export var max_force: float = 1000
@export var gravity: float = 9.8
@export var brake_power: float = 50

const SAFETY_STOP_MARGIN: float = 15.0
const LOOK_AHEAD_TRACKS: int = 10
const DELTA_BRAKING_DISTANCE: float = 10.0

enum TrainState {
	Conducting,
	Braking
}

var _state: TrainState = TrainState.Conducting
var _next_stop_distance: float = INF
var _is_positive_velocity: bool = true
var _is_braking: bool = false

var friction_force: float
var target_force_percent: float = 0
var applied_force: float = 0
var brake_force: float = 0
var velocity: float = 0

func _ready() -> void:
	self.set_color(self.color)
	super._ready()
	self.front_wheel.new_track_entered.connect(self._on_track_entered)

func set_color(new_color: Color) -> void:
	self.color = new_color
	super.set_color(new_color)

func connect_tracks_controller(tracks_controller: TracksController) -> void:
	tracks_controller.track_changed.connect(self._on_track_change)

# Update the friction forces that depend on mass when the towed mass changes
func change_towed_mass(mass_delta: float) -> void:
	super.change_towed_mass(mass_delta)

# Emit a signal to update the HUD
func _process(delta: float) -> void:
	super._process(delta)
	self._update_throttle()
	self._update_auto_stop_break()
	self.train_info.emit({
		"throttle": target_force_percent,
		"force_applied": applied_force,
		"force_max": max_force,
		"brake": brake_force,
		"total_mass": total_mass,
		"velocity": velocity,
		"friction": friction_force,
	})

# Apply forces
func _physics_process(delta: float) -> void:
	self._updated_applied_force(delta)
	if self.velocity != 0 or self.applied_force != 0:
		self._move_with_friction(delta)
	else:
		if self._is_stop_signal():
			self._state = TrainState.Braking
		else:
			self._state = TrainState.Conducting

func _is_stop_signal() -> bool:
	var current_track = self.front_wheel.current_track
	if current_track.is_in_group("left_track"):
		return false
	if current_track.is_in_group("right_track"):
		return false
	var from = self._get_track_entry_dir(current_track)
	var to = self._get_track_end_dir(from, current_track)
	if to == Track.Directions.HEAD:
		if current_track.head_signal_enabled and current_track.head_signal:
			return true
	if to == Track.Directions.TAIL:
		if current_track.tail_signal_enabled and current_track.tail_signal:
			return true
	return false

# Set the "throttle lever" position
func _update_throttle() -> void:
	if self._state == TrainState.Conducting:
		self.target_force_percent = 1.0
		self.brake_force = 0.0
	else:
		self.target_force_percent = 0.0
		self.brake_force = 1.0
		self.applied_force = 0.0

# Move the front wheel by the applied force, minus friction forces
func _move_with_friction(delta: float) -> void:
	var resistance := 0
	if self.applied_force == 0 && abs(self.velocity) < resistance / self.total_mass * delta:
		self.velocity = 0
	else:
		if self.velocity > 0:
			self.velocity = self.velocity + ((self.applied_force - resistance) / self.total_mass * delta)
		elif self.velocity < 0:
			self.velocity = self.velocity + ((self.applied_force + resistance) / self.total_mass * delta)
		else:
			self.velocity = self.velocity + (self.applied_force / self.total_mass * delta)
	self._apply_brake(delta)
	self.front_wheel.move(self.velocity * delta)
	self._detect_change_in_direction()

func _detect_change_in_direction():
	if self.velocity >= 0 and !self._is_positive_velocity:
		self._calc_distance_to_next_stop()
	elif self.velocity < 0 and self._is_positive_velocity:
		self._calc_distance_to_next_stop()
	self._is_positive_velocity = self.velocity >= 0

# Lerp the actual engine force from its current value to the throttle position
func _updated_applied_force(delta: float) -> void:
	self.applied_force = lerp(float(self.applied_force), float(self.max_force * self.target_force_percent), delta)
	if abs(self.applied_force) < 0.1: self.applied_force = 0

# Reduce the velocity based on applied brake power
func _apply_brake(delta: float) -> void:
	if self.velocity == 0: return
	elif self.velocity > 0:
		self.velocity = max(self.velocity - self.brake_force * self.brake_power * delta, 0)
	elif self.velocity < 0:
		self.velocity = min(self.velocity + self.brake_force * self.brake_power * delta, 0)

func _update_auto_stop_break() -> void:
	var braking_distance = self._get_braking_distance() + SAFETY_STOP_MARGIN
	var remaining_distance = self._next_stop_distance - self._get_covered_track_distance()
	if !self._is_braking and (remaining_distance <= braking_distance):
		self._is_braking = true
		self._state = TrainState.Braking
	if self._is_braking and remaining_distance > braking_distance and braking_distance > DELTA_BRAKING_DISTANCE:
		self._state = TrainState.Conducting
		self._is_braking = false

func _get_braking_distance() -> float:
	var time_to_stop = self.velocity / self.brake_power
	return time_to_stop * self.velocity / 2.0

func _origins_from_head() -> bool:
	if self.front_wheel.direction == TrainWheel.Directions.HEADWARD and self.velocity < 0:
		return true
	if self.front_wheel.direction == TrainWheel.Directions.TAILWARD and self.velocity >= 0:
		return true
	return false

func _get_track_entry_dir(track: Track) -> Track.Directions:
	if self._origins_from_head():
		return Track.Directions.HEAD
	if track.owner.is_in_group("track_switch"):
		if track.is_in_group("right_track"):
			return Track.Directions.RIGHT
		return Track.Directions.LEFT
	return Track.Directions.TAIL

# Returns the covered distance of the current track
func _get_covered_track_distance() -> float:
	if self._origins_from_head():
		return (self.front_wheel.progress_ratio) * self.front_wheel.current_track_length
	return (1.0-self.front_wheel.progress_ratio) * self.front_wheel.current_track_length

func _get_track_end_dir(from_dir: Track.Directions, track) -> Track.Directions:
	if track.is_in_group("track_switch"):
		var track_switch = track as TrackSwitch
		if from_dir == Track.Directions.HEAD:
			return track_switch.direction
	if from_dir == Track.Directions.HEAD:
		return Track.Directions.TAIL
	return Track.Directions.HEAD

func _get_track_length(from_dir: Track.Directions, track) -> float:
	if track.is_in_group("track_switch"):
		var track_switch = track as TrackSwitch
		if from_dir == Track.Directions.HEAD:
			if track_switch.direction == Track.Directions.RIGHT:
				return track_switch.right_track.curve.get_baked_length()
			return track_switch.left_track.curve.get_baked_length()
		if from_dir == Track.Directions.RIGHT:
			return track_switch.right_track.curve.get_baked_length()
		return track_switch.left_track.curve.get_baked_length()
	return track.curve.get_baked_length()

func _is_stopping_track(dir: Track.Directions, track) -> bool:
	if track.is_in_group("train_station_track"):
		return true
	if track.is_in_group("track_switch"):
		return false
	
	if dir == Track.Directions.HEAD:
		return track.head_signal_enabled and track.head_signal
	elif dir == Track.Directions.TAIL:
		return track.tail_signal_enabled and track.tail_signal
	
	return false

# Calculates distance to next stop w/ current track length
func _calc_distance_to_next_stop() -> void:
	var track: Track = self.front_wheel.current_track
	if !track:
		return
	
	var distance = 0.0
	var from_dir = self._get_track_entry_dir(track)
	var to_dir = Track.Directions.HEAD
	
	var current_track = track
	if track.owner.is_in_group("track_switch"):
		current_track = track.owner
	
	for i in range(LOOK_AHEAD_TRACKS):
		to_dir = self._get_track_end_dir(from_dir, current_track)
		distance += self._get_track_length(from_dir, current_track)
		if self._is_stopping_track(to_dir, current_track):
			if self.velocity < 0:
				distance -= current_track.curve.get_baked_length()
			self._next_stop_distance = distance
			return
		from_dir = current_track.neighboring_tracks[to_dir][0]
		current_track = current_track.neighboring_tracks[to_dir][1]

func _on_track_change() -> void:
	self._calc_distance_to_next_stop()

func _on_track_entered() -> void:
	self._calc_distance_to_next_stop()

func _on_area_2d_area_entered(area: Area2D) -> void:
	if !area.is_in_group("train_station"): return
	self.entered_station.emit(self, area)

func _on_area_2d_area_exited(area: Area2D) -> void:
	if !area.is_in_group("train_station"): return
	self.left_station.emit(self, area)
