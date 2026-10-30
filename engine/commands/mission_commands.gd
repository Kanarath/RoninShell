extends RefCounted
## Órdenes de la capa de juego: mision, pista, responder, expediente y perfil.
## No existen en Linux: son tu cuaderno de campo dentro del laboratorio.

const CommandResult := preload("res://engine/shell/command_result.gd")

var tracker: RefCounted


func _init(mission_tracker: RefCounted) -> void:
	tracker = mission_tracker


func register_all(registry: RefCounted) -> void:
	registry.register("mision", "[juego] Muestra la misión y tus objetivos", _mision)
	registry.register("pista", "[juego] Pide una pista (pista N para el objetivo N)", _pista)
	registry.register("responder", "[juego] Responde a la pregunta activa (responder 2)", _responder)
	registry.register("hallazgo", "[juego] Registra un hallazgo con su clasificación", _hallazgo)
	registry.register("revisar", "[juego] Revisa tu informe contra la lista de comprobación", _revisar)
	registry.register("expediente", "[juego] Muestra las evidencias reunidas", _expediente)
	registry.register("perfil", "[juego] Muestra tu nivel y competencias", _perfil)


const ReportReview := preload("res://engine/missions/report_review.gd")
const Vfs := preload("res://engine/vfs.gd")

const FINDING_TYPES := {
	"indicio": "indicio", "hipotesis": "hipotesis", "hipótesis": "hipotesis", "confirmado": "confirmado",
	"falso-positivo": "falso-positivo", "falsopositivo": "falso-positivo", "falso_positivo": "falso-positivo",
}
const FINDING_HELP := "TIPOS DE HALLAZGO\n" \
	+ "  indicio          un dato que sugiere algo, pero no lo demuestra (p. ej. una versión)\n" \
	+ "  hipotesis        una explicación posible que aún hay que comprobar\n" \
	+ "  confirmado       demostrado con una prueba que otra persona puede repetir\n" \
	+ "  falso-positivo   parecía un problema y has comprobado que no lo es\n" \
	+ "Uso: hallazgo <tipo> \"descripción\"\n"


func _hallazgo(session: RefCounted, args: Array, _stdin: String) -> RefCounted:
	if args.is_empty():
		var text: String = FINDING_HELP
		if session.findings.is_empty():
			text += "\nTodavía no has registrado ningún hallazgo.\n"
		else:
			text += "\nTU CUADERNO DE HALLAZGOS\n"
			for finding: Dictionary in session.findings:
				text += "  [%s] %s\n" % [finding["type"].to_upper(), finding["text"]]
		return CommandResult.ok(text)

	var kind: String = FINDING_TYPES.get(str(args[0]).to_lower(), "")
	if kind == "":
		return CommandResult.error("hallazgo: tipo desconocido '%s' (usa indicio, hipotesis, confirmado o falso-positivo)" % args[0])
	var description := " ".join(args.slice(1)).strip_edges()
	if description == "":
		return CommandResult.error("hallazgo: falta la descripción. Uso: hallazgo <tipo> \"descripción\"")

	session.findings.append({"type": kind, "text": description})
	session.record("finding_recorded", {"kind": kind, "text": description})
	var result := CommandResult.ok("Hallazgo registrado como %s: %s\n" % [kind.to_upper(), description])
	var verdict: Dictionary = tracker.engine.classify(kind, description)
	if verdict["matched"]:
		if verdict["accepted"]:
			result.stdout += "  => %s\n" % verdict["message"]
		else:
			result.stdout += "  => No cuadra: %s\n" % verdict["message"]
			result.exit_code = 1
	return result


