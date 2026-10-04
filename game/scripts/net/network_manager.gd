extends Node
## NetworkManager (autoload "Net"). Multiplayer em rede local/Internet via ENet.
## O host é a autoridade (peer 1): roda a partida e envia eventos. Clientes só mandam ações.
## Sem conexão, o jogo usa OfflineMultiplayerPeer e esta máquina é o host.

signal connected_to_host
signal connection_failed
signal disconnected_from_host
signal peer_joined(peer: int)
signal peer_left(peer: int)

const DEFAULT_PORT := 7777
const MAX_CLIENTS := 7

var _online := false
var _lobby_open := true
var _peers: Array[int] = []


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(func():
		_online = true
		connected_to_host.emit())
	multiplayer.connection_failed.connect(func():
		close()
		connection_failed.emit())
	multiplayer.server_disconnected.connect(func():
		close()
		disconnected_from_host.emit())


func is_online() -> bool:
	return _online and multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


func is_host() -> bool:
	return not is_online() or multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id() if is_online() else 1


func has_peer(peer: int) -> bool:
	return _peers.has(peer)


func peers() -> Array[int]:
	return _peers


func host(port: int = DEFAULT_PORT) -> Error:
	close()
	var p := ENetMultiplayerPeer.new()
	var err := p.create_server(port, MAX_CLIENTS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = p
	_online = true
	_lobby_open = true
	return OK


func join(address: String, port: int = DEFAULT_PORT) -> Error:
	close()
	var p := ENetMultiplayerPeer.new()
	var err := p.create_client(address.strip_edges() if address.strip_edges() != "" else "127.0.0.1", port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = p
	_online = false   # vira true em connected_to_server
	return OK


func close() -> void:
	var p := multiplayer.multiplayer_peer
	if p and not (p is OfflineMultiplayerPeer):
		p.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_online = false
	_peers.clear()


func set_lobby_open(open: bool) -> void:
	_lobby_open = open
	var p := multiplayer.multiplayer_peer
	if p is ENetMultiplayerPeer and multiplayer.is_server():
		p.refuse_new_connections = not open


## Endereços IPv4 locais (para mostrar no lobby e o amigo digitar).
func local_addresses() -> Array:
	var out := []
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254"):
			out.append(a)
	return out


func _on_peer_connected(peer: int) -> void:
	if not _peers.has(peer):
		_peers.append(peer)
	peer_joined.emit(peer)
	if multiplayer.is_server():
		Game._broadcast_view()


func _on_peer_disconnected(peer: int) -> void:
	_peers.erase(peer)
	peer_left.emit(peer)
