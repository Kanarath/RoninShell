extends RefCounted
## Estado "de fuera del laboratorio": en qué modo juegas (misión, libre o repaso) y qué
## cosas han pedido los comandos (reiniciar, cambiar de modo, empezar un repaso).
##
## Los comandos no pueden reconstruir el laboratorio ellos mismos: dejan una petición aquí y la
## pantalla principal las atiende después de cada comando. Así el motor sigue sin saber nada de la interfaz.

const MODES := ["mision", "libre", "repaso"]

var mode: String = "mision"
var current_review_concept: String = ""
## Laboratorios de la campaña: id -> "completado" | "disponible" | "bloqueado" (los pone la pantalla principal).
var book_states: Dictionary = {}
var book_titles: Dictionary = {}
var active_book: String = ""
var scheduler: RefCounted = null          # ReviewScheduler
var review_book: Dictionary = {}          # libro de retos de repaso (puede estar vacío)
var now_fn: Callable = func() -> float: return Time.get_unix_time_from_system()
var _requests: Array = []


func now() -> float:
	return now_fn.call()


func request(type: String, data := {}) -> void:
	var item: Dictionary = data.duplicate()
	item["type"] = type
	_requests.append(item)


## Devuelve y vacía las peticiones pendientes, en orden.
func take_requests() -> Array:
	var pending := _requests
	_requests = []
	return pending


## Conceptos para los que hay un reto de repaso.
func review_concepts() -> Array[String]:
	var concepts: Array[String] = []
	for mission: Dictionary in review_book.get("missions", []):
		var concept := str(mission.get("concept", ""))
		if concept != "" and not concept in concepts:
			concepts.append(concept)
	return concepts


func review_mission_for(concept: String) -> Dictionary:
	for mission: Dictionary in review_book.get("missions", []):
		if mission.get("concept", "") == concept:
			return mission
	return {}


## Conceptos que toca repasar ahora Y para los que existe un reto.
func due_reviews() -> Array[String]:
	var result: Array[String] = []
	if scheduler == null:
		return result
	var available := review_concepts()
	for concept in scheduler.due(now()):
		if concept in available:
			result.append(concept)
	return result
