extends RefCounted
## Perfil de competencias y logros, calculados a partir del progreso de todos los laboratorios.
## Nada de esto se guarda aparte: se deriva de lo que ya demostraste (qué objetivos, con cuánta ayuda).

## El árbol de habilidades: grupos de conceptos en el orden en que se aprenden.
const TREE := [
	{"title": "Fundamentos Linux", "concepts": [["navegacion", "Navegación"], ["archivos_ocultos", "Ocultos"], ["usuarios", "Usuarios"], ["permisos", "Permisos"]]},
	{"title": "Redes y reconocimiento", "concepts": [["descubrimiento_hosts", "Descubrir"], ["puertos_servicios", "Puertos"], ["versiones", "Versiones"], ["interpretacion_resultados", "Interpretar"]]},
	{"title": "Web", "concepts": [["http", "HTTP"], ["cabeceras_http", "Cabeceras"], ["cookies_sesiones", "Cookies"], ["control_acceso", "Acceso"]]},
	{"title": "Análisis e informe", "concepts": [["alcance", "Alcance"], ["analisis_hallazgos", "Hallazgos"], ["analisis_logs", "Logs"], ["informe", "Informe"]]},
	{"title": "Automatización", "concepts": [["tuberias", "Tuberías"], ["variables_shell", "Variables"], ["bucles", "Bucles"], ["encadenar_comandos", "Encadenar"], ["comodines", "Comodines"]]},
	{"title": "Defensa y configuración", "concepts": [["configuracion_segura", "Configurar"], ["datos_sensibles", "Datos"], ["verificacion", "Verificar"]]},
]

const ACHIEVEMENTS := [
	["primer_paso", "Primer paso", "Completa tu primer objetivo."],
	["por_tu_cuenta", "Por tu cuenta", "Completa 5 objetivos sin pedir ayuda."],
	["mision_limpia", "Misión limpia", "Completa una misión entera sin pistas ni soluciones."],
	["transferencia", "Transferencia", "Aplica lo aprendido en otro escenario (objetivo de transferencia)."],
	["sin_miedo", "Sin miedo a equivocarte", "Completa un objetivo tras haber fallado antes: los errores enseñan."],
	["cabeza_fria", "Cabeza fría", "Acierta una autoevaluación a la primera."],
	["detective", "Detective", "Reúne 10 evidencias."],
	["primer_laboratorio", "Primer laboratorio", "Completa el primer laboratorio."],
	["auditoria_completa", "Auditoría completa", "Completa todos los laboratorios."],
	["memoria", "Memoria de acero", "Supera 3 repasos."],
	["nivel_5", "Nivel 5", "Alcanza el nivel 5 con tu XP total."],
]

const XP_PER_LEVEL := 300


## Estado de cada concepto: "solo", "ayuda", "solucion" o "" (sin hacer). Manda el peor resultado,
## como en el repaso: un concepto no está dominado hasta que lo está en todos sus objetivos.
static func concept_levels(engines: Dictionary) -> Dictionary:
	var counts := {}
	for engine: RefCounted in engines.values():
		var profile: Dictionary = engine.competency_profile()
		for concept: String in profile:
			if not counts.has(concept):
				counts[concept] = {"solo": 0, "ayuda": 0, "solucion": 0}
			for key: String in ["solo", "ayuda", "solucion"]:
				counts[concept][key] += profile[concept][key]
	var levels := {}
	for concept: String in counts:
		var entry: Dictionary = counts[concept]
		levels[concept] = "solucion" if entry["solucion"] > 0 else ("ayuda" if entry["ayuda"] > 0 else "solo")
	return levels


## Cuántos objetivos hay completados por concepto (para mostrarlo en el árbol).
static func concept_counts(engines: Dictionary) -> Dictionary:
	var result := {}
	for engine: RefCounted in engines.values():
		var profile: Dictionary = engine.competency_profile()
		for concept: String in profile:
			result[concept] = result.get(concept, 0) + profile[concept]["solo"] + profile[concept]["ayuda"] + profile[concept]["solucion"]
	return result


## [{id, title, description, unlocked}] para todos los logros. stats = {"review_passes": n}.
static func evaluate(engines: Dictionary, stats: Dictionary) -> Array:
	var done := 0
	var alone := 0
	var transfer := false
	var after_failing := false
	var first_try_quiz := false
	var clean_mission := false
	var evidence := 0
	var total_xp := 0
	var finished_books := 0
	for engine: RefCounted in engines.values():
		total_xp += engine.xp
		if engine.is_finished():
			finished_books += 1
		for card: Dictionary in engine.evidence_cards():
			evidence += 1 if card["collected"] else 0
		for mission: Dictionary in engine.book["missions"]:
			var required_all_done := true
			var required_all_alone := true
			var required_count := 0
			for objective: Dictionary in mission["objectives"]:
				var id: String = objective["id"]
				var is_done: bool = engine.status_of(id) == "done"
				if is_done:
					done += 1
					alone += 1 if engine.mastery_of(id) == "solo" else 0
					transfer = transfer or objective.get("transfer", false)
					after_failing = after_failing or engine.attempts_of(id) > 0
					first_try_quiz = first_try_quiz or (objective.has("question") and engine.attempts_of(id) == 0)
				if not engine.is_optional(objective):
					required_count += 1
					required_all_done = required_all_done and is_done
					required_all_alone = required_all_alone and is_done and engine.mastery_of(id) == "solo"
			clean_mission = clean_mission or (required_count > 0 and required_all_done and required_all_alone)

	var unlocked := {
		"primer_paso": done >= 1,
		"por_tu_cuenta": alone >= 5,
		"mision_limpia": clean_mission,
		"transferencia": transfer,
		"sin_miedo": after_failing,
		"cabeza_fria": first_try_quiz,
		"detective": evidence >= 10,
		"primer_laboratorio": engines.size() > 0 and engines.values()[0].is_finished(),
		"auditoria_completa": engines.size() > 0 and finished_books == engines.size(),
		"memoria": int(stats.get("review_passes", 0)) >= 3,
		"nivel_5": total_xp / XP_PER_LEVEL + 1 >= 5,
	}
	var result: Array = []
	for item: Array in ACHIEVEMENTS:
		result.append({"id": item[0], "title": item[1], "description": item[2], "unlocked": unlocked.get(item[0], false)})
	return result


static func unlocked_ids(achievements: Array) -> Array[String]:
	var ids: Array[String] = []
	for item: Dictionary in achievements:
		if item["unlocked"]:
			ids.append(item["id"])
	return ids
