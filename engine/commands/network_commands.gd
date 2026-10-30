extends RefCounted
## ping, nmap y curl simulados. Ninguno devuelve texto inventado: todo se calcula a partir
## de los hosts, servicios y sitios web del laboratorio (ver engine/network.gd).
##
## Límites conocidos (a propósito):
##   ping: siempre envía un número fijo de paquetes (-c, por defecto 4), nunca "infinito".
##   nmap: solo -sn, -sV, -Pn, -p (incluido -p-) y las opciones inofensivas -sS -sT -n -v -T<n>.
##         El escaneo por defecto cubre 1000 puertos (los 983 primeros y 17 altos habituales).
##   curl: HTTP/HTTPS sin TLS real, GET y HEAD; opciones -i -I -s -S -v -L -k -o.

const CommandResult := preload("res://engine/shell/command_result.gd")
const Network := preload("res://engine/network.gd")
const Host := preload("res://engine/host.gd")
const Vfs := preload("res://engine/vfs.gd")
const ArgParser := preload("res://engine/commands/arg_parser.gd")
const CurlCommand := preload("res://engine/commands/curl_command.gd")

const NMAP_VERSION := "7.94"
const SCAN_DATE := "2026-10-29 12:00 UTC"
const COLLAPSE_THRESHOLD := 25
const HIGH_PORTS := [1433, 1521, 2049, 3000, 3306, 3389, 5000, 5432, 5900, 6379, 8000, 8080, 8443, 8888, 9000, 9200, 27017]
const WELL_KNOWN := {
	20: "ftp-data", 21: "ftp", 22: "ssh", 23: "telnet", 24: "priv-mail", 25: "smtp", 53: "domain", 80: "http", 110: "pop3",
	139: "netbios-ssn", 143: "imap", 443: "https", 445: "microsoft-ds", 3306: "mysql",
	3389: "ms-wbt-server", 5432: "postgresql", 8080: "http-proxy",
}


func register_all(registry: RefCounted) -> void:
	registry.register("ping", "Comprueba si un host responde (-c N)", _ping)
	registry.register("nmap", "Escanea hosts y puertos (-sn -sV -Pn -p)", _nmap)
	registry.register("curl", "Hace una petición HTTP (-i -I -v -L -X -d -H -b -c -o)", CurlCommand.new().run)


# =============================================================================
# ping
# =============================================================================

func _ping(session: RefCounted, args: Array, _stdin: String) -> RefCounted:
	var parsed := ArgParser.parse(args, "", "c")
	if parsed["error"] != "":
		return CommandResult.error("ping: %s" % parsed["error"], 2)
	if parsed["rest"].is_empty():
		return CommandResult.error("ping: usage error: Destination address required", 2)
	var count_text: String = parsed["values"].get("c", "4")
	if not count_text.is_valid_int() or int(count_text) < 1 or int(count_text) > 20:
		return CommandResult.error("ping: invalid argument: '%s': out of range: 1 <= value <= 20" % count_text, 2)
	var count := int(count_text)

	var target: String = parsed["rest"][0]
	var host = Network.resolve(session.world, target)
	if host == null and not Host.is_valid_ip(target):
		return CommandResult.error("ping: %s: Name or service not known" % target, 2)

	var ip: String = host.ip if host != null else target
	if target == "localhost":
		ip = Network.LOCALHOST_IP
	var typed_is_name := not Host.is_valid_ip(target)
	var out := "PING %s (%s) 56(84) bytes of data.\n" % [target, ip]
	var result := CommandResult.new()
	var times: Array[float] = []

	if Network.answers_discovery(host):
		var source := "%s (%s)" % [target, ip] if typed_is_name else ip
		for seq in range(1, count + 1):
			var ms := Network.latency_ms(ip, seq)
			times.append(ms)
			out += "64 bytes from %s: icmp_seq=%d ttl=64 time=%.2f ms\n" % [source, seq, ms]
		session.record("ping_reply", {"ip": ip})
		session.record("host_discovered", {"ip": ip, "via": "ping"})
		out += "\n--- %s ping statistics ---\n" % target
		out += "%d packets transmitted, %d received, 0%% packet loss, time %dms\n" % [count, count, (count - 1) * 1000 + count]
		out += "rtt min/avg/max/mdev = %.3f/%.3f/%.3f/%.3f ms\n" % _rtt_stats(times)
	elif host != null and host.up:
		# Encendida pero que descarta los sondeos: silencio, sin mensajes de error.
		out += "\n--- %s ping statistics ---\n" % target
		out += "%d packets transmitted, 0 received, 100%% packet loss, time %dms\n" % [count, (count - 1) * 1000 + count * 3]
		result.exit_code = 1
		session.record("ping_no_reply", {"ip": ip})
	else:
		# Apagada o inexistente en la red local: el propio equipo informa de que no la alcanza.
		for seq in range(1, count + 1):
			out += "From %s icmp_seq=%d Destination Host Unreachable\n" % [session.host.ip, seq]
		out += "\n--- %s ping statistics ---\n" % target
		out += "%d packets transmitted, 0 received, +%d errors, 100%% packet loss, time %dms\n" % [count, count, (count - 1) * 1000 + count * 3]
		result.exit_code = 1
		session.record("ping_no_reply", {"ip": ip})
	result.stdout = out
	return result


