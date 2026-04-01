extends Control

## Visual test for particle effect system
## Allows manual testing of all particle types with contextual selection

var character: WaterDropletCharacter
var current_particles: GPUParticles2D = null

@onready var particle_type_label: Label = $VBoxContainer/ParticleTypeLabel
@onready var density_label: Label = $VBoxContainer/DensityLabel
@onready var fps_label: Label = $VBoxContainer/FPSLabel


func _ready() -> void:
	# Create character
	character = preload("res://scenes/cutscenes/WaterDropletCharacter.tscn").instantiate()
	add_child(character)
	character.position = size / 2.0
	
	# Set up UI
	_setup_ui()
	
	# Update labels
	_update_labels()


func _setup_ui() -> void:
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	add_child(vbox)
	vbox.position = Vector2(10, 10)
	
	# Title
	var title = Label.new()
	title.text = "Particle Effect Visual Test"
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	
	# Instructions
	var instructions = Label.new()
	instructions.text = "Press 1-5 to spawn particles, C for contextual selection"
	vbox.add_child(instructions)
	
	# Particle type label
	particle_type_label = Label.new()
	particle_type_label.name = "ParticleTypeLabel"
	particle_type_label.text = "Particle Type: None"
	vbox.add_child(particle_type_label)
	
	# Density label
	density_label = Label.new()
	density_label.name = "DensityLabel"
	density_label.text = "Density Factor: 1.0"
	vbox.add_child(density_label)
	
	# FPS label
	fps_label = Label.new()
	fps_label.name = "FPSLabel"
	fps_label.text = "FPS: 60"
	vbox.add_child(fps_label)
	
	# Buttons
	var button_container = HBoxContainer.new()
	vbox.add_child(button_container)
	
	var sparkles_btn = Button.new()
	sparkles_btn.text = "1: Sparkles"
	sparkles_btn.pressed.connect(_spawn_sparkles)
	button_container.add_child(sparkles_btn)
	
	var water_btn = Button.new()
	water_btn.text = "2: Water Drops"
	water_btn.pressed.connect(_spawn_water_drops)
	button_container.add_child(water_btn)
	
	var stars_btn = Button.new()
	stars_btn.text = "3: Stars"
	stars_btn.pressed.connect(_spawn_stars)
	button_container.add_child(stars_btn)
	
	var smoke_btn = Button.new()
	smoke_btn.text = "4: Smoke"
	smoke_btn.pressed.connect(_spawn_smoke)
	button_container.add_child(smoke_btn)
	
	var splash_btn = Button.new()
	splash_btn.text = "5: Splash"
	splash_btn.pressed.connect(_spawn_splash)
	button_container.add_child(splash_btn)
	
	# Contextual buttons
	var contextual_container = HBoxContainer.new()
	vbox.add_child(contextual_container)
	
	var win_btn = Button.new()
	win_btn.text = "Win Context"
	win_btn.pressed.connect(_spawn_contextual_win)
	contextual_container.add_child(win_btn)
	
	var fail_btn = Button.new()
	fail_btn.text = "Fail Context"
	fail_btn.pressed.connect(_spawn_contextual_fail)
	contextual_container.add_child(fail_btn)
	
	var water_intro_btn = Button.new()
	water_intro_btn.text = "Water Intro"
	water_intro_btn.pressed.connect(_spawn_contextual_water_intro)
	contextual_container.add_child(water_intro_btn)
	
	# Clear button
	var clear_btn = Button.new()
	clear_btn.text = "Clear Particles"
	clear_btn.pressed.connect(_clear_particles)
	vbox.add_child(clear_btn)


func _process(_delta: float) -> void:
	_update_labels()


func _update_labels() -> void:
	if density_label:
		var density = ParticleEffectManager.get_adaptive_density_factor()
		density_label.text = "Density Factor: %.2f" % density
	
	if fps_label:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_spawn_sparkles()
			KEY_2:
				_spawn_water_drops()
			KEY_3:
				_spawn_stars()
			KEY_4:
				_spawn_smoke()
			KEY_5:
				_spawn_splash()
			KEY_C:
				_spawn_contextual_win()


func _spawn_sparkles() -> void:
	_spawn_particle(CutsceneTypes.ParticleType.SPARKLES, "Sparkles")


func _spawn_water_drops() -> void:
	_spawn_particle(CutsceneTypes.ParticleType.WATER_DROPS, "Water Drops")


func _spawn_stars() -> void:
	_spawn_particle(CutsceneTypes.ParticleType.STARS, "Stars")


func _spawn_smoke() -> void:
	_spawn_particle(CutsceneTypes.ParticleType.SMOKE, "Smoke")


func _spawn_splash() -> void:
	_spawn_particle(CutsceneTypes.ParticleType.SPLASH, "Splash")


func _spawn_contextual_win() -> void:
	var particle_type = ParticleEffectManager.select_contextual_particle(
		CutsceneTypes.CutsceneType.WIN,
		"TestMinigame"
	)
	var type_name = _get_particle_type_name(particle_type)
	_spawn_particle(particle_type, "Win Context: " + type_name)


func _spawn_contextual_fail() -> void:
	var particle_type = ParticleEffectManager.select_contextual_particle(
		CutsceneTypes.CutsceneType.FAIL,
		"TestMinigame"
	)
	var type_name = _get_particle_type_name(particle_type)
	_spawn_particle(particle_type, "Fail Context: " + type_name)


func _spawn_contextual_water_intro() -> void:
	var particle_type = ParticleEffectManager.select_contextual_particle(
		CutsceneTypes.CutsceneType.INTRO,
		"CatchTheRain"
	)
	var type_name = _get_particle_type_name(particle_type)
	_spawn_particle(particle_type, "Water Intro: " + type_name)


func _spawn_particle(particle_type: CutsceneTypes.ParticleType, label: String) -> void:
	if not character:
		return
	
	# Clear previous particles
	_clear_particles()
	
	# Spawn new particles
	current_particles = character.spawn_particles(particle_type, 2.0)
	
	# Apply adaptive density
	if current_particles:
		ParticleEffectManager.apply_adaptive_density(current_particles)
	
	# Update label
	if particle_type_label:
		particle_type_label.text = "Particle Type: " + label


func _clear_particles() -> void:
	if character and character.particle_container:
		for child in character.particle_container.get_children():
			child.queue_free()
	current_particles = null
	if particle_type_label:
		particle_type_label.text = "Particle Type: None"


func _get_particle_type_name(particle_type: CutsceneTypes.ParticleType) -> String:
	match particle_type:
		CutsceneTypes.ParticleType.SPARKLES:
			return "Sparkles"
		CutsceneTypes.ParticleType.WATER_DROPS:
			return "Water Drops"
		CutsceneTypes.ParticleType.STARS:
			return "Stars"
		CutsceneTypes.ParticleType.SMOKE:
			return "Smoke"
		CutsceneTypes.ParticleType.SPLASH:
			return "Splash"
		_:
			return "Unknown"
