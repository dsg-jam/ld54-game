class_name TrainRoute extends Node2D

signal train_stopped(train: TrainEngine)
signal train_game_over(train: TrainEngine)

@export var tracks_controller: TracksController
@export var car_count: int = 1
@export var color: Color
@export var route_name: String
@export var route_objective: int = 3
@export var train_engine: PackedScene = load("res://prefabs/TrainEngine.tscn")
@export var train_vehicle: PackedScene = load("res://prefabs/TrainVehicle.tscn")

var _train: TrainEngine
var _stops: Array[TrainRouteStop]
var _stop_idx: int = -1 # -1 means the route is disabled

func _ready() -> void:
	self._stops.assign(self.find_children("*", "TrainRouteStop"))
	if self._stops.is_empty():
		push_warning("route with no stops")
		return

	var seen_stations := {}
	for stop in self._stops:
		if seen_stations.has(stop.station):
			continue
		seen_stations[stop.station] = null
		assert(stop.station.is_node_ready())
		stop.station.timeout.connect(self._on_station_timeout)

	self.spawn()

func spawn() -> void:
	assert(self.tracks_controller)

	self._stop_idx = 0
	self._choose_available_stop(false)
	var stop: TrainRouteStop = self._stops[self._stop_idx]
	
	var engine: TrainEngine = self.train_engine.instantiate()
	self.add_child(engine)
	engine.connect_tracks_controller(self.tracks_controller)
	engine.add_to_track(stop.station.get_node("Track"), 500)
	engine.set_color(self.color)

	var last_car: TrainVehicle = engine
	for index in range(car_count):
		var car: TrainVehicle = self.train_vehicle.instantiate()
		self.add_child(car)
		last_car.set_follower_car(car)
		last_car = car

	self._set_train(engine)

func _set_train(new_train: TrainEngine) -> void:
	assert(new_train)
	assert(new_train.color == self.color) # since we can't change the color at this point
	self._train = new_train
	self._train.entered_station.connect(self._on_train_entered_station)
	self._train.left_station.connect(self._on_train_left_station)
	self._train.crashed.connect(self._on_train_crashed)
	self._activate_stop()

func is_disabled() -> bool:
	return self._stop_idx < 0 || !self._train

func _on_train_entered_station(incoming_train: TrainEngine, station: TrainStation) -> void:
	var stop: TrainRouteStop = self._stops[self._stop_idx]
	if self.is_disabled() || incoming_train != self._train || station != stop.station:
		return
	self.train_stopped.emit(incoming_train)
	station.reset()

func _on_train_left_station(leaving_train: TrainEngine, station: TrainStation) -> void:
	var stop: TrainRouteStop = self._stops[self._stop_idx]
	if self.is_disabled() || leaving_train != self._train || station != stop.station:
		return
	station.reset_color()
	self._choose_available_stop(true)
	self._activate_stop()

func _on_train_crashed() -> void:
	if self.is_disabled(): return
	self.train_game_over.emit(self._train)

func _on_station_timeout(station: TrainStation) -> void:
	var stop: TrainRouteStop = self._stops[self._stop_idx]
	if self.is_disabled() || station != stop.station:
		return
	self._stop_idx = -1
	self.train_game_over.emit(self._train)

func _choose_available_stop(next: bool) -> void:
	if next:
		self._stop_idx = (self._stop_idx + 1)  % len(self._stops)
	for _n in range(len(self._stops)):
		if self._stops[self._stop_idx].station.available:
			return
		self._stop_idx = (self._stop_idx + 1)  % len(self._stops)
	push_error("no available stop found")

func _activate_stop() -> void:
	assert(!self.is_disabled())
	var stop: TrainRouteStop = self._stops[self._stop_idx]
	assert(stop.station.available)
	stop.station.start_timer(stop.delay)
	stop.station.set_color(self.color)