func _rtt_stats(times: Array[float]) -> Array:
	var low := times[0]
	var high := times[0]
	var total := 0.0
	for value in times:
		low = minf(low, value)
		high = maxf(high, value)
		total += value
	var mean := total / times.size()
	var variance := 0.0
	for value in times:
		variance += (value - mean) * (value - mean)
	return [low, mean, high, sqrt(variance / times.size())]


# =============================================================================
# nmap
# =============================================================================

func _nmap(session: RefCounted, args: Array, _stdin: String) -> RefCounted:
	var options := _parse_nmap_args(args)
	if options["error"] != "":
		return CommandResult.error(options["error"], 1)
	if options["targets"].is_empty():
		return CommandResult.ok("Nmap %s ( https://nmap.org )\nUsage: nmap [Scan Type(s)] [Options] {target specification}\nSEE THE MAN PAGE (https://nmap.org/book/man.html) FOR MORE OPTIONS AND EXAMPLES\n" % NMAP_VERSION)

	var ports: Array[int] = []
	if options["ports_spec"] != "":
		var parsed_ports := _parse_ports(options["ports_spec"])
		if parsed_ports["error"] != "":
			return CommandResult.error(parsed_ports["error"], 1)
		ports = parsed_ports["ports"]
	else:
		ports = _default_ports()

	var entries: Array = []        # [{ip, name, host}]
	var total_addresses := 0
	var multi_target := false
	var unresolved: Array[String] = []
	for spec: String in options["targets"]:
		var expanded := _expand_target(session.world, spec)
		if expanded["error"] != "":
			unresolved.append(spec)
			continue
		if expanded["multi"]:
			multi_target = true
		total_addresses += expanded["count"]
		for entry in expanded["entries"]:
			entries.append(entry)

	if multi_target and options["no_ping"]:
		return CommandResult.error("nmap: -Pn on ranges is not simulated in this lab (it would list every address)", 1)

	var out := "Starting Nmap %s ( https://nmap.org ) at %s\n" % [NMAP_VERSION, SCAN_DATE]
	for spec in unresolved:
		out += "Failed to resolve \"%s\".\n" % spec
	if entries.is_empty() and total_addresses == 0:
		out += "WARNING: No targets were specified, so 0 hosts scanned.\n"
		out += "Nmap done: 0 IP addresses (0 hosts up) scanned in 0.03 seconds\n"
		return CommandResult.ok(out)

	var hosts_up := 0
	var scanned_hosts := 0
	var down_notes := 0
	var detection_used := false
	var reports: Array[String] = []
	for entry: Dictionary in entries:
		var host = entry["host"]
		var discoverable: bool = Network.answers_discovery(host)
		if options["ping_only"]:
			if discoverable:
				hosts_up += 1
				session.record("host_discovered", {"ip": entry["ip"], "via": "nmap"})
				reports.append("Nmap scan report for %s\nHost is up (%.5fs latency).\n" % [_label(entry), Network.latency_ms(entry["ip"]) / 1000.0])
			continue
		if not discoverable and not options["no_ping"]:
			if not multi_target:
				down_notes += 1
				reports.append("Note: Host seems down. If it is really up, but blocking our ping probes, try -Pn\n")
			continue
		hosts_up += 1
		scanned_hosts += 1
		var report := _scan_report(entry, ports, options["version"])
		reports.append(report["text"])
		if discoverable:
			session.record("host_discovered", {"ip": entry["ip"], "via": "nmap"})
		for row: Dictionary in report["rows"]:
			session.record("port_found", {"ip": entry["ip"], "port": row["port"], "state": row["state"], "service": row["service"]})
			if options["version"] and row["detail"] != "":
				session.record("service_version", {"ip": entry["ip"], "port": row["port"], "detail": row["detail"]})
		detection_used = detection_used or (options["version"] and report["open"] > 0)

	if options["ping_only"]:
		out += "".join(reports)
		var seconds_sn := 0.50 + total_addresses * 0.008
		out += "Nmap done: %s scanned in %.2f seconds\n" % [_addresses_summary(total_addresses, hosts_up), seconds_sn]
		return CommandResult.ok(out)

	out += "\n".join(reports)
	if not reports.is_empty() and not (down_notes == reports.size()):
		out += "\n"
	if detection_used:
		out += "Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .\n"
	var seconds := 0.30 + 0.00012 * ports.size() * scanned_hosts + (6.5 if detection_used else 0.0) + 2.75 * down_notes
	out += "Nmap done: %s scanned in %.2f seconds\n" % [_addresses_summary(total_addresses, hosts_up), seconds]
	return CommandResult.ok(out)


