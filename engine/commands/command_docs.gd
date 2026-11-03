extends RefCounted
## Fichas de ayuda de cada comando: se muestran con `cmd --help` (resumen), `man cmd`
## (ficha completa, con límites y "qué NO puedes concluir") y `cheatsheet` (chuleta por temas).
##
## Cada ficha: usage, summary, options [[opción, texto]], examples [[comando, texto]],
## notes [texto], dont_conclude [texto], see_also [comando], short_h (¿-h muestra la ayuda?).
## Es contenido didáctico: explica para qué sirve, qué significan las opciones y qué no deduces.

const DOCS := {
	"ls": {
		"usage": "ls [-l] [-a] [-A] [ruta...]",
		"summary": "Lista el contenido de directorios (o muestra archivos concretos).",
		"options": [["-l", "formato largo: permisos, dueño, grupo, tamaño y fecha"], ["-a", "incluye los archivos ocultos (empiezan por punto), además de . y .."], ["-A", "como -a, pero sin . ni .."]],
		"examples": [["ls", "el contenido del directorio actual"], ["ls -la /etc", "todo, con detalles, de otro directorio"]],
		"notes": ["Sin -a no ves los archivos ocultos. Ocultos no significa secretos: solo no se muestran por defecto.", "En este laboratorio ls escribe un nombre por línea."],
		"dont_conclude": ["Que un archivo aparezca en la lista no significa que puedas leerlo: eso lo dicen los permisos (-l)."],
		"see_also": ["stat", "find", "chmod"],
	},
	"cd": {
		"usage": "cd [directorio]",
		"summary": "Cambia el directorio actual. Sin argumento vuelve a tu directorio personal.",
		"options": [],
		"examples": [["cd /etc", "ruta absoluta (empieza por /)"], ["cd ..", "sube un nivel"], ["cd informe", "ruta relativa al directorio actual"]],
		"notes": ["Para entrar en un directorio necesitas el permiso de ejecución (x) sobre él."],
		"see_also": ["pwd", "ls"],
	},
	"pwd": {"usage": "pwd", "summary": "Muestra la ruta del directorio actual.", "options": [], "examples": [["pwd", "dónde estás ahora"]], "see_also": ["cd"]},
	"cat": {
		"usage": "cat [archivo...]",
		"summary": "Muestra el contenido de uno o varios archivos. Sin archivos, lee la entrada estándar.",
		"options": [],
		"examples": [["cat nota.txt", "lee un archivo"], ["cat /etc/passwd | grep ronin", "envía el contenido a otro comando"]],
		"notes": ["Si un archivo no se puede leer, el mensaje te dice por qué: No such file (no existe), Permission denied (existe pero no tienes permiso), Is a directory."],
		"dont_conclude": ["Permission denied no significa que el archivo no exista: significa que existe y tu usuario no puede leerlo."],
		"see_also": ["head", "tail", "grep"],
	},
	"head": {"usage": "head [-n N] [archivo...]", "summary": "Muestra las primeras líneas (10 por defecto).", "options": [["-n N", "número de líneas (también -N)"]], "examples": [["head -n 3 /etc/passwd", "las 3 primeras líneas"]], "see_also": ["tail", "cat"]},
	"tail": {"usage": "tail [-n N] [archivo...]", "summary": "Muestra las últimas líneas (10 por defecto).", "options": [["-n N", "número de líneas (también -N)"]], "examples": [["tail -n 2 /etc/hosts", "las 2 últimas líneas"]], "see_also": ["head", "cat"]},
	"wc": {"usage": "wc [-l] [-w] [-c] [archivo...]", "summary": "Cuenta líneas, palabras y bytes.", "options": [["-l", "solo líneas"], ["-w", "solo palabras"], ["-c", "solo bytes"]], "examples": [["cat /etc/hosts | wc -l", "cuántas líneas tiene"]], "see_also": ["sort", "uniq"]},
	"sort": {"usage": "sort [-r] [-u] [-n] [archivo...]", "summary": "Ordena líneas de texto.", "options": [["-r", "orden inverso"], ["-u", "elimina duplicados"], ["-n", "orden numérico"]], "examples": [["sort -u lista.txt", "ordena y quita repetidos"]], "see_also": ["uniq"]},
	"uniq": {"usage": "uniq [-c] [archivo...]", "summary": "Quita líneas repetidas CONSECUTIVAS.", "options": [["-c", "antepone cuántas veces se repite"]], "examples": [["sort f.txt | uniq -c", "cuenta repeticiones (ordena primero)"]], "notes": ["uniq solo junta repetidas que estén seguidas: por eso se usa después de sort."], "see_also": ["sort"]},
	"grep": {
		"usage": "grep [-i] [-n] [-v] [-c] [-r] patrón [archivo...]",
		"summary": "Busca líneas que coinciden con un patrón (expresión regular).",
		"options": [["-i", "ignora mayúsculas y minúsculas"], ["-n", "muestra el número de línea"], ["-v", "invierte: líneas que NO coinciden"], ["-c", "solo cuenta las líneas que coinciden"], ["-r", "busca dentro de directorios, recursivamente"]],
		"examples": [["grep -n root /etc/passwd", "líneas con 'root', numeradas"], ["grep -ri password .", "busca 'password' en todo lo de aquí"]],
		"notes": ["Código de salida: 0 si hubo coincidencias, 1 si no, 2 si hubo un error. Los scripts se apoyan en eso.", "Aquí usa expresiones regulares extendidas (como grep -E)."],
		"dont_conclude": ["Que grep no encuentre nada no prueba que lo buscado no exista: quizá no tienes permiso, está en otro archivo o el patrón no era el adecuado."],
		"see_also": ["find", "cat"],
	},
	"find": {
		"usage": "find [ruta...] [-name patrón] [-type f|d]",
		"summary": "Busca archivos y directorios recorriendo un árbol.",
		"options": [["-name patrón", "por nombre; admite * y ? (ponlo entre comillas)"], ["-type f|d", "solo archivos (f) o solo directorios (d)"]],
		"examples": [["find / -name '*.conf'", "todos los .conf del sistema"], ["find . -type d", "los directorios desde aquí"]],
		"notes": ["Si un directorio no se puede leer, find lo dice y sigue con el resto."],
		"dont_conclude": ["Que find no vea algo no prueba que no esté: puede estar en un directorio al que no tienes acceso."],
		"see_also": ["ls", "grep"],
	},
	"chmod": {
		"usage": "chmod modo archivo...",
		"summary": "Cambia los permisos de un archivo (solo su dueño o root).",
		"options": [["755, 644...", "modo octal: tres cifras = dueño, grupo y otros (4 = leer, 2 = escribir, 1 = ejecutar)"], ["u+x", "forma simbólica: u (dueño), g (grupo), o (otros), a (todos); + añade, - quita, = fija; r, w, x"]],
		"examples": [["chmod 600 nota.txt", "solo el dueño lee y escribe"], ["chmod u+x script.sh", "el dueño puede ejecutarlo"], ["chmod go-r nota.txt", "grupo y otros pierden la lectura"]],
		"notes": ["Puedes quitarte permisos a ti mismo, incluso de lectura sobre tu propio archivo."],
		"see_also": ["ls", "stat", "id"],
	},
	"stat": {
		"usage": "stat archivo...",
		"summary": "Muestra los datos completos de un archivo: dueño, grupo, permisos, tamaño.",
		"options": [],
		"examples": [["stat /etc/shadow", "quién es el dueño y con qué permisos"]],
		"notes": ["Para entender un permiso necesitas los dos lados: el archivo (dueño, grupo, modo) y tú (usuario y grupos, con id)."],
		"see_also": ["ls", "id", "chmod"],
	},
	"whoami": {"usage": "whoami", "summary": "Muestra tu nombre de usuario.", "options": [], "examples": [["whoami", "quién eres"]], "see_also": ["id"]},
	"id": {"usage": "id", "summary": "Muestra tu identidad: usuario, grupo principal y todos tus grupos.", "options": [], "examples": [["id", "uid, gid y grupos"]], "notes": ["Un permiso de grupo solo te sirve si perteneces a ese grupo."], "see_also": ["groups", "stat"]},
	"groups": {"usage": "groups", "summary": "Muestra los grupos a los que perteneces.", "options": [], "examples": [["groups", "lista de grupos"]], "see_also": ["id"]},
	"hostname": {"usage": "hostname", "summary": "Muestra el nombre de esta máquina.", "options": [], "examples": [["hostname", "nombre del equipo"]]},
	"history": {"usage": "history", "summary": "Muestra los comandos que has escrito, numerados.", "options": [], "examples": [["history", "tu historial"]], "notes": ["Con las flechas arriba y abajo recorres el historial sin escribir history."]},
	"echo": {"usage": "echo [-n] texto...", "summary": "Escribe texto. Con -n no añade salto de línea al final.", "options": [["-n", "sin salto de línea final"]], "examples": [["echo hola > f.txt", "crea o sobrescribe un archivo"], ["echo mas >> f.txt", "añade al final"]]},
	"sudo": {"usage": "sudo comando", "summary": "Ejecuta un comando con los privilegios de otro usuario (normalmente root).", "options": [], "examples": [["sudo cat /etc/shadow", "intento de leer como root"]], "notes": ["En este laboratorio tu usuario NO está en sudoers: es lo normal en un usuario sin privilegios.", "Escalar privilegios es un tema de misiones futuras, no un atajo para saltarse permisos."], "dont_conclude": ["Que sudo te rechace no significa que el archivo esté 'roto' ni protegido para siempre: significa que tu cuenta no tiene esa autorización."], "see_also": ["su", "id"]},
	"su": {"usage": "su [usuario]", "summary": "Cambia de usuario; pide la contraseña de ese usuario.", "options": [], "examples": [["su", "intenta pasar a root"]], "notes": ["Sin la contraseña no puedes cambiar de usuario."], "see_also": ["sudo"]},
	"ping": {
		"usage": "ping [-c N] host",
		"summary": "Envía paquetes de eco (ICMP) a un host y espera respuesta.",
		"options": [["-c N", "número de paquetes (por defecto 4 en este laboratorio)"]],
		"examples": [["ping -c 3 web01", "3 paquetes a web01"], ["ping 10.0.0.5", "lo mismo, por IP"]],
		"notes": ["Dos silencios distintos: 'Destination Host Unreachable' (tu equipo no alcanza esa dirección) y la ausencia total de respuesta (algo descarta los paquetes).", "En el laboratorio envía un número fijo de paquetes, nunca indefinidamente."],
		"dont_conclude": ["Que un host NO responda al ping no demuestra que esté apagado: puede estar vivo y descartar el ICMP con un cortafuegos."],
		"short_h": true,
		"see_also": ["nmap", "curl"],
	},
	"nmap": {
		"usage": "nmap [opciones] objetivo",
		"summary": "Descubre hosts y escanea puertos para ver qué servicios ofrecen.",
		"options": [["-sn", "solo descubrimiento de hosts, sin escanear puertos"], ["-sV", "intenta identificar producto y versión de cada servicio"], ["-Pn", "no hace descubrimiento previo: escanea aunque el host 'no responda'"], ["-p 22,80 / -p 1-100 / -p-", "puertos concretos, un rango, o todos (1-65535)"]],
		"examples": [["nmap -sn 10.0.0.0/24", "qué hosts responden en la red"], ["nmap -sV web01", "puertos y versiones de web01"], ["nmap -Pn 10.0.0.9", "escanea un host que ignora el ping"]],
		"notes": ["Estados de puerto: open (algo escucha), closed (el host responde y nada escucha) y filtered (algo impide saberlo, p. ej. un cortafuegos).", "Por defecto escanea 1000 puertos habituales: un servicio en un puerto raro no aparece sin -p-.", "Objetivos: IP, nombre, rango 10.0.0.1-20 o red 10.0.0.0/24."],
		"dont_conclude": ["Un puerto 'filtered' no está ni abierto ni cerrado: es 'no se puede saber'.", "Una versión (-sV) no prueba que haya una vulnerabilidad: es un dato para investigar.", "Que un host no salga en el descubrimiento no prueba que no exista (mira -Pn)."],
		"short_h": true,
		"see_also": ["ping", "curl"],
	},
	"curl": {
		"usage": "curl [opciones] URL",
		"summary": "Hace una petición HTTP y muestra la respuesta.",
		"options": [["-i", "incluye las cabeceras de la respuesta"], ["-I", "solo las cabeceras (petición HEAD)"], ["-v", "modo detallado: muestra la petición y la respuesta"], ["-L", "sigue las redirecciones"], ["-s / -S", "silencioso / silencioso pero muestra errores"], ["-o archivo", "guarda la respuesta en un archivo"], ["-X MÉTODO", "fuerza el método (GET, POST, PUT...)"], ["-d 'a=1&b=2'", "envía datos de formulario (usa POST)"], ["--data-urlencode 'q=a b'", "como -d, pero codifica el valor"], ["-G", "manda los datos en la URL en vez de en el cuerpo"], ["-H 'Nombre: valor'", "añade una cabecera a la petición"], ["-b 'a=1; b=2' | -b archivo", "envía cookies (texto o archivo de cookies)"], ["-c archivo", "guarda en un archivo las cookies que reciba"]],
		"examples": [["curl web01/robots.txt", "pide un archivo"], ["curl -i web01/admin", "cabeceras y cuerpo"], ["curl -L web01/old", "sigue una redirección"], ["curl -i -d 'u=demo&p=x' shop01/login", "envía un formulario y muestra cabeceras"], ["curl -b cookies.txt shop01/perfil", "reutiliza una sesión guardada"]],
		"notes": ["Errores de conexión distintos: (7) Connection refused = puerto cerrado; (28) timed out = nadie responde (filtrado); (52) Empty reply = el puerto está abierto pero no habla HTTP.", "Códigos de estado: 200 OK, 301/302 redirección, 403 prohibido, 404 no existe."],
		"dont_conclude": ["Un 403 no significa que no exista: significa que el servidor se niega a mostrártelo.", "Un 200 en una ruta no implica por sí solo que sea una vulnerabilidad: depende de qué contenga."],
		"short_h": true,
		"see_also": ["nmap", "grep"],
	},
	"man": {"usage": "man comando", "summary": "Muestra la ficha completa de un comando: opciones, ejemplos, límites y qué NO concluir.", "options": [], "examples": [["man nmap", "la ficha de nmap"]], "short_h": true, "see_also": ["help", "cheatsheet"]},
	"help": {"usage": "help [comando]", "summary": "Lista los comandos disponibles, o resume uno concreto.", "options": [], "examples": [["help", "todos los comandos"], ["help grep", "resumen de grep"]], "short_h": true, "see_also": ["man", "cheatsheet"]},
	"cheatsheet": {"usage": "cheatsheet [tema]", "summary": "Chuleta de comandos útiles agrupados por tema.", "options": [], "examples": [["cheatsheet", "todos los temas"], ["cheatsheet red", "solo reconocimiento de red"]], "notes": ["Temas: orientarte, leer, permisos, red, http, scripts, combinar, juego."], "short_h": true, "see_also": ["man", "help"]},
	"mision": {"usage": "mision", "summary": "[juego] Muestra tu misión actual y el estado de cada objetivo.", "options": [], "examples": [["mision", "dónde estás en la misión"]], "short_h": true},
	"pista": {"usage": "pista [N]", "summary": "[juego] Pide una pista del objetivo actual (o del N). Cada llamada da una ayuda más concreta; la última es la solución explicada.", "options": [], "examples": [["pista", "ayuda del objetivo actual"], ["pista 3", "ayuda del objetivo 3"]], "notes": ["Pedir pistas no bloquea nada ni resta de forma injusta: solo anota qué conviene repasar."], "short_h": true},
	"responder": {"usage": "responder [número|letra]", "summary": "[juego] Muestra o contesta la pregunta de autoevaluación activa.", "options": [], "examples": [["responder", "ver la pregunta"], ["responder 2", "elegir la opción 2"]], "short_h": true},
	"hallazgo": {"usage": "hallazgo <tipo> \"descripción\"", "summary": "[juego] Registra un hallazgo en tu cuaderno con su clasificación: indicio, hipotesis, confirmado o falso-positivo.", "options": [["indicio", "un dato que sugiere algo pero no lo demuestra"], ["hipotesis", "explicación posible que falta comprobar"], ["confirmado", "demostrado con una prueba repetible"], ["falso-positivo", "parecía un problema y se ha descartado"]], "examples": [["hallazgo indicio \"Apache 2.4.49 en web01:80\"", "una versión es un indicio"]], "notes": ["Sin argumentos muestra los tipos y tu cuaderno."], "short_h": true},
	"revisar": {"usage": "revisar [archivo]", "summary": "[juego] Revisa tu informe contra una lista de comprobación: qué, dónde, evidencia, impacto y recomendación.", "options": [], "examples": [["revisar", "revisa el informe de la misión"]], "notes": ["Comprueba que contiene los elementos de un buen hallazgo y que no afirmas más de lo que probaste. No juzga tu redacción."], "short_h": true},
	"modo": {"usage": "modo [libre|mision]", "summary": "[juego] Muestra o cambia el modo de juego. En modo libre no hay objetivos ni XP: es un laboratorio para experimentar sin miedo.", "options": [["libre", "sin objetivos: experimenta y rompe cosas"], ["mision", "vuelve a tus objetivos"]], "examples": [["modo", "ver el modo actual"], ["modo libre", "pasar a experimentar"]], "notes": ["Lo que hagas en modo libre no da XP ni cuenta para los objetivos."], "short_h": true, "see_also": ["reiniciar", "repaso"]},
	"reiniciar": {"usage": "reiniciar", "summary": "[juego] Restaura el laboratorio a su estado inicial (archivos, permisos y descubrimientos). Tu progreso no se pierde.", "options": [], "examples": [["reiniciar", "empezar el laboratorio de cero"]], "notes": ["Útil en modo libre si estropeas algo: borras o cambias permisos y vuelves al principio."], "short_h": true, "see_also": ["modo"]},
	"nano": {"usage": "nano archivo", "summary": "Editor de texto sencillo. Abre una ventana para escribir o corregir un archivo, por ejemplo tu informe.", "options": [], "examples": [["nano informe/borrador.md", "edita el borrador del informe"], ["nano notas.txt", "crea o edita un archivo en tu directorio"]], "notes": ["Ctrl+S guarda; Esc cierra (si hay cambios sin guardar, avisa antes de descartarlos).", "Respeta los permisos: necesitas poder leer el archivo para abrirlo y escribir en él para guardarlo."], "short_h": true, "see_also": ["cat", "echo", "revisar"]},
	"true": {"usage": "true", "summary": "No hace nada y termina con éxito (código de salida 0).", "options": [], "examples": [["true && echo ok", "el && deja pasar al siguiente comando"]], "notes": ["Sirve para entender los códigos de salida: `echo $?` muestra el del último comando."], "see_also": ["false", "test"]},
	"false": {"usage": "false", "summary": "No hace nada y termina con fallo (código de salida 1).", "options": [], "examples": [["false || echo plan B", "el || solo corre si el anterior falló"]], "see_also": ["true", "test"]},
	"export": {"usage": "export NOMBRE=valor", "summary": "Crea o actualiza una variable y la marca como exportada (la verá `env`). Sin argumentos lista las exportadas.", "options": [], "examples": [["export OBJETIVO=app02", "variable lista para usar como $OBJETIVO"]], "notes": ["Una variable normal se crea con NOMBRE=valor (sin espacios alrededor del =)."], "see_also": ["env", "unset"]},
	"unset": {"usage": "unset NOMBRE", "summary": "Borra una variable.", "options": [], "examples": [["unset OBJETIVO", "olvida la variable OBJETIVO"]], "see_also": ["export", "env"]},
	"env": {"usage": "env", "summary": "Muestra las variables exportadas (HOME, USER, PATH...).", "options": [], "examples": [["env | grep HOME", "buscar una variable concreta"]], "see_also": ["export"]},
	"seq": {"usage": "seq [primero [paso]] último", "summary": "Escribe una secuencia de números enteros, uno por línea.", "options": [], "examples": [["seq 3", "1 2 3"], ["seq 2 2 10", "2 4 6 8 10"]], "notes": ["Muy útil dentro de un bucle: for n in $(seq 1 5); do echo intento $n; done", "Máximo 1000 elementos."], "see_also": ["echo"]},
	"test": {"usage": "test expresión", "summary": "Comprueba una condición y sale con 0 si es cierta, 1 si es falsa. No escribe nada: el resultado va en el código de salida.", "options": [["-e f / -f f / -d f", "existe / es archivo / es directorio"], ["-r f / -w f / -x f", "puedes leerlo / escribirlo / ejecutarlo"], ["-z s / -n s", "cadena vacía / no vacía"], ["a = b / a != b", "cadenas iguales / distintas"], ["n -eq m (-ne -lt -le -gt -ge)", "comparación numérica"], ["! expr", "niega la condición"]], "examples": [["test -f informe/borrador.md && echo existe", "actuar solo si existe"], ["test -d /srv || echo falta", "avisar si NO existe"]], "see_also": ["true", "false"]},
	"ahora": {"usage": "ahora", "summary": "[juego] ¿Qué hago ahora? Muestra dónde estás, tu objetivo actual y un paso pequeño para seguir. También con F4.", "options": [], "examples": [["ahora", "orientarte si te has perdido"]], "notes": ["No gasta pistas ni afecta a tu puntuación."], "short_h": true, "see_also": ["mision", "pista"]},
	"tutorial": {"usage": "tutorial", "summary": "[juego] Vuelve a ver el tutorial inicial.", "options": [], "examples": [["tutorial", "repasar cómo funciona el juego"]], "short_h": true},
	"[": {"usage": "[ expresión ]", "summary": "Igual que `test`, pero la expresión va entre corchetes (con espacios dentro). Es lo habitual en un if.", "options": [], "examples": [["[ -f informe/borrador.md ] && echo existe", "comprobar un archivo"], ["if [ 3 -lt 5 ]; then echo menor; fi", "condición dentro de un if"]], "notes": ["Los espacios son obligatorios: `[ -f x ]` funciona, `[-f x]` no."], "see_also": ["test"]},
	"laboratorio": {"usage": "laboratorio [id]", "summary": "[juego] Lista los laboratorios (cada uno con sus misiones) y cambia de uno a otro. Se desbloquean en orden y el progreso de cada uno se guarda por separado.", "options": [], "examples": [["laboratorio", "ver la lista y el estado"], ["laboratorio tienda_web", "cambiar a ese laboratorio"]], "notes": ["Solo se puede cambiar desde el modo misión."], "short_h": true, "see_also": ["mision", "modo"]},
	"repaso": {"usage": "repaso [iniciar [concepto] | salir]", "summary": "[juego] Repaso espaciado: muestra qué conceptos conviene repasar e inicia retos nuevos en otra red, para demostrar que no es memoria.", "options": [["iniciar", "repasa el concepto más atrasado, o el que indiques"], ["salir", "abandona el repaso y vuelve a tu laboratorio"]], "examples": [["repaso", "qué toca repasar"], ["repaso iniciar permisos", "reto de permisos"]], "notes": ["Lo que resuelves con ayuda vuelve pronto; lo que resuelves solo, más tarde. Fallar un repaso nunca resta XP.", "Un repaso es un escenario distinto: otros hosts, otras IP, otros puertos."], "short_h": true, "see_also": ["modo", "perfil"]},
	"expediente": {"usage": "expediente", "summary": "[juego] Muestra las evidencias reunidas.", "options": [], "examples": [["expediente", "tus pruebas"]], "short_h": true},
	"perfil": {"usage": "perfil", "summary": "[juego] Muestra tu nivel y las competencias que has demostrado.", "options": [], "examples": [["perfil", "tu progreso"]], "short_h": true},
}

