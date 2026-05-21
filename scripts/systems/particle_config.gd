class_name ParticleConfig
extends RefCounted

## Configuration for a particle effect
enum EffectType {
	# Attack effects
	ATTACK_BULLET,       # Generic bullet trail
	ATTACK_EXPLOSION,    # Explosion impact
	ATTACK_SPARK,        # Spark/splash on hit
	ATTACK_SLASH,        # Melee slash effect
	
	# Skill effects - Damage
	SKILL_DAMAGE_GENERIC,   # Generic skill damage
	SKILL_DAMAGE_FIRE,      # Fire damage
	SKILL_DAMAGE_ICE,       # Ice/frost damage
	SKILL_DAMAGE_ELECTRIC,  # Electric/lightning damage
	
	# Skill effects - Buff/Debuff
	SKILL_BUFF_UP,          # Buff rising effect
	SKILL_DEBUFF_DOWN,      # Debuff falling effect
	SKILL_SHIELD,           # Shield/protect effect
	SKILL_HEAL,             # Healing glow
	
	# Skill effects - Special
	SKILL_AOE_RING,         # AoE expanding ring
	SKILL_TELEPORT,         # Teleport effect
	SKILL_TURRET_DEPLOY,    # Turret deployment
	SKILL_TAUNT,            # Taunt/aggro effect
	
	# Status effects
	STATUS_SLOW,            # Slow effect indicator
	STATUS_SHATTER,         # Armor shatter indicator
	STATUS_WEAKEN,          # Weaken effect indicator
	STATUS_HASTE,           # Haste effect indicator
	STATUS_POWER_UP,        # Power up effect indicator
	STATUS_FORTIFY,         # Fortify effect indicator
}

var effect_type: EffectType
var color: Color = Color.WHITE
var scale: float = 1.0
var duration: float = 0.5
var intensity: float = 1.0

func _init(p_type: EffectType, p_color: Color = Color.WHITE, p_scale: float = 1.0, p_duration: float = 0.5, p_intensity: float = 1.0) -> void:
	effect_type = p_type
	color = p_color
	scale = p_scale
	duration = p_duration
	intensity = p_intensity