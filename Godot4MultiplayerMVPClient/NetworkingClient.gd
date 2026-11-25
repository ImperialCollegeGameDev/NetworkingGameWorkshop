extends Node

const DEV = true

const PlayerScene = preload("res://player.tscn")
@onready var players_node = $Players

@onready var connect_btn = $Lobby/ConnectBtn
@onready var disconnect_btn = $Lobby/DisconnectBtn

var multiplayer_peer = ENetMultiplayerPeer.new()
var url : String = "your-prod.url"
const PORT = 9009

var connected_peer_ids = []

func _ready():
	if DEV == true:
		url = "127.0.0.1"
		
	if not connect_btn.pressed.is_connected(_on_connect_btn_pressed):
		connect_btn.pressed.connect(_on_connect_btn_pressed)
	if not disconnect_btn.pressed.is_connected(_on_disconnect_btn_pressed):
		disconnect_btn.pressed.connect(_on_disconnect_btn_pressed)
	
	update_connection_buttons()
	multiplayer.server_disconnected.connect(_on_server_disconnected)

@rpc("any_peer", "call_remote", "reliable")
func sync_player_list(updated_connected_peer_ids):
	connected_peer_ids = updated_connected_peer_ids
	update_connection_buttons()
	print("Currently connected Players: " + str(connected_peer_ids))
	
	for peer_id in connected_peer_ids:
		if not players_node.has_node(str(peer_id)):
			var player = PlayerScene.instantiate()
			player.name = str(peer_id)
			
			# Give each joining player a slight random offset to prevent spawn overlap
			var random_offset = Vector3(randf_range(-1.5, 1.5), 1.0, randf_range(-1.5, 1.5))
			player.global_position = random_offset
			
			players_node.add_child(player)

	for child in players_node.get_children():
		var peer_id = child.name.to_int()
		if peer_id not in connected_peer_ids:
			child.queue_free()

func send_my_transform(pos: Vector3, rot: Vector3):
	if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		rpc_id(1, "relay_transform", pos, rot)

func _on_connect_btn_pressed() -> void:
	print("Connecting ...")
	multiplayer_peer.create_client(url, PORT)
	multiplayer.multiplayer_peer = multiplayer_peer
	update_connection_buttons()

func _on_disconnect_btn_pressed():
	multiplayer_peer.close()
	update_connection_buttons()
	for child in players_node.get_children():
		child.queue_free()
	connected_peer_ids.clear()
	print("Disconnected.")

func _on_server_disconnected():
	multiplayer_peer.close()
	update_connection_buttons()
	for child in players_node.get_children():
		child.queue_free()
	connected_peer_ids.clear()
	print("Connection to server lost.")

func update_connection_buttons() -> void:
	var status = multiplayer_peer.get_connection_status()
	if status == multiplayer_peer.CONNECTION_DISCONNECTED:
		connect_btn.disabled = false
		disconnect_btn.disabled = true
	elif status == multiplayer_peer.CONNECTION_CONNECTING:
		connect_btn.disabled = true
		disconnect_btn.disabled = true
	elif status == multiplayer_peer.CONNECTION_CONNECTED:
		connect_btn.disabled = true
		disconnect_btn.disabled = false

@rpc("any_peer", "call_remote", "unreliable")
func relay_transform(_pos: Vector3, _rot: Vector3):
	pass

@rpc("any_peer", "call_remote", "unreliable")
func receive_transform(sender_id: int, pos: Vector3, rot: Vector3):
	if sender_id == multiplayer.get_unique_id():
		# Ignore echos
		return
		
	var remote_player = players_node.get_node_or_null(str(sender_id))
	if remote_player and remote_player.has_method("update_remote_transform"):
		remote_player.update_remote_transform(pos, rot)
