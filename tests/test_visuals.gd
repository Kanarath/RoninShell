extends "res://tests/framework/test_case.gd"
## Sprites, mapa que se revela y mascota. (Lo que se ve bien o mal se juzga jugando;
## aquí se comprueba que el arte existe, que la lógica de revelado es correcta y que no se rompe.)

const SpriteStore := preload("res://ui/sprite_store.gd")
const NetworkMap := preload("res://ui/widgets/network_map.gd")
const SealIcon := preload("res://ui/widgets/seal_icon.gd")
const Mascot := preload("res://ui/widgets/mascot.gd")
const LabLoader := preload("res://engine/lab_loader.gd")
const ShellSession := preload("res://engine/shell/shell_session.gd")
const CommandSet := preload("res://engine/commands/command_set.gd")

## nombre -> tamaño esperado (tras el contorno que añade pxl)
const SPRITES := {
	"host_you": Vector2i(24, 22), "host_pc": Vector2i(24, 22), "host_server": Vector2i(22, 22),
	"host_router": Vector2i(26, 20), "host_ghost": Vector2i(24, 22),
	"door_open": Vector2i(16, 18), "door_closed": Vector2i(16, 18), "door_filtered": Vector2i(16, 18),
	"icon_ssh": Vector2i(16, 14), "icon_http": Vector2i(16, 16), "icon_ftp": Vector2i(16, 14), "icon_lock": Vector2i(14, 16),
	"seal_done": Vector2i(22, 22), "seal_active": Vector2i(22, 22), "seal_pending": Vector2i(22, 22), "seal_locked": Vector2i(22, 22),
	"ronin_idle": Vector2i(34, 34), "ronin_happy": Vector2i(34, 34), "ronin_think": Vector2i(34, 34), "ronin_alert": Vector2i(34, 34),
	"torii": Vector2i(42, 36),
}


func _session() -> RefCounted:
	var world = LabLoader.load_file("res://data/labs/primer_contacto.json")["world"]
	return ShellSession.new(world, CommandSet.create_registry())


func _map(session: RefCounted) -> Control:
	var map := NetworkMap.new()
	map.world = session.world
	map.session = session
	return map


# --- Sprites ---

func test_todos_los_sprites_existen_y_tienen_el_tamano_esperado() -> void:
	for sprite_name: String in SPRITES:
		var texture := SpriteStore.texture(sprite_name)
		assert_true(texture != null, "falta el sprite %s (ejecuta build_art.cmd)" % sprite_name)
		if texture != null:
			assert_eq(Vector2i(texture.get_size()), SPRITES[sprite_name], "tamaño de %s" % sprite_name)


func test_un_sprite_inexistente_devuelve_null_sin_romper() -> void:
	assert_true(SpriteStore.texture("no_existe") == null)


func test_cada_estado_de_sello_tiene_sprite() -> void:
	for state in SealIcon.SPRITES:
		assert_true(SpriteStore.texture(SealIcon.SPRITES[state]) != null)
	assert_eq(SealIcon.SPRITES.size(), SealIcon.State.size(), "todos los estados cubiertos")


# --- Mapa que se revela ---

func test_al_empezar_no_conoces_ningun_host() -> void:
	var map := _map(_session())
	assert_eq(map.discovered_ips(), [])
	assert_eq(map.ports_seen("10.0.0.5"), {})
	map.free()


func test_descubrir_un_host_lo_revela_en_el_mapa() -> void:
	var s := _session()
	var map := _map(s)
	s.run("ping -c 1 web01")
	assert_eq(map.discovered_ips(), ["10.0.0.5"])
	s.run("nmap -sn 10.0.0.0/24")
	assert_eq(map.discovered_ips(), ["10.0.0.5", "10.0.0.2"], "sin repetidos y en el orden en que los viste")
	assert_false("10.0.0.9" in map.discovered_ips(), "files01 sigue oculto: no responde al descubrimiento")
	map.free()


func test_las_puertas_reflejan_lo_que_el_escaneo_mostro() -> void:
	var s := _session()
	var map := _map(s)
	s.run("nmap web01")
	assert_eq(map.ports_seen("10.0.0.5"), {22: "open", 80: "open", 8080: "filtered"})
	s.run("nmap -Pn files01")
	assert_eq(map.ports_seen("10.0.0.9"), {21: "open"})
	assert_true("10.0.0.9" in map.discovered_ips(), "un escaneo con -Pn también lo revela")
	map.free()


func test_el_mapa_dibuja_sin_errores_con_y_sin_progreso() -> void:
	var s := _session()
	var map := _map(s)
	(Engine.get_main_loop() as SceneTree).root.add_child(map)
	map.size = Vector2(330, 160)
	map.notification(CanvasItem.NOTIFICATION_DRAW)
	s.run("nmap -sn 10.0.0.0/24")
	s.run("nmap -Pn -sV 10.0.0.9")
	map.refresh()
	map.notification(CanvasItem.NOTIFICATION_DRAW)
	assert_true(true, "se dibujó con hosts conocidos y desconocidos")
	(Engine.get_main_loop() as SceneTree).root.remove_child(map)
	map.free()


# --- Mascota ---

func test_la_mascota_cambia_de_gesto_y_ignora_gestos_inventados() -> void:
	var mascot := Mascot.new()
	assert_eq(mascot.state, "idle")
	mascot.react("happy", 0.2)
	assert_eq(mascot.state, "happy")
	assert_eq(mascot.texture, SpriteStore.texture("ronin_happy"))
	mascot.react("baila")
	assert_eq(mascot.state, "happy", "un gesto desconocido no cambia nada")
	mascot.react("idle")
	assert_eq(mascot.state, "idle")
	mascot.free()
