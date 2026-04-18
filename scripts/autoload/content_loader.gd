extends Node

## Cached consequences dictionary (loaded once)
var _cached_consequences: Dictionary = {}
var _consequences_loaded: bool = false


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Loads a single book from a Markdown file with YAML-frontmatter.
## Returns a Dictionary with: id, title, shelf, pages, tags, knowledge_keys,
## content, file_path.  Returns empty Dictionary on failure.
func load_book(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		print_debug("ContentLoader: File not found '%s'" % file_path)
		return {}

	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print_debug("ContentLoader: Cannot open '%s'" % file_path)
		return {}

	var text: String = file.get_as_text()
	file.close()

	# Split frontmatter and content
	var parts := _split_frontmatter(text)
	if parts.is_empty():
		print_debug("ContentLoader: No valid frontmatter in '%s'" % file_path)
		return {}

	var meta: Dictionary = _parse_frontmatter(parts["frontmatter"])
	meta["content"] = parts["content"].strip_edges()
	meta["file_path"] = file_path

	# Ensure pages is int
	if meta.has("pages"):
		meta["pages"] = int(meta["pages"])

	return meta


## Scans fiction/ and practical/ directories, returning metadata for all books
## (without content field).
func load_all_books() -> Array[Dictionary]:
	var books: Array[Dictionary] = []
	var dirs: Array[String] = [
		"res://content/books/fiction/",
		"res://content/books/practical/"
	]
	for dir_path in dirs:
		var dir := DirAccess.open(dir_path)
		if not dir:
			print_debug("ContentLoader: Cannot open directory '%s'" % dir_path)
			continue
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".md"):
				var full_path: String = dir_path + file_name
				var book: Dictionary = load_book(full_path)
				if not book.is_empty():
					book.erase("content")  # metadata only
					books.append(book)
			file_name = dir.get_next()
		dir.list_dir_end()
	return books


## Loads visitors for a given day number from day_XX.yaml.
func load_visitors_for_day(day: int) -> Array[Dictionary]:
	var day_str: String = "%02d" % day
	var file_path: String = "res://content/visitors/day_%s.yaml" % day_str

	if not FileAccess.file_exists(file_path):
		print_debug("ContentLoader: Visitors file not found '%s'" % file_path)
		return []

	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return []

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = _parse_yaml(text)
	if parsed is Dictionary and parsed.has("visitors"):
		var result: Array[Dictionary] = []
		for v in parsed["visitors"]:
			if v is Dictionary:
				result.append(v)
		return result
	return []


## Returns the max_visitors value for a given day from its YAML file.
## Defaults to 3 if not specified or file not found.
func get_max_visitors_for_day(day: int) -> int:
	var day_str: String = "%02d" % day
	var file_path: String = "res://content/visitors/day_%s.yaml" % day_str

	if not FileAccess.file_exists(file_path):
		return 3

	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return 3

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = _parse_yaml(text)
	if parsed is Dictionary and parsed.has("max_visitors"):
		return int(parsed["max_visitors"])
	return 3


## Loads evening walk entries for a given day from content/walks/day_XX.yaml.
## Returns an array of entry dictionaries. Empty array if file not found.
func load_walk_entries(day: int) -> Array[Dictionary]:
	var day_str: String = "%02d" % day
	var file_path: String = "res://content/walks/day_%s.yaml" % day_str

	if not FileAccess.file_exists(file_path):
		return []

	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return []

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = _parse_yaml(text)
	if parsed is Dictionary and parsed.has("entries"):
		var result: Array[Dictionary] = []
		for e in parsed["entries"]:
			if e is Dictionary:
				result.append(e)
		return result
	return []


