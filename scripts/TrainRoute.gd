extends Node2D

@export var train: TrainEngine

var _stops: Array[TrainRouteStop]
var _stop_idx: int = 0

func _ready() -> void:
	if self.train == null:
		push_warning("route has no assigned train engine")
		return

	self._stops.assign(self.find_children("*", "TrainRouteStop"))
	if self._stops.is_empty():
		push_warning("route with no stops")
		return

	self.train.entered_station.connect(self._on_train_entered_station)
	for stop in self._stops:
		assert(stop.station.is_node_ready())
		stop.station.timeout.connect(self._on_station_timeout)

	self._choose_available_stop(false)
	self._activate_stop()

func _on_train_entered_station(incoming_train: TrainEngine, station: TrainStation) -> void:
	var stop: TrainRouteStop = self._stops[self._stop_idx]
	if incoming_train != self.train || station != stop.station:
		return
	stop.station.reset()
	self._choose_available_stop(true)
	self._activate_stop()

func _on_station_timeout(station: TrainStation) -> void:
	var stop: TrainRouteStop = self._stops[self._stop_idx]
	if station != stop.station:
		return
	print("INSERT GAME OVER HERE")

func _choose_available_stop(next: bool) -> void:
	if next:
		self._stop_idx = (self._stop_idx + 1)  % len(self._stops)
	for _n in range(len(self._stops)):
		if self._stops[self._stop_idx].station.available:
			return
		self._stop_idx = (self._stop_idx + 1)  % len(self._stops)
	push_error("no available stop found")

func _activate_stop() -> void:
	var stop: TrainRouteStop = self._stops[self._stop_idx]
	assert(stop.station.available)
	stop.station.start_timer(stop.delay)
	stop.station.set_color(self.train.color)
