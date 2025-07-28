class_name ProjectileAttack
extends BaseAttack

## Base movement speed of the projectile.
@export var speed := 600
## Correctional rotation for the sprite. A float in Radians to add to the rotation to face "right" from neutral.
@export var rotation_correction := 0.0

@onready var life_timer: Timer = $LifeTimer

var direction: Vector2


func _ready() -> void:
	super()
	life_timer.timeout.connect(_on_life_timer_timeout)


func _process(delta: float) -> void:
	global_position += direction * speed * delta


func start(aim_direction: Vector2):
	self.direction = aim_direction
	rotation = aim_direction.angle()
	rotation += rotation_correction


func register_collision() -> void:
	super()
	kill()


func _on_life_timer_timeout() -> void:
	kill()