## Loads a single visitor by ID, searching day files and conditional.yaml.
## The day parameter is used to search the specific day file first.
## Returns empty Dictionary if not found.
func load_visitor_by_id(visitor_id: String, day: int = 0) -> Dictionary:
	# First, search in the specific day file
	if day > 0:
		var day_visitors: Array[Dictionary] = load_visitors_for_day(day)
		for v in day_visitors:
			if v.get("id", "") == visitor_id:
				return v

	# Search in conditional.yaml
	var cond_path: String = "res://content/visitors/conditional.yaml"
	if FileAccess.file_exists(cond_path):
		var file := FileAccess.open(cond_path, FileAccess.READ)
		if file:
			var text: String = file.get_as_text()
			file.close()
			var parsed: Variant = _parse_yaml(text)
			if parsed is Dictionary and parsed.has("conditional_visitors"):
				for v in parsed["conditional_visitors"]:
					if v is Dictionary and v.get("id", "") == visitor_id:
						return v

	# Search across all day files as a last resort
	for d in range(1, 30):
		if d == day:
			continue
		var day_str: String = "%02d" % d
		var file_path: String = "res://content/visitors/day_%s.yaml" % day_str
		if not FileAccess.file_exists(file_path):
			continue
		var visitors: Array[Dictionary] = load_visitors_for_day(d)
		for v in visitors:
			if v.get("id", "") == visitor_id:
				return v

	return {}


## Loads endings from endings.yaml. Returns Dictionary keyed by ending id.
func load_endings() -> Dictionary:
	var file_path: String = "res://content/events/endings.yaml"
	if not FileAccess.file_exists(file_path):
		print_debug("ContentLoader: Endings file not found")
		return {}

	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = _parse_yaml(text)
	var result: Dictionary = {}
	if parsed is Dictionary and parsed.has("endings"):
		for e in parsed["endings"]:
			if e is Dictionary and e.has("id"):
				result[e["id"]] = e
	return result


## Loads consequences from consequences.yaml. Caches after first load.
## Returns Dictionary keyed by consequence id.
func load_consequences() -> Dictionary:
	if _consequences_loaded:
		return _cached_consequences

	var file_path: String = "res://content/events/consequences.yaml"
	if not FileAccess.file_exists(file_path):
		print_debug("ContentLoader: Consequences file not found")
		return {}

	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = _parse_yaml(text)
	if parsed is Dictionary and parsed.has("consequences"):
		for c in parsed["consequences"]:
			if c is Dictionary and c.has("id"):
				_cached_consequences[c["id"]] = c
	_consequences_loaded = true
	return _cached_consequences


# ---------------------------------------------------------------------------
# Frontmatter helpers
# ---------------------------------------------------------------------------

## Splits Markdown text into { "frontmatter": String, "content": String }.
## Returns empty Dictionary if no valid frontmatter found.
func _split_frontmatter(text: String) -> Dictionary:
	var lines := text.split("\n")
	if lines.size() < 3 or lines[0].strip_edges() != "---":
		return {}

	var end_index: int = -1
	for i in range(1, lines.size()):
		if lines[i].strip_edges() == "---":
			end_index = i
			break

	if end_index == -1:
		return {}

	var fm_lines: PackedStringArray = []
	for i in range(1, end_index):
		fm_lines.append(lines[i])
	var content_lines: PackedStringArray = []
	for i in range(end_index + 1, lines.size()):
		content_lines.append(lines[i])

	return {
		"frontmatter": "\n".join(fm_lines),
		"content": "\n".join(content_lines)
	}


## Parses simple YAML frontmatter (key: value, arrays with "  - item").
func _parse_frontmatter(text: String) -> Dictionary:
	var result: Dictionary = {}
	var lines := text.split("\n")
	var current_key: String = ""

	for line in lines:
		var stripped := line.strip_edges()
		if stripped.is_empty():
			continue

		# Array item
		if line.begins_with("  - ") or line.begins_with("    - "):
			var value: String = stripped.substr(2).strip_edges()
			if current_key != "" and result.has(current_key):
				if result[current_key] is Array:
					result[current_key].append(value)
			continue

		# Key: value pair
		var colon_pos: int = stripped.find(":")
		if colon_pos > 0:
			var key: String = stripped.substr(0, colon_pos).strip_edges()
			var value: String = stripped.substr(colon_pos + 1).strip_edges()
			current_key = key
			if value.is_empty():
				result[key] = []
			else:
				result[key] = value

	return result


