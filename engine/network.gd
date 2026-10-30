extends RefCounted
## Reglas de red compartidas por ping, nmap y curl, para que los tres cuenten la misma historia.
##
## Modelo (simple a propósito):
##   - "up" = la máquina está encendida.
##   - "responds_to_ping" = deja pasar los sondeos de descubrimiento (ICMP y similares).
##     Una máquina encendida que NO responde a esos sondeos parece apagada para
##     ping y para el descubrimiento de nmap, pero sus puertos siguen ahí (nmap -Pn).
##   - un puerto no definido en el laboratorio está "closed" (la máquina responde con un reset).

const Host := preload("res://engine/host.gd")

const LOCALHOST_IP := "127.0.0.1"


## Resuelve un nombre o IP a un host del laboratorio. Devuelve null si no existe.
static func resolve(world: RefCounted, target: String) -> RefCounted:
	if target == "localhost" or target == LOCALHOST_IP:
		return world.player_host()
	if world.hosts.has(target):
		return world.get_host(target)
	return world.host_by_name(target)


## ¿Responde a los sondeos de descubrimiento (ping, nmap sin -Pn)?
static func answers_discovery(host: RefCounted) -> bool:
	return host != null and host.up and host.responds_to_ping


## Latencia determinista (en ms) según la IP: no depende del reloj ni del azar.
static func latency_ms(ip: String, sequence := 1) -> float:
	var last_octet := int(ip.get_slice(".", 3))
	return 0.20 + (last_octet % 9) * 0.07 + (sequence % 3) * 0.02