## Chuleta por temas: [clave, título, [[comando, para qué]]]
const CHEATSHEET := [
	["orientarte", "ORIENTARTE", [["pwd", "dónde estoy"], ["ls -la", "qué hay aquí (incluido lo oculto)"], ["cd <dir> / cd .. / cd", "moverme / subir / ir a casa"], ["whoami / id / hostname", "quién soy y en qué máquina estoy"]]],
	["leer", "LEER Y BUSCAR", [["cat <archivo>", "ver un archivo"], ["head -n 5 <f> / tail -n 5 <f>", "primeras / últimas líneas"], ["grep -rn <texto> .", "buscar texto dentro de archivos"], ["find / -name '*.conf'", "buscar archivos por nombre"], ["wc -l <f>", "contar líneas"]]],
	["permisos", "PERMISOS E IDENTIDAD", [["ls -l <f> / stat <f>", "dueño, grupo y permisos de un archivo"], ["id / groups", "quién soy y a qué grupos pertenezco"], ["chmod 600 <f> / chmod u+x <f>", "cambiar permisos (solo en lo tuyo)"], ["sudo / su", "cambiar de usuario (aquí no estás autorizado)"]]],
	["red", "RED Y RECONOCIMIENTO", [["ping -c 3 <host>", "¿responde? (no responder no prueba que esté apagado)"], ["nmap -sn <red>", "descubrir qué hosts responden"], ["nmap <host>", "puertos abiertos"], ["nmap -sV <host>", "servicios y versiones"], ["nmap -Pn <host>", "escanear aunque no responda al ping"], ["nmap -p- <host>", "todos los puertos"]]],
	["http", "HTTP", [["curl <url>", "ver el cuerpo de una página"], ["curl -i <url>", "con cabeceras"], ["curl -I <url>", "solo cabeceras"], ["curl -v <url>", "petición y respuesta, paso a paso"], ["curl -L <url>", "seguir redirecciones"], ["curl -o <f> <url>", "guardar la respuesta"], ["curl -i -d 'a=1&b=2' <url>", "enviar un formulario"], ["curl -c <f> ... / curl -b <f> ...", "guardar / reutilizar cookies de sesión"], ["curl -H 'Nombre: valor' <url>", "añadir una cabecera"]]],
	["scripts", "SCRIPTS DE UNA LÍNEA", [["VAR=valor / $VAR / ${VAR}", "guardar y usar valores (sin espacios en el =)"], ["echo $?", "código de salida del último comando (0 = bien)"], ["a ; b", "b se ejecuta siempre, tras a"], ["a && b", "b solo si a salió bien"], ["a || b", "b solo si a falló"], ["for x in 1 2 3; do echo $x; done", "repetir un comando por cada elemento"], ["if [ -f f ]; then echo si; else echo no; fi", "decidir según una condición"], ["while [ $n -lt 3 ]; do ...; done", "repetir mientras se cumpla (con límite de seguridad)"], ["break / continue", "salir del bucle / saltar a la siguiente vuelta"], ["case $x in a|b) ...;; *) ...;; esac", "elegir una rama según el valor (patrones con * y ?)"], ["f() { echo $1; }  /  f hola", "funciones: $1 $2, $# y $@, return N (hasta 20 llamadas anidadas)"], ["$(comando)", "usar la salida de un comando como texto"], ["*.log / a?c", "comodines: todos los archivos que encajan (entre comillas no se expanden)"], ["test -f f && echo ok", "comprobar condiciones"], ["seq 1 5 / env / export", "números, variables exportadas"]]],
	["combinar", "COMBINAR Y EDITAR", [["cmd1 | cmd2", "la salida de uno es la entrada del otro"], ["cmd > f / cmd >> f", "guardar salida (sobrescribe / añade)"], ["nano <f>", "editar un archivo (Ctrl+S guarda, Esc cierra)"], ["history / flechas ↑↓", "repetir comandos"], ["ahora / F4", "¿qué hago ahora? (sin gastar pistas)"], ["Tab", "autocompletar"], ["Ctrl+L / clear", "limpiar pantalla"]]],
	["juego", "TU CUADERNO (JUEGO)", [["mision", "tu misión y objetivos"], ["pista [N]", "ayuda progresiva"], ["responder [n]", "autoevaluación opcional"], ["hallazgo <tipo> \"texto\"", "registrar un hallazgo"], ["revisar", "revisar tu informe"], ["expediente / perfil", "evidencias y competencias"], ["man <cmd> / <cmd> --help", "ayuda de cualquier comando"]]],
]


