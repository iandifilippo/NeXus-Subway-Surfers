extends Control


func _ready():
	$VBoxContainer/PlayButton.pressed.connect(_on_play_button_pressed)
	$VBoxContainer/CreditsButton.pressed.connect(_on_credits_button_pressed)
	$VBoxContainer/ExitButton.pressed.connect(_on_exit_button_pressed)


func _on_play_button_pressed():
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")


func _on_credits_button_pressed():
	print("Botón Créditos presionado")


func _on_exit_button_pressed():
	get_tree().quit()
