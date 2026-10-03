extends RefCounted

static func event(identity: String = "evt_death", causes: Array = []) -> Dictionary:
	return {
		"schema_version": 1, "event_id": identity, "event_type": "character_death",
		"world_time_seconds": 100.0,
		"location_ref": {"region_id": "region_mine", "area_id": "mine_7", "position": [10.0, 20.0]},
		"absolute_depth_m": 2130.0,
		"actor_refs": [{"entity_id": "character_mara", "role": "subject"}],
		"object_refs": [{"instance_id": "knife_x", "role": "carried_evidence"}],
		"cause_event_ids": causes, "effect_tags": ["death"],
		"facts": [{"key": "death_cause", "value": "blood_loss"}, {"key": "companion", "value": "character_elias"}],
		"significance_tags": ["historical"], "source_system": "lifecycle",
	}

static func anchor(identity: String, category: String = "corpse", profile: String = "corpse") -> Dictionary:
	return {
		"anchor_id": identity, "anchor_type": category, "target_ref": {"kind": category, "id": identity+"_target"},
		"profile_id": profile, "memory_ids": [], "durability": 1.0, "readability": 1.0,
		"accessibility": 1.0, "environmental_exposure": 0.0, "available": true,
		"last_known_location": {"region_id": "region_mine", "area_id": "mine_7"},
	}
