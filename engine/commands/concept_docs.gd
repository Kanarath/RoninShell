extends RefCounted
## Fichas de CONCEPTOS del temario (`man dns`, `man tls`...): explican qué es algo, por qué
## importa en una auditoría, qué NO se puede concluir y cómo se previene o corrige.
##
## Son explicativas y defensivas: no son comandos del laboratorio ni ejecutan nada. Cada ficha:
##   summary, notes [qué es y por qué pasa], audit [qué mira un auditor],
##   dont_conclude [errores de interpretación], defense [cómo se previene], see_also [temas o comandos]

const CONCEPTS := {
	"dns": {
		"summary": "El sistema que traduce nombres (web01.empresa.com) en direcciones IP.",
		"notes": [
			"Un servidor DNS guarda registros: A (nombre a IPv4), AAAA (a IPv6), CNAME (alias), MX (correo), NS (servidores de nombres) y TXT (texto libre, p. ej. políticas de correo).",
			"Hay servidores autoritativos (los que tienen la información de una zona) y recursivos (los que preguntan por ti y guardan respuestas en caché).",
			"Un nombre es solo una etiqueta: la misma IP puede tener varios nombres y un nombre puede apuntar a varias IP.",
		],
		"audit": [
			"El DNS revela nombres de equipos y servicios (correo, VPN, intranet) que orientan el reconocimiento.",
			"Una zona que permite transferirse a cualquiera entrega la lista completa de nombres: es un hallazgo de configuración.",
		],
		"dont_conclude": [
			"Que un nombre exista en DNS no prueba que el equipo esté encendido.",
			"Que un nombre no aparezca no prueba que no exista: puede estar en una zona interna o no publicado.",
		],
		"defense": [
			"Restringir las transferencias de zona a los servidores secundarios autorizados.",
			"No publicar en DNS externo nombres de equipos internos (separar zona interna y externa).",
		],
		"see_also": ["tls", "cabeceras"],
	},
	"tls": {
		"summary": "La capa de cifrado y autenticación que convierte HTTP en HTTPS.",
		"notes": [
			"Aporta tres cosas: cifrado del tráfico, comprobación de a quién te conectas (el certificado) e integridad de los datos.",
			"Un certificado lo firma una autoridad en la que tu sistema confía; el navegador comprueba la cadena, el nombre y la fecha de caducidad.",
			"Existen versiones del protocolo: las antiguas (SSL, TLS 1.0 y 1.1) están obsoletas; hoy se usan TLS 1.2 y 1.3.",
		],
		"audit": [
			"Se revisa que el certificado no esté caducado, que su nombre coincida con el servicio y que no se admitan protocolos obsoletos.",
			"Se comprueba si la web fuerza HTTPS y envía la cabecera HSTS.",
		],
		"dont_conclude": [
			"El candado de HTTPS no significa que el sitio sea seguro: solo que la conexión va cifrada hasta el servidor.",
			"TLS no protege contra fallos de la aplicación, como un control de acceso mal hecho.",
		],
		"defense": [
			"Usar TLS 1.2 o superior, renovar los certificados antes de que caduquen y activar HSTS.",
			"Redirigir todo el tráfico HTTP a HTTPS.",
		],
		"see_also": ["dns", "cabeceras"],
	},
	"cookies": {
		"summary": "Pequeños datos que el servidor pide al navegador que guarde y devuelva en cada petición; así se mantiene una sesión.",
		"notes": [
			"Tras iniciar sesión, el servidor entrega un identificador de sesión en una cookie. El navegador lo envía en cada petición y el servidor sabe quién eres.",
			"Las cookies tienen banderas: HttpOnly (el código de la página no puede leerla), Secure (solo viaja por HTTPS) y SameSite (limita su envío entre sitios).",
			"Una cookie la controla quien la tiene: el usuario puede verla y modificarla. Por eso el servidor nunca debe fiarse de su contenido para decidir permisos.",
		],
		"audit": [
			"Se revisan las banderas de la cookie de sesión y que el identificador sea largo e impredecible.",
			"Se busca si el servidor confía en datos que controla el cliente (por ejemplo, una cookie con el rol).",
		],
		"dont_conclude": [
			"Que una cookie no tenga HttpOnly o Secure es un indicio de mala configuración, no una intrusión: hay que valorar el impacto real.",
			"Que una cookie parezca ilegible no significa que sea segura: puede estar solo codificada, no protegida.",
		],
		"defense": [
			"Marcar la cookie de sesión con HttpOnly, Secure y SameSite.",
			"Guardar en el servidor quién es cada sesión y qué puede hacer; nunca decidir permisos con datos de la cookie.",
		],
		"see_also": ["cabeceras", "control_acceso", "tls"],
	},
	"cabeceras": {
		"summary": "Líneas de metadatos que acompañan a cada petición y respuesta HTTP. Algunas existen para reforzar la seguridad del navegador.",
		"notes": [
			"Cabeceras de seguridad habituales: Content-Security-Policy (qué recursos puede cargar la página), X-Frame-Options (evita que la incrusten en otra web), X-Content-Type-Options y Strict-Transport-Security (HSTS).",
			"La cabecera Server y similares anuncian el software y su versión: útil para el reconocimiento, e innecesaria para el visitante.",
			"Se ven con curl -I (solo cabeceras) o curl -i (cabeceras y cuerpo).",
		],
		"audit": [
			"Se anota qué cabeceras de seguridad faltan y qué información de versión se filtra.",
			"Cada ausencia se valora por su impacto real: no todas tienen la misma gravedad.",
		],
		"dont_conclude": [
			"Que falte una cabecera no demuestra que la aplicación sea vulnerable: es una defensa en profundidad que no está.",
			"Que la cabecera Server diga una versión no prueba que sea la real: puede estar modificada.",
		],
		"defense": [
			"Configurar las cabeceras de seguridad en el servidor y revisarlas con cada despliegue.",
			"Ocultar o reducir la versión que anuncia el servidor.",
		],
		"see_also": ["cookies", "tls", "curl"],
	},
	"control_acceso": {
		"summary": "Las reglas que deciden quién puede ver o hacer qué en una aplicación. Los fallos aquí son de los más frecuentes y graves.",
		"notes": [
			"Autenticación es comprobar quién eres; autorización es decidir qué puedes hacer. Que alguien haya iniciado sesión no significa que pueda ver cualquier dato.",
			"Fallo típico: la aplicación comprueba que estás identificado pero no que el recurso sea tuyo. Si el pedido 15 es tuyo y el 16 también se muestra, falta esa comprobación (referencia directa insegura a objetos).",
			"Otro fallo típico: confiar en datos que controla el usuario, como un parámetro o una cookie, para decidir si es administrador.",
		],
		"audit": [
			"Con una cuenta de pruebas se comprueba si se puede acceder a recursos de otras cuentas y a funciones de administración.",
			"Cada hallazgo se documenta con la petición exacta, la respuesta y qué cuenta se usó.",
		],
		"dont_conclude": [
			"Que una página de administración responda 403 no prueba que esté bien protegida: puede haber otra ruta o un parámetro que la evite.",
			"Que un identificador sea difícil de adivinar no sustituye a comprobar el permiso.",
		],
		"defense": [
			"Comprobar siempre en el servidor, en cada petición, que el usuario autenticado tiene permiso sobre ese recurso concreto.",
			"Denegar por defecto y no usar datos del cliente para decidir permisos.",
		],
		"see_also": ["cookies", "cabeceras"],
	},
	"path_traversal": {
		"summary": "Fallo en el que una aplicación usa una ruta que le da el usuario para leer archivos y no comprueba que se quede dentro de la carpeta prevista.",
		"notes": [
			"Ocurre cuando el código construye la ruta de un archivo a partir de un dato del usuario sin normalizarla ni limitarla a una carpeta permitida.",
			"Las rutas pueden contener '..' (subir un nivel), como ya conoces de cd. Si la aplicación no lo controla, el usuario podría salir de la carpeta que debía ver.",
			"Es un fallo de validación de entrada: el servidor se fía de una ruta que no debería fiarse.",
		],
		"audit": [
			"En una revisión de código se buscan los lugares donde se abre un archivo con un nombre que viene de la petición.",
			"Se comprueba que el servidor se ejecuta con los mínimos permisos, para limitar qué podría leerse aunque haya un fallo.",
		],
		"dont_conclude": [
			"Que un parámetro contenga un nombre de archivo no significa que sea vulnerable: puede estar bien validado.",
			"Que el servidor no devuelva un archivo del sistema no prueba que esté bien protegido: depende de cómo valide.",
		],
		"defense": [
			"No construir rutas con datos del usuario; usar una lista de archivos permitidos o identificadores propios.",
			"Si hay que usar la ruta, normalizarla y comprobar que sigue dentro de la carpeta permitida.",
			"Ejecutar el servicio con un usuario sin privilegios (los permisos de archivos que ya conoces son la última barrera).",
		],
		"see_also": ["control_acceso", "chmod"],
	},
	"xss": {
		"summary": "Cross-site scripting: fallo en el que una web muestra datos de un usuario sin tratarlos y el navegador de otra persona los interpreta como código de la página.",
		"notes": [
			"Ocurre cuando una aplicación incluye en su HTML texto que viene de un usuario (un comentario, un nombre, un parámetro) sin convertir los caracteres especiales en texto inofensivo.",
			"El navegador no distingue entre el código que puso el sitio y el que se coló, y lo trata con la misma confianza.",
			"Por eso importa el contexto: el mismo dato necesita un tratamiento distinto dentro del HTML, de un atributo o de un script.",
		],
		"audit": [
			"Se revisan los puntos donde la aplicación muestra datos introducidos por usuarios, y si se escapan según el contexto.",
			"Se comprueba si existe una Content-Security-Policy y si las cookies de sesión llevan HttpOnly, que limitan el daño.",
		],
		"dont_conclude": [
			"Que una página refleje un parámetro no prueba que sea vulnerable: si lo escapa correctamente, no lo es.",
			"Que no haya XSS no implica que la aplicación sea segura.",
		],
		"defense": [
			"Escapar siempre los datos al mostrarlos, según el contexto (HTML, atributo, script).",
			"Usar plantillas o frameworks que escapen por defecto, y una Content-Security-Policy restrictiva.",
			"Marcar las cookies de sesión como HttpOnly.",
		],
		"see_also": ["cookies", "cabeceras"],
	},
}