static func has(command_name: String) -> bool:
	return DOCS.has(command_name)


## ¿Debe `-h` mostrar la ayuda de este comando? (En otros, -h es una opción real.)
static func short_h_is_help(command_name: String) -> bool:
	return DOCS.has(command_name) and DOCS[command_name].get("short_h", false)


const WIDTH := 74        # ancho de línea que cabe cómodamente en la terminal del juego
const OPTION_COLUMN := 22
const EXAMPLE_COLUMN := 26
const CHEAT_COLUMN := 30


## Resumen: lo que sale con `comando --help`.
static func short_help(command_name: String) -> String:
	var doc: Dictionary = DOCS[command_name]
	var text := "Uso: %s\n%s\n" % [doc["usage"], _wrap_lines(doc["summary"], WIDTH, 0)]
	if not doc.get("options", []).is_empty():
		text += "\nOpciones:\n"
		for option: Array in doc["options"]:
			text += _row(option[0], option[1], OPTION_COLUMN)
	if not doc.get("examples", []).is_empty():
		text += "\nEjemplos:\n"
		for example: Array in doc["examples"]:
			text += _row(example[0], example[1], EXAMPLE_COLUMN)
	return text + "\n(Ficha completa, con límites y qué NO concluir: man %s)\n" % command_name


