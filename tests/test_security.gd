extends "res://tests/framework/test_case.gd"
## Garantías de seguridad: lo que el jugador escribe nunca llega al sistema real.

const LabLoader := preload("res://engine/lab_loader.gd")
const ShellSession := preload("res://engine/shell/shell_session.gd")
const CommandRegistry := preload("res://engine/shell/command_registry.gd")
const BasicCommands := preload("res://engine/commands/basic_commands.gd")

## Llamadas que darían acceso al sistema anfitrión. Ningún archivo de engine/ debe usarlas.
const FORBIDDEN_CALLS := [
	"OS.execute", "OS.create_process", "OS.create_instance", "OS.shell_open",
	"OS.shell_show_in_file_manager", "OS.kill", "OS.set_environment", "DirAccess.remove",
	"FileAccess.WRITE", "FileAccess.READ_WRITE", "ClassDB.instantiate", "Expression.new",
]


func _gd_files_under(path: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return found
	for sub in dir.get_directories():
		found.append_array(_gd_files_under("%s/%s" % [path, sub]))
	for file_name in dir.get_files():
		if file_name.ends_with(".gd"):
			found.append("%s/%s" % [path, file_name])
	return found


func test_el_motor_no_contiene_llamadas_al_sistema_operativo() -> void:
	var files := _gd_files_under("res://engine")
	assert_true(files.size() >= 8, "el escaneo debe encontrar los archivos del motor (encontró %d)" % files.size())
	for file_path in files:
		var source := FileAccess.get_file_as_string(file_path)
		for call in FORBIDDEN_CALLS:
			assert_false(call in source, "%s usa la llamada prohibida %s" % [file_path, call])


func test_comandos_peligrosos_del_sistema_real_no_existen() -> void:
	var world = LabLoader.load_file("res://data/labs/primer_contacto.json")["world"]
	var registry := CommandRegistry.new()
	BasicCommands.new().register_all(registry)
	var session := ShellSession.new(world, registry)
	var files_before: int = session.host.fs.all_paths().size()

	for line in ["rm -rf /", "del C:\\*", "powershell -c calc", "calc.exe", "cmd /c dir",
			"curl http://example.com", "python -c 'import os'", "$(whoami)", "`id`"]:
		var result = session.run(line)
		assert_true(result.exit_code != 0, "'%s' no debe ejecutarse con éxito" % line)

	assert_eq(session.host.fs.all_paths().size(), files_before, "ninguna de ellas altera el laboratorio")
	assert_eq(session.host.fs.read_file("/home/ronin/nota.txt").begins_with("Red autorizada"), true)