func _revisar(session: RefCounted, args: Array, _stdin: String) -> RefCounted:
	var spec: Dictionary = tracker.engine.report_spec()
	if spec.is_empty():
		return CommandResult.error("revisar: ahora mismo no hay ningún informe que revisar.")
	var shown: String = args[0] if not args.is_empty() else spec["path"]
	var path := Vfs.normalize(session.cwd, shown)
	var fs = session.host.fs
	if not fs.exists(path):
		return CommandResult.error("revisar: %s: No such file or directory" % shown)
	if fs.is_dir(path):
		return CommandResult.error("revisar: %s: Is a directory" % shown)
	if not fs.check_access(path, session.user, "r"):
		return CommandResult.error("revisar: %s: Permission denied" % shown)

	var review: Dictionary = ReportReview.review(fs.read_file(path), spec)
	var text := "REVISIÓN DEL INFORME: %s\n" % shown
	var missing := 0
	for element: Dictionary in review["elements"]:
		text += "  [%s] %s\n" % ["x" if element["ok"] else " ", element["label"]]
		missing += 0 if element["ok"] else 1
	for warning: String in review["warnings"]:
		text += "  ! %s\n" % warning
	var result := CommandResult.ok(text)
	if review["complete"]:
		result.stdout += "El informe cumple la lista de comprobación. Un informe real, además, debe permitir a otra persona repetir tus pasos.\n"
		session.record("report_complete", {"path": path})
	else:
		if missing > 0:
			result.stdout += "Faltan %d elemento(s). Completa el informe y vuelve a usar `revisar`.\n" % missing
		result.exit_code = 1
	return result


func _mision(_session: RefCounted, _args: Array, _stdin: String) -> RefCounted:
	return CommandResult.ok(tracker.mission_text())


func _expediente(_session: RefCounted, _args: Array, _stdin: String) -> RefCounted:
	return CommandResult.ok(tracker.dossier_text())


func _perfil(_session: RefCounted, _args: Array, _stdin: String) -> RefCounted:
	return CommandResult.ok(tracker.profile_text())


func _pista(_session: RefCounted, args: Array, _stdin: String) -> RefCounted:
	var engine: RefCounted = tracker.engine
	var number := 0
	if args.is_empty():
		var active: Dictionary = engine.active_objective()
		if active.is_empty():
			return CommandResult.ok("No hay objetivos pendientes que necesiten pista.\n")
		number = engine.objectives().find(active) + 1
	elif args[0].is_valid_int():
		number = int(args[0])
	else:
		return CommandResult.error("pista: uso: pista [número de objetivo]")

	var hint: Dictionary = engine.request_hint(number)
	if not hint["ok"]:
		return CommandResult.error(hint["message"])
	var objective: Dictionary = engine.objectives()[number - 1]
	var title := "SOLUCIÓN EXPLICADA" if hint["is_solution"] else "PISTA %d/%d" % [hint["level"], hint["total"] - 1]
	var text := "%s  -  objetivo %d: %s\n  %s\n" % [title, number, objective["text"], hint["text"]]
	if objective.has("question"):
		text += "  => Esto es una pregunta, no un comando: escribe `responder` para ver las opciones y `responder <número>` para contestar.\n"
	if not hint["is_solution"]:
		text += "(Otra llamada a `pista` te dará una ayuda más concreta. Pedir ayuda no te penaliza: solo me dice qué conviene repasar.)\n"
	else:
		text += "(Quedará anotado para repasar el concepto más adelante.)\n"
	return CommandResult.ok(text)


func _responder(_session: RefCounted, args: Array, _stdin: String) -> RefCounted:
	var engine: RefCounted = tracker.engine
	var objective: Dictionary = engine.active_question()
	if objective.is_empty():
		return CommandResult.error("Ahora mismo no hay ninguna pregunta pendiente.")
	var question: Dictionary = objective["question"]

	if args.is_empty():
		var text := "PREGUNTA: %s\n" % question["prompt"]
		var number := 0
		for option: Dictionary in question["options"]:
			number += 1
			text += "  %d) %s\n" % [number, option["text"]]
		return CommandResult.ok(text + "Responde con `responder <número>`. Puedes pedir `pista` si lo necesitas.\n")

	var choice := _parse_choice(args[0])
	var level_before: int = engine.level()
	var outcome: Dictionary = engine.answer(choice)
	if not outcome["ok"]:
		return CommandResult.error(outcome["message"])
	var result: RefCounted
	if outcome["correct"]:
		result = CommandResult.ok("Correcto. %s\n" % outcome["message"])
		result.notices.append_array(tracker.format_notifications(outcome["notifications"], level_before))
	else:
		result = CommandResult.ok("Todavía no. %s\nPuedes intentarlo de nuevo o pedir una pista.\n" % outcome["message"])
		result.exit_code = 1
	return result


## Acepta "2" o la letra "b".
func _parse_choice(text: String) -> int:
	if text.is_valid_int():
		return int(text)
	if text.length() == 1 and text.to_lower() >= "a" and text.to_lower() <= "z":
		return text.to_lower().unicode_at(0) - "a".unicode_at(0) + 1
	return 0
