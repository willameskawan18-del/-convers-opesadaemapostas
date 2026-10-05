extends Node
## NetworkManager (autoload "Net"). Multiplayer em rede local/Internet via ENet.
## O host é a autoridade (peer 1): roda a partida e envia eventos. Clientes só mandam ações.
## Sem conexão, o jogo usa OfflineMultiplayerPeer e esta máquina é o host.

signal connected_to_host
signal connection_failed
signal disconnected_from_host
signal peer_joined(peer: int)
signal peer_left(peer: int)
signal upnp_finished(ok: bool, external_ip: String)

const DEFAULT_PORT := 7797
const MAX_CLIENTS := 3

var _online := false
var _lobby_open := true
var _peers: Array[int] = []
## UPnP: abre a porta no roteador automaticamente para jogar pela INTERNET.
var upnp_status := ""          # "", "procurando", "ok", "falhou"
var external_ip := ""
var _upnp: UPNP
var _upnp_thread: Thread
var _mapped_port := 0


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
	_start_upnp(port)
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
	_remove_upnp()
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


# --- UPnP (internet sem configurar o roteador) -----------------------------------

func _start_upnp(port: int) -> void:
	if DisplayServer.get_name() == "headless" or (_upnp_thread and _upnp_thread.is_alive()):
		return
	upnp_status = "procurando"
	external_ip = ""
	_upnp_thread = Thread.new()
	_upnp_thread.start(_upnp_work.bind(port))


func _upnp_work(port: int) -> void:
	var u := UPNP.new()
	var ok := false
	var ip := ""
	if u.discover(2000, 2) == UPNP.UPNP_RESULT_SUCCESS and u.get_gateway() and u.get_gateway().is_valid_gateway():
		var r1 := u.add_port_mapping(port, port, "PESCA NO ABISMO", "UDP", 0)
		if r1 == UPNP.UPNP_RESULT_SUCCESS:
			ok = true
			ip = u.query_external_address()
	call_deferred("_upnp_done", u, ok, ip, port)


func _upnp_done(u: UPNP, ok: bool, ip: String, port: int) -> void:
	if _upnp_thread:
		_upnp_thread.wait_to_finish()
		_upnp_thread = null
	if not _online:
		if ok:
			u.delete_port_mapping(port, "UDP")
		return
	_upnp = u if ok else null
	_mapped_port = port if ok else 0
	upnp_status = "ok" if ok else "falhou"
	external_ip = ip
	upnp_finished.emit(ok, ip)
	if multiplayer.is_server():
		Game._broadcast_view()


func _remove_upnp() -> void:
	if _upnp and _mapped_port > 0:
		_upnp.delete_port_mapping(_mapped_port, "UDP")
	_upnp = null
	_mapped_port = 0
	upnp_status = ""
	external_ip = ""


func _exit_tree() -> void:
	_remove_upnp()
	if _upnp_thread:
		_upnp_thread.wait_to_finish()


func _on_peer_connected(peer: int) -> void:
	if not _peers.has(peer):
		_peers.append(peer)
	peer_joined.emit(peer)
	if multiplayer.is_server():
		Game._broadcast_view()


func _on_peer_disconnected(peer: int) -> void:
	_peers.erase(peer)
	peer_left.emit(peer)