func _parse_nmap_args(args: Array) -> Dictionary:
	var options := {
		"ping_only": false, "no_ping": false, "version": false,
		"ports_spec": "", "targets": [], "error": "",
	}
	var harmless := ["-sS", "-sT", "-n", "-v", "-vv", "-T0", "-T1", "-T2", "-T3", "-T4", "-T5"]
	var unsupported := ["-O", "-A", "-F", "-sU", "-sC", "-sA", "-sN", "-sF", "-sX", "-oN", "-oX", "-oG", "-6", "-iL", "-sP"]
	var index := 0
	while index < args.size():
		var arg: String = args[index]
		if arg == "-sn":
			options["ping_only"] = true
		elif arg == "-Pn":
			options["no_ping"] = true
		elif arg == "-sV":
			options["version"] = true
		elif arg == "-p":
			if index + 1 >= args.size():
				options["error"] = "nmap: option requires an argument -- 'p'\nQUITTING!"
				return options
			index += 1
			options["ports_spec"] = args[index]
		elif arg.begins_with("-p") and arg.length() > 2 and not arg.begins_with("-Pn"):
			options["ports_spec"] = arg.substr(2)
		elif arg in harmless:
			pass  # aceptadas: en este laboratorio no cambian el resultado
		elif arg in unsupported or arg.begins_with("--"):
			options["error"] = "nmap: this lab does not simulate the option '%s'.\nSupported here: -sn, -sV, -Pn, -p, -p-" % arg
			return options
		elif arg.begins_with("-"):
			options["error"] = "nmap: invalid option -- '%s'\nQUITTING!" % arg.substr(1, 1) if arg.length() == 2 else "nmap: unrecognized option '%s'\nQUITTING!" % arg
			return options
		else:
			options["targets"].append(arg)
		index += 1
	return options


