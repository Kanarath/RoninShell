extends "res://tests/framework/test_case.gd"
## mkdir, touch, cp, mv, rm, sha256sum y diff: solo sobre el sistema de archivos simulado y con permisos.

const LabLoader := preload("res://engine/lab_loader.gd")
const ShellSession := preload("res://engine/shell/shell_session.gd")
const CommandSet := preload("res://engine/commands/command_set.gd")
const Vfs := preload("res://engine/vfs.gd")


func _session() -> RefCounted:
	var world = LabLoader.load_file("res://data/labs/primer_contacto.json")["world"]
	return ShellSession.new(world, CommandSet.create_registry())


func _out(s: RefCounted, line: String) -> String:
	return s.run(line).stdout


func _err(s: RefCounted, line: String) -> String:
	return s.run(line).stderr


func _count(s: RefCounted, type: String) -> int:
	var total := 0
	for event: Dictionary in s.events:
		if event["type"] == type:
			total += 1
	return total


func test_mkdir_y_touch_crean_en_casa() -> void:
	var s := _session()
	assert_eq(_err(s, "mkdir pruebas"), "")
	assert_eq(_out(s, "ls"), _out(s, "ls"))
	assert_true("pruebas" in _out(s, "ls"))
	assert_eq(_err(s, "touch pruebas/a.txt"), "")
	assert_eq(_out(s, "cat pruebas/a.txt"), "")
	assert_true("File exists" in _err(s, "mkdir pruebas"))
	assert_eq(_err(s, "mkdir -p pruebas"), "", "con -p no falla si ya existe")
	assert_eq(_err(s, "mkdir -p x/y/z"), "")
	assert_true("z" in _out(s, "ls x/y"))
	assert_true("No such file" in _err(s, "mkdir q/r"))
	assert_eq(_count(s, "dir_created"), 4)


func test_cp_copia_y_conserva_el_original() -> void:
	var s := _session()
	s.run("echo hola > a.txt")
	assert_eq(_err(s, "cp a.txt b.txt"), "")
	assert_eq(_out(s, "cat b.txt"), "hola\n")
	assert_eq(_out(s, "cat a.txt"), "hola\n")
	s.run("echo cambio > a.txt")
	assert_eq(_out(s, "cat b.txt"), "hola\n", "la copia no cambia con el original")
	assert_eq(_count(s, "file_copied"), 1)


func test_cp_a_un_directorio_y_recursivo() -> void:
	var s := _session()
	s.run("mkdir d")
	s.run("echo 1 > d/uno.txt")
	s.run("mkdir copia")
	assert_eq(_err(s, "cp d/uno.txt copia"), "")
	assert_eq(_out(s, "cat copia/uno.txt"), "1\n", "dentro del directorio, con su nombre")
	assert_true("-r not specified" in _err(s, "cp d copia2"))
	assert_eq(_err(s, "cp -r d copia2"), "")
	assert_eq(_out(s, "cat copia2/uno.txt"), "1\n")
	assert_true("into itself" in _err(s, "cp -r d d/dentro"))


func test_cp_sobrescribe_el_destino() -> void:
	var s := _session()
	s.run("echo viejo > a.txt")
	s.run("echo nuevo > b.txt")
	s.run("cp b.txt a.txt")
	assert_eq(_out(s, "cat a.txt"), "nuevo\n")


func test_mv_renombra_y_mueve_directorios_con_contenido() -> void:
	var s := _session()
	s.run("mkdir d")
	s.run("echo x > d/f.txt")
	assert_eq(_err(s, "mv d e"), "")
	assert_eq(_out(s, "cat e/f.txt"), "x\n")
	assert_true("No such file" in _err(s, "cat d/f.txt"))
	s.run("echo y > g.txt")
	assert_eq(_err(s, "mv g.txt e"), "")
	assert_eq(_out(s, "cat e/g.txt"), "y\n")
	assert_true("subdirectory of itself" in _err(s, "mv e e/dentro") or "No such file" in _err(s, "mv e e/dentro"))
	assert_eq(_count(s, "file_moved"), 2)


func test_rm_borra_y_protege() -> void:
	var s := _session()
	s.run("echo x > a.txt")
	assert_eq(_err(s, "rm a.txt"), "")
	assert_true("No such file" in _err(s, "cat a.txt"))
	assert_true("No such file" in _err(s, "rm a.txt"))
	assert_eq(_err(s, "rm -f a.txt"), "", "-f no se queja")
	s.run("mkdir d")
	s.run("echo x > d/f")
	assert_true("Is a directory" in _err(s, "rm d"))
	assert_eq(_err(s, "rm -r d"), "")
	assert_true("No such file" in _err(s, "ls d"))
	assert_true("dangerous" in _err(s, "rm -rf /"))
	assert_true("refusing" in _err(s, "rm -r ."))
	assert_true(s.host.fs.exists("/etc/passwd"), "la raíz sigue intacta")


func test_los_permisos_se_respetan() -> void:
	var s := _session()
	assert_true("Permission denied" in _err(s, "touch /etc/x.txt"), "ronin no escribe en /etc")
	assert_true("Permission denied" in _err(s, "mkdir /etc/d"))
	assert_true("Permission denied" in _err(s, "rm /etc/passwd"))
	assert_true("Permission denied" in _err(s, "mv /etc/passwd /tmp"), "tampoco mover")
	assert_true("Permission denied" in _err(s, "cp /etc/shadow ."), "ni copiar lo que no puede leer")
	assert_true(s.host.fs.exists("/etc/passwd"))


func test_sha256sum_cambia_con_el_contenido() -> void:
	var s := _session()
	s.run("echo hola > a.txt")
	s.run("cp a.txt b.txt")
	var first := _out(s, "sha256sum a.txt").split(" ")[0]
	assert_eq(first.length(), 64)
	assert_eq(_out(s, "sha256sum b.txt").split(" ")[0], first, "una copia fiel tiene la misma huella")
	s.run("echo hola! > b.txt")
	assert_true(_out(s, "sha256sum b.txt").split(" ")[0] != first, "un cambio cambia la huella")
	assert_true("No such file" in _err(s, "sha256sum nada"))
	assert_eq(_count(s, "hash_computed"), 3)


func test_diff_distingue_iguales_y_distintos() -> void:
	var s := _session()
	s.run("echo uno > a.txt")
	s.run("cp a.txt b.txt")
	var same: RefCounted = s.run("diff a.txt b.txt")
	assert_eq(same.stdout, "")
	assert_eq(same.exit_code, 0)
	s.run("echo dos >> b.txt")
	var different: RefCounted = s.run("diff a.txt b.txt")
	assert_eq(different.exit_code, 1)
	assert_true("> dos" in different.stdout)
	assert_true("differ" in s.run("diff -q a.txt b.txt").stdout)
	assert_eq(_out(s, "if diff -q a.txt a.txt; then echo igual; else echo distinto; fi"), "igual\n")
	assert_true("No such file" in _err(s, "diff a.txt nada"))


func test_vfs_operaciones_basicas() -> void:
	var fs := Vfs.new()
	fs.add_dir("/d")
	fs.add_file("/d/f", "x")
	assert_false(fs.remove("/d"), "un directorio con contenido no se borra con remove")
	assert_eq(fs.remove_tree("/d"), 2)
	assert_false(fs.exists("/d/f"))
	assert_false(fs.remove("/"), "la raíz es intocable")
	assert_eq(fs.remove_tree("/"), 0)
