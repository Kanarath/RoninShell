extends RefCounted
## Base de datos LOCAL de avisos de seguridad por producto y versión, para el laboratorio.
##
## No son CVE reales: son avisos ficticios ("SIM-año-número") inventados para este simulador,
## con el mismo formato que un aviso real (clase de fallo, gravedad, CVSS orientativo, versión
## corregida) pero SIN pasos para explotarlos. Sirven para practicar lo que de verdad hace un
## analista: detectar la versión, mirar si tiene avisos conocidos y decidir qué se parchea antes.
##
## Que un producto no aparezca aquí NO significa que esté libre de fallos: solo que esta base de
## datos de juego no tiene nada registrado. Es una lección a propósito (ver "avisos" en vuln_commands.gd).

const SEVERITIES := ["bajo", "medio", "alto", "critico"]

const DB := {
	"Apache httpd|2.4.49": [
		{
			"id": "SIM-2021-0441",
			"severity": "critico",
			"cvss": 9.8,
			"class": "path_traversal",
			"summary": "Una función de normalización de rutas no bloquea correctamente ciertas secuencias de salida de directorio en algunas configuraciones del servidor.",
			"fixed_in": "2.4.50 o posterior",
		},
	],
	"Apache httpd|2.4.41": [
		{
			"id": "SIM-2019-1333",
			"severity": "bajo",
			"cvss": 3.1,
			"class": "divulgacion_informacion",
			"summary": "Una cabecera que no se valida correctamente puede exponer la IP real de un cliente que pasa por un proxy intermedio.",
			"fixed_in": "2.4.48 o posterior",
		},
	],
	"OpenSSH|8.2p1": [
		{
			"id": "SIM-2020-1013",
			"severity": "bajo",
			"cvss": 3.7,
			"class": "enumeracion_usuarios",
			"summary": "Las respuestas a un intento de acceso con usuario válido y con usuario inválido no tardan lo mismo, lo que permite deducir qué cuentas existen por temporización.",
			"fixed_in": "8.4p1 o posterior",
		},
	],
	"OpenSSH|7.9p1": [
		{
			"id": "SIM-2018-0718",
			"severity": "bajo",
			"cvss": 3.7,
			"class": "enumeracion_usuarios",
			"summary": "Variante anterior del mismo fallo de temporización que distingue usuarios válidos de inválidos.",
			"fixed_in": "8.4p1 o posterior",
		},
	],
	"vsftpd|3.0.3": [
		{
			"id": "SIM-2016-0092",
			"severity": "medio",
			"cvss": 5.9,
			"class": "texto_claro",
			"summary": "El usuario y la contraseña viajan sin cifrar: cualquiera que intercepte el tráfico de la red puede leerlos.",
			"fixed_in": "no aplica: usar SFTP o FTPS en su lugar",
		},
	],
	"nginx|1.14.0": [
		{
			"id": "SIM-2019-0847",
			"severity": "medio",
			"cvss": 6.5,
			"class": "denegacion_servicio",
			"summary": "Una respuesta manipulada durante la resolución de nombres interna puede provocar que el proceso se caiga.",
			"fixed_in": "1.17.7 o posterior",
		},
	],
	"MariaDB|10.3.29": [
		{
			"id": "SIM-2021-0559",
			"severity": "medio",
			"cvss": 5.3,
			"class": "denegacion_servicio",
			"summary": "Una consulta de administración especialmente larga puede agotar la memoria del proceso si el servicio es alcanzable sin restricciones de red.",
			"fixed_in": "10.3.32 o posterior",
		},
	],
}


## Avisos conocidos para un producto y versión exactos (puede ser una lista vacía).
static func lookup(product: String, version: String) -> Array:
	return DB.get("%s|%s" % [product, version], [])


## La gravedad más alta de una lista de avisos (o "" si está vacía).
static func worst_severity(advisories: Array) -> String:
	var worst := ""
	for advisory: Dictionary in advisories:
		var severity: String = advisory["severity"]
		if worst == "" or SEVERITIES.find(severity) > SEVERITIES.find(worst):
			worst = severity
	return worst
