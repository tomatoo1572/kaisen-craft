extends RefCounted
class_name KZ_TextureAtlas

# Builds a single texture atlas from a list of texture paths.
# All tiles are forced to the same size.

var atlas_texture: Texture2D
var tile_size_px: int = 16
var tile_size_uv: Vector2 = Vector2.ONE

# path -> origin_uv (normalized)
var origins: Dictionary = {}

func build_from_paths(paths: Array[String], preferred_tile_size: int = 16) -> void:
	tile_size_px = max(1, preferred_tile_size)
	origins.clear()

	var unique: Array[String] = []
	for p in paths:
		if p != "" and not unique.has(p):
			unique.append(p)
	unique.sort()
	if unique.is_empty():
		# Fallback 1x1 white
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 1))
		atlas_texture = ImageTexture.create_from_image(img)
		tile_size_uv = Vector2.ONE
		return

	# Load images
	var images: Array[Image] = []
	for p in unique:
		var img := Image.new()
		var err: Error = img.load(p)
		if err != OK:
			# Try as resource
			var tex: Texture2D = load(p) as Texture2D
			if tex != null:
				img = tex.get_image()
			else:
				img = Image.create(tile_size_px, tile_size_px, false, Image.FORMAT_RGBA8)
				img.fill(Color(1, 0, 1, 1))
		# Force RGBA
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		# Resize to tile_size_px
		if img.get_width() != tile_size_px or img.get_height() != tile_size_px:
			img.resize(tile_size_px, tile_size_px, Image.INTERPOLATE_NEAREST)
		images.append(img)

	var count: int = unique.size()
	var grid: int = int(ceil(sqrt(float(count))))
	var atlas_w: int = grid * tile_size_px
	var atlas_h: int = grid * tile_size_px

	var atlas_img := Image.create(atlas_w, atlas_h, false, Image.FORMAT_RGBA8)
	atlas_img.fill(Color(0, 0, 0, 0))

	for i in range(count):
		var col: int = i % grid
		var row: int = i / grid
		var ox: int = col * tile_size_px
		var oy: int = row * tile_size_px
		atlas_img.blit_rect(images[i], Rect2i(0, 0, tile_size_px, tile_size_px), Vector2i(ox, oy))
		var origin_uv := Vector2(float(ox) / float(atlas_w), float(oy) / float(atlas_h))
		origins[unique[i]] = origin_uv

	# Mipmaps reduce shimmering when moving.
	atlas_img.generate_mipmaps()
	atlas_texture = ImageTexture.create_from_image(atlas_img)

	tile_size_uv = Vector2(float(tile_size_px) / float(atlas_w), float(tile_size_px) / float(atlas_h))

func get_origin_uv(path: String) -> Vector2:
	var v: Variant = origins.get(path)
	if v == null:
		return Vector2.ZERO
	return v as Vector2