const CommandDocs := preload("res://engine/commands/command_docs.gd")


static func has(topic: String) -> bool:
	return CONCEPTS.has(topic)


## Ficha de un concepto, con el mismo formato que `man` de un comando.
static func page(topic: String) -> String:
	var doc: Dictionary = CONCEPTS[topic]
	var text := "%s (concepto)\n%s\n" % [topic.to_upper().replace("_", " "), CommandDocs._wrap_lines(doc["summary"], CommandDocs.WIDTH, 0)]
	var sections := [["QUÉ ES Y POR QUÉ PASA", "notes", "-"], ["QUÉ MIRA UN AUDITOR", "audit", "-"], ["QUÉ NO PUEDES CONCLUIR", "dont_conclude", "x"], ["CÓMO SE PREVIENE", "defense", "-"]]
	for section: Array in sections:
		if doc.get(section[1], []).is_empty():
			continue
		text += "\n%s\n" % section[0]
		for item: String in doc[section[1]]:
			text += CommandDocs._bullet(section[2], item)
	if not doc.get("see_also", []).is_empty():
		text += "\nVER TAMBIÉN\n  %s\n" % ", ".join(doc["see_also"])
	return text


static func topics() -> Array[String]:
	var result: Array[String] = []
	for topic: String in CONCEPTS:
		result.append(topic)
	result.sort()
	return result
