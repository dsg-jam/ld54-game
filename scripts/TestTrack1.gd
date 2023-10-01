extends Node

@export var car_count = 2

@onready var train_vehicle_reference = load("res://prefabs/TrainVehicle.tscn")
@onready var engine1 = $TrainEngine1
@onready var engine2 = $TrainEngine2

func _ready():
	#engine.connect("train_info", $TestWorld, "update_train_info")
	engine1.add_to_track($Tracks/Track8, 500)
	engine2.add_to_track($Tracks/Track2, 500)
	
	var last_car = engine1
	for index in range(car_count):
		var car = train_vehicle_reference.instantiate()
		add_child(car)
		last_car.set_follower_car(car)
		last_car = car
	
	last_car = engine2
	for index in range(car_count):
		var car = train_vehicle_reference.instantiate()
		add_child(car)
		last_car.set_follower_car(car)
		last_car = car
