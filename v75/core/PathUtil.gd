extends RefCounted
class_name KZ_PathUtil

static func join(a: String, b: String) -> String:
	if a.ends_with("/"):
		return a + b
	return a + "/" + b

static func user_to_abs(user_path: String) -> String:
	return ProjectSettings.globalize_path(user_path)

static func ensure_dir(user_path: String) -> void:
	var abs_path: String = user_to_abs(user_path)
	DirAccess.make_dir_recursive_absolute(abs_path)

static func write_text(user_path: String, text: String) -> void:
	ensure_dir(user_path.get_base_dir())
	var f: FileAccess = FileAccess.open(user_path, FileAccess.WRITE)
	if f == null:
		push_error("Failed to write file: %s" % user_path)
		return
	f.store_string(text)
	f.flush()
	f.close()

static func read_text(user_path: String) -> String:
	if not FileAccess.file_exists(user_path):
		return ""
	var f: FileAccess = FileAccess.open(user_path, FileAccess.READ)
	if f == null:
		return ""
	var s: String = f.get_as_text()
	f.close()
	return s

static func file_exists(user_path: String) -> bool:
	return FileAccess.file_exists(user_path)

static func list_files(user_dir: String, extension: String) -> Array[String]:
	var out: Array[String] = []
	if not DirAccess.dir_exists_absolute(user_to_abs(user_dir)):
		return out

	var d: DirAccess = DirAccess.open(user_dir)
	if d == null:
		return out

	d.list_dir_begin()
	while true:
		var name: String = d.get_next()
		if name == "":
			break
		if d.current_is_dir():
			continue
		if extension == "" or name.to_lower().ends_with(extension.to_lower()):
			out.append(join(user_dir, name))
	d.list_dir_end()
	return out


static func list_dirs(user_dir: String) -> Array[String]:
	var out: Array[String] = []
	if not DirAccess.dir_exists_absolute(user_to_abs(user_dir)):
		return out

	var d: DirAccess = DirAccess.open(user_dir)
	if d == null:
		return out

	d.list_dir_begin()
	while true:
		var name: String = d.get_next()
		if name == "":
			break
		if name == "." or name == "..":
			continue
		if d.current_is_dir():
			out.append(join(user_dir, name))
	d.list_dir_end()
	return out
