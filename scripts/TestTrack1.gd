extends Node

@export var car_count = 2

@onready var _train_vehicle_reference = load("res://prefabs/TrainVehicle.tscn")
@onready var _engine1: TrainEngine = $TrainEngine1
@onready var _engine2: TrainEngine = $TrainEngine2
@onready var _tracks_controller: TracksController = $Tracks

func _ready():
	self._engine1.connect_tracks_controller(self._tracks_controller)
	self._engine2.connect_tracks_controller(self._tracks_controller)
	self._engine1.add_to_track($Tracks/Track8, 500)
	self._engine2.add_to_track($Tracks/Track2, 500)
	
	var last_car = self._engine1
	for index in range(car_count):
		var car = self._train_vehicle_reference.instantiate()
		add_child(car)
		last_car.set_follower_car(car)
		last_car = car
	
	last_car = self._engine2
	for index in range(car_count):
		var car = self._train_vehicle_reference.instantiate()
		add_child(car)
		last_car.set_follower_car(car)
		last_car = car
