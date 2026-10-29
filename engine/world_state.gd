extends RefCounted
## El mundo de un laboratorio: red, hosts y desde cuál juega el jugador.
## Es la única fuente de verdad: los comandos calculan sus salidas a partir de esto.

var id: String = ""
var title: String = ""
var cidr: String = ""
var player_host_ip: String = ""
var hosts: Dictionary = {}  # ip -> Host


func get_host(ip: String) -> RefCounted:
	return hosts.get(ip)


func host_by_name(hostname: String) -> RefCounted:
	for host in hosts.values():
		if host.hostname == hostname:
			return host
	return null


func host_ips() -> Array[String]:
	var ips: Array[String] = []
	for ip: String in hosts:
		ips.append(ip)
	ips.sort_custom(func(a: String, b: String) -> bool: return _ip_to_int(a) < _ip_to_int(b))
	return ips


func player_host() -> RefCounted:
	return get_host(player_host_ip)


static func _ip_to_int(ip: String) -> int:
	var value := 0
	for octet in ip.split("."):
		value = value * 256 + int(octet)
	return value