## "22", "22,80", "1-100", "80,8000-8100" o "-" (todos los puertos).
func _parse_ports(spec: String) -> Dictionary:
	var ports: Array[int] = []
	var illegal := "Your port specifications are illegal. Example of proper form: \"-100,200-1024,3000-4000,60000-\"\nQUITTING!"
	if spec == "-":
		for port in range(1, 65536):
			ports.append(port)
		return {"ports": ports, "error": ""}
	var seen := {}
	var range_pattern := RegEx.create_from_string("^(\\d+)-(\\d+)$")
	for part in spec.split(","):
		var low := 0
		var high := 0
		var found := range_pattern.search(part)
		if found != null:
			low = int(found.get_string(1))
			high = int(found.get_string(2))
		elif part.is_valid_int():
			low = int(part)
			high = low
		else:
			return {"ports": [], "error": illegal}
		if low < 0 or high > 65535:
			return {"ports": [], "error": "Ports specified must be between 0 and 65535 inclusive\nQUITTING!"}
		if low > high:
			return {"ports": [], "error": illegal}
		for port in range(maxi(low, 1), high + 1):
			if not seen.has(port):
				seen[port] = true
				ports.append(port)
	ports.sort()
	return {"ports": ports, "error": ""}


func _default_ports() -> Array[int]:
	var ports: Array[int] = []
	for port in range(1, 984):
		ports.append(port)
	for port: int in HIGH_PORTS:
		ports.append(port)
	return ports


## Expande un objetivo (IP, nombre, CIDR o rango a.b.c.x-y) en los hosts del laboratorio que caen dentro.
func _expand_target(world: RefCounted, spec: String) -> Dictionary:
	var cidr := RegEx.create_from_string("^(\\d+\\.\\d+\\.\\d+\\.\\d+)/(\\d+)$").search(spec)
	if cidr != null and Host.is_valid_ip(cidr.get_string(1)):
		var bits := int(cidr.get_string(2))
		if bits < 22 or bits > 32:
			return {"error": "range", "entries": [], "count": 0, "multi": true}
		var size := 1 << (32 - bits)
		var start := (_ip_to_int(cidr.get_string(1)) >> (32 - bits)) << (32 - bits)
		var entries: Array = []
		for ip in world.host_ips():
			var value := _ip_to_int(ip)
			if value >= start and value < start + size:
				entries.append({"ip": ip, "name": world.get_host(ip).hostname, "host": world.get_host(ip)})
		return {"error": "", "entries": entries, "count": size, "multi": true}

	var span := RegEx.create_from_string("^(\\d+\\.\\d+\\.\\d+\\.)(\\d+)-(\\d+)$").search(spec)
	if span != null:
		var first := int(span.get_string(2))
		var last := int(span.get_string(3))
		if first > last or last > 255:
			return {"error": "range", "entries": [], "count": 0, "multi": true}
		var found: Array = []
		for number in range(first, last + 1):
			var ip: String = span.get_string(1) + str(number)
			if world.hosts.has(ip):
				found.append({"ip": ip, "name": world.get_host(ip).hostname, "host": world.get_host(ip)})
		return {"error": "", "entries": found, "count": last - first + 1, "multi": true}

	if spec == "localhost" or spec == Network.LOCALHOST_IP:
		return {"error": "", "entries": [{"ip": Network.LOCALHOST_IP, "name": "localhost", "host": world.player_host()}], "count": 1, "multi": false}
	if Host.is_valid_ip(spec):
		var known = world.get_host(spec)
		return {"error": "", "entries": [{"ip": spec, "name": known.hostname if known != null else "", "host": known}], "count": 1, "multi": false}
	var by_name = world.host_by_name(spec)
	if by_name == null:
		return {"error": "resolve", "entries": [], "count": 0, "multi": false}
	return {"error": "", "entries": [{"ip": by_name.ip, "name": by_name.hostname, "host": by_name}], "count": 1, "multi": false}


