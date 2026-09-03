class_name MicrogameIntroBase
extends MicrogameOutroBase

## Shared stage for AUTHORED CAUSE clips (the "why this round matters" beat).
##
## Same 4-beat rhythm as the outro, compressed into the intro budget:
##   SETUP 0.35 + IMPACT HOLD 0.18 + PAYOFF 0.60 + SNAP 0.25 ≈ 1.38 s
## (spec: intro total 1.0–1.5 s).
##
## Per-game scenes extend this, override _setup_stage()/_beat_setup()/
## _on_impact()/_beat_payoff(), and are resolved by MiniGameIntroBridge from
## res://scenes/ui/cutscenes/beats/<Game>Intro.tscn.
##
## Intros do NOT get the outro's camera punch or particle burst — beat 2 for
## an intro is the moment the situation becomes clear (Dribble's "uh oh"),
## sold by expression + a small flash, not by a hit.

func play_cause() -> void:
	win = true
	_run()

## Compatibility with MiniGameIntroBridge, which awaits play_cutscene() on
## every intro clip (CartoonStage and legacy scenes both expose it).
func play_cutscene() -> void:
	play_cause()
	await outro_finished

func _setup_sec() -> float: return 0.35
func _impact_hold_sec() -> float: return 0.18
func _payoff_sec() -> float: return 0.60
func _snap_sec() -> float: return 0.25

## Intro impact: the flash only. No camera punch, no burst, no stinger —
## the CAUSE beat sets up, it doesn't resolve.
func _on_impact() -> void:
	_impact_flash()

## Intros hand off INTO gameplay, so the snap reads as the camera whipping
## toward the action rather than a celebratory zoom.
func _beat_snap() -> void:
	transition.snap_out(TransitionLayer.Snap.WHIP_PAN, _snap_sec())