## Ficha completa: lo que sale con `man comando`.
static func man_page(command_name: String) -> String:
	var doc: Dictionary = DOCS[command_name]
	var text := "%s(1)\n%s\n\nUSO\n  %s\n" % [command_name.to_upper(), _wrap_lines(doc["summary"], WIDTH, 0), doc["usage"]]
	if not doc.get("options", []).is_empty():
		text += "\nOPCIONES\n"
		for option: Array in doc["options"]:
			text += _row(option[0], option[1], OPTION_COLUMN)
	if not doc.get("examples", []).is_empty():
		text += "\nEJEMPLOS\n"
		for example: Array in doc["examples"]:
			text += _row(example[0], example[1], EXAMPLE_COLUMN)
	if not doc.get("notes", []).is_empty():
		text += "\nNOTAS\n"
		for note: String in doc["notes"]:
			text += _bullet("-", note)
	if not doc.get("dont_conclude", []).is_empty():
		text += "\nQUÉ NO PUEDES CONCLUIR\n"
		for item: String in doc["dont_conclude"]:
			text += _bullet("x", item)
	if not doc.get("see_also", []).is_empty():
		text += "\nVER TAMBIÉN\n  %s\n" % ", ".join(doc["see_also"])
	return text


## Parte un texto en palabras en líneas de como mucho "width" caracteres.
static func _wrap(text: String, width: int) -> Array[String]:
	var lines: Array[String] = []
	var current := ""
	for word in text.split(" ", false):
		if current != "" and current.length() + 1 + word.length() > width:
			lines.append(current)
			current = word
		else:
			current = word if current == "" else current + " " + word
	if current != "":
		lines.append(current)
	if lines.is_empty():
		lines.append("")
	return lines


