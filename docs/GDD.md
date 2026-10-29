# RoninShell: documento de diseño (resumen)

Fecha: 2026-10-29. Versión de trabajo, pendiente de revisión.

> Este archivo resume el diseño. La versión completa, con tablas y el esquema de arquitectura, está en el documento de diseño compartido durante la sesión de descubrimiento.

## 1. Visión y objetivos

RoninShell es un juego en Godot donde aprendes pentesting investigando en un laboratorio controlado, no leyendo. Es el sucesor práctico de Pentest Academy: aquella app ayuda a recordar conceptos; esta obliga a usarlos.

Objetivo: pasar de conocer comandos a investigar, razonar, validar hallazgos y cerrar laboratorios de forma autónoma.

- Aprender haciendo: ningún reto se supera pegando una secuencia memorizada.
- Misiones de 10-15 min con recompensa visible.
- Un solo ejecutable de Godot, sin Docker, cuentas ni internet.
- La terminal nunca toca el sistema real.

No es: una historia con personajes, un curso en vídeo, un Kali real ni un juego con vidas, energía o esperas.

## 2. Público, nivel inicial y ritmo de aprendizaje

Jugador: nivel intermedio en Linux, poca programación, aprendizaje visual, sesiones cortas y sin presión.

| Problema habitual | Respuesta de diseño |
| --- | --- |
| Arrancar cuesta | Botón "Continuar" que deja en la última misión |
| Perder el hilo | Panel fijo de objetivo actual |
| Recompensa lejana | Micro-victorias cada 1-2 minutos |
| Muros de texto | Frases cortas, iconos y esquemas |
| Sobrecarga | Revelado progresivo de ayuda y teoría |
| Frustración | Pistas sin penalización; errores que enseñan |
| Sesiones impredecibles | Punto de guardado en cada paso |
| Repetición aburrida | Repasos en escenarios distintos |
| Sesiones demasiado largas | Aviso suave de descanso a los 45-50 min (ignorable) |

## 3. Filosofía pedagógica

Ciclo: objetivo, investigar, probar, interpretar, decidir, validar, reflexionar (las misiones cortas usan 3-4 pasos).

Pistas en cuatro niveles: pregunta, concepto, orientación, solución explicada. Ninguna bloquea; el juego anota si resolviste por tu cuenta, con ayuda o viendo la solución.

Cada comando tiene una ficha: para qué sirve, parámetros, cómo leer la salida, alternativas, errores típicos y qué conclusiones NO se pueden sacar. Tras aprender algo, un ejercicio de transferencia lo repite en otro escenario.

## 4. Mecánicas de juego

Misiones cortas, expediente de evidencias, XP por razonamiento (no por velocidad), evaluación de metodología, logros, árbol de habilidades, desbloqueo de herramientas, retos opcionales, repasos con repetición espaciada, modo libre y modo examen. Sin vidas, energía, esperas, anuncios ni suscripciones.

## 5. Dirección visual

Terminal oscura cyber-retro con iconos y mapa de red en pixel art (generado con `pxl`, exportado como PNG con filtro nearest). La imagen explica: hosts como sprites, puertos como puertas, iconos por servicio, expediente con tarjetas de evidencia, árbol de habilidades iluminado.

```
+--------------------------------------------------------------+
| RoninShell   Misión 3: Primer contacto        XP ███░░  ▶   |
+-------------------------------+------------------------------+
|                               |  OBJETIVO                    |
|  ronin@lab:~$ nmap 10.0.0.5   |  [ ] Encuentra el host       |
|  Starting scan...             |  [x] Descubre sus puertos    |
|  22/tcp open  ssh             |  [ ] Identifica el servicio  |
|  80/tcp open  http            +------------------------------+
|  ronin@lab:~$ _               |  MAPA  (pixel art)           |
|                               |   [PC]---[host .5]--[host .9]|
|                               +------------------------------+
|                               |  EXPEDIENTE   [Pista] [Docs] |
+-------------------------------+------------------------------+
```

Efecto CRT, animaciones y sonido: opcionales y desactivables.

## 6. Arquitectura técnica

Recomendación: terminal simulada con motor de estado real, dentro de Godot, con la puerta abierta a herramientas reales aisladas en el futuro.

| | Simulada (recomendada) | Linux real | Híbrida |
| --- | --- | --- | --- |
| Instalación | Solo Godot | Docker o WSL | Opcional |
| Seguridad | Total | Requiere aislar | Depende |
| Control pedagógico | Total | Difícil | Mixto |
| Coste | Medio | Bajo al inicio, alto al integrar | Alto |

Zonas: interfaz de Godot; motor de laboratorio en GDScript puro y sin interfaz (intérprete, comandos simulados, estado del mundo); juego (motor de misiones, perfil del jugador, guardado local en `user://`); datos de contenido (laboratorios, misiones y fichas como archivos de texto).

Dependencias: Godot 4.7 + GDScript y tests automatizados. Sin base de datos, Docker, cuentas, internet ni IA externa.

## 7. Terminal y motor de simulación

Regla de oro: ningún comando devuelve texto inventado; todo se calcula sobre el estado del laboratorio.

Estado: hosts, servicios y puertos, sistema de archivos, usuarios, procesos, sitios web simulados, reglas de ocultación.

Intérprete: separar, resolver, ejecutar. Soporta comillas, rutas, `|`, `>`, `>>`. Variables, `&&` y bucles en fases posteriores. Nada llega al shell de Windows. Errores como los de Linux real, con nota didáctica aparte.