# ---------------------------------------------------------------------------
# Minimal YAML parser
# ---------------------------------------------------------------------------

## Parses a subset of YAML used by the project:
## - String keys, numbers, booleans
## - Arrays via "- " items
## - Multiline strings via ">"
## - Nested dictionaries via indentation
func _parse_yaml(text: String) -> Variant:
	var lines := text.split("\n")
	var cleaned: Array[String] = []
	for line in lines:
		# Skip comments and empty lines (but keep indentation-significant lines)
		var stripped := line.strip_edges()
		if stripped.begins_with("#"):
			continue
		cleaned.append(line)

	var ctx := {"lines": cleaned, "index": 0}
	return _parse_yaml_block(ctx, 0)


## Parse a YAML block at a given indentation level.
func _parse_yaml_block(ctx: Dictionary, indent: int) -> Variant:
	# Peek at first meaningful line to determine if this is a list or dict
	while ctx["index"] < ctx["lines"].size():
		var line: String = ctx["lines"][ctx["index"]]
		var stripped := line.strip_edges()
		if stripped.is_empty():
			ctx["index"] += 1
			continue

		var line_indent := _get_indent(line)
		if line_indent < indent:
			return null

		if stripped.begins_with("- "):
			return _parse_yaml_list(ctx, indent)
		else:
			return _parse_yaml_dict(ctx, indent)

	return null


## Parse a YAML dictionary at a given indentation level.
func _parse_yaml_dict(ctx: Dictionary, indent: int) -> Dictionary:
	var result: Dictionary = {}

	while ctx["index"] < ctx["lines"].size():
		var line: String = ctx["lines"][ctx["index"]]
		var stripped := line.strip_edges()

		if stripped.is_empty():
			ctx["index"] += 1
			continue

		var line_indent := _get_indent(line)
		if line_indent < indent:
			break
		if line_indent > indent:
			# This shouldn't happen for a well-formed dict at this level
			ctx["index"] += 1
			continue

		var colon_pos := stripped.find(":")
		if colon_pos == -1:
			ctx["index"] += 1
			continue

		var key: String = stripped.substr(0, colon_pos).strip_edges()
		var value_part: String = stripped.substr(colon_pos + 1).strip_edges()
		ctx["index"] += 1

		if value_part == ">":
			# Multiline folded string
			result[key] = _parse_yaml_multiline(ctx, indent)
		elif value_part == "|":
			# Multiline literal string
			result[key] = _parse_yaml_multiline(ctx, indent)
		elif value_part.is_empty():
			# Could be a nested dict or list
			if ctx["index"] < ctx["lines"].size():
				var next_line: String = _peek_next_content_line(ctx)
				if next_line.is_empty():
					result[key] = null
				else:
					var next_indent := _get_indent(next_line)
					if next_indent > indent:
						result[key] = _parse_yaml_block(ctx, next_indent)
					else:
						result[key] = null
			else:
				result[key] = null
		else:
			result[key] = _parse_yaml_value(value_part)

	return result