func _ip_to_int(ip: String) -> int:
	var value := 0
	for octet in ip.split("."):
		value = value * 256 + int(octet)
	return value


func _label(entry: Dictionary) -> String:
	return "%s (%s)" % [entry["name"], entry["ip"]] if entry["name"] != "" else entry["ip"]


func _addresses_summary(addresses: int, up: int) -> String:
	return "%d IP address%s (%d host%s up)" % [addresses, "" if addresses == 1 else "es", up, "" if up == 1 else "s"]


## Informe de puertos de un host. Devuelve {"text": String, "open": int}.
func _scan_report(entry: Dictionary, ports: Array[int], version_scan: bool) -> Dictionary:
	var host = entry["host"]
	var label := _label(entry)
	var alive: bool = host != null and host.up
	var default_state := "closed" if alive else "filtered"

	var rows: Array = []
	for port in ports:
		var service = host.get_service(port) if host != null else null
		var state: String = service.state if service != null else default_state
		var shown_name := ""
		if service != null:
			shown_name = service.name if version_scan else service.guessed_name
		else:
			shown_name = WELL_KNOWN.get(port, "unknown")
		var detail := ""
		if version_scan and service != null and state == "open":
			detail = ("%s %s" % [service.product, service.version]).strip_edges()
		rows.append({"port": port, "state": state, "service": shown_name, "detail": detail})

	# Si un estado (cerrado/filtrado) domina con muchos puertos, nmap lo resume en una línea.
	var counts := {"closed": 0, "filtered": 0}
	for row: Dictionary in rows:
		if counts.has(row["state"]):
			counts[row["state"]] += 1
	var collapsed_state := ""
	var collapsed_count := 0
	for state_name: String in counts:
		if counts[state_name] > COLLAPSE_THRESHOLD and counts[state_name] > collapsed_count:
			collapsed_state = state_name
			collapsed_count = counts[state_name]
	var shown_rows: Array = []
	var open_count := 0
	for row: Dictionary in rows:
		if row["state"] == "open":
			open_count += 1
		if collapsed_state != "" and row["state"] == collapsed_state:
			continue
		shown_rows.append(row)

	var text := "Nmap scan report for %s\n" % label
	if alive:
		text += "Host is up (%.5fs latency).\n" % (Network.latency_ms(entry["ip"]) / 1000.0)
	else:
		text += "Host is up.\n"
	var reason := "reset" if collapsed_state == "closed" else "no-response"
	if shown_rows.is_empty():
		text += "All %d scanned ports on %s are in ignored states.\n" % [ports.size(), label]
		text += "Not shown: %d %s tcp ports (%s)\n" % [collapsed_count, collapsed_state, reason]
		return {"text": text, "open": 0, "rows": []}
	if collapsed_count > 0:
		text += "Not shown: %d %s tcp ports (%s)\n" % [collapsed_count, collapsed_state, reason]
	text += _port_table(shown_rows, version_scan)
	return {"text": text, "open": open_count, "rows": shown_rows}


func _port_table(rows: Array, version_scan: bool) -> String:
	var port_width := 4
	var state_width := 5
	var service_width := 7
	for row: Dictionary in rows:
		port_width = maxi(port_width, ("%d/tcp" % row["port"]).length())
		state_width = maxi(state_width, str(row["state"]).length())
		service_width = maxi(service_width, str(row["service"]).length())
	var lines: Array[String] = []
	var header := "%s %s %s" % ["PORT".rpad(port_width), "STATE".rpad(state_width), "SERVICE".rpad(service_width)]
	if version_scan:
		header += " VERSION"
	lines.append(header.strip_edges(false, true))
	for row: Dictionary in rows:
		var line := "%s %s %s" % [("%d/tcp" % row["port"]).rpad(port_width), str(row["state"]).rpad(state_width), str(row["service"]).rpad(service_width)]
		if version_scan and row["detail"] != "":
			line += " " + row["detail"]
		lines.append(line.strip_edges(false, true))
	return "\n".join(lines) + "\n"