Comandos MVP: `ls`, `cd`, `pwd`, `cat`, `grep`, `find`, `ping`, `nmap`, `curl`, `help`, `man`, `history`.

Nmap MVP: `nmap <host>`, `-p`, `-p-`, `-sV`, `-sn`, `-Pn`, con salidas ambiguas a propósito (`filtered`, banner dudoso).

Lo no soportado se dice con claridad, sin fingir.

## 8. Itinerario de aprendizaje

| Módulo | Dominas al terminar | Requiere |
| --- | --- | --- |
| 0. Chequeo inicial | El juego sabe qué conoces | Nada |
| 1. Fundamentos Linux | Navegar, permisos, archivos, usuarios, procesos | 0 |
| 2. Redes y servicios | IP, puertos, TCP/UDP, DNS, servicios | 1 |
| 3. Reconocimiento y enumeración | Descubrir hosts, escanear, identificar servicios | 2 |
| 4. Análisis de vulnerabilidades | Indicio, hipótesis, confirmada, falso positivo | 3 |
| 5. Pentesting web | HTTP, sesiones, SQLi, XSS, path traversal | 2, 4 |
| 6. Validación y post-explotación controlada | Impacto seguro, relacionar hallazgos | 4, 5 |
| 7. Informe y comunicación | Hallazgos reproducibles con impacto y mitigación | 3+ |

Recorrido por módulo: aprender, practicar, aplicar, transferir, dominio, repaso.

## 9. Alcance del MVP

Un laboratorio, "Primer contacto": red ficticia de 2-3 hosts, 4 misiones de 10-15 min.

1. Orientación: moverse por el sistema y localizar una nota.
2. Quién está ahí: descubrir hosts activos.
3. Qué ofrece: puertos y versiones; interpretar un resultado ambiguo.
4. Lo que demuestras: evidencias y mini informe.

Incluye: terminal con historial y autocompletado básico, motor de estado, `nmap` con 5 opciones, panel de misión, 4 pistas, expediente, fichas, perfil sencillo, guardado local, una misión de transferencia, 15-20 sprites y tests del motor.

Fuera por ahora: pentesting web, privesc, scripts Bash, repetición espaciada completa, modo examen, herramientas reales, más de un laboratorio.

## 10. Funcionalidades futuras

Más laboratorios y módulos 4-7, repetición espaciada completa, modo examen, pentesting web simulado, scripts y variables, generador de variantes, editor de laboratorios, importar tarjetas de Pentest Academy, sonido, laboratorios reales aislados (sin internet, objetivos fijados, confirmación explícita), IA opcional, exportar progreso.

## 11. Criterios de aceptación

- "Continuar" lleva a una misión en menos de 10 segundos.
- Comandos coherentes entre sí con el estado.
- Errores de Linux real con nota didáctica; los comandos no soportados lo dicen.
- Ningún texto escrito llega al shell del PC.
- Las misiones se superan demostrando el objetivo, no con una secuencia fija.
- 4 pistas por misión; ninguna bloquea; se registra cómo resolviste.
- Al menos un resultado ambiguo que exige interpretar.
- Misión de transferencia, evidencias y mini informe.
- Cerrar y reabrir a mitad de misión restaura el estado; todo funciona sin internet.
- Animaciones, CRT y sonido ajustables.
- Los tests automáticos pasan.
- Una sesión de 15 min termina con una micro-victoria visible y un siguiente paso claro.

## 12. Estrategia de pruebas

El motor es código puro y se prueba en modo consola con el ejecutable de Godot.

| Capa | Qué se prueba |
| --- | --- |
| Intérprete | Comillas, rutas, pipes, errores de sintaxis |
| Comandos | Cada opción contra un estado conocido |
| Coherencia | `ls`, `cat`, `nmap`, `curl` sobre el mismo estado |
| Laboratorios | Misiones resolubles y sin atajo trivial (jugador automático) |
| Misiones y pistas | Objetivos, orden de pistas, puntuación |
| Guardado | Guardar, cerrar, reabrir |
| Seguridad | Ningún comando llega al anfitrión |
| Interfaz | Arranque sin errores y revisión visual |

Regla: no se pasa a la siguiente funcionalidad hasta que pasan las pruebas y se ha jugado lo que cambió.

## 13. Plan incremental

1. Esqueleto: proyecto Godot, carpetas, repo, pruebas en consola.
2. Estado del mundo cargado desde datos.
3. Intérprete con errores reales.
4. Comandos de archivos.
5. Terminal visual con historial y autocompletado.
6. Red y Nmap coherentes con el estado.
7. Misiones, pistas y evidencias.
8. Arte con pxl, mapa y animaciones.
9. Laboratorio completo con transferencia e informe.
10. Perfil, guardado y accesibilidad.

### Decisiones abiertas

- Estilo visual: terminal central + paneles + mapa pixel art.
- Nombre definitivo (RoninShell es provisional).
- ¿"Primer contacto" como primer laboratorio?
- Aviso de descanso activado por defecto.
- Pruebas: scripts propios (recomendado al inicio) o plugin GUT.
- Detalle de las fichas de comando: breves o completas.

### Riesgos

- Simular demasiado Linux: acotar la sintaxis y añadir comandos solo cuando una misión los necesite.
- Dedicar meses al arte: sprites mínimos primero.
- Contenido que se vuelve receta: cada misión debe admitir varias soluciones válidas.
- Perder el hilo: un paso a la vez, con commit y explicación al terminar.