## Parse a YAML list at a given indentation level.
func _parse_yaml_list(ctx: Dictionary, indent: int) -> Array:
	var result: Array = []

	while ctx["index"] < ctx["lines"].size():
		var line: String = ctx["lines"][ctx["index"]]
		var stripped := line.strip_edges()

		if stripped.is_empty():
			ctx["index"] += 1
			continue

		var line_indent := _get_indent(line)
		if line_indent < indent:
			break

		if not stripped.begins_with("- "):
			break

		var item_text: String = stripped.substr(2).strip_edges()
		ctx["index"] += 1

		# Check if this list item starts a nested dict (e.g. "- id: value")
		var colon_pos := item_text.find(":")
		if colon_pos > 0:
			# This is a dict entry starting inline
			var inline_key: String = item_text.substr(0, colon_pos).strip_edges()
			var inline_val: String = item_text.substr(colon_pos + 1).strip_edges()
			var item_dict: Dictionary = {}

			if inline_val == ">":
				item_dict[inline_key] = _parse_yaml_multiline(ctx, line_indent + 2)
			elif inline_val.is_empty():
				# Check for nested block
				var next_content := _peek_next_content_line(ctx)
				if not next_content.is_empty() and _get_indent(next_content) > line_indent + 2:
					item_dict[inline_key] = _parse_yaml_block(ctx, _get_indent(next_content))
				else:
					item_dict[inline_key] = null
			else:
				item_dict[inline_key] = _parse_yaml_value(inline_val)

			# Continue reading more keys at the item's nested indent
			var item_indent: int = line_indent + 2
			while ctx["index"] < ctx["lines"].size():
				var next_line: String = ctx["lines"][ctx["index"]]
				var next_stripped := next_line.strip_edges()
				if next_stripped.is_empty():
					ctx["index"] += 1
					continue
				var next_indent := _get_indent(next_line)
				if next_indent < item_indent:
					break
				if next_indent == item_indent:
					var nc := next_stripped.find(":")
					if nc > 0:
						var nk: String = next_stripped.substr(0, nc).strip_edges()
						var nv: String = next_stripped.substr(nc + 1).strip_edges()
						ctx["index"] += 1
						if nv == ">" or nv == "|":
							item_dict[nk] = _parse_yaml_multiline(ctx, item_indent)
						elif nv.is_empty():
							var peek := _peek_next_content_line(ctx)
							if not peek.is_empty() and _get_indent(peek) > item_indent:
								item_dict[nk] = _parse_yaml_block(ctx, _get_indent(peek))
							else:
								item_dict[nk] = null
						else:
							item_dict[nk] = _parse_yaml_value(nv)
					else:
						break
				elif next_indent > item_indent:
					# Part of a nested value, skip (handled by recursive call)
					break
				else:
					break

			result.append(item_dict)
		else:
			result.append(_parse_yaml_value(item_text))

	return result


## Parse a multiline folded/literal string.
func _parse_yaml_multiline(ctx: Dictionary, parent_indent: int) -> String:
	var parts: PackedStringArray = []
	while ctx["index"] < ctx["lines"].size():
		var line: String = ctx["lines"][ctx["index"]]
		var stripped := line.strip_edges()

		if stripped.is_empty():
			ctx["index"] += 1
			parts.append("")
			continue

		var line_indent := _get_indent(line)
		if line_indent <= parent_indent:
			break

		parts.append(stripped)
		ctx["index"] += 1

	return " ".join(parts).strip_edges()


## Parse a scalar YAML value (string, int, float, bool, null).
func _parse_yaml_value(text: String) -> Variant:
	if text.is_empty():
		return ""

	# Remove surrounding quotes
	if (text.begins_with("\"") and text.ends_with("\"")) or \
	   (text.begins_with("'") and text.ends_with("'")):
		return text.substr(1, text.length() - 2)

	# Boolean
	if text == "true" or text == "True":
		return true
	if text == "false" or text == "False":
		return false

	# Null
	if text == "null" or text == "~":
		return null

	# Integer
	if text.is_valid_int():
		return text.to_int()

	# Float
	if text.is_valid_float():
		return text.to_float()

	return text


## Get indentation level (number of leading spaces).
func _get_indent(line: String) -> int:
	var count: int = 0
	for c in line:
		if c == " ":
			count += 1
		elif c == "\t":
			count += 2
		else:
			break
	return count


## Peek at the next non-empty line without advancing the index.
func _peek_next_content_line(ctx: Dictionary) -> String:
	var i: int = ctx["index"]
	while i < ctx["lines"].size():
		var line: String = ctx["lines"][i]
		if not line.strip_edges().is_empty():
			return line
		i += 1
	return ""
