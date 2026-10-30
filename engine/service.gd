extends RefCounted
## Un puerto de un host y el servicio que escucha (o no) en él.
##
## "state" sigue el vocabulario de Nmap:
##   open      algo escucha y responde
##   closed    el host responde, pero nada escucha
##   filtered  algo (un firewall) impide saberlo; no hay respuesta útil

const STATES := ["open", "closed", "filtered"]
const PROTOCOLS := ["tcp", "udp"]

var port: int = 0
var proto: String = "tcp"
var state: String = "open"
var name: String = ""      # nombre REAL del servicio, p. ej. "http" (lo que ve nmap -sV)
var guessed_name: String = ""  # lo que nmap supone solo por el número de puerto (sin -sV)
var product: String = ""   # p. ej. "Apache httpd"
var version: String = ""   # p. ej. "2.4.49"
var banner: String = ""    # lo que el servicio dice de sí mismo; puede no coincidir con la realidad


## Construye un servicio desde un diccionario de datos. Añade los problemas a "errors".
static func from_dict(data: Variant, errors: Array, context: String) -> RefCounted:
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("%s: el servicio debe ser un objeto" % context)
		return null
	var service := new()
	var port_value = data.get("port", 0)
	if typeof(port_value) != TYPE_INT and typeof(port_value) != TYPE_FLOAT:
		errors.append("%s: 'port' debe ser un número" % context)
		return null
	service.port = int(port_value)
	if service.port < 1 or service.port > 65535:
		errors.append("%s: puerto fuera de rango (%d)" % [context, service.port])
		return null
	service.proto = str(data.get("proto", "tcp"))
	if not service.proto in PROTOCOLS:
		errors.append("%s: protocolo desconocido '%s'" % [context, service.proto])
		return null
	service.state = str(data.get("state", "open"))
	if not service.state in STATES:
		errors.append("%s: estado desconocido '%s'" % [context, service.state])
		return null
	service.name = str(data.get("name", ""))
	service.guessed_name = str(data.get("guessed_name", service.name))
	service.product = str(data.get("product", ""))
	service.version = str(data.get("version", ""))
	service.banner = str(data.get("banner", ""))
	return service
