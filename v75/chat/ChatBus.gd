extends Node
class_name KZ_ChatBus

signal message_posted(packet: Dictionary)

var proximity_radius_blocks: float = 30.0
var world_id: String = ""
var voice_feature_stub_enabled: bool = true

func setup(p_world_id: String, p_radius_blocks: float = 30.0) -> void:
	world_id = p_world_id
	proximity_radius_blocks = maxf(1.0, p_radius_blocks)

func build_text_packet(sender_id: String, sender_name: String, sender_pos: Vector3, text: String, radius_blocks: float = -1.0) -> Dictionary:
	var radius: float = proximity_radius_blocks if radius_blocks <= 0.0 else radius_blocks
	return {
		"kind": "text",
		"channel": "proximity",
		"sender_id": sender_id,
		"sender_name": sender_name,
		"world_id": world_id,
		"position": sender_pos,
		"radius_blocks": radius,
		"text": text,
		"voice_channel_id": "prox:%s" % sender_id,
		"voice_ready_later": voice_feature_stub_enabled,
		"timestamp_ms": Time.get_ticks_msec()
	}

func post_text(sender_id: String, sender_name: String, sender_pos: Vector3, text: String, radius_blocks: float = -1.0) -> Dictionary:
	var packet: Dictionary = build_text_packet(sender_id, sender_name, sender_pos, text, radius_blocks)
	emit_signal("message_posted", packet)
	return packet

func post_system(text: String) -> Dictionary:
	var packet: Dictionary = {
		"kind": "system",
		"channel": "system",
		"sender_id": "system",
		"sender_name": "System",
		"world_id": world_id,
		"position": Vector3.ZERO,
		"radius_blocks": 0.0,
		"text": text,
		"timestamp_ms": Time.get_ticks_msec()
	}
	emit_signal("message_posted", packet)
	return packet

func should_deliver(packet: Dictionary, listener_world_id: String, listener_pos: Vector3) -> bool:
	var kind: String = str(packet.get("kind", "text"))
	if kind == "system":
		return true
	if str(packet.get("world_id", "")) != listener_world_id:
		return false
	var radius: float = float(packet.get("radius_blocks", proximity_radius_blocks))
	var pos_v: Variant = packet.get("position", Vector3.ZERO)
	if typeof(pos_v) != TYPE_VECTOR3:
		return false
	var pos: Vector3 = pos_v as Vector3
	return pos.distance_to(listener_pos) <= radius
