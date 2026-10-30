extends "res://tests/framework/test_case.gd"

const Scheduler := preload("res://engine/review/review_scheduler.gd")

const T0 := 1000000.0
const DAY := 86400.0


func test_lo_resuelto_viendo_la_solucion_toca_repasarlo_ya() -> void:
	var s := Scheduler.new()
	s.schedule("permisos", "solucion", T0)
	assert_eq(s.box_of("permisos"), 0)
	assert_eq(s.due(T0), ["permisos"])


func test_con_ayuda_vuelve_al_dia_siguiente_y_solo_a_los_3_dias() -> void:
	var s := Scheduler.new()
	s.schedule("a", "ayuda", T0)
	s.schedule("b", "solo", T0)
	assert_eq(s.due(T0 + 0.5 * DAY), [], "todavía no")
	assert_eq(s.due(T0 + 1.0 * DAY), ["a"])
	assert_eq(s.due(T0 + 3.0 * DAY), ["a", "b"], "ordenados del más atrasado al menos")


func test_acertar_un_repaso_sube_de_caja_y_retrasa_el_siguiente() -> void:
	var s := Scheduler.new()
	s.schedule("a", "ayuda", T0)       # caja 1
	s.record_result("a", true, T0 + DAY)
	assert_eq(s.box_of("a"), 2)
	assert_eq(s.due_at("a"), T0 + DAY + 3.0 * DAY)
	for i in 10:
		s.record_result("a", true, T0)
	assert_eq(s.box_of("a"), Scheduler.MAX_BOX, "la caja tiene techo")
	assert_eq(s.due_at("a"), T0 + 30.0 * DAY)


func test_fallar_un_repaso_vuelve_a_empezar_sin_penalizar_mas() -> void:
	var s := Scheduler.new()
	s.schedule("a", "solo", T0)
	s.record_result("a", true, T0)
	assert_eq(s.box_of("a"), 3)
	s.record_result("a", false, T0)
	assert_eq(s.box_of("a"), 0)
	assert_eq(s.due(T0), ["a"])


func test_si_un_concepto_se_resuelve_varias_veces_manda_el_peor_resultado() -> void:
	var s := Scheduler.new()
	s.schedule("a", "solo", T0)
	s.schedule("a", "solucion", T0)
	assert_eq(s.box_of("a"), 0)
	s.schedule("a", "solo", T0)
	assert_eq(s.box_of("a"), 0, "un buen resultado posterior no borra el malo")


func test_un_repaso_de_un_concepto_desconocido_empieza_en_la_caja_cero_y_sube() -> void:
	var s := Scheduler.new()
	s.record_result("nuevo", true, T0)
	assert_eq(s.box_of("nuevo"), 1)
	assert_eq(s.box_of("no_existe"), -1)
	assert_false(s.has_concept("no_existe"))


func test_resumen_ordenado_con_dias_restantes() -> void:
	var s := Scheduler.new()
	s.schedule("lejos", "solo", T0)
	s.schedule("cerca", "ayuda", T0)
	var rows := s.overview(T0)
	assert_eq(rows[0]["concept"], "cerca")
	assert_eq(rows[0]["days"], 1.0)
	assert_eq(rows[1]["days"], 3.0)


func test_ida_y_vuelta_y_datos_danados() -> void:
	var s := Scheduler.new()
	s.schedule("a", "ayuda", T0)
	var restored := Scheduler.new()
	restored.load_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	assert_eq(restored.to_dict(), s.to_dict())
	restored.load_dict({"x": {"box": 99, "due": 5}, "y": "basura", "z": {"box": 1}})
	assert_eq(restored.box_of("x"), Scheduler.MAX_BOX, "la caja se corrige al rango válido")
	assert_false(restored.has_concept("y") or restored.has_concept("z"), "las entradas rotas se ignoran")
	restored.load_dict("no es un diccionario")
	assert_eq(restored.to_dict(), {})