static func _wrap_lines(text: String, width: int, indent: int) -> String:
	return ("\n" + " ".repeat(indent)).join(_wrap(text, width - indent))


## Fila "opción  descripción" con sangría francesa: la descripción larga sigue alineada.
## Si la opción no cabe en su columna, va sola en una línea y la descripción debajo.
static func _row(left: String, right: String, column: int) -> String:
	var indent := 2 + column + 1
	var lines := _wrap(right, WIDTH - indent)
	var text := ""
	if left.length() > column:
		text += "  %s\n" % left
		for line in lines:
			text += " ".repeat(indent) + line + "\n"
	else:
		text += "  %s %s\n" % [left.rpad(column), lines[0]]
		for line in lines.slice(1):
			text += " ".repeat(indent) + line + "\n"
	return text


static func _bullet(mark: String, text: String) -> String:
	var lines := _wrap(text, WIDTH - 4)
	var out := "  %s %s\n" % [mark, lines[0]]
	for line in lines.slice(1):
		out += "    %s\n" % line
	return out


## Chuleta completa o de un tema. Devuelve "" si el tema no existe.
static func cheatsheet(topic := "") -> String:
	var text := ""
	for section: Array in CHEATSHEET:
		if topic != "" and section[0] != topic.to_lower():
			continue
		text += "%s\n" % section[1]
		for row: Array in section[2]:
			text += _row(row[0], row[1], CHEAT_COLUMN)
		text += "\n"
	if text != "" and topic == "":
		text += "Temas sueltos: cheatsheet <tema>. Ayuda de un comando: <comando> --help o man <comando>.\n"
	return text


static func topics() -> Array[String]:
	var result: Array[String] = []
	for section: Array in CHEATSHEET:
		result.append(section[0])
	return result
