extends PanelContainer

# UI References
@onready var title: Label = $Panel/VBoxContainer/TitleBar/Title
@onready var grid_container: GridContainer = $Panel/VBoxContainer/ScrollContainer/GridContainer
@onready var draw_button: Button = $Panel/VBoxContainer/Footer/DrawButton
@onready var close_button: Button = $Panel/VBoxContainer/TitleBar/CloseButton
@onready var close_button2: Button = $Panel/VBoxContainer/Footer/CloseButton2
