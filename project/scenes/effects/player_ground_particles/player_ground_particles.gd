extends Node2D

@onready var particles: GPUParticles2D = $GPUParticles2D

var color: Color


func _ready() -> void:
	if color:
		var mat = particles.process_material as ParticleProcessMaterial
		var gradient := Gradient.new()
		var gradient_texture := GradientTexture1D.new()
		var colors := PackedColorArray()
		colors.append(color)
		gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		gradient.colors = colors
		gradient_texture.gradient = gradient
		mat.color_initial_ramp = gradient_texture
