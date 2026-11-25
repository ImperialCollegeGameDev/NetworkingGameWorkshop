extends Node

const PORT = 9009
var multiplayer_peer = ENetMultiplayerPeer.new()
var connected_peer_ids = []

func _ready():
	multiplayer_peer.create_server(PORT)
	multiplayer.multiplayer_peer = multiplayer_peer
	multiplayer_peer.peer_connected.connect(_on_peer_connected)
	multiplayer_peer.peer_disconnected.connect(_on_peer_disconnected)
	print("Relay Server is up and running.")

func _on_peer_connected(new_peer_id : int) -> void:
	connected_peer_ids.append(new_peer_id)
	print("Player " + str(new_peer_id) + " joined.")
	rpc("sync_player_list", connected_peer_ids)

func _on_peer_disconnected(leaving_peer_id : int) -> void:
	connected_peer_ids.erase(leaving_peer_id)
	print("Player " + str(leaving_peer_id) + " disconnected.")
	rpc("sync_player_list", connected_peer_ids)

@rpc("any_peer", "call_remote", "reliable")
func sync_player_list(_updated_connected_peer_ids):
	pass

@rpc("any_peer", "call_remote", "unreliable")
func relay_transform(pos: Vector3, rot: Vector3):
	var sender_id = multiplayer.get_remote_sender_id()
	for peer_id in connected_peer_ids:
		if peer_id != sender_id:
			rpc_id(peer_id, "receive_transform", sender_id, pos, rot)

@rpc("any_peer", "call_remote", "unreliable")
func receive_transform(_sender_id: int, _pos: Vector3, _rot: Vector3):
	pass
