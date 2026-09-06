extends Node

## ═══════════════════════════════════════════════════════════════════
## LOCALIZATION MANAGER
## Handles English ↔ Filipino language switching
## ═══════════════════════════════════════════════════════════════════

signal language_changed(new_language: String)

enum Language {
	ENGLISH,
	FILIPINO
}

var current_language: Language = Language.FILIPINO  # Default to Filipino
var translations: Dictionary = {}
const SAVE_PATH = "user://settings.cfg"

func _ready() -> void:
	_load_translations()
	_load_settings()

func _load_translations() -> void:
	translations = {
		# Main Menu
		"title": {
			"en": "WATERVILLE",
			"tl": "WATERVILLE"
		},
		"subtitle": {
			"en": "Every Drop Counts",
			"tl": "Bawat Patak ay Mahalaga"
		},
		"play": {
			"en": "▶️ PLAY",
			"tl": "▶️ MAGLARO"
		},
		"multiplayer": {
			"en": "MULTIPLAYER",
			"tl": "MULTIPLAYER"
		},
		"multiplayer_locked_hint": {
			"en": "Finish one round to unlock co-op",
			"tl": "Tapusin ang isang round para ma-unlock ang co-op"
		},
		# Multiplayer departure notices. Produced as KEYS by NetworkManager through
		# GameManager.set_multiplayer_notice() and rendered by whichever multiplayer screen
		# comes up first, so the wording follows the current language even when the
		# departure happened before the player switched it.
		"notice_host_left": {
			"en": "The host left the game. Round cancelled.",
			"tl": "Umalis ang host. Kanselado ang round."
		},
		"notice_partner_left": {
			"en": "Your partner left the game. Round cancelled.",
			"tl": "Umalis ang kapareha mo. Kanselado ang round."
		},
		"notice_partner_no_return": {
			"en": "Your partner never came back. Round cancelled.",
			"tl": "Hindi na bumalik ang kapareha mo. Kanselado ang round."
		},
		"host": {
			"en": "HOST",
			"tl": "HOST"
		},
		"join": {
			"en": "JOIN",
			"tl": "JOIN"
		},
		"customize": {
			"en": "👤 CUSTOMIZE",
			"tl": "👤 BAGUHIN ANG CHARACTER"
		},
		"instructions": {
			"en": "📖 HOW TO PLAY",
			"tl": "📖 PAANO MAGLARO"
		},
		"settings": {
			"en": "⚙️ SETTINGS",
			"tl": "⚙️ SETTINGS"
		},
		"quit": {
			"en": "🚪 EXIT",
			"tl": "🚪 UMALIS"
		},
		"continue_test": {
			"en": "📝 CONTINUE TO TEST",
			"tl": "📝 MAGPATULOY SA TEST"
		},
		"loading_game": {
			"en": "Loading game...",
			"tl": "Naglo-load ng laro..."
		},
		"all_character_unlocks_owned": {
			"en": "All character unlocks owned",
			"tl": "Nakuha na lahat ng unlock ng character"
		},
		"points_to_go": {
			"en": "%d points to go",
			"tl": "%d puntos pa"
		},
		"initial_highscore_sign": {
			"en": "HIGHSCORE",
			"tl": "HIGHSCORE"
		},
		"leaderboard_title": {
			"en": "🏆 LEADERBOARD",
			"tl": "🏆 LEADERBOARD"
		},
		"leaderboard_empty": {
			"en": "No single-player scores yet.",
			"tl": "Wala pang score sa single-player."
		},
		"leaderboard_summary": {
			"en": "Best score: %d | Runs saved: %d",
			"tl": "Pinakamataas na puntos: %d | Naitalang runs: %d"
		},
		"leaderboard_score_row": {
			"en": "%d. Tier %s | %d pts",
			"tl": "%d. Tier %s | %d pts"
		},
		
		# Settings
		"language": {
			"en": "Language / Wika",
			"tl": "Language / Wika"
		},
		"english": {
			"en": "English",
			"tl": "Ingles"
		},
		"filipino": {
			"en": "Filipino",
			"tl": "Filipino"
		},
		"volume": {
			"en": "Volume",
			"tl": "Lakas ng Tunog"
		},
		"fullscreen": {
			"en": "Fullscreen",
			"tl": "Buong Screen"
		},
		"back": {
			"en": "⬅️ BACK",
			"tl": "⬅️ BUMALIK"
		},
		"exit": {
			"en": "EXIT",
			"tl": "UMALIS"
		},
		"settings_accessibility_header": {
			"en": "♿ Accessibility",
			"tl": "♿ Accessibility / Aksesibilidad"
		},
		"settings_colorblind_mode": {
			"en": "🎨 Colorblind Mode",
			"tl": "🎨 Mode para sa Colorblind"
		},
		"settings_enable": {
			"en": "Enable",
			"tl": "I-enable"
		},
		"settings_large_touch_targets": {
			"en": "👆 Large Touch Targets",
			"tl": "👆 Malalaking Touch Target"
		},
		"settings_audio_cues": {
			"en": "🔊 Audio Cues",
			"tl": "🔊 Mga Audio Cue"
		},
		"settings_haptic_feedback": {
			"en": "📳 Haptic Feedback",
			"tl": "📳 Haptic na Feedback"
		},
		"settings_screen_shake": {
			"en": "📳 Screen Shake",
			"tl": "📳 Pag-uga ng Screen"
		},
		"settings_particles_effects": {
			"en": "✨ Particles/Effects",
			"tl": "✨ Particle/Epekto"
		},
		"settings_reduced_motion": {
			"en": "🐢 Reduce Motion",
			"tl": "🐢 Bawasan ang Paggalaw"
		},
		"settings_dev_mode_header": {
			"en": "🛠 Dev Mode / Thesis Monitoring",
			"tl": "🛠 Dev Mode / Thesis Monitoring"
		},
		"settings_enable_dev_mode": {
			"en": "Enable Dev Mode",
			"tl": "I-enable ang Dev Mode"
		},
		"settings_show_iso_profiler": {
			"en": "Show ISO Profiler (F11)",
			"tl": "Ipakita ang ISO Profiler (F11)"
		},
		"settings_show_algorithm_overlay": {
			"en": "Show Algorithm Overlay (F12)",
			"tl": "Ipakita ang Algorithm Overlay (F12)"
		},
		"settings_auto_play": {
			"en": "Auto-Play Mode (Testing)",
			"tl": "Auto-Play Mode (Pagsusulit)"
		},
		"settings_auto_play_duration": {
			"en": "Duration (0 = Unlimited)",
			"tl": "Tagal (0 = Walang Hangganan)"
		},
		"settings_auto_play_duration_hint": {
			"en": "(0 = ∞, any value)",
			"tl": "(0 = ∞, kahit anong halaga)"
		},
		"settings_show": {
			"en": "Show",
			"tl": "Ipakita"
		},

		# Instructions
		"how_to_play": {
			"en": "📖 HOW TO PLAY",
			"tl": "📖 PAANO MAGLARO"
		},
		"gameplay": {
			"en": "🎮 GAMEPLAY",
			"tl": "🎮 PAGLALARO"
		},
		"gameplay_text": {
			"en": (
				"Play fun mini-games about water conservation! "
				+ "Complete tasks quickly and accurately to score points."
			),
			"tl": (
				"Maglaro ng mga masayang mini-games tungkol sa "
				+ "pagtitipid ng tubig! Kumpletuhin ang mga gawain "
				+ "nang mabilis at tama para makakuha ng puntos."
			)
		},
		"difficulty": {
			"en": "🎯 DIFFICULTY",
			"tl": "🎯 HIRAP"
		},
		
		# Mini-Game Instructions
		"rice_wash_rescue": {
			"en": "Rice Wash Rescue",
			"tl": "Sagipin ang Hugas-Bigas"
		},
		"rice_wash_instruction": {
			"en": "DRAG TO CATCH THE WATER!\nDON'T SPILL THE RICE!",
			"tl": "I-DRAG PARA SALUHIN ANG TUBIG!\nHUWAG ITAPON ANG BIGAS!"
		},
		"vegetable_bath": {
			"en": "Vegetable Bath",
			"tl": "Hugasan ang Gulay"
		},
		"veggie_instruction": {
			"en": "DRAG VEGGIES OUT!\nDON'T TIP THE BOWL!",
			"tl": "I-DRAG ANG MGA GULAY!\nHUWAG ITUMBA ANG MANGKOK!"
		},
		# The key RoadmapScreen.gd:69 asks for first. `veggie_instruction` above is
		# its fallback, but that string describes tipping a bowl — a mechanic
		# VegetableBath does not have — so it cannot be reused as the real
		# instruction. This one states the actual three-station pipeline.
		"vegetable_bath_instructions": {
			"en": "DRAG: Dirty Basket ➡ Wash Bowl ➡ Clean Basket!"
				+ "\nDirty in clean = TIME PENALTY! 🥕",
			"tl": "I-DRAG: Maruming Basket ➡ Palanggana ➡ Malinis na Basket!"
				+ "\nMarumi sa malinis = PARUSA SA ORAS! 🥕"
		},
		"greywater_sorter": {
			"en": "Greywater Sorter",
			"tl": "Paghiwalayin ang Greywater"
		},
		"greywater_instruction": {
			"en": "SWIPE LEFT for GARDEN\nSWIPE RIGHT for DRAIN",
			"tl": "SWIPE KALIWA para sa HALAMAN\nSWIPE KANAN para sa KANAL"
		},
		"wring_it_out": {
			"en": "Wring It Out",
			"tl": "Piga ang Damit"
		},
		"wring_instruction": {
			"en": "TAP FAST TO WRING!\nFILL THE BUCKET!",
			"tl": "TAP NANG MABILIS PARA PIGA!\nPUNUIN ANG TIMBA!"
		},
		"thirsty_plant": {
			"en": "Thirsty Plant",
			"tl": "Ang Nauuhaw na Halaman"
		},
		"plant_instruction": {
			"en": "TAP THE GREEN BUCKET!\nUSE REUSED WATER!",
			"tl": "TAP ANG BERDENG TIMBA!\nGAMITIN ANG MULING GINAMIT NA TUBIG!"
		},
		"mud_pie_maker": {
			"en": "Mud Pie Maker",
			"tl": "Gawa ng Putik"
		},
		"mud_instruction": {
			# Was "SLIDE TO POUR WATER! / MIX PERFECT MUD!", which describes an input the game
			# does not have: MudPieMaker._input pours while the finger is HELD and the round is
			# survival — keep the gauge in the green band until the clock runs out. Rewritten
			# rather than translated, because the instruction itself was wrong in both languages.
			"en": "HOLD to pour water!\nKeep the gauge in the GREEN zone! 💧",
			"tl": "HAWAKAN para buhusan ng tubig!\nPanatilihin ang gauge sa BERDENG zone! 💧"
		},
		"catch_the_rain": {
			"en": "Catch The Rain",
			"tl": "Saluhin ang Ulan"
		},
		"rain_instruction": {
			"en": "DRAG TO CATCH BLUE DROPS!\nAVOID RED ACID RAIN!",
			"tl": "I-DRAG PARA SALUHIN ANG ASUL NA PATAK!\nIWASAN ANG PULANG ACID RAIN!"
		},
		"cover_the_drum": {
			"en": "Cover The Drum",
			"tl": "Takpan ang Drum"
		},
		"drum_instruction": {
			"en": "TAP DRUMS TO CLOSE LIDS!\nSTOP THE MOSQUITOES!",
			# "Pigilan" was the one lower-case word in an all-caps pair of lines.
			"tl": "TAP ANG MGA DRUM PARA ISARA ANG TAKIP!\nPIGILAN ANG MGA LAMOK!"
		},
		"spot_the_speck": {
			"en": "Spot The Speck",
			"tl": "Tukuyin ang Dumi"
		},
		"speck_instruction": {
			# Widened from "DIRTY? SWIPE DOWN / CLEAN? SWIPE UP" so the Filipino line carries
			# the same detail SpotTheSpeck was showing in hardcoded English before it started
			# reading this key: what you are looking at, and which way means what.
			"en": "Check each glass of water!\n⬆️ SWIPE UP = clean (drink!) | ⬇️ SWIPE DOWN = dirty",
			"tl": "Tingnan ang bawat baso ng tubig!\n⬆️ SWIPE PATAAS = malinis (inumin!) | ⬇️ SWIPE PABABA = marumi"
		},
		"water_plant": {
			"en": "Water Plant",
			"tl": "Diligan ang Halaman"
		},
		"water_plant_instruction": {
			"en": "USE WATERING CAN!\nNOT THE HOSE!",
			"tl": "GUMAMIT NG REGADERA!\nHINDI ANG HOSE!"
		},
		"fix_leak": {
			"en": "Fix Leak",
			"tl": "Ayusin ang Tagas"
		},
		"fix_leak_instruction": {
			"en": "TAP TO FIX LEAKS!\nSAVE WATER FAST!",
			# The second line used to be the English "SAVE WATER FAST!" verbatim, so a
			# Filipino player got half a translated instruction. Same string, finished.
			"tl": "TAP PARA AYUSIN ANG TAGAS!\nMAGTIPID NG TUBIG, BILISAN!"
		},
		# FixLeakV2's own objective, which the short line above does not carry: there are
		# several leaks and a waste bar that fills while any of them is open. Authored
		# because FixLeakV2 hardcoded English here, and because RoadmapScreen has been
		# asking for "fix_leak_instructions" (plural) all along and silently falling back.
		"fix_leak_instructions": {
			"en": "TAP every leaking pipe to patch it!\nPatch them all before the water is wasted! 🔧",
			"tl": "TAP ang bawat tumutulong tubo para tapalan!\nTapalan lahat bago masayang ang tubig! 🔧"
		},
		# New instruction keys for minigames
		"rice_wash_rescue_instructions": {
			"en": "FOLLOW the moving pot with the basin!\nCatch the rice water! 🍚",
			"tl": (
				"SUNDAN ang kumikilos na kaldero gamit ang "
				+ "palanggana!\nSaluhin ang hugas-bigas! 🍚"
			)
		},
		"catch_the_rain_instructions": {
			"en": "DRAG to move the drum!\nCatch BLUE drops! Avoid RED drops!",
			"tl": "I-DRAG para ilipat ang drum!\nSaluhin ang ASUL na patak! Iwasan ang PULA!"
		},
		"greywater_sorter_instructions": {
			"en": "SWIPE buckets left or right!\n🌿 Garden = Blue | 🚿 Drain = Brown",
			"tl": "SWIPE ang mga timba pakaliwa o pakanan!\n🌿 Halaman = Asul | 🚿 Kanal = Kayumanggi"
		},
		"tap_to_start": {
			"en": "TAP ANYWHERE TO START",
			"tl": "TAP KAHIT SAAN PARA MAGSIMULA"
		},
		# Shown in place of tap_to_start while the multiplayer first-play beat still has pages
		# left, so the prompt does not promise a start the tap will not deliver.
		"mp_tap_to_continue": {
			"en": "TAP ANYWHERE TO CONTINUE",
			"tl": "TAP KAHIT SAAN PARA MAGPATULOY"
		},
		# Emoji-free twin of tutorial_tip_prefix. The bulb glyph in that one renders as an
		# "unknown character" box on the Android 8 test phone, and the multiplayer beat is new
		# copy, so it does not add to that pile. The singleplayer prefix is left alone.
		"mp_tutorial_tip_prefix": {
			"en": "TIP: ",
			"tl": "PAYO: "
		},
		# New Mini-Game Instructions
		"plug_the_leak_instructions": {
			"en": "HOLD on leaking pipes to plug them!\nDon't let damage reach 100%! 🔧",
			"tl": (
				"I-HOLD ang tumatagos na tubo para ayusin!"
				+ "\nHuwag hayaang umabot ng 100% ang pinsala! 🔧"
			)
		},
		"swipe_the_soap_instructions": {
			"en": "SWIPE in the shown direction!\nFast and accurate = water saved! 🧼",
			"tl": "I-SWIPE sa tamang direksyon!\nMabilis at tama = nakatipid ng tubig! 🧼"
		},
		# Alternative keys used by games
		"swipe_soap_instructions": {
			"en": "SWIPE in the direction shown!\nQuick rinse saves water! 🧼",
			"tl": "I-SWIPE sa direksyong ipinapakita!\nMabilis na banlawan para makatipid! 🧼"
		},
		"quick_shower_instructions": {
			"en": "TAP when the marker is in the GREEN zone!\nStop the shower at the right time! 🚿",
			"tl": "TAP kapag ang marker ay nasa BERDENG zone!\nIhinto ang shower sa tamang oras! 🚿"
		},
		"filter_builder_instructions": {
			# Must match FilterBuilder.correct_order (top → bottom) and the
			# numbered zone guides in _create_solution_guides(). This string
			# used to read "Gravel → Sand → Charcoal → Cloth", the exact
			# reverse of the order the game validates, so a player who
			# followed the instruction was always marked wrong.
			"en": (
				"DRAG filter layers to the correct slots!"
				+ "\nTop to bottom: Cloth ➡ Charcoal ➡ Sand ➡ Gravel 🧱"
			),
			"tl": (
				"I-DRAG ang mga layer ng filter sa tamang posisyon!"
				+ "\nItaas pababa: Tela ➡ Uling ➡ Buhangin ➡ Graba 🧱"
			)
		},
		"water_plant_instructions": {
			"en": (
				"TAP the thirsty plants to water them! 🌱"
				+ "\nDon't let any plant dry out! 💧"
			),
			"tl": (
				"TAP ang mga nauuhaw na halaman para diligan! 🌱"
				+ "\nHuwag hayaang matuyo ang kahit isa! 💧"
			)
		},
		"toilet_tank_fix_instructions": {
			"en": "HOLD to stop water flow!\nTAP to adjust the float mechanism! 🚽",
			"tl": "I-HOLD para ihinto ang daloy ng tubig!\nTAP para ayusin ang mekanismo! 🚽"
		},
		"toilet_tank_instructions": {
			"en": "HOLD to fill tank!\nRelease when water reaches the LINE! 🚽",
			"tl": "I-HOLD para punuin ang tangke!\nBitawan kapag umabot na sa LINYA ang tubig! 🚽"
		},
		"trace_pipe_path_instructions": {
			"en": "TRACE the path to connect the pipes!\nDraw from start to finish! 🛠️",
			"tl": (
				"I-TRACE ang landas para ikonekta ang mga "
				+ "tubo!\nGuhit mula simula hanggang dulo! 🛠️"
			)
		},
		"trace_pipe_instructions": {
			"en": "DRAW along the pipe to connect water!\nFollow the dotted line! 🔧",
			"tl": (
				"GUMUHIT sa kahabaan ng tubo para ikonekta "
				+ "ang tubig!\nSundan ang tuldok na linya! 🔧"
			)
		},
		"scrub_to_save_instructions": {
			"en": "RUB dishes to clean them!\nUse water efficiently! 🍽️",
			"tl": "KUSUTAN ang mga pinggan para linisin!\nGumamit ng tubig nang tama! 🍽️"
		},
		"scrub_save_instructions": {
			"en": "RUB the dish to clean it!\nUse water wisely! 🍽️",
			"tl": "KUSUTAN ang pinggan para linisin!\nGumamit ng tubig nang matalino! 🍽️"
		},
		# Was "TAP when bucket reaches target!", which describes a timing game. Neither
		# BucketBrigade family works that way: _handle_tap looks for the person under the
		# thumb who is HOLDING a bucket and passes it on, and tapping an empty-handed
		# person is the one recorded mistake. The old line told the player to wait for a
		# target that does not exist — a mismatched instruction, not a translation bug.
		"bucket_brigade_instructions": {
			"en": "TAP the person holding the bucket!\nPass it down the line to the garden! 🏺",
			"tl": "TAP ang taong may hawak ng timba!\nIpasa sa susunod hanggang halamanan! 🏺"
		},
		"timing_tap_instructions": {
			"en": "HOLD to fill container!\nStop at the TARGET line! 💧",
			"tl": "I-HOLD para punuin ang lalagyan!\nIhinto sa TARGET na linya! 💧"
		},
		"turn_off_tap_instructions": {
			"en": "TAP running faucets to turn them off!\nDon't waste water! 🚿",
			"tl": "TAP ang mga bukas na gripo para isara!\nHuwag mag-aksaya ng tubig! 🚿"
		},
		# ── Titles for the ten games that had no key at all ──────────────
		# Fourteen of the 24 roster games already had a translated title here and
		# nothing read it: every game except FixLeakV2 assigned game_name as a
		# hardcoded English literal, so the HUD showed "TIMING TAP" above a Filipino
		# objective. These ten had no row to read even if they had asked.
		"plug_the_leak": {
			"en": "Plug The Leak",
			"tl": "Tapalan ang Tagas"
		},
		"trace_pipe_path": {
			"en": "Trace Pipe Path",
			"tl": "Sundan ang Tubo"
		},
		"quick_shower": {
			"en": "Quick Shower",
			"tl": "Mabilis na Shower"
		},
		"toilet_tank_fix": {
			"en": "Toilet Tank Fix",
			"tl": "Ayusin ang Tangke"
		},
		"scrub_to_save": {
			"en": "Scrub To Save",
			"tl": "Kuskusin para Makatipid"
		},
		"bucket_brigade": {
			"en": "Bucket Brigade",
			"tl": "Hanay ng Timba"
		},
		"timing_tap": {
			"en": "Timing Tap",
			"tl": "Tamang Tiyempo"
		},
		"turn_off_tap": {
			"en": "Turn Off Tap",
			"tl": "Isara ang Gripo"
		},
		"swipe_the_soap": {
			"en": "Swipe The Soap",
			"tl": "I-swipe ang Sabon"
		},
		"filter_builder": {
			"en": "Filter Builder",
			"tl": "Gumawa ng Filter"
		},
		"score": {
			"en": "SCORE",
			"tl": "PUNTOS"
		},
		"high_score": {
			"en": "HIGH SCORE",
			"tl": "PINAKAMATAAS NA PUNTOS"
		},
		"round": {
			"en": "Round",
			"tl": "Round"
		},
		"total_score": {
			"en": "TOTAL SCORE",
			"tl": "KABUUANG PUNTOS"
		},
		"new_high_score": {
			"en": "🎉 NEW HIGH SCORE! 🎉",
			"tl": "🎉 BAGONG PINAKAMATAAS NA PUNTOS! 🎉"
		},
		"game_over": {
			"en": "GAME OVER!",
			"tl": "TAPOS NA ANG LARO!"
		},
		"finalscore_rank": {
			"en": "Rank: %s",
			"tl": "Ranggo: %s"
		},
		"finalscore_round_row": {
			"en": "%d. %s | %d pts | x%d",
			"tl": "%d. %s | %d pts | x%d"
		},
		"finalscore_top_scores": {
			"en": "TOP SCORES",
			"tl": "PINAKAMATAAS NA PUNTOS"
		},
		"finalscore_top_score_row": {
			"en": "%d. Tier %s | %d pts",
			"tl": "%d. Tier %s | %d pts"
		},
		"finalscore_no_rounds_played": {
			"en": "No rounds played.",
			"tl": "Walang round na nalaro."
		},
		"finalscore_summary_legend": {
			"en": "Legend pace. Water saved like a pro!",
			"tl": "Legend ang pacing. Parang pro ang pagtitipid sa tubig!"
		},
		"finalscore_summary_solid": {
			"en": "Solid run. Nice consistency!",
			"tl": "Solid ang run. Maganda ang consistency!"
		},
		"finalscore_summary_good": {
			"en": "Good effort. Keep building combos!",
			"tl": "Magandang effort. Ituloy ang pagbuo ng combos!"
		},
		"finalscore_summary_rough": {
			"en": "Rough run. Bounce back next session!",
			"tl": "Medyo hirap ang run. Bawi sa susunod na session!"
		},
		# The seven keys below were referenced by FinalScore.gd but never defined here.
		# Every call site passes an English fallback, so the English build looked fine
		# and nothing failed — but the Filipino build silently rendered the end-of-run
		# summary in English, and every completed session logged 7 "Missing translation
		# key" warnings. Wording follows the entries already in this table:
		# main_menu → PANGUNAHING MENU, retry → SUBUKAN MULI, difficulty → HIRAP.
		"finalscore_rounds": {
			"en": "Rounds:",
			"tl": "Round:"
		},
		"finalscore_wins": {
			"en": "Wins:",
			"tl": "Panalo:"
		},
		"finalscore_best": {
			"en": "Best:",
			"tl": "Pinakamataas:"
		},
		"finalscore_difficulty": {
			"en": "Difficulty:",
			"tl": "Hirap:"
		},
		"finalscore_main_menu": {
			"en": "MAIN MENU",
			"tl": "PANGUNAHING MENU"
		},
		"finalscore_try_again": {
			"en": "TRY AGAIN",
			"tl": "SUBUKAN MULI"
		},
		"finalscore_all_droplets_lost": {
			"en": "All your droplets evaporated...",
			"tl": "Sumingaw na lahat ng patak mo..."
		},

		# ── Per-minigame intro instruction lines ──
		# Referenced by MiniGameIntroCutscene.gd with English fallbacks, never defined
		# here. Same silent-fallback defect as the finalscore keys above: the one line
		# that tells the player what to do was English-only in the Filipino build, on
		# every one of the 24 games. Wording stays imperative and short — it is on
		# screen for about a second before play starts.
		"intro_instruction_default": {
			"en": "Get ready...",
			"tl": "Maghanda na..."
		},
		"intro_instruction_bucket_brigade": {
			"en": "Pass the buckets!",
			"tl": "Ipasa ang mga timba!"
		},
		"intro_instruction_catch_the_rain": {
			"en": "Tap the falling drops!",
			"tl": "Tapikin ang bumabagsak na patak!"
		},
		"intro_instruction_cloud_catcher": {
			"en": "Catch the clouds for water!",
			"tl": "Saluhin ang ulap para sa tubig!"
		},
		"intro_instruction_cover_the_drum": {
			"en": "Cover it before contamination!",
			"tl": "Takpan bago mahawa!"
		},
		"intro_instruction_droplet_dash": {
			"en": "Guide the droplet to safety!",
			"tl": "Ihatid ang patak sa ligtas na daan!"
		},
		"intro_instruction_filter_builder": {
			"en": "Stack the filter layers!",
			"tl": "Isalansan ang mga layer ng filter!"
		},
		"intro_instruction_fix_leak": {
			"en": "Find and seal the leaks!",
			"tl": "Hanapin at takpan ang tagas!"
		},
		"intro_instruction_greywater_sorter": {
			"en": "Sort the water streams!",
			"tl": "Ihiwalay ang mga daloy ng tubig!"
		},
		"intro_instruction_mud_pie_maker": {
			"en": "Mix the perfect ratio!",
			"tl": "Ihalo sa tamang timpla!"
		},
		"intro_instruction_plug_the_leak": {
			"en": "Plug the pipe fast!",
			"tl": "Bilis, takpan ang tubo!"
		},
		"intro_instruction_quick_shower": {
			"en": "Finish before time runs out!",
			"tl": "Tapusin bago maubos ang oras!"
		},
		"intro_instruction_rice_wash_rescue": {
			"en": "Save the rice water!",
			"tl": "Itabi ang hugas-bigas!"
		},
		"intro_instruction_scrub_to_save": {
			"en": "Scrub smart, not wet!",
			"tl": "Magkuskos ng tama, huwag basang-basa!"
		},
		"intro_instruction_spot_the_speck": {
			"en": "Find all the particles!",
			"tl": "Hanapin ang lahat ng dumi!"
		},
		"intro_instruction_swipe_the_soap": {
			"en": "Swipe fast, save water!",
			"tl": "Bilisan ang swipe, tipid sa tubig!"
		},
		"intro_instruction_thirsty_plant": {
			"en": "Water just the right amount!",
			"tl": "Diligan ng tamang dami!"
		},
		"intro_instruction_timing_tap": {
			"en": "Tap on the beat!",
			"tl": "Tapik sa tamang beat!"
		},
		"intro_instruction_toilet_tank_fix": {
			"en": "Calibrate the flush!",
			"tl": "I-ayos ang tamang flush!"
		},
		"intro_instruction_trace_pipe_path": {
			"en": "Follow the pipe route!",
			"tl": "Sundan ang ruta ng tubo!"
		},
		"intro_instruction_turn_off_tap": {
			"en": "Cut the flow on time!",
			"tl": "Isara ang gripo sa tamang oras!"
		},
		"intro_instruction_vegetable_bath": {
			"en": "Rinse veggies efficiently!",
			"tl": "Banlawan ang gulay nang matipid!"
		},
		"intro_instruction_water_memory": {
			"en": "Match the water pairs!",
			"tl": "Itapat ang magkapareha!"
		},
		"intro_instruction_water_plant": {
			"en": "Water with precision!",
			"tl": "Diligan nang tama!"
		},
		"intro_instruction_wring_it_out": {
			"en": "Squeeze every last drop!",
			"tl": "Pigain ang bawat patak!"
		},

		# ── Per-minigame failure reaction lines ──
		# Referenced by MiniGameBase._get_result_reaction() with English fallbacks and
		# never defined here. These are the short funny failure lines that replaced the
		# bare "FAILED" text, so an untranslated one lands on the single most-read
		# screen in the game. Kept as "what went wrong + what to do", two beats, so the
		# Filipino reads as fast as the English.
		"result_line_fail_default": {
			"en": "Oops! Try a faster rescue next round!",
			"tl": "Aray! Bilisan ang sagip sa susunod!"
		},
		"result_line_fail_bucket_brigade": {
			"en": "Relay broke pace. Move!",
			"tl": "Nawala ang timing. Bilis!"
		},
		"result_line_fail_catch_the_rain": {
			"en": "Rain got away. Track drops!",
			"tl": "Nakatakas ang ulan. Sundan ang patak!"
		},
		"result_line_fail_cloud_catcher": {
			"en": "Rain hit concrete. Aim over the plants!",
			"tl": "Sa semento tumama ang ulan. Ituon sa halaman!"
		},
		"result_line_fail_cover_the_drum": {
			"en": "Drum stayed open. Cover faster!",
			"tl": "Bukas ang drum. Bilisan ang takip!"
		},
		"result_line_fail_filter_builder": {
			"en": "Wrong layer stack. Rebuild!",
			"tl": "Mali ang salansan. Ayusin muli!"
		},
		"result_line_fail_fix_leak": {
			"en": "Leak still live. Seal now!",
			"tl": "Tumutulo pa. Takpan na!"
		},
		"result_line_fail_greywater_sorter": {
			"en": "Wrong route. Sort cleaner!",
			"tl": "Maling ruta. Ayusin ang hatian!"
		},
		"result_line_fail_mud_pie_maker": {
			"en": "Mix missed. Steady hands!",
			"tl": "Sablay ang timpla. Steady lang!"
		},
		"result_line_fail_plug_the_leak": {
			"en": "Plug missed. Line it up!",
			"tl": "Sablay ang takip. Itapat!"
		},
		"result_line_fail_quick_shower": {
			"en": "Shower too long. Speed run!",
			"tl": "Sobrang tagal maligo. Bilisan!"
		},
		"result_line_fail_rainwater_harvesting": {
			"en": "Harvest missed. Reposition!",
			"tl": "Sablay ang huli. Iwasto ang puwesto!"
		},
		"result_line_fail_rice_wash_rescue": {
			"en": "Rice water spilled. Retry!",
			"tl": "Natapon ang hugas-bigas. Ulitin!"
		},
		"result_line_fail_scrub_to_save": {
			"en": "Scrub wasted water. Stay tight!",
			"tl": "Nasayang ang tubig sa kuskos. Higpitan!"
		},
		"result_line_fail_spot_the_speck": {
			"en": "Speck missed. Scan sharper!",
			"tl": "May nalampasang dumi. Tingnan pa!"
		},
		"result_line_fail_swipe_the_soap": {
			"en": "Swipe too slow. Clean cut!",
			"tl": "Mabagal ang swipe. Bilisan!"
		},
		"result_line_fail_thirsty_plant": {
			"en": "Watering off-balance. Re-aim!",
			"tl": "Hindi tama ang dilig. Ituon muli!"
		},
		"result_line_fail_timing_tap": {
			"en": "Timing off. Tap on beat!",
			"tl": "Sablay ang timing. Sabayan ang beat!"
		},
		"result_line_fail_toilet_tank_fix": {
			"en": "Tank unstable. Retune it!",
			"tl": "Hindi tama ang tangke. Ayusin muli!"
		},
		"result_line_fail_trace_pipe_path": {
			"en": "Route drifted. Follow flow!",
			"tl": "Lumihis ang ruta. Sundan ang daloy!"
		},
		"result_line_fail_turn_off_tap": {
			"en": "Tap stayed on. Cut early!",
			"tl": "Bukas pa ang gripo. Isara agad!"
		},
		"result_line_fail_vegetable_bath": {
			"en": "Too much rinse. One-pass next!",
			"tl": "Sobra ang banlaw. Isang pass na lang!"
		},
		"result_line_fail_water_plant": {
			"en": "Watering off. Find the sweet spot!",
			"tl": "Sablay ang dilig. Hanapin ang tama!"
		},
		"result_line_fail_wring_it_out": {
			"en": "Still dripping. Wring harder!",
			"tl": "Tumutulo pa. Pigain pa!"
		},

		# ── Per-minigame success reaction lines ──
		# The win-side twins of the failure block above, referenced by the same
		# MiniGameBase._get_result_line_for_key() with English fallbacks. Every one was
		# missing here, so the Filipino build showed English on the round score page for
		# every win -- the exact defect the failure block's comment describes, on the
		# more common outcome of the two. Same two-beat shape: what went right, then the
		# water point it proves.
		"result_line_success_default": {
			"en": "Clean save! Keep it flowing!",
			"tl": "Malinis na sagip! Ituloy lang!"
		},
		"result_line_success_bucket_brigade": {
			"en": "Relay complete. Team flow secured!",
			"tl": "Kumpleto ang relay. Ayos ang takbo ng grupo!"
		},
		"result_line_success_catch_the_rain": {
			"en": "Rain caught clean. Tanks up!",
			"tl": "Malinis ang huli sa ulan. Puno ang tangke!"
		},
		"result_line_success_cloud_catcher": {
			"en": "Rain landed on roots. Free water, zero waste!",
			"tl": "Sa ugat bumagsak ang ulan. Libreng tubig, walang sayang!"
		},
		"result_line_success_cover_the_drum": {
			"en": "Drum covered in time. Great reflex!",
			"tl": "Natakpan agad ang drum. Bilis mo!"
		},
		"result_line_success_filter_builder": {
			"en": "Filter stack built like a pro!",
			"tl": "Tama sa tama ang salansan ng filter!"
		},
		"result_line_success_fix_leak": {
			"en": "Leak fixed fast. Flow restored!",
			"tl": "Agad naayos ang tagas. Ayos na ang daloy!"
		},
		"result_line_success_greywater_sorter": {
			"en": "Greywater routed to the right use!",
			"tl": "Tamang gamit ang inulit na tubig!"
		},
		"result_line_success_mud_pie_maker": {
			"en": "Mud mix perfect. Zero waste vibes!",
			"tl": "Tamang-tama ang timpla. Walang sayang!"
		},
		"result_line_success_plug_the_leak": {
			"en": "Pipe plugged. Waste stopped cold!",
			"tl": "Nasarhan ang tubo. Tigil ang sayang!"
		},
		"result_line_success_quick_shower": {
			"en": "Quick shower run. Big water saved!",
			"tl": "Bilis na shower. Laking tipid!"
		},
		"result_line_success_rainwater_harvesting": {
			"en": "Harvest complete. Rain put to work!",
			"tl": "Kumpleto ang huli. Napakinabangan ang ulan!"
		},
		"result_line_success_rice_wash_rescue": {
			"en": "Rice water saved. Smart kitchen move!",
			"tl": "Nasalba ang hugas-bigas. Galing sa kusina!"
		},
		"result_line_success_scrub_to_save": {
			"en": "Scrub done water-wise. Spotless!",
			"tl": "Kuskos na matipid. Kinis na kinis!"
		},
		"result_line_success_spot_the_speck": {
			"en": "All impurities spotted. Crystal clear!",
			"tl": "Nakita lahat ng dumi. Linaw na linaw!"
		},
		"result_line_success_swipe_the_soap": {
			"en": "Soap swipe efficiency unlocked!",
			"tl": "Tipid sa sabon. Ayos ang swipe!"
		},
		"result_line_success_thirsty_plant": {
			"en": "Plant hydrated with just enough water!",
			"tl": "Nadiligan ang halaman sa tamang dami!"
		},
		"result_line_success_timing_tap": {
			"en": "Tap timing nailed. Zero extra drip!",
			"tl": "Tumpak ang timing. Walang tulo!"
		},
		"result_line_success_toilet_tank_fix": {
			"en": "Tank tuned right. No excess flush!",
			"tl": "Tama ang tangke. Walang sobrang flush!"
		},
		"result_line_success_trace_pipe_path": {
			"en": "Path traced clean. Nice routing!",
			"tl": "Malinis ang ruta. Ayos ang daloy!"
		},
		"result_line_success_turn_off_tap": {
			"en": "Tap shut off right on cue!",
			"tl": "Sakto ang pagsara ng gripo!"
		},
		"result_line_success_vegetable_bath": {
			"en": "Veggies cleaned with one smart rinse!",
			"tl": "Isang banlaw lang, linis na ang gulay!"
		},
		"result_line_success_water_plant": {
			"en": "Perfect pour. Happy roots!",
			"tl": "Tamang buhos. Masaya ang ugat!"
		},
		"result_line_success_wring_it_out": {
			"en": "Nice squeeze. Every drop counted!",
			"tl": "Ayos ang piga. Walang patak na sayang!"
		},

		# ── Per-game narrative copy (intro / win / fail) ──
		# The three-beat comic lines held in MiniGameBase._get_narratives(). They reach
		# the player on the intro screen and on the round score page, where the narrative
		# is preferred over the short result_line_* twins above -- so before these existed
		# the score page was English in the Filipino build for all 24 games, win and lose,
		# AND the narrative shadowed every result_line_* key at the same time. The "en"
		# side must stay byte-identical to the literal in _get_narratives() (asserted by
		# tools/VerifyResultCopy.tscn); the Filipino keeps the same beat count so the
		# comic timing survives translation.
		"narrative_rice_wash_rescue_intro": {
			"en": "Nanay is washing rice. The rice water is gold. It is also running down the drain.",
			"tl": "Naghuhugas ng bigas si Nanay. Ginto ang hugas-bigas. Pero patungo sa kanal."
		},
		"narrative_rice_wash_rescue_win": {
			"en": "Basin full of precious starchy water. The plants are about to be very happy.",
			"tl": "Punong-puno ang planggana ng hugas-bigas. Matutuwa nang bongga ang mga halaman."
		},
		"narrative_rice_wash_rescue_fail": {
			"en": "The pot zigs, you zag. The rice water hits the drain. A single grain of rice rolls away in disappointment.",
			"tl": "Umiwas ang kaldero, iba ang iwas mo. Sa kanal napunta ang hugas-bigas. May isang butil ng bigas na gumulong palayo sa lungkot."
		},
		"narrative_vegetable_bath_intro": {
			"en": "Dirty vegetables. One wash bowl. A very particular basket system.",
			"tl": "Maruming gulay. Isang planggana. At isang napakapihikang sistema ng basket."
		},
		"narrative_vegetable_bath_win": {
			"en": "All veggies clean and sorted. Dinner is saved. Someone says \"you're actually useful.\"",
			"tl": "Linis lahat ng gulay, tama ang basket. Salbado ang hapunan. May nagsabing \"may pakinabang ka pala.\""
		},
		"narrative_vegetable_bath_fail": {
			"en": "You throw a dirty carrot directly into the clean basket. Cross-contamination achieved. Dinner is canceled. The carrot is ashamed.",
			"tl": "Binato mo ang maruming karot sa malinis na basket. Nahawa ang lahat. Kanselado ang hapunan. Nahihiya ang karot."
		},
		"narrative_greywater_sorter_intro": {
			"en": "Two buckets. One for the garden. One for the drain. The water doesn't know the difference.",
			"tl": "Dalawang timba. Isa sa halamanan. Isa sa kanal. Walang alam ang tubig sa pinagkaiba."
		},
		"narrative_greywater_sorter_win": {
			"en": "Every bucket sorted. The garden blooms. The drain thanks you for not dumping soap on it.",
			"tl": "Tama lahat ng hatian. Namumukadkad ang halamanan. Nagpapasalamat ang kanal na hindi mo binuhusan ng sabon."
		},
		"narrative_greywater_sorter_fail": {
			"en": "Soapy water hits the tomatoes. They wilt in real time. The garden dies. The tomatoes had a name.",
			"tl": "Tumama ang sabon sa kamatis. Nalanta agad sa harap mo. Patay ang halamanan. May pangalan pa ang kamatis na iyon."
		},
		"narrative_wring_it_out_intro": {
			"en": "Wet laundry. A basin below. Physics awaiting.",
			"tl": "Basang labada. Planggana sa ilalim. Naghihintay ang pisika."
		},
		"narrative_wring_it_out_win": {
			"en": "Basin full, clothes dry enough. The water goes to the garden. The clothes go on the line.",
			"tl": "Puno ang planggana, tuyo na ang damit. Sa halamanan ang tubig. Sa sampayan ang damit."
		},
		"narrative_wring_it_out_fail": {
			"en": "You tap too slowly. The clothes drip-dry on the floor instead. The basin has three drops in it. The garden sulks.",
			"tl": "Mabagal ang piga mo. Sa sahig na lang tumulo ang damit. Tatlong patak lang ang laman ng planggana. Nagtampo ang halamanan."
		},
		"narrative_thirsty_plant_intro": {
			"en": "Three buckets. One is the green one. You will second-guess yourself.",
			"tl": "Tatlong timba. Berde ang isa. Magdadalawang-isip ka talaga."
		},
		"narrative_thirsty_plant_win": {
			"en": "Correct bucket. The plant gets watered. It grows noticeably. It seems grateful.",
			"tl": "Tamang timba. Nadiligan ang halaman. Halatang tumangkad. Mukhang nagpapasalamat."
		},
		"narrative_thirsty_plant_fail": {
			"en": "Wrong bucket. You pour fertilizer directly on the plant's face. It recoils. The real green bucket watches silently.",
			"tl": "Maling timba. Pataba ang binuhos mo sa mukha ng halaman. Napaurong ito. Tahimik lang ang tunay na berdeng timba."
		},
		"narrative_mud_pie_maker_intro": {
			"en": "Children want mud pies. You have water. The gauge has opinions.",
			"tl": "Gusto ng mga bata ng mud pie. May tubig ka. May opinyon ang gauge."
		},
		"narrative_mud_pie_maker_win": {
			"en": "Perfect consistency. The mud pie is structurally sound. A child somewhere is delighted. You feel strangely proud.",
			"tl": "Tamang-tama ang timpla. Matibay ang mud pie. May batang sobrang tuwa. Bigla kang naproud sa sarili mo."
		},
		"narrative_mud_pie_maker_fail": {
			"en": "Too much water. The mud pie is now mud soup. It collapses immediately. The child is not delighted. You have failed mud.",
			"tl": "Sobrang tubig. Mud soup na ang mud pie. Gumuho agad. Hindi natuwa ang bata. Bumagsak ka sa putik."
		},
		"narrative_catch_the_rain_intro": {
			"en": "The clouds finally show up. You have one drum. Gravity is merciless.",
			"tl": "Sumipot din ang ulap. Isang drum lang ang meron ka. Walang awa ang grabidad."
		},
		"narrative_catch_the_rain_win": {
			"en": "The drum overflows with glory. A tiny rainbow forms. You take a bow.",
			"tl": "Umapaw ang drum sa tagumpay. May maliit na bahagharing lumitaw. Yumukod ka pa."
		},
		"narrative_catch_the_rain_fail": {
			"en": "You chase a red drop \"just to see.\" The drum fills with mystery liquid. A plant nearby dies on the spot.",
			"tl": "Hinabol mo ang pulang patak \"para lang makita.\" Napuno ang drum ng misteryosong likido. May halamang namatay agad sa tabi."
		},
		"narrative_cover_the_drum_intro": {
			"en": "Standing water. Mosquitoes circling. They look personally offended.",
			"tl": "Tubig na hindi umaagos. Lumilibot ang lamok. Mukhang personal na ang tampo nila."
		},
		"narrative_cover_the_drum_win": {
			"en": "Every drum sealed. The mosquitoes hold a sad little funeral. The water is safe.",
			"tl": "Takip lahat ng drum. May maliit at malungkot na lamay ang mga lamok. Ligtas ang tubig."
		},
		"narrative_cover_the_drum_fail": {
			"en": "You miss one drum. Within seconds, a mosquito the size of a fist has claimed it as a condo. The water is lost. So is your dignity.",
			"tl": "Isang drum ang nakalimutan mo. Segundo lang, may lamok na kalaki ng kamao na nag-condo na doon. Wala na ang tubig. Wala na rin ang dangal mo."
		},
		"narrative_spot_the_speck_intro": {
			"en": "A row of water glasses. Some clean. Some containing things that should not be in water.",
			"tl": "Hanay ng basong tubig. May malinis. May may-lamang hindi dapat nandoon."
		},
		"narrative_spot_the_speck_win": {
			"en": "Perfect record. You are basically a water-quality inspector now. Add it to your resume.",
			"tl": "Walang mintis. Water inspector ka na talaga. Isama mo na sa resume."
		},
		"narrative_spot_the_speck_fail": {
			"en": "You approve the glass with a visible something floating in it. Someone drinks it. You don't want to know what happens next.",
			"tl": "Pinayagan mo ang basong may lumulutang na kung ano. May uminom. Huwag na nating alamin ang susunod."
		},
		"narrative_fix_leak_intro": {
			"en": "The pipe is leaking. Dramatically. Personally.",
			"tl": "Tumutulo ang tubo. Sobrang drama. Parang may galit sa iyo."
		},
		"narrative_fix_leak_win": {
			"en": "The pipe is sealed. Silence. Peace. A single drip salutes you.",
			"tl": "Sarado na ang tubo. Katahimikan. Kapayapaan. May isang patak na sumaludo."
		},
		"narrative_fix_leak_fail": {
			"en": "You plug one, three more burst open. The room is now a splash park. The water bill is catastrophic.",
			"tl": "Isang tinakpan, tatlo ang sumabog. Splash park na ang kuwarto. Katakot-takot ang water bill."
		},
		"narrative_water_plant_intro": {
			"en": "A shelf of plants, all quietly dehydrating. None of them will say anything.",
			"tl": "Isang istante ng halaman, tahimik na nauuhaw. Wala isa mang magsasabi sa iyo."
		},
		"narrative_water_plant_win": {
			"en": "Every plant still standing. Nobody drowned, nobody wilted. The shelf looks smug.",
			"tl": "Buhay pa lahat ng halaman. Walang nalunod, walang nalanta. Mukhang mayabang na ang istante."
		},
		"narrative_water_plant_fail": {
			"en": "One plant crisps up while you flood the one beside it. You have somehow overwatered AND underwatered the same shelf. The survivors are taking notes.",
			"tl": "May halamang natuyot habang binabaha mo ang katabi. Nasobrahan AT nakulangan mo ang parehong istante. Nagtatala ang mga nakaligtas."
		},
		"narrative_plug_the_leak_intro": {
			"en": "Pipes with holes. One thumb. Hold and hope.",
			"tl": "Butas-butas na tubo. Isang hinlalaki. Hawakan at magdasal."
		},
		"narrative_plug_the_leak_win": {
			"en": "Every leak held shut until the pressure dropped. Barely a litre lost. Your thumb is a hero.",
			"tl": "Sarado lahat ng tagas hanggang humupa ang presyon. Halos walang litrong nasayang. Bayani ang hinlalaki mo."
		},
		"narrative_plug_the_leak_fail": {
			"en": "You let go early and the pipe rediscovers freedom. A hundred litres later the floor is a wading pool. The pipe seems happier than you.",
			"tl": "Bumitaw ka agad at nakawala ang tubo. Isang daang litro ang lumipas, wading pool na ang sahig. Mukhang mas masaya ang tubo kaysa sa iyo."
		},
		"narrative_swipe_the_soap_intro": {
			"en": "Handwashing. Quick. Purposeful. The soap has opinions.",
			"tl": "Paghuhugas ng kamay. Bilis. May direksyon. May opinyon ang sabon."
		},
		"narrative_swipe_the_soap_win": {
			"en": "Clean hands. Minimal water. The soap bar is impressed.",
			"tl": "Malinis ang kamay. Konting tubig lang. Impressed ang sabon."
		},
		"narrative_swipe_the_soap_fail": {
			"en": "You swipe wrong. The soap flies off the screen. You rinse with the tap full open for 30 seconds. The soap lands somewhere outside.",
			"tl": "Mali ang swipe. Lumipad ang sabon palabas ng screen. Tatlumpung segundong bukas na gripo ang pinambanlaw mo. Nasa labas pa rin ang sabon."
		},
		"narrative_quick_shower_intro": {
			"en": "A shower that runs forever. A water meter that cries.",
			"tl": "Shower na walang katapusan. Metrong umiiyak na."
		},
		"narrative_quick_shower_win": {
			"en": "Precise stop. Clean. Efficient. The water meter gives a thumbs up.",
			"tl": "Tumpak ang hinto. Malinis. Matipid. Thumbs up ang metro."
		},
		"narrative_quick_shower_fail": {
			"en": "You overshoot. The shower runs another 45 minutes. The meter explodes. You're clean but the planet is not.",
			"tl": "Nalampasan mo. Apatnapu't limang minuto pang tumakbo ang shower. Sumabog ang metro. Malinis ka, pero hindi ang planeta."
		},
		"narrative_filter_builder_intro": {
			"en": "The water is brown. Very brown. Suspiciously brown.",
			"tl": "Kayumanggi ang tubig. Sobrang kayumanggi. Nakakadudang kayumanggi."
		},
		"narrative_filter_builder_win": {
			"en": "Sparkling clean water pours out. A child somewhere drinks it gratefully. You are basically a hero.",
			"tl": "Kumikinang na tubig ang lumabas. May batang uminom nang may pasasalamat. Bayani ka na, in fairness."
		},
		"narrative_filter_builder_fail": {
			"en": "Wrong order. The dirt comes out worse. It looks like gravy. No one is drinking that.",
			"tl": "Maling salansan. Lumala pa ang dumi. Parang sarsa na ang itsura. Walang iinom niyan."
		},
		"narrative_toilet_tank_fix_intro": {
			"en": "The toilet is running. Constantly. It's been running since Tuesday.",
			"tl": "Tumatakbo ang inodoro. Walang tigil. Simula pa noong Martes."
		},
		"narrative_toilet_tank_fix_win": {
			"en": "Tank filled correctly. The phantom flush stops. Peace returns to the household.",
			"tl": "Tamang laman ng tangke. Tigil na ang kusang-flush. Bumalik ang kapayapaan sa bahay."
		},
		"narrative_toilet_tank_fix_fail": {
			"en": "Overfilled. The tank overflows into the bowl into the floor into your problems. The Tuesday leak was less bad.",
			"tl": "Sobra ang laman. Umapaw ang tangke sa bowl, sa sahig, sa problema mo. Mas maganda pa ang tagas noong Martes."
		},
		"narrative_trace_pipe_path_intro": {
			"en": "The pipe is broken. Water is going to the wrong neighborhood.",
			"tl": "Sira ang tubo. Sa ibang baryo napupunta ang tubig."
		},
		"narrative_trace_pipe_path_win": {
			"en": "Pipe connected. Water flows true. The neighborhood cheers.",
			"tl": "Konektado na ang tubo. Tama ang daloy. Nagsaya ang buong baryo."
		},
		"narrative_trace_pipe_path_fail": {
			"en": "You draw off-path. Water detours through the kitchen ceiling. Everyone in the house gets an unexpected shower.",
			"tl": "Lumihis ang guhit mo. Dumaan ang tubig sa kisame ng kusina. Libreng shower ang lahat sa bahay."
		},
		"narrative_scrub_to_save_intro": {
			"en": "One dirty dish. One mission. Use as little water as possible.",
			"tl": "Isang maruming plato. Isang misyon. Kaunting tubig lang."
		},
		"narrative_scrub_to_save_win": {
			"en": "Spotless dish. Minimum water used. The dish sparkles. A fork nearby applauds.",
			"tl": "Kinang na kinang ang plato. Konting tubig lang ang nagamit. May tinidor na pumalakpak."
		},
		"narrative_scrub_to_save_fail": {
			"en": "You scrub in panic. The gauge drains dry. The dish is still dirty AND you wasted water. The dish does not sparkle. It judges you.",
			"tl": "Nagpanic ka sa kuskos. Naubos ang gauge. Marumi pa rin ang plato AT nasayang ang tubig. Hindi kumikinang. Nanghuhusga."
		},
		"narrative_bucket_brigade_intro": {
			"en": "A line of people. One bucket. A very thirsty plant at the end.",
			"tl": "Hanay ng tao. Isang timba. At isang uhaw na halaman sa dulo."
		},
		"narrative_bucket_brigade_win": {
			"en": "The plant gets water. Everyone high-fives. Someone shouts \"TEAMWORK!\" unironically.",
			"tl": "Nadiligan ang halaman. High-five ang lahat. May sumigaw ng \"TEAMWORK!\" nang seryosong-seryoso."
		},
		"narrative_bucket_brigade_fail": {
			"en": "You tap too slow. The third person in line sits down and eats a sandwich. The bucket goes nowhere. The plant writes a strongly worded letter.",
			"tl": "Mabagal ang tapik mo. Umupo ang pangatlo sa hanay at kumain ng sandwich. Hindi umusad ang timba. Nagsulat ng reklamo ang halaman."
		},
		"narrative_timing_tap_intro": {
			"en": "A tap. A container. A line that means \"enough.\"",
			"tl": "Isang gripo. Isang lalagyan. At isang guhit na ang ibig sabihin ay \"tama na.\""
		},
		"narrative_timing_tap_win": {
			"en": "Perfect fill. Not a drop over. The container does a little shimmy.",
			"tl": "Tamang-tamang laman. Walang sobrang patak. May maliit na kembot ang lalagyan."
		},
		"narrative_timing_tap_fail": {
			"en": "You hold too long. It overflows spectacularly. The floor is now a small lake. The target line is underwater.",
			"tl": "Sobrang tagal ng hawak. Umapaw nang bongga. Maliit na lawa na ang sahig. Nasa ilalim ng tubig ang guhit."
		},
		"narrative_turn_off_tap_intro": {
			"en": "Multiple faucets. All running. Nobody knows why.",
			"tl": "Maraming gripo. Bukas lahat. Walang nakakaalam kung bakit."
		},
		"narrative_turn_off_tap_win": {
			"en": "All taps off. Silence. The water bill sighs with relief.",
			"tl": "Sarado lahat ng gripo. Katahimikan. Huminga na ang water bill."
		},
		"narrative_turn_off_tap_fail": {
			"en": "You can't keep up. Every tap you close, another opens in protest. The house is now a fountain. It's actually kind of beautiful. But wrong.",
			"tl": "Hindi mo naabot lahat. Kada isara mo, may bagong bumubukas na protesta. Fountain na ang bahay. Maganda, actually. Pero mali."
		},
		"narrative_cloud_catcher_intro": {
			"en": "Clouds drift past carrying free water. The plants below are extremely aware of this.",
			"tl": "Dumadaan ang ulap na may dalang libreng tubig. Alam na alam ito ng mga halaman sa ilalim."
		},
		"narrative_cloud_catcher_win": {
			"en": "Every plant soaked straight from the sky. The clouds float off empty and smug. Not one drop of tap water spent.",
			"tl": "Basang-basa lahat ng halaman, galing mismo sa langit. Umalis ang ulap na walang laman at mayabang. Walang isang patak na galing sa gripo."
		},
		"narrative_cloud_catcher_fail": {
			"en": "You pop the clouds over bare concrete. The rain hits pavement, steams off, and is gone. The plants are still thirsty, and now they're judging you.",
			"tl": "Sa hubad na semento mo pinatak ang ulan. Tumama sa aspalto, umusok, tapos wala na. Uhaw pa rin ang halaman, at nanghuhusga na sila."
		},
		"narrative_water_memory_intro": {
			"en": "Water-saving tips are flashing on cards. They vanish. Your brain says \"I got this.\"",
			"tl": "Kumikislap ang mga tip sa pagtitipid ng tubig. Nawala. Sabi ng utak mo, \"kaya ko ito.\""
		},
		"narrative_water_memory_win": {
			"en": "All pairs matched. The tips are now burned into your brain. You will never run a tap unnecessarily again.",
			"tl": "Tugma lahat ng pares. Nakaukit na sa utak mo ang mga tip. Hinding-hindi ka na magbubukas ng gripo nang walang dahilan."
		},
		"narrative_water_memory_fail": {
			"en": "You flip the wrong card every time. The cards start to look identical. You match \"Don't waste water\" with \"Turtle.\" That is not a pair.",
			"tl": "Puro maling kard ang binaliktad mo. Nagkamukha na ang lahat. Tinugma mo ang \"Huwag sayangin ang tubig\" sa \"Pagong.\" Hindi iyon pares."
		},
		"narrative_droplet_dash_intro": {
			"en": "Water droplets are escaping. They are faster than you. They know this.",
			"tl": "Tumatakas ang mga patak ng tubig. Mabilis pa sila sa iyo. At alam nila iyon."
		},
		"narrative_droplet_dash_win": {
			"en": "Every drop caught. The droplets look betrayed. You did good.",
			"tl": "Nasalo lahat ng patak. Parang nagtampo ang mga patak. Ayos ang ginawa mo."
		},
		"narrative_droplet_dash_fail": {
			"en": "The last droplet waves goodbye. The whole glass is empty. You're thirsty and it's your fault.",
			"tl": "Kumaway paalam ang huling patak. Wala nang laman ang baso. Uhaw ka, at kasalanan mo."
		},

		# ── Roadmap screen tabs ──
		# Mode names stay as loanwords in Filipino because this table already made that
		# call for "multiplayer" (line ~38), and Filipino players use both terms as-is.
		# Defined explicitly so the choice is deliberate rather than a missing-key
		# fallback that happens to produce the same string.
		"roadmap_tab_singleplayer": {
			"en": "🎮 Single Player",
			"tl": "🎮 Single Player"
		},
		"roadmap_tab_multiplayer": {
			"en": "🤝 Multiplayer",
			"tl": "🤝 Multiplayer"
		},
		
		"difficulty_text": {
			"en": (
				"The game adapts to your skill level! Play well "
				+ "and face harder challenges. Struggle a bit and "
				+ "get easier tasks."
			),
			"tl": (
				"Ang laro ay umaangkop sa iyong kakayahan! "
				+ "Maglaro nang mabuti at haharapin ang mas "
				+ "mahihirap na hamon. Kung nahihirapan ka, "
				+ "magiging mas madali ang mga gawain."
			)
		},
		"post_test": {
			"en": "📝 POST-TEST",
			"tl": "📝 PAGSUSULIT"
		},
		"post_test_text": {
			"en": (
				"After completing games, take a knowledge test "
				+ "to see how much you learned!"
			),
			"tl": (
				"Pagkatapos maglaro, kumuha ng pagsusulit "
				+ "upang makita kung gaano karami ang iyong "
				+ "natutunan!"
			)
		},
		"water_tips": {
			"en": "💧 WATER TIPS",
			"tl": "💧 MGA TIPS SA TUBIG"
		},
		"water_tips_text": {
			"en": (
				"• Use watering cans instead of hoses\n"
				+ "• Fix leaks immediately\n"
				+ "• Time your showers\n"
				+ "• Use buckets wisely\n"
				+ "• Turn off taps when not in use"
			),
			"tl": (
				"• Gumamit ng regadera kaysa hose\n"
				+ "• Ayusin kaagad ang mga tumatagos\n"
				+ "• Magpaligo nang mabilis\n"
				+ "• Gumamit ng timba nang maayos\n"
				+ "• Isara ang gripo kapag hindi ginagamit"
			)
		},
		
		# Mini-game Results
		"perfect": {
			"en": "🌟 PERFECT!",
			"tl": "🌟 PERPEKTO!"
		},
		"success": {
			"en": "🎉 SUCCESS!",
			"tl": "🎉 TAGUMPAY!"
		},
		"complete": {
			"en": "✅ COMPLETE",
			"tl": "✅ KUMPLETO"
		},
		"accuracy": {
			"en": "Accuracy",
			"tl": "Katumpakan"
		},
		"time": {
			"en": "Time",
			"tl": "Oras"
		},
		"mistakes": {
			"en": "Mistakes",
			"tl": "Mga Mali"
		},
		"difficulty_level": {
			"en": "Difficulty",
			"tl": "Hirap"
		},
		"continue": {
			"en": "➡️ CONTINUE",
			"tl": "➡️ MAGPATULOY"
		},
		"retry": {
			"en": "🔄 RETRY",
			"tl": "🔄 SUBUKAN MULI"
		},
		"mini_results_you_earned": {
			"en": "YOU EARNED",
			"tl": "NANALO KA NG"
		},
		"mini_results_accuracy_line": {
			"en": "%s: %.0f%%",
			"tl": "%s: %.0f%%"
		},
		"mini_results_time_line": {
			"en": "%s: %.1fs",
			"tl": "%s: %.1fs"
		},
		"mini_results_mistakes_line": {
			"en": "%s: %d",
			"tl": "%s: %d"
		},
		"mini_results_difficulty_line": {
			"en": "%s: %s",
			"tl": "%s: %s"
		},
		"mini_results_accuracy_caps": {
			"en": "%s  %.0f%%",
			"tl": "%s  %.0f%%"
		},
		"mini_results_mistakes_caps": {
			"en": "%s  %d",
			"tl": "%s  %d"
		},
		"outcome_nice": {
			"en": "NICE!",
			"tl": "AYOS!"
		},
		"outcome_oops": {
			"en": "OOPS!",
			"tl": "NAKU!"
		},
		"cutscene_scene_complete": {
			"en": "Scene Complete",
			"tl": "Tapos ang Eksena"
		},
		"cutscene_scene_failed": {
			"en": "Scene Failed",
			"tl": "Bigo ang Eksena"
		},
		"cutscene_outro_stats": {
			"en": "+%d pts   |   Combo x%d   |   Lives %s",
			"tl": "+%d pts   |   Combo x%d   |   Buhay %s"
		},
		
		# Difficulty Levels
		"easy": {
			"en": "Easy",
			"tl": "Madali"
		},
		"medium": {
			"en": "Medium",
			"tl": "Katamtaman"
		},
		"hard": {
			"en": "Hard",
			"tl": "Mahirap"
		},
		
		# Post-Test
		"knowledge_assessment": {
			"en": "📝 Knowledge Assessment",
			"tl": "📝 Pagsusulit sa Kaalaman"
		},
		"question_of": {
			"en": "Question %d of %d",
			"tl": "Tanong %d ng %d"
		},
		"posttest_timer": {
			"en": "⏱️ Time: %d:%02d",
			"tl": "⏱️ Oras: %d:%02d"
		},
		
		# Post-Test Results
		"test_results": {
			"en": "🎓 Test Results",
			"tl": "🎓 Resulta ng Pagsusulit"
		},
		"excellent": {
			"en": "⭐⭐⭐ EXCELLENT!",
			"tl": "⭐⭐⭐ NAPAKAHUSAY!"
		},
		"very_good": {
			"en": "⭐⭐ VERY GOOD!",
			"tl": "⭐⭐ NAPAKAGALING!"
		},
		"good": {
			"en": "⭐ GOOD",
			"tl": "⭐ MAGALING"
		},
		"passing": {
			"en": "✔ PASSING",
			"tl": "✔ PUMASA"
		},
		"needs_improvement": {
			"en": "📚 NEEDS IMPROVEMENT",
			"tl": "📚 KAILANGAN NG PAGPAPABUTI"
		},
		"conceptual": {
			"en": "📚 Conceptual",
			"tl": "📚 Konsepto"
		},
		"application": {
			"en": "🔧 Application",
			"tl": "🔧 Paggamit"
		},
		"retention": {
			"en": "🧠 Retention",
			"tl": "🧠 Pagkakaalala"
		},
		"behavioral": {
			"en": "🎮 Behavioral",
			"tl": "🎮 Pag-uugali"
		},
		"research_validation": {
			"en": "📊 Research Validation",
			"tl": "📊 Pagpapatunay ng Pananaliksik"
		},
		"gameplay_performance": {
			"en": "Gameplay Performance",
			"tl": "Performance sa Laro"
		},
		"knowledge_score": {
			"en": "Knowledge Score",
			"tl": "Marka sa Kaalaman"
		},
		"correlation": {
			"en": "Correlation (r)",
			"tl": "Ugnayan (r)"
		},
		# Replaces "correlation" on the posttest screen. The value shown there is one
		# participant's gameplay score compared against their own knowledge score, not
		# a coefficient over a sample, so it must not be labelled r. The old key is
		# kept because save files and screenshots from earlier builds reference it.
		"knowledge_alignment": {
			"en": "Gameplay/Knowledge Match",
			"tl": "Tugma ng Laro at Kaalaman"
		},
		"posttest_gameplay_performance_line": {
			"en": "%s: %d%%",
			"tl": "%s: %d%%"
		},
		"posttest_knowledge_score_line": {
			"en": "%s: %d%%",
			"tl": "%s: %d%%"
		},
		"posttest_correlation_line": {
			"en": "%s: %s",
			"tl": "%s: %s"
		},
		"posttest_alignment_line": {
			"en": "%s: %s",
			"tl": "%s: %s"
		},
		"posttest_interpretation_line": {
			"en": "Interpretation: %s",
			"tl": "Interpretasyon: %s"
		},
		"export_data": {
			"en": "📁 EXPORT DATA",
			"tl": "📁 I-EXPORT ANG DATA"
		},
		"main_menu": {
			"en": "🏠 MAIN MENU",
			"tl": "🏠 PANGUNAHING MENU"
		},
		"data_exported": {
			"en": "✅ Data exported successfully!",
			"tl": "✅ Matagumpay na na-export ang data!"
		},
		
		# Loading Screen
		"loading": {
			"en": "Loading...",
			"tl": "Naglo-load..."
		},
		"get_ready": {
			"en": "Get Ready!",
			"tl": "Maghanda!"
		},
		
		# Character Customization
		"character_customization": {
			"en": "👤 Character Customization",
			"tl": "👤 Pag-customize ng Character"
		},
		"coming_soon": {
			"en": "(Coming Soon)",
			"tl": "(Malapit Na)"
		},
		"apply_look": {
			"en": "APPLY LOOK",
			"tl": "I-APPLY ANG LOOK"
		},
		"character_status_pick_apply": {
			"en": "Pick a character, equip accessories, then apply.",
			"tl": "Pumili ng character, lagyan ng accessory, tapos i-apply."
		},
		"character_accessory_of": {
			"en": "%s's Accessory: %s",
			"tl": "Accessory ni %s: %s"
		},
		"character_ready_customize": {
			"en": "%s - Ready to customise",
			"tl": "%s - Handa nang i-customize"
		},
		"character_unlock_in_shop": {
			"en": "Unlock %s in the Shop first",
			"tl": "I-unlock muna si %s sa Shop"
		},
		"character_locked_buy_shop": {
			"en": "%s - Locked (buy in Shop first)",
			"tl": "%s - Naka-lock (bilhin muna sa Shop)"
		},
		"character_unlock_first": {
			"en": "Unlock %s first!",
			"tl": "I-unlock muna si %s!"
		},
		"character_buy_accessory_first": {
			"en": "Buy this accessory in the Shop first!",
			"tl": "Bilhin muna ang accessory na ito sa Shop!"
		},
		"character_now_wears": {
			"en": "%s now wears %s!",
			"tl": "Suot na ngayon ni %s ang %s!"
		},
		"character_locked_buy_first": {
			"en": "Character is locked. Buy it in the Shop first.",
			"tl": "Naka-lock ang character. Bilhin muna ito sa Shop."
		},
		"character_saved_main": {
			"en": "Saved! %s will appear on the main screen.",
			"tl": "Naka-save! Lalabas si %s sa main screen."
		},
		"character_name_droppy_blue": {
			"en": "Droppy",
			"tl": "Droppy"
		},
		"character_name_pinky": {
			"en": "Pinky",
			"tl": "Pinky"
		},
		"character_name_minty": {
			"en": "Minty",
			"tl": "Minty"
		},
		"character_name_sunny": {
			"en": "Sunny",
			"tl": "Sunny"
		},
		"character_name_lavvy": {
			"en": "Lavvy",
			"tl": "Lavvy"
		},
		"character_name_peachy": {
			"en": "Peachy",
			"tl": "Peachy"
		},
		"character_name_cyanny": {
			"en": "Cyanny",
			"tl": "Cyanny"
		},
		"character_name_coral": {
			"en": "Coral",
			"tl": "Coral"
		},
		"accessory_default": {
			"en": "Default",
			"tl": "Default"
		},
		"accessory_sun_hat": {
			"en": "Sun Hat",
			"tl": "Sombrerong Pangsikat"
		},
		"accessory_cool_shades": {
			"en": "Cool Shades",
			"tl": "Cool na Salamin"
		},
		"accessory_party_cap": {
			"en": "Party Cap",
			"tl": "Party Cap"
		},
		"accessory_leaf_crown": {
			"en": "Leaf Crown",
			"tl": "Koronang Dahon"
		},
		"accessory_bow": {
			"en": "Bow",
			"tl": "Laso"
		},
		"accessory_safety_helmet": {
			"en": "Safety Helmet",
			"tl": "Helmet Pangkaligtasan"
		},
		"shop_title": {
			"en": "🛍️ SHOP",
			"tl": "🛍️ TINDAHAN"
		},
		"shop_tab_characters": {
			"en": "👤 Characters",
			"tl": "👤 Mga Character"
		},
		"shop_tab_minigames": {
			"en": "🎮 Minigames",
			"tl": "🎮 Mga Minigame"
		},
		"shop_tab_accessories": {
			"en": "🧢 Accessories",
			"tl": "🧢 Mga Accessory"
		},
		"shop_tab_decor": {
			"en": "🏠 Decor",
			"tl": "🏠 Dekor"
		},
		"shop_owned": {
			"en": "✅ OWNED",
			"tl": "✅ PAGMAMAY-ARI"
		},
		"shop_active": {
			"en": "⭐ ACTIVE",
			"tl": "⭐ AKTIBO"
		},
		"shop_use": {
			"en": "▶️ Use",
			"tl": "▶️ Gamitin"
		},
		"shop_equip": {
			"en": "👕 Equip",
			"tl": "👕 Isuot"
		},
		"shop_equipped": {
			"en": "⭐ EQUIPPED",
			"tl": "⭐ NAKASUOT"
		},
		"shop_in_rotation": {
			"en": "✅ IN ROTATION",
			"tl": "✅ NASA ROTATION"
		},
		"shop_unlocked": {
			"en": "✅ UNLOCKED",
			"tl": "✅ NAKA-UNLOCK"
		},
		"shop_not_enough_drops": {
			"en": "❌ Not enough drops!",
			"tl": "❌ Kulang ang patak!"
		},
		"shop_accessory_character_hat": {
			"en": "Character Hat",
			"tl": "Sombrero ng Character"
		},
		"shop_decor_sailboat": {
			"en": "Sailboat",
			"tl": "Bangka"
		},
		"minigame_pipe_puzzle": {
			"en": "Pipe Puzzle",
			"tl": "Pipe Puzzle"
		},
		"minigame_water_sorting": {
			"en": "Water Sort",
			"tl": "Pag-sort ng Tubig"
		},
		"minigame_leak_fix": {
			"en": "Fix Leaks",
			"tl": "Ayusin ang mga Tagas"
		},
		"minigame_water_quiz": {
			"en": "Water Quiz",
			"tl": "Water Quiz"
		},
		"minigame_bucket_relay": {
			"en": "Bucket Relay",
			"tl": "Bucket Relay"
		},
		"minigame_fun_games": {
			"en": "Fun Games",
			"tl": "Fun Games"
		},
		
		# Multiplayer / Co-op
		"multiplayer_lobby": {
			"en": "🎮 MULTIPLAYER LOBBY",
			"tl": "🎮 MULTIPLAYER LOBBY"
		},
		"create_game": {
			"en": "🏠 CREATE GAME",
			"tl": "🏠 GUMAWA NG LARO"
		},
		"join_game": {
			"en": "🔗 JOIN GAME",
			"tl": "🔗 SUMALI SA LARO"
		},
		"waiting_for_player": {
			"en": "Waiting for player to join...",
			"tl": "Naghihintay ng manlalaro..."
		},
		"player_connected": {
			"en": "✅ Player connected!",
			"tl": "✅ May sumali na!"
		},
		"start_game": {
			"en": "▶️ START GAME",
			"tl": "▶️ SIMULAN ANG LARO"
		},
		"enter_ip": {
			"en": "Enter Host IP Address:",
			"tl": "Ilagay ang IP Address ng Host:"
		},
		"connect": {
			"en": "🔗 CONNECT",
			"tl": "🔗 KUMONEKTA"
		},
		"disconnect": {
			"en": "❌ DISCONNECT",
			"tl": "❌ MAGDISKONEKTA"
		},
		"connection_failed": {
			"en": "Connection failed! Check IP and try again.",
			"tl": "Hindi nakakonekta! Suriin ang IP at subukan muli."
		},
		"server_disconnected": {
			"en": "Server disconnected!",
			"tl": "Nawala ang koneksyon sa server!"
		},
		"you_are_host": {
			"en": "You are the HOST (Player 1)",
			"tl": "Ikaw ang HOST (Manlalaro 1)"
		},
		"you_are_client": {
			"en": "You are the CLIENT (Player 2)",
			"tl": "Ikaw ang CLIENT (Manlalaro 2)"
		},
		"role_collector": {
			"en": "🌧️ Collector - Catch the Drops!",
			"tl": "🌧️ Tagasalo - Saluhin ang mga Patak!"
		},
		"role_user": {
			"en": "🍃 User - Destroy the Leaves!",
			"tl": "🍃 Tagagamit - Sirain ang mga Dahon!"
		},
		"team_score": {
			"en": "TEAM SCORE",
			"tl": "PUNTOS NG TEAM"
		},
		"team_lives": {
			"en": "TEAM LIVES",
			"tl": "BUHAY NG TEAM"
		},
		"multiplayer_team_effort": {
			"en": "TEAM EFFORT!",
			"tl": "SAMA-SAMANG SIKAP!"
		},
		"multiplayer_final_score": {
			"en": "Final Score: %d",
			"tl": "Huling Puntos: %d"
		},
		"multiplayer_rounds_survived": {
			"en": "Rounds Survived: %d",
			"tl": "Mga Round na Nalagpasan: %d"
		},
		"multiplayer_p1_contribution": {
			"en": "Player 1: %d points (%.1f%%)",
			"tl": "Player 1: %d puntos (%.1f%%)"
		},
		"multiplayer_p2_contribution": {
			"en": "Player 2: %d points (%.1f%%)",
			"tl": "Player 2: %d puntos (%.1f%%)"
		},
		"round_transition_complete": {
			"en": "ROUND %d COMPLETE!",
			"tl": "TAPOS NA ANG ROUND %d!"
		},
		"round_transition_p1_gain": {
			"en": "Player 1: +%d",
			"tl": "Manlalaro 1: +%d"
		},
		"round_transition_p2_gain": {
			"en": "Player 2: +%d",
			"tl": "Manlalaro 2: +%d"
		},
		"round_transition_team_total": {
			"en": "Team Total: %d",
			"tl": "Kabuuang Team: %d"
		},
		"round_transition_lives": {
			"en": "Lives: %s",
			"tl": "Buhay: %s"
		},
		"round_transition_rounds_survived": {
			"en": "Rounds Survived: %d",
			"tl": "Mga Round na Nalagpasan: %d"
		},
		"round_transition_next_round": {
			"en": "Next Round:\nP1: %s | P2: %s",
			"tl": "Susunod na Round:\nP1: %s | P2: %s"
		},
		"round_transition_countdown": {
			"en": "Next round in %.0fs...",
			"tl": "Susunod na round sa %.0fs..."
		},
		"debug_status_prefix": {
			"en": "Status: ",
			"tl": "Katayuan: "
		},
		"debug_ready_connect": {
			"en": "Ready to connect",
			"tl": "Handa nang kumonekta"
		},
		"debug_creating_server_port": {
			"en": "Creating server on port %d...",
			"tl": "Gumagawa ng server sa port %d..."
		},
		"debug_server_created_waiting": {
			"en": "✅ Server created! Waiting for players...",
			"tl": "✅ Nalikha ang server! Naghihintay ng players..."
		},
		"debug_server_create_failed": {
			"en": "❌ Failed to create server! Check console.",
			"tl": "❌ Hindi nalikha ang server! Suriin ang console."
		},
		"debug_connecting_to": {
			"en": "Connecting to %s:%d...",
			"tl": "Kumokonekta sa %s:%d..."
		},
		"debug_connecting_short": {
			"en": "🔄 Connecting...",
			"tl": "🔄 Kumokonekta..."
		},
		"debug_connected_wait_host": {
			"en": "✅ Connected! Waiting for host to start...",
			"tl": "✅ Konektado! Hinihintay magsimula ang host..."
		},
		"debug_connection_failed_ip_port": {
			"en": "❌ Connection failed! Check IP/Port.",
			"tl": "❌ Hindi kumonekta! Suriin ang IP/Port."
		},
		"debug_connect_failed_console": {
			"en": "❌ Failed to connect! Check console.",
			"tl": "❌ Hindi nakakonekta! Suriin ang console."
		},
		"debug_player2_connected_ready": {
			"en": "✅ Player 2 connected! Ready to start.",
			"tl": "✅ Konektado si Player 2! Handa nang magsimula."
		},
		"debug_starting_multiplayer": {
			"en": "🎮 Starting multiplayer game...",
			"tl": "🎮 Sinisimulan ang multiplayer game..."
		},
		"debug_copied_clipboard": {
			"en": "📋 Debug info copied to clipboard!",
			"tl": "📋 Nakopya ang debug info sa clipboard!"
		},
		"team_wins": {
			"en": "🎉 TEAM WINS!",
			"tl": "🎉 PANALO ANG TEAM!"
		},
		"team_loses": {
			"en": "💀 GAME OVER",
			"tl": "💀 TAPOS NA"
		},
		
		# Roadmap / Journey
		"roadmap": {
			"en": "🗺️ JOURNEY",
			"tl": "🗺️ PAGLALAKBAY"
		},
		"roadmap_title": {
			"en": "🗺️ WATER JOURNEY",
			"tl": "🗺️ PAGLALAKBAY SA TUBIG"
		},
		"stage_locked": {
			"en": "🔒 LOCKED",
			"tl": "🔒 NAKA-LOCK"
		},
		"roadmap_stage_locked": {
			"en": "🔒 This stage is still locked.",
			"tl": "🔒 Naka-lock pa ang stage na ito."
		},
		"roadmap_included_minigames": {
			"en": "Included mini-games",
			"tl": "Kasamang mga minigame"
		},
		"roadmap_how_to_play_preview": {
			"en": "How to play (animated preview)",
			"tl": "Paano laruin (animated preview)"
		},
		"roadmap_close": {
			"en": "CLOSE",
			"tl": "ISARA"
		},
		"roadmap_no_minigame_data": {
			"en": "No mini-game data",
			"tl": "Walang data ng minigame"
		},
		"roadmap_no_tutorial_info": {
			"en": "No tutorial information available yet.",
			"tl": "Wala pang tutorial information sa ngayon."
		},
		"roadmap_default_instruction_hint": {
			"en": "Follow on-screen controls to conserve water effectively.",
			"tl": "Sundin ang controls sa screen para epektibong makatipid ng tubig."
		},
		"roadmap_progress_completed": {
			"en": "%d/%d Completed",
			"tl": "%d/%d Tapos"
		},
		"roadmap_scroll_to_explore": {
			"en": "↕️ Scroll to explore",
			"tl": "↕️ Mag-scroll para mag-explore"
		},
		"stage_1_title": {
			"en": "💧 Water Drop Village",
			"tl": "💧 Nayon ng Patak"
		},
		"stage_1_desc": {
			"en": "Learn the basics of water conservation",
			"tl": "Alamin ang mga batayan ng pagtitipid ng tubig"
		},
		"stage_2_title": {
			"en": "🔧 Pipe Puzzle District",
			"tl": "🔧 Distrito ng Palaisipang Tubo"
		},
		"stage_2_desc": {
			"en": "Trace and repair the water network",
			"tl": "Sundan at ayusin ang network ng tubig"
		},
		"stage_3_title": {
			"en": "🧪 Water Sorting Lab",
			"tl": "🧪 Lab ng Paghahati ng Tubig"
		},
		"stage_3_desc": {
			"en": "Sort clean and reusable water correctly",
			"tl": "Ihiwalay nang tama ang malinis at reusable na tubig"
		},
		"stage_4_title": {
			"en": "🚿 Leak Fix Zone",
			"tl": "🚿 Sona ng Pag-ayos ng Tagas"
		},
		"stage_4_desc": {
			"en": "Stop waste in daily home routines",
			"tl": "Pigilan ang aksaya sa pang-araw-araw na gawain"
		},
		"stage_5_title": {
			"en": "❓ Water Wisdom Corner",
			"tl": "❓ Sulok ng Karunungan sa Tubig"
		},
		"stage_5_desc": {
			"en": "Use quick thinking for water-saving choices",
			"tl": "Gamitin ang mabilis na pag-iisip sa pagtitipid ng tubig"
		},
		"stage_6_title": {
			"en": "🏺 Bucket Relay Park",
			"tl": "🏺 Parke ng Bucket Relay"
		},
		"stage_6_desc": {
			"en": "Teamwork and timing save every drop",
			"tl": "Teamwork at timing ang susi sa bawat patak"
		},
		"stage_7_title": {
			"en": "🎉 Fun Games Pier",
			"tl": "🎉 Pantalan ng Masayang Laro"
		},
		"stage_7_desc": {
			"en": "Bonus challenges for mastery and memory",
			"tl": "Bonus challenges para sa mastery at memory"
		},
		"stage_8_title": {
			"en": "🏆 Waterville Champion Path",
			"tl": "🏆 Landas ng Kampeon ng Waterville"
		},
		"stage_8_desc": {
			"en": "Combine all your water-saving skills",
			"tl": "Pagsamahin ang lahat ng water-saving skills mo"
		},
		"stage_9_title": {
			"en": "🏆 Master",
			"tl": "🏆 Dalubhasa"
		},
		"stage_9_desc": {
			"en": "Complete water conservation expert!",
			"tl": "Eksperto na sa pagtitipid ng tubig!"
		},
		
		# Welcome Popup
		"welcome": {
			"en": "Welcome!",
			"tl": "Maligayang Pagdating!"
		},
		"welcome_message": {
			"en": "Learn to save water through fun mini-games!",
			"tl": "Matutong magtipid ng tubig sa pamamagitan ng masasayang mini-games!"
		},
		"lets_go": {
			"en": "LET'S GO!",
			"tl": "TARA NA!"
		},
		
		# Theme
		"theme": {
			"en": "Theme",
			"tl": "Tema"
		},
		"light_mode": {
			"en": "Light",
			"tl": "Maliwanag"
		},
		"dark_mode": {
			"en": "Dark",
			"tl": "Madilim"
		},
		
		# Story Screen
		"story_tap_continue": {
			"en": "👆 Tap to continue",
			"tl": "👆 Tap para magpatuloy"
		},
		"story_tap_play": {
			"en": "👆 Tap to play!",
			"tl": "👆 Tap para maglaro!"
		},
		"story_page_indicator": {
			"en": "%d / %d",
			"tl": "%d / %d"
		},
		
		# Session / Lives
		"lives_remaining": {
			"en": "Lives: %d",
			"tl": "Buhay: %d"
		},
		"session_complete": {
			"en": "Session Complete!",
			"tl": "Tapos na ang Session!"
		},
		"games_played": {
			"en": "Games Played: %d",
			"tl": "Mga Laro: %d"
		},
		"final_score": {
			"en": "Final Score",
			"tl": "Huling Puntos"
		},
		"play_again": {
			"en": "🔄 PLAY AGAIN",
			"tl": "🔄 MAGLARO MULI"
		},
		
		# New Minigame Names
		"cloud_catcher": {
			"en": "Cloud Catcher",
			"tl": "Saluhin ang Ulap"
		},
		"cloud_catcher_instructions": {
			"en": "TAP clouds to release rain!\nWater the thirsty plants below! ☁️",
			"tl": "TAP ang mga ulap para umulan!\nDiligan ang mga nauuhaw na halaman sa ibaba! ☁️"
		},
		"water_memory": {
			"en": "Water Memory",
			"tl": "Alaala ng Tubig"
		},
		"water_memory_instructions": {
			"en": "MATCH pairs of water-saving tips!\nFind all pairs before time runs out! 🧠",
			"tl": (
				"IPARES ang mga tip sa pagtitipid ng tubig!"
				+ "\nHanapin lahat ng pares bago maubos ang oras! 🧠"
			)
		},
		"droplet_dash": {
			"en": "Droplet Dash",
			"tl": "Takbo ni Patak"
		},
		"droplet_dash_instructions": {
			"en": "SWIPE to dodge obstacles!\nGuide Droppy to the reservoir! 💧",
			"tl": "SWIPE para umiwas sa mga hadlang!\nGabayan si Droppy papunta sa reservoir! 💧"
		},
		"all_unlocks_owned": {
			"en": "🏆 All items unlocked!",
			"tl": "🏆 Naka-unlock na lahat ng items!"
		},

		# Narrative overrides (optional)
		"narrative_trace_pipe_path_lose_character": {
			"en": "😕",
			"tl": "😕"
		},
		"narrative_trace_pipe_path_lose_context": {
			"en": "Pipe route got lost\nFlow blocked!",
			"tl": "Naligaw ang ruta ng tubo\nNabara ang daloy!"
		},
		"narrative_cover_the_drum_win_character": {
			"en": "🛢️",
			"tl": "🛢️"
		},
		# Co-op minigame copy. Every one of the 12 MP_* games returned its instruction overlay
		# and its controls panel as an English literal, so co-op was the only part of the build
		# that ignored the language setting — and the setting defaults to Filipino. The numbers
		# stay OUT of the table: each game formats its own constants into these, so a retune
		# cannot leave a stale figure behind in a translation nobody reads.
		"mp_catch_rain_aquarium_instructions": {
			"en": "🌧️ CATCH RAIN\n\nDrag anywhere to slide your bucket under the raindrops!\nEvery drop you catch is +%d to the TEAM meter.\nThe team needs %d points — your partner's pours count too.\n\n⚠️ Miss %d drops and lose 1 life!\n👆 Drag to move, or ⬅️ ➡️",
			"tl": "🌧️ SALUIN ANG ULAN\n\nI-drag kahit saan para isalya ang timba sa ilalim ng patak!\nBawat patak na masasalo ay +%d sa TEAM meter.\nKailangan ng team ng %d puntos — kasama ang binubuhos ng kapareha mo.\n\n⚠️ Kung makalampas ang %d patak, mababawasan ka ng 1 buhay!\n👆 I-drag para gumalaw, o ⬅️ ➡️"
		},
		"mp_catch_rain_aquarium_controls": {
			"en": "👆 Drag to move\n🏺 Catch rain\n💧 Fill aquarium",
			"tl": "👆 I-drag para gumalaw\n🏺 Saluin ang ulan\n💧 Punuin ang aquarium"
		},
		"mp_catch_the_rain_instructions": {
			"en": "Catch the raindrops!\nDrag anywhere - or use LEFT/RIGHT - to move the bucket.\nEvery drop you catch is +%d to the TEAM meter and water your partner can filter.\nThe team needs %d points.\n\n⚠️ Miss %d drops and lose 1 life!",
			"tl": "Saluin ang mga patak ng ulan!\nI-drag kahit saan - o gamitin ang KALIWA/KANAN - para igalaw ang timba.\nBawat patak na masasalo ay +%d sa TEAM meter at tubig na masasala ng kapareha mo.\nKailangan ng team ng %d puntos.\n\n⚠️ Kung makaligtaan ang %d patak, mababawasan ka ng 1 buhay!"
		},
		"mp_catch_the_rain_controls": {
			"en": "👆 Drag or ⬅️ ➡️\n🏺 Move bucket\n💧 Catch raindrops",
			"tl": "👆 I-drag o ⬅️ ➡️\n🏺 Igalaw ang timba\n💧 Saluin ang ulan"
		},
		"mp_collect_dish_water_instructions": {
			"en": "🍽️ COLLECT DISH WATER\n\nDrag your buckets under the drops from the dishwashing!\nEvery drop you catch is +%d to the TEAM meter.\nThe team needs %d points — your partner's scrubbing counts too.\n\n⚠️ Spill %d drops and lose 1 life!\n👆 Drag buckets under falling drops",
			"tl": "🍽️ SALUIN ANG HUGAS-PLATO\n\nI-drag ang mga timba sa ilalim ng tumutulong hugas-plato!\nBawat patak na masasalo ay +%d sa TEAM meter.\nKailangan ng team ng %d puntos — kasama ang kuskos ng kapareha mo.\n\n⚠️ Kung matapon ang %d patak, mababawasan ka ng 1 buhay!\n👆 I-drag ang timba sa ilalim ng patak"
		},
		"mp_collect_dish_water_controls": {
			"en": "👆 Drag buckets\n🏺 Catch drops\n💧 Send water",
			"tl": "👆 I-drag ang timba\n🏺 Saluin ang patak\n💧 Ipadala ang tubig"
		},
		"mp_collect_laundry_water_instructions": {
			"en": "🧺 COLLECT LAUNDRY WATER\n\nSlide your containers under the washing machine streams!\nEvery catch is +%d to the TEAM meter.\nThe team needs %d points — your partner's mopping counts too.\n\n⚠️ Miss %d water streams and lose 1 life!\n👆 Drag containers under the streams",
			"tl": "🧺 SALUIN ANG TUBIG SA LABADA\n\nIsalya ang mga lalagyan sa ilalim ng buga ng washing machine!\nBawat salo ay +%d sa TEAM meter.\nKailangan ng team ng %d puntos — kasama ang pagmamap ng kapareha mo.\n\n⚠️ Kung makalampas ang %d buga ng tubig, mababawasan ka ng 1 buhay!\n👆 I-drag ang lalagyan sa ilalim ng buga"
		},
		"mp_collect_laundry_water_controls": {
			"en": "👆 Drag containers\n🧺 Catch water\n💧 Fill & send",
			"tl": "👆 I-drag ang lalagyan\n🧺 Saluin ang tubig\n💧 Punuin at ipadala"
		},
		"mp_collect_shower_water_instructions": {
			"en": "🚿 COLLECT SHOWER WATER\n\nDrag your 4 buckets under the falling shower water!\nEvery drop you catch is +%d to the TEAM meter.\nThe team needs %d points — your partner's flushing counts too.\nEach bucket sends its load to your partner after %d drops.\n\n⚠️ Let %d drops overflow and lose 1 life!\n👆 Drag buckets under falling drops",
			"tl": "🚿 SALUIN ANG TUBIG SA SHOWER\n\nI-drag ang 4 na timba sa ilalim ng bumubuhos na tubig!\nBawat patak na masasalo ay +%d sa TEAM meter.\nKailangan ng team ng %d puntos — kasama ang pag-flush ng kapareha mo.\nBawat timba ay ipapadala sa kapareha mo pagkatapos ng %d patak.\n\n⚠️ Kung umapaw ang %d patak, mababawasan ka ng 1 buhay!\n👆 I-drag ang timba sa ilalim ng patak"
		},
		"mp_collect_shower_water_controls": {
			"en": "👆 Drag buckets\n🏺 Catch drops\n💧 Fill & send",
			"tl": "👆 I-drag ang timba\n🏺 Saluin ang patak\n💧 Punuin at ipadala"
		},
		"mp_fill_aquarium_instructions": {
			"en": "🐟 FILL AQUARIUM\n\nTap the aquarium to pour in your partner's rainwater!\nPour in %d loads to reach the team target.\nWater evaporates, so keep the tank above 5%%.\n\n⚠️ Let the aquarium sit empty for %d seconds and lose 1 life!\n💧 Wait for your partner to catch rain",
			"tl": "🐟 PUNUIN ANG AQUARIUM\n\nI-tap ang aquarium para ibuhos ang ulang nasalo ng kapareha mo!\nMagbuhos ng %d beses para maabot ang team target.\nNasisingaw ang tubig, kaya panatilihin ang tangke sa itaas ng 5%%.\n\n⚠️ Kung matuyo ang aquarium ng %d segundo, mababawasan ka ng 1 buhay!\n💧 Hintayin ang kapareha mong sumalo ng ulan"
		},
		"mp_fill_aquarium_controls": {
			"en": "👆 Tap aquarium\n💧 Add water\n🐟 Keep full",
			"tl": "👆 I-tap ang aquarium\n💧 Magdagdag ng tubig\n🐟 Panatilihing puno"
		},
		"mp_filter_water_instructions": {
			"en": "Wait for water from your partner.\nTap the dirt to filter it — +%d each.\nClear all %d specks in one unit for +%d more.\nThe team needs %d points — your partner's catching counts too.",
			"tl": "Hintayin ang tubig mula sa kapareha mo.\nI-tap ang dumi para masala ito — +%d bawat isa.\nLinisin lahat ng %d dumi sa isang yunit para sa dagdag +%d.\nKailangan ng team ng %d puntos — kasama ang salo ng kapareha mo."
		},
		"mp_filter_water_controls": {
			"en": "👆 Tap particles\n💧 Filter water\n⏸ Pause game",
			"tl": "👆 I-tap ang dumi\n💧 Salain ang tubig\n⏸ I-pause ang laro"
		},
		"mp_flush_toilets_instructions": {
			"en": "🚽 FLUSH TOILETS\n\nTap a dirty toilet to flush it with your partner's shower water!\nAnother toilet gets dirty every %d seconds.\n\n⚠️ Leave %d toilets unflushed and lose 1 life!\n💧 You need water from your partner to flush",
			"tl": "🚽 I-FLUSH ANG MGA KUBETA\n\nI-tap ang maruming kubeta para i-flush gamit ang tubig-shower ng kapareha mo!\nMay panibagong kubetang dumudumi tuwing %d segundo.\n\n⚠️ Kung %d kubeta ang hindi na-flush, mababawasan ka ng 1 buhay!\n💧 Kailangan mo ng tubig mula sa kapareha mo para maka-flush"
		},
		"mp_flush_toilets_controls": {
			"en": "👆 Tap toilets\n🚽 Flush them\n💧 Use water",
			"tl": "👆 I-tap ang kubeta\n🚽 I-flush ito\n💧 Gamitin ang tubig"
		},
		"mp_mop_floor_instructions": {
			"en": "🧹 MOP FLOOR\n\nTap dirty tiles to mop them with your partner's laundry water!\nAnother tile gets dirty every %d seconds.\n\n⚠️ Let %d tiles stay dirty and lose 1 life!\n💧 You need water from your partner to mop",
			"tl": "🧹 MAGMAP NG SAHIG\n\nI-tap ang maruming tiles para mapunasan gamit ang tubig-labada ng kapareha mo!\nMay panibagong tiles na dumudumi tuwing %d segundo.\n\n⚠️ Kung %d tiles ang manatiling marumi, mababawasan ka ng 1 buhay!\n💧 Kailangan mo ng tubig mula sa kapareha mo para makapagmap"
		},
		"mp_mop_floor_controls": {
			"en": "👆 Tap tiles\n🧹 Mop floor\n💧 Use water",
			"tl": "👆 I-tap ang tiles\n🧹 Mapin ang sahig\n💧 Gamitin ang tubig"
		},
		"mp_wash_car_instructions": {
			"en": "🚗 WASH CAR\n\nTap a dirty car section to scrub it with your partner's dish water!\nAnother section gets dirty a couple of seconds after each one you finish.\n\n⚠️ Let a section stay dirty for %d seconds and lose 1 life!\n💧 You need water from your partner to wash",
			"tl": "🚗 MAGHUGAS NG KOTSE\n\nI-tap ang maruming parte ng kotse para kuskusin gamit ang hugas-plato ng kapareha mo!\nMay panibagong parteng dumudumi makalipas ang ilang segundo sa tuwing may matatapos ka.\n\n⚠️ Kung manatiling marumi ang isang parte ng %d segundo, mababawasan ka ng 1 buhay!\n💧 Kailangan mo ng tubig mula sa kapareha mo para makahugas"
		},
		"mp_wash_car_controls": {
			"en": "👆 Tap sections\n🚗 Wash car\n💧 Use water",
			"tl": "👆 I-tap ang parte\n🚗 Hugasan ang kotse\n💧 Gamitin ang tubig"
		},
		"mp_wash_vegetables_instructions": {
			"en": "🥬 WASH VEGETABLES\n\nWash %d veggies before time runs out. Drag them into the sink to clean them and send the dirty water to your partner.\n\n⚠️ Miss %d veggies and you lose a life!\n👆 Drag vegetables into the sink",
			"tl": "🥬 MAGHUGAS NG GULAY\n\nMaghugas ng %d gulay bago maubos ang oras. I-drag ang mga ito sa lababo para malinis at maipadala ang hugas sa kapareha mo.\n\n⚠️ Kung makalampas ang %d gulay, mababawasan ka ng buhay!\n👆 I-drag ang gulay papunta sa lababo"
		},
		"mp_wash_vegetables_controls": {
			"en": "👆 Drag & drop\n🥬 To the sink\n💧 Send water",
			"tl": "👆 I-drag at bitawan\n🥬 Sa lababo\n💧 Ipadala ang tubig"
		},
		"mp_water_plants_instructions": {
			"en": "🌱 WATER PLANTS\n\nWater %d plants before time runs out. Tap a plant to pour on the water your partner sent.\nPlants wilt after %ds if ignored.\n\n⚠️ Let %d plants wilt and you lose a life!\n💧 Wait for water from your partner, then tap the plants",
			"tl": "🌱 MAGDILIG NG HALAMAN\n\nDiligan ang %d halaman bago maubos ang oras. I-tap ang halaman para ibuhos ang tubig na ipinadala ng kapareha mo.\nNalalanta ang halaman pagkalipas ng %ds kung hindi papansinin.\n\n⚠️ Kung %d halaman ang malanta, mababawasan ka ng buhay!\n💧 Hintayin ang tubig mula sa kapareha mo, tapos i-tap ang halaman"
		},
		"mp_water_plants_controls": {
			"en": "👆 Tap plants\n💧 Water them\n🌱 Keep alive",
			"tl": "👆 I-tap ang halaman\n💧 Diligan ito\n🌱 Panatilihing buhay"
		},
		# The co-op SHELL's own copy. FIX 72 localized the 12 games; the frame around them —
		# MultiplayerMiniGameBase — still built its HUD, pause menu, overlays, controls panel,
		# disconnect notice, game-over screen and round summary out of English literals, so on a
		# default (Filipino) install the player read a Filipino briefing inside an English frame.
		# 25 labels were measured rendering byte-identical in both languages before this block.
		# game_name deliberately stays OUT of here: SessionLogger keys the thesis session log by
		# it, and FIX 68 is the record of what a localized identity costs. The titles below are
		# DISPLAY titles, selected by each game's own title_key.
		"mp_hud_endless": {
			"en": "ENDLESS",
			"tl": "WALANG HANGGAN"
		},
		"mp_hud_you": {
			"en": "YOU: %s",
			"tl": "IKAW: %s"
		},
		"mp_hud_partner": {
			"en": "PARTNER: %s",
			"tl": "KAPAREHA: %s"
		},
		"mp_paused": {
			"en": "PAUSED",
			"tl": "NAKA-PAUSE"
		},
		"mp_resume": {
			"en": "RESUME",
			"tl": "MAGPATULOY"
		},
		"mp_quit_session": {
			"en": "QUIT SESSION",
			"tl": "UMALIS SA SESSION"
		},
		"mp_waiting_partner": {
			"en": "Waiting for partner...",
			"tl": "Hinihintay ang kapareha..."
		},
		"mp_waiting_team_progress": {
			"en": "Team progress: %d / %d",
			"tl": "Progreso ng team: %d / %d"
		},
		"mp_waiting_partner_gain": {
			"en": "Partner has added +%d since you finished",
			"tl": "Nakadagdag ng +%d ang kapareha mo"
		},
		"mp_your_role": {
			"en": "Your Role: %s",
			"tl": "Papel Mo: %s"
		},
		"mp_instructions_placeholder": {
			"en": "Instructions will appear here",
			"tl": "Lalabas dito ang mga tagubilin"
		},
		"mp_countdown_go": {
			"en": "GO!",
			"tl": "SIMULAN!"
		},
		"mp_player_disconnected": {
			"en": "Player Disconnected",
			"tl": "Nadiskonekta ang Manlalaro"
		},
		"mp_session_terminated": {
			"en": "Session terminated. Returning to lobby...",
			"tl": "Tapos na ang session. Babalik sa lobby..."
		},
		"mp_reconnecting": {
			"en": "Connection Lost",
			"tl": "Nawala ang Koneksyon"
		},
		"mp_reconnecting_hint": {
			"en": "Holding the round open - reconnecting...",
			"tl": "Hinihintay ang kalaro - kumokonekta muli..."
		},
		"mp_controls_title": {
			"en": "CONTROLS",
			"tl": "MGA KONTROL"
		},
		"mp_team_out_of_lives": {
			"en": "The team ran out of lives!",
			"tl": "Naubusan ng buhay ang team!"
		},
		"mp_return_to_lobby": {
			"en": "Return to Lobby",
			"tl": "Bumalik sa Lobby"
		},
		"mp_level_complete": {
			"en": "LEVEL COMPLETE!",
			"tl": "TAPOS NA ANG LEVEL!"
		},
		"mp_your_score": {
			"en": "Your Score: %d",
			"tl": "Puntos Mo: %d"
		},
		"mp_round_complete": {
			"en": "ROUND COMPLETE",
			"tl": "TAPOS NA ANG ROUND"
		},
		"mp_your_result_header": {
			"en": "YOUR RESULT  (Player %d)",
			"tl": "ANG RESULTA MO  (Manlalaro %d)"
		},
		"mp_result_row_mine": {
			"en": "%s   This Round: %d pts   Session Total: %d pts",
			"tl": "%s   Round na Ito: %d puntos   Kabuuan ng Session: %d puntos"
		},
		"mp_result_row_partner": {
			"en": "Partner (Player %d): %s — %d pts",
			"tl": "Kapareha (Manlalaro %d): %s — %d puntos"
		},
		"mp_result_totals": {
			"en": "Team Score This Round: %d   |   Session Team Total: %d\nLives:  x%d   |   Rounds: %d",
			"tl": "Puntos ng Team Ngayong Round: %d   |   Kabuuan ng Team sa Session: %d\nBuhay:  x%d   |   Mga Round: %d"
		},
		"mp_life_lost": {
			"en": "💔 Life Lost!",
			"tl": "💔 May Nawalang Buhay!"
		},
		"mp_loading_next_round": {
			"en": "Loading next round...",
			"tl": "Naglo-load ng susunod na round..."
		},
		"mp_win_token": {
			"en": "✅ WIN",
			"tl": "✅ PANALO"
		},
		"mp_fail_token": {
			"en": "❌ FAIL",
			"tl": "❌ TALO"
		},
		# The two role ids NetworkManager hands out on the shipping path. The ids themselves stay
		# English: RainwaterHarvesting branches on player_role == "Collector", so the id is logic.
		# These are what the HUD and the briefing show instead.
		"mp_role_collector": {
			"en": "Collector",
			"tl": "Tagakolekta"
		},
		"mp_role_user": {
			"en": "Water User",
			"tl": "Gumagamit ng Tubig"
		},
		# The ten flavour roles LevelSets hands out, one pair per set, swapped every other round.
		# They reached no player before this: round 1 never left the {Collector, User} placeholder
		# and the round-transition RPC never assigned roles on the client, so all ten names sat in
		# LevelSets unread. Keyed the way _role_display() slugs a role id — "Vegetable Washer"
		# -> mp_role_vegetable_washer — so the English column stays the authored name.
		"mp_role_vegetable_washer": {
			"en": "Vegetable Washer",
			"tl": "Taga-hugas ng Gulay"
		},
		"mp_role_plant_waterer": {
			"en": "Plant Waterer",
			"tl": "Taga-dilig ng Halaman"
		},
		"mp_role_shower_water_collector": {
			"en": "Shower Water Collector",
			"tl": "Taga-salok ng Tubig-Shower"
		},
		"mp_role_toilet_flusher": {
			"en": "Toilet Flusher",
			"tl": "Taga-flush ng Kubeta"
		},
		"mp_role_rain_catcher": {
			"en": "Rain Catcher",
			"tl": "Taga-salo ng Ulan"
		},
		"mp_role_aquarium_keeper": {
			"en": "Aquarium Keeper",
			"tl": "Tagapag-alaga ng Aquarium"
		},
		"mp_role_laundry_water_collector": {
			"en": "Laundry Water Collector",
			"tl": "Taga-salok ng Tubig-Labada"
		},
		"mp_role_floor_mopper": {
			"en": "Floor Mopper",
			"tl": "Taga-mop ng Sahig"
		},
		"mp_role_dish_water_collector": {
			"en": "Dish Water Collector",
			"tl": "Taga-salok ng Hugas-Pinggan"
		},
		"mp_role_car_washer": {
			"en": "Car Washer",
			"tl": "Taga-hugas ng Kotse"
		},
		# DISPLAY titles for the 12 co-op rounds. MP_CatchTheRain reuses the existing
		# catch_the_rain key rather than adding a thirteenth.
		"mp_title_catch_rain_aquarium": {
			"en": "Catch Rain for Aquarium",
			"tl": "Salok ng Ulan para sa Aquarium"
		},
		"mp_title_collect_dish_water": {
			"en": "Collect Dish Water",
			"tl": "Kolektahin ang Tubig sa Hugasan"
		},
		"mp_title_collect_laundry_water": {
			"en": "Collect Laundry Water",
			"tl": "Kolektahin ang Tubig sa Labada"
		},
		"mp_title_collect_shower_water": {
			"en": "Collect Shower Water",
			"tl": "Kolektahin ang Tubig sa Shower"
		},
		"mp_title_fill_aquarium": {
			"en": "Fill Aquarium",
			"tl": "Lagyan ng Tubig ang Aquarium"
		},
		"mp_title_filter_water": {
			"en": "Filter Water",
			"tl": "Salain ang Tubig"
		},
		"mp_title_flush_toilets": {
			"en": "Flush Toilets",
			"tl": "I-flush ang mga Kubeta"
		},
		"mp_title_mop_floor": {
			"en": "Mop Floor",
			"tl": "Magmop ng Sahig"
		},
		"mp_title_wash_car": {
			"en": "Wash Car",
			"tl": "Hugasan ang Kotse"
		},
		"mp_title_wash_vegetables": {
			"en": "Wash Vegetables",
			"tl": "Hugasan ang Gulay"
		},
		"mp_title_water_plants": {
			"en": "Water Plants",
			"tl": "Diligan ang mga Halaman"
		},
		# ── Co-op failure and success reactions ──
		# The brief asks for funny readable failure states instead of a bare verdict. The
		# singleplayer path got them (MiniGameBase._get_result_line_for_key); the co-op path
		# kept ending a LOST ROUND with a 72 px red "GAME OVER!" while the team still had
		# lives, and kept an unconditional green "ROUND COMPLETE" header over a wipe.
		# Keyed by the game's own script name (MP_WashCar.gd -> wash_car), resolved by
		# MultiplayerMiniGameBase._react_line(). Two beats each, same shape as the SP lines:
		# what just happened, then the reuse point it proves — every co-op game is a pair
		# where one player collects water and the partner spends it, so the joke and the
		# lesson are the same sentence.
		"mp_round_lost": {
			"en": "ROUND SLIPPED AWAY!",
			"tl": "NADULAS ANG ROUND!"
		},
		"mp_round_rough": {
			"en": "ROUGH ROUND!",
			"tl": "MAGULONG ROUND!"
		},
		"mp_react_session_over": {
			"en": "Out of lives, not out of water tips!",
			"tl": "Wala nang buhay, sagana pa sa tips!"
		},
		"mp_react_fail_catch_rain_aquarium": {
			"en": "The clouds won that one. Slide sooner!",
			"tl": "Panalo ang ulap. Bilisan ang salo!"
		},
		"mp_react_win_catch_rain_aquarium": {
			"en": "Bucket full, tank happy. Free rain beats the tap!",
			"tl": "Punong timba! Libre ang ulan, mahal ang gripo."
		},
		"mp_react_fail_catch_the_rain": {
			"en": "Rain hit the dirt instead. Chase the drops!",
			"tl": "Sa lupa napunta ang ulan. Habulin ang patak!"
		},
		"mp_react_win_catch_the_rain": {
			"en": "Caught it clean. Your partner can filter that!",
			"tl": "Nasalo nang malinis. Masasala na ito ng kasama!"
		},
		"mp_react_fail_collect_dish_water": {
			"en": "Dish water hit the floor. Bucket up faster!",
			"tl": "Sa sahig bumagsak ang hugas. Bilisan ang timba!"
		},
		"mp_react_win_collect_dish_water": {
			"en": "Rinse water saved. That is a car wash, not a drain!",
			"tl": "Nasalba ang hugas-pinggan. Panghugas kotse na!"
		},
		"mp_react_fail_collect_laundry_water": {
			"en": "Laundry water escaped. Slide under the stream!",
			"tl": "Tumakas ang tubig-labada. Sumalo sa ilalim!"
		},
		"mp_react_win_collect_laundry_water": {
			"en": "Suds secured. Your partner can mop with those!",
			"tl": "Naipon ang labada. Pamumog na ng kasama!"
		},
		"mp_react_fail_collect_shower_water": {
			"en": "Buckets overflowed. Rotate them sooner!",
			"tl": "Umapaw ang mga timba. Palitan nang mas mabilis!"
		},
		"mp_react_win_collect_shower_water": {
			"en": "Shower runoff bottled. The toilets will drink it!",
			"tl": "Naipon ang tubig-shower. Pang-flush na ito!"
		},
		"mp_react_fail_fill_aquarium": {
			"en": "Tank ran dry. The fish filed a complaint!",
			"tl": "Naubos ang tubig. Nagreklamo ang isda!"
		},
		"mp_react_win_fill_aquarium": {
			"en": "Topped up with rainwater. The fish approve!",
			"tl": "Napuno ng tubig-ulan. Sang-ayon ang isda!"
		},
		"mp_react_fail_filter_water": {
			"en": "Grit got through. Tap the dirt, not the water!",
			"tl": "Nakalusot ang dumi. Tapikin ang dumi, hindi tubig!"
		},
		"mp_react_win_filter_water": {
			"en": "Filtered clear. Reused water, zero tap!",
			"tl": "Naging malinaw. Muling gamit, walang gripo!"
		},
		"mp_react_fail_flush_toilets": {
			"en": "The toilets staged a protest. Flush on time!",
			"tl": "Nagwelga ang mga inodoro. Bilisan ang flush!"
		},
		"mp_react_win_flush_toilets": {
			"en": "Flushed with shower water. Drinking water saved!",
			"tl": "Tubig-shower ang pang-flush. Tipid sa inumin!"
		},
		"mp_react_fail_mop_floor": {
			"en": "The floor won the staring contest. Mop quicker!",
			"tl": "Nanalo ang sahig sa titigan. Bilisan ang mop!"
		},
		"mp_react_win_mop_floor": {
			"en": "Mopped with laundry water. Nothing wasted!",
			"tl": "Tubig-labada ang pamumog. Walang nasayang!"
		},
		"mp_react_fail_wash_car": {
			"en": "Car still filthy. Scrub every panel!",
			"tl": "Marumi pa ang kotse. Kuskusin bawat parte!"
		},
		"mp_react_win_wash_car": {
			"en": "It shines on dish water. The hose stayed off!",
			"tl": "Kuminang sa hugas-pinggan. Patay ang hose!"
		},
		"mp_react_fail_wash_vegetables": {
			"en": "Veggies left gritty. Drag them into the sink!",
			"tl": "Maputik pa ang gulay. Hulugan sa lababo!"
		},
		"mp_react_win_wash_vegetables": {
			"en": "Veggies clean, rinse water forwarded!",
			"tl": "Malinis ang gulay, naipasa ang hugas!"
		},
		"mp_react_fail_water_plants": {
			"en": "The plants wilted dramatically. Water sooner!",
			"tl": "Nalanta ang halaman sa drama. Diligan agad!"
		},
		# ── In-game HUD labels (Batch 3: were hardcoded English at the assignment site)
		"hud_plants_watered": {
			"en": "🌱 %d / %d watered",
			"tl": "🌱 %d / %d nadiligan"
		},
		"hud_mosquitoes_inside": {
			"en": "🦟 Inside: %d / %d",
			"tl": "🦟 Nakapasok: %d / %d"
		},
		"hud_drum_open": {
			"en": "⚠️ OPEN",
			"tl": "⚠️ BUKAS"
		},
		"hud_drum_safe": {
			"en": "✔ SAFE",
			"tl": "✔ LIGTAS"
		},
		"hud_filters_built": {
			"en": "🧱 %d / %d filters",
			"tl": "🧱 %d / %d salaan"
		},
		"hud_undo_last": {
			"en": "Undo Last",
			"tl": "Bawiin ang Huli"
		},
		"hud_hold_to_pour_hint": {
			"en": "👆 HOLD to pour, release to drain!",
			"tl": "👆 PINDUTIN para magbuhos, bitawan para maubos!"
		},
		"hud_too_wet": {
			"en": "🌊 WET",
			"tl": "🌊 BASA"
		},
		"hud_too_dry": {
			"en": "🏜️ DRY",
			"tl": "🏜️ TUYO"
		},
		"hud_pouring": {
			"en": "Pouring... 💧",
			"tl": "Nagbubuhos... 💧"
		},
		"hud_hold_to_pour": {
			"en": "Hold to pour!",
			"tl": "Pindutin para magbuhos!"
		},
		"hud_out_of_range": {
			"en": "💦 Out of range!",
			"tl": "💦 Sobra na!"
		},
		"hud_too_dry_fail": {
			"en": "🏜️ Too dry!",
			"tl": "🏜️ Kulang ang tubig!"
		},
		"hud_water_wasted": {
			"en": "💧 Water Wasted: %.0f%%",
			"tl": "💧 Natapon: %.0f%%"
		},
		"hud_go": {
			"en": "GO!",
			"tl": "SIMULAN!"
		},
		"hud_time_seconds": {
			"en": "Time: %.1fs",
			"tl": "Oras: %.1fs"
		},
		"hud_waiting_collector": {
			"en": "Waiting for collector to gather water...",
			"tl": "Hinihintay ang kasama na mag-ipon ng tubig..."
		},
		"hud_partner_completed": {
			"en": "Partner: COMPLETED (%.0f%%)",
			"tl": "Kasama: TAPOS NA (%.0f%%)"
		},
		# RainwaterHarvesting: the co-op role brief and its counter. One line per language,
		# because TaskLabel is one line tall and AccuracyLabel sits directly under it.
		"rwh_task_collector": {
			"en": "YOUR TASK: Put containers under the roof gutters",
			"tl": "GAWAIN MO: Maglagay ng lalagyan sa ilalim ng alulod"
		},
		"rwh_task_user": {
			"en": "YOUR TASK: Use the collected rain for toilet and plants",
			"tl": "GAWAIN MO: Gamitin ang tubig-ulan sa inidoro at halaman"
		},
		"rwh_completed_count": {
			"en": "Completed: %d/%d (%.0f%%)",
			"tl": "Natapos: %d/%d (%.0f%%)"
		},
		"hud_catches": {
			"en": "💧 Catches: %d",
			"tl": "💧 Nasalo: %d"
		},
		"hud_follow": {
			"en": "⬅ FOLLOW ➡",
			"tl": "⬅ SUNDAN ➡"
		},
		"hud_dirt_percent": {
			"en": "Dirt: %.0f%%",
			"tl": "Dumi: %.0f%%"
		},
		"hud_correct_count": {
			"en": "✔ Correct: %d / %d",
			"tl": "✔ Tama: %d / %d"
		},
		"hud_swipe_clean": {
			"en": "⬆️ CLEAN",
			"tl": "⬆️ MALINIS"
		},
		"hud_swipe_dirty": {
			"en": "⬇️ DIRTY",
			"tl": "⬇️ MADUMI"
		},
		"hud_correct": {
			"en": "✔ CORRECT!",
			"tl": "✔ TAMA!"
		},
		"hud_wrong": {
			"en": "✖ WRONG!",
			"tl": "✖ MALI!"
		},
		"hud_watch_green_bucket": {
			"en": "👀 Watch the GREEN bucket!",
			"tl": "👀 Tutukan ang BERDENG timba!"
		},
		"hud_shuffling": {
			"en": "🔀 Shuffling... (%d/%d)",
			"tl": "🔀 Naghahalo... (%d/%d)"
		},
		"hud_tap_water_bucket": {
			"en": "👆 TAP the water bucket!",
			"tl": "👆 PINDUTIN ang timbang may tubig!"
		},
		"hud_target_arrow": {
			"en": "⬅ TARGET",
			"tl": "⬅ TAMANG LEBEL"
		},
		"hud_hold_to_fill": {
			"en": "👆 HOLD TO FILL",
			"tl": "👆 PINDUTIN PARA MAGLAMAN"
		},
		"hud_filling": {
			"en": "💧 FILLING...",
			"tl": "💧 NAGLALAMAN..."
		},
		"hud_overflow": {
			"en": "OVERFLOW! 💦",
			"tl": "UMAPAW! 💦"
		},
		"hud_not_enough": {
			"en": "NOT ENOUGH! ⬆️",
			"tl": "KULANG PA! ⬆️"
		},
		"hud_next_tank": {
			"en": "🔧 NEXT TANK...",
			"tl": "🔧 SUSUNOD NA TANGKE..."
		},
		"hud_taps_closed": {
			"en": "🚰 %d / %d closed",
			"tl": "🚰 %d / %d nasara"
		},
		"hud_water_ok": {
			"en": "💧 Water: OK",
			"tl": "💧 Tubig: OK"
		},
		"hud_water_caution": {
			"en": "💧 Water: Caution!",
			"tl": "💧 Tubig: Mag-ingat!"
		},
		"hud_water_critical": {
			"en": "💧 Water: CRITICAL!",
			"tl": "💧 Tubig: DELIKADO NA!"
		},
		"hud_veggies_clean": {
			"en": "🥬 Clean: %d / %d",
			"tl": "🥬 Malinis: %d / %d"
		},
		"hud_veggie_dirty": {
			"en": "🥬 DIRTY",
			"tl": "🥬 MADUMI"
		},
		"hud_veggie_wash": {
			"en": "💧 WASH",
			"tl": "💧 HUGASAN"
		},
		"hud_veggie_clean": {
			"en": "✔ CLEAN",
			"tl": "✔ MALINIS"
		},
		"hud_pairs_found": {
			"en": "🧠 %d / %d pairs",
			"tl": "🧠 %d / %d pares"
		},
		"hud_keep_plants_alive": {
			"en": "🌱 Keep all plants alive!",
			"tl": "🌱 Panatilihing buhay ang lahat ng halaman!"
		},
		"hud_too_much_water": {
			"en": "💦 Too much!",
			"tl": "💦 Sobra na!"
		},
		"hud_plant_died": {
			"en": "🥀 A plant died!",
			"tl": "🥀 May namatay na halaman!"
		},
		"hud_plants_happy": {
			"en": "🌱 %d/%d plants happy",
			"tl": "🌱 %d/%d halaman masaya"
		},
		"hud_tap_anywhere": {
			"en": "👆 TAP ANYWHERE! 👆",
			"tl": "👆 PINDUTIN KAHIT SAAN! 👆"
		},
		"hud_combo": {
			"en": "COMBO x%d!",
			"tl": "COMBO x%d!"
		},
		"hud_level_short": {
			"en": "LVL %d",
			"tl": "ANTAS %d"
		},
		# Tries left in an attempt-budget round (MiniGameBase.use_attempt_budget).
		# "Tira" is the ordinary Filipino playground word for a turn/shot you have
		# left, which is exactly the quantity this counts.
		"hud_tries_short": {
			"en": "TRIES %d",
			"tl": "TIRA %d"
		},
		# ── Shared minigame shell: pause sheet, session end, round summary
		"shell_current_score": {
			"en": "Current Score: %d",
			"tl": "Kasalukuyang Puntos: %d"
		},
		"shell_resume": {
			"en": "▶  RESUME",
			"tl": "▶  MAGPATULOY"
		},
		"shell_quit_game": {
			"en": "✖  QUIT GAME",
			"tl": "✖  UMALIS SA LARO"
		},
		"shell_session_ended": {
			"en": "SESSION ENDED",
			"tl": "TAPOS NA ANG SESSION"
		},
		"shell_this_round": {
			"en": "This Round",
			"tl": "Ngayong Round"
		},
		"shell_round_points": {
			"en": "+%d pts",
			"tl": "+%d puntos"
		},
		"round_failed": {
			"en": "ROUND FAILED",
			"tl": "BIGO ANG ROUND"
		},
		"finalscore_rank_row": {
			"en": "%d. %s — %s | %d pts | %d%%",
			"tl": "%d. %s — %s | %d puntos | %d%%"
		},
		"leaderboard_tier": {
			"en": "Tier %s",
			"tl": "Antas %s"
		},
		"score_points": {
			"en": "%d pts",
			"tl": "%d puntos"
		},
		# ── Menus, settings and lobby chrome
		"menu_auto_play_toggle": {
			"en": "🤖 Auto-Play: %s",
			"tl": "🤖 Auto-Play: %s"
		},
		"toggle_on": {
			"en": "ON",
			"tl": "BUKAS"
		},
		"toggle_off": {
			"en": "OFF",
			"tl": "SARADO"
		},
		"settings_auto_play_mp": {
			"en": "🤖 Auto-Play (MP)",
			"tl": "🤖 Auto-Play (MP)"
		},
		"settings_dev_stats": {
			"en": "📊 Dev Stats & Export Log",
			"tl": "📊 Dev Stats at I-export ang Log"
		},
		"settings_beat_viewer": {
			"en": "🎬 Beat Viewer (animation check)",
			"tl": "🎬 Beat Viewer (tsek ng animation)"
		},
		"settings_game_lab": {
			"en": "🧪 Game Lab (try any minigame)",
			"tl": "🧪 Game Lab (subukan ang kahit anong minigame)"
		},
		"settings_erase_data": {
			"en": "🗑️ Erase All Data",
			"tl": "🗑️ Burahin Lahat ng Data"
		},
		"settings_erase_data_title": {
			"en": "Erase all data?",
			"tl": "Burahin lahat ng data?"
		},
		"settings_erase_data_warning": {
			"en": (
				"This deletes every droplet, unlock, high score and setting on this "
				+ "device.\nIt cannot be undone."
			),
			"tl": (
				"Buburahin nito ang lahat ng droplet, unlock, high score at setting "
				+ "sa device na ito.\nHindi ito maibabalik."
			)
		},
		"settings_erase_data_ok": {
			"en": "Erase everything",
			"tl": "Burahin lahat"
		},
		"cancel": {
			"en": "Cancel",
			"tl": "Kanselahin"
		},
		"settings_export_logs": {
			"en": "📤 Export Session Logs",
			"tl": "📤 I-export ang Session Logs"
		},
		"mp_session_leaderboard": {
			"en": "📊 Session Leaderboard",
			"tl": "📊 Ranggo Ngayong Session"
		},
		# "round" is a loanword in this project's Tagalog throughout ("Kanselado ang round"),
		# so the caption keeps it rather than reaching for "bilog", which is the shape.
		"mp_round_timer": {
			"en": "Round:",
			"tl": "Round:"
		},
		# "Karaniwan" rather than the English "Default": unlike "round", "host" and
		# "multiplayer", this is not a word this project already treats as a loanword, and
		# VerifyLocalization exists to stop an untranslated string entering as an invisible
		# note. It reads as "the usual one", which is what the value means here - leave the
		# round at the length its own scene authored.
		"mp_round_timer_default": {
			"en": "Default (30s)",
			"tl": "Karaniwan (30s)"
		},
		"mp_round_timer_host_only": {
			"en": "Only the host can change the round timer",
			"tl": "Ang host lang ang makakapagpalit ng haba ng round"
		},
		"mp_duration_label": {
			"en": "Duration:",
			"tl": "Tagal:"
		},
		"mp_auto_play_on": {
			"en": "🤖 AUTO PLAY ON",
			"tl": "🤖 BUKAS ANG AUTO PLAY"
		},
		"mp_auto_play": {
			"en": "🤖 AUTO PLAY",
			"tl": "🤖 AUTO PLAY"
		},
		"mp_session_log_note": {
			"en": "Recorded in session log — exported on app quit",
			"tl": "Nakatala sa session log — ilalabas kapag isinara ang app"
		},
		"mp_no_rounds_yet": {
			"en": "No rounds played yet this session.",
			"tl": "Wala pang round na nalaro ngayong session."
		},
		# ── Co-op HUD: resource meters, hints and object states
		"mp_res_rainwater": {
			"en": "Rainwater:",
			"tl": "Tubig-ulan:"
		},
		"mp_res_shower_water": {
			"en": "Shower Water:",
			"tl": "Tubig sa Shower:"
		},
		"mp_res_laundry_water": {
			"en": "Laundry Water:",
			"tl": "Tubig sa Labada:"
		},
		"mp_res_dish_water": {
			"en": "Dish Water:",
			"tl": "Tubig sa Hugasan:"
		},
		"mp_res_available_water": {
			"en": "Available Water:",
			"tl": "Tubig na Pwedeng Gamitin:"
		},
		"mp_hint_click_aquarium": {
			"en": "Click aquarium to fill",
			"tl": "Pindutin ang aquarium para lagyan"
		},
		"mp_hint_click_plants": {
			"en": "Click plants to water",
			"tl": "Pindutin ang halaman para diligan"
		},
		"mp_aquarium_label": {
			"en": "🐟 AQUARIUM\n%.0f%%",
			"tl": "🐟 AQUARIUM\n%.0f%%"
		},
		"mp_sink_label": {
			"en": "SINK\n🚰",
			"tl": "LABABO\n🚰"
		},
		"mp_toilet_clean": {
			"en": "🚽 Clean",
			"tl": "🚽 Malinis"
		},
		"mp_toilet_dirty": {
			"en": "🚽 Dirty",
			"tl": "🚽 Madumi"
		},
		"mp_plant_dry": {
			"en": "🥀 Dry",
			"tl": "🥀 Tuyot"
		},
		"mp_plant_dead": {
			"en": "💀 Dead",
			"tl": "💀 Patay"
		},
		# ── Cutscene stingers and the tutorial card
		"cutscene_success": {
			"en": "🎉 Success! 💧",
			"tl": "🎉 Ayos! 💧"
		},
		"cutscene_try_again": {
			"en": "💦 Try Again! 💧",
			"tl": "💦 Subukan Muli! 💧"
		},
		"cutscene_ready": {
			"en": "💧 Ready! 💧",
			"tl": "💧 Tara na! 💧"
		},
		"tutorial_tip_prefix": {
			"en": "💡 TIP: ",
			"tl": "💡 PAYO: "
		},
		"hud_perfect_ok": {
			"en": "✔ OK",
			"tl": "✔ TAMA"
		},
		"menu_auto_play_tooltip": {
			"en": "Enable automated gameplay for single-player performance testing",
			"tl": "Paganahin ang awtomatikong paglalaro para sa pagsubok ng performance sa solo"
		},
		"mp_waiting_host_start": {
			"en": "Waiting for host to start...",
			"tl": "Hinihintay ang host na magsimula..."
		},
		"mp_waiting_all_players": {
			"en": "Waiting for all players...",
			"tl": "Hinihintay ang lahat ng manlalaro..."
		},
		"unlock_droplets_to_go": {
			"en": "%s\n💧 %d to go",
			"tl": "%s\n💧 %d pa"
		},
		"narrative_filter_builder_win_context": {
			"en": "Built perfect filter stack\nClean water! Delicious! ✨",
			"tl": "Perpektong salansan ng filter\nMalinis na tubig! Ang tamis! ✨"
		},
		"narrative_filter_builder_lose_context": {
			"en": "Wrong layer order\nMurky water! Blech!",
			"tl": "Maling sunod-sunod ng layer\nMalabo ang tubig! Kadiri!"
		},
		"narrative_fix_leak_win_context": {
			"en": "Sealed the leak instantly\nWater stops flowing! ✨",
			"tl": "Nasarhan agad ang tagas\nTumigil na ang tubig! ✨"
		},
		"narrative_fix_leak_lose_context": {
			"en": "Leak keeps spraying\nWater keeps wasting!",
			"tl": "Tuloy pa rin ang tagas\nPatuloy na nasasayang!"
		},
		"narrative_catch_the_rain_win_context": {
			"en": "Rain captured perfectly\nDrum filling up! ✨",
			"tl": "Perpektong nasalo ang ulan\nNapupuno ang drum! ✨"
		},
		"narrative_catch_the_rain_lose_context": {
			"en": "Rain escaped everywhere\nDrum stays empty!",
			"tl": "Nakatakas ang ulan\nWalang laman ang drum!"
		},
		"narrative_rice_wash_rescue_win_context": {
			"en": "Rice water saved for reuse\nZero waste! ✨",
			"tl": "Naitabi ang hugas-bigas\nWalang nasayang! ✨"
		},
		"narrative_rice_wash_rescue_lose_context": {
			"en": "Rice water lost to drain\nWater wasted!",
			"tl": "Naagos ang hugas-bigas\nNasayang ang tubig!"
		},
		"narrative_vegetable_bath_win_context": {
			"en": "Veggie rinse captured\nWater reused! ✨",
			"tl": "Nasalo ang banlaw ng gulay\nNagamit muli ang tubig! ✨"
		},
		"narrative_vegetable_bath_lose_context": {
			"en": "Too much rinse water used\nWasted away!",
			"tl": "Sobrang tubig sa pagbabanlaw\nNasayang lahat!"
		},
		"narrative_greywater_sorter_win_context": {
			"en": "Greywater sorted correctly\nReady to reuse! ✨",
			"tl": "Tamang pag-uuri ng greywater\nPuwede nang gamitin muli! ✨"
		},
		"narrative_greywater_sorter_lose_context": {
			"en": "Streams got contaminated\nCan't reuse it!",
			"tl": "Nahaluan ang mga agos\nHindi na magagamit!"
		},
		"narrative_wring_it_out_win_context": {
			"en": "Every drop saved from sponge\nNothing wasted! ✨",
			"tl": "Bawat patak, napiga sa espongha\nWalang nasayang! ✨"
		},
		"narrative_wring_it_out_lose_context": {
			"en": "Sponge still dripping\nDrops lost!",
			"tl": "Tumutulo pa ang espongha\nNawala ang mga patak!"
		},
		"narrative_thirsty_plant_win_context": {
			"en": "Plant watered perfectly\nHappy and thriving! ✨",
			"tl": "Perpektong nadiligan ang halaman\nMasaya at lumalago! ✨"
		},
		"narrative_thirsty_plant_lose_context": {
			"en": "Over/under watered\nPlant unhappy!",
			"tl": "Sobra o kulang ang tubig\nMalungkot ang halaman!"
		},
		"narrative_mud_pie_maker_win_context": {
			"en": "Mud mix ratio perfect\nZero waste! ✨",
			"tl": "Tamang timpla ng putik\nWalang nasayang! ✨"
		},
		"narrative_mud_pie_maker_lose_context": {
			"en": "Wrong consistency\nMessed up!",
			"tl": "Maling kalabnawan\nNasira ang timpla!"
		},
		"narrative_cover_the_drum_win_context": {
			"en": "Drum covered in time\nWater protected! ✨",
			"tl": "Natakpan agad ang drum\nProtektado ang tubig! ✨"
		},
		"narrative_cover_the_drum_lose_context": {
			"en": "Drum got contaminated\nToo late!",
			"tl": "Nadumihan ang drum\nHuli na ang lahat!"
		},
		"narrative_spot_the_speck_win_context": {
			"en": "All specks spotted and removed\nCrystal clear! ✨",
			"tl": "Lahat ng dumi, nahanap at naalis\nLinaw na linaw! ✨"
		},
		"narrative_spot_the_speck_lose_context": {
			"en": "A speck got through\nImpure water!",
			"tl": "May dumi na nakalampas\nMarumi ang tubig!"
		},
		"narrative_water_plant_win_context": {
			"en": "Watering rhythm locked in\nPlant thriving! ✨",
			"tl": "Sakto ang ritmo ng pagdidilig\nLumalago ang halaman! ✨"
		},
		"narrative_water_plant_lose_context": {
			"en": "Pattern timing off\nPlant wilting!",
			"tl": "Sablay ang timing ng pattern\nNalalanta ang halaman!"
		},
		"narrative_plug_the_leak_win_context": {
			"en": "Pipe plugged under pressure\nFixed! ✨",
			"tl": "Natakpan ang tubo kahit malakas ang presyon\nAyos na! ✨"
		},
		"narrative_plug_the_leak_lose_context": {
			"en": "Plug didn't hold\nStill leaking!",
			"tl": "Hindi humawak ang pantapal\nTumatagas pa rin!"
		},
		"narrative_swipe_the_soap_win_context": {
			"en": "Soap swipe efficient and fast\nWater saved! ✨",
			"tl": "Mabilis at tipid ang pagsasabon\nNakatipid ng tubig! ✨"
		},
		"narrative_swipe_the_soap_lose_context": {
			"en": "Swipe took too long\nWater wasted!",
			"tl": "Matagal ang pagsasabon\nNasayang ang tubig!"
		},
		"narrative_quick_shower_win_context": {
			"en": "Shower sprint complete\nSuper quick! ✨",
			"tl": "Tapos na ang bilis-shower\nSobrang bilis! ✨"
		},
		"narrative_quick_shower_lose_context": {
			"en": "Shower ran way too long\nToo slow!",
			"tl": "Sobrang tagal sa shower\nAng bagal!"
		},
		"narrative_toilet_tank_fix_win_context": {
			"en": "Tank calibrated perfectly\nNo excess flush! ✨",
			"tl": "Perpektong kalibrasyon ng tangke\nWalang sobrang flush! ✨"
		},
		"narrative_toilet_tank_fix_lose_context": {
			"en": "Tank still overflowing\nWater wasted!",
			"tl": "Umaapaw pa ang tangke\nNasayang ang tubig!"
		},
		"narrative_trace_pipe_path_win_context": {
			"en": "Pipe path traced cleanly\nFlow optimized! ✨",
			"tl": "Malinis ang pagsubaybay sa tubo\nAyos na ang agos! ✨"
		},
		"narrative_scrub_to_save_win_context": {
			"en": "Scrub pattern water-wise\nSpotless and dry! ✨",
			"tl": "Matipid sa tubig ang pagkukuskos\nMalinis at tuyo! ✨"
		},
		"narrative_scrub_to_save_lose_context": {
			"en": "Scrub wasted water\nStill soaking!",
			"tl": "Nasayang ang tubig sa kuskos\nBasang-basa pa rin!"
		},
		"narrative_bucket_brigade_win_context": {
			"en": "Relay team nailed handoff\nWater delivered! ✨",
			"tl": "Sakto ang abot-abot ng timba\nNarating ang tubig! ✨"
		},
		"narrative_bucket_brigade_lose_context": {
			"en": "Relay dropped the buckets\nWater spilled!",
			"tl": "Nabitawan ang mga timba\nNatapon ang tubig!"
		},
		"narrative_timing_tap_win_context": {
			"en": "Tap timing perfect\nZero extra drip! ✨",
			"tl": "Perpektong tiyempo sa gripo\nWalang tumulong patak! ✨"
		},
		"narrative_timing_tap_lose_context": {
			"en": "Timing missed the beat\nDripping away!",
			"tl": "Sablay sa tamang tiyempo\nPatak-patak ang sayang!"
		},
		"narrative_turn_off_tap_win_context": {
			"en": "Tap cut off right on cue\nOn the dot! ✨",
			"tl": "Sakto ang pagsara ng gripo\nHustong-husto! ✨"
		},
		"narrative_turn_off_tap_lose_context": {
			"en": "Tap stayed running\nWater wasted!",
			"tl": "Bukas pa rin ang gripo\nNasayang ang tubig!"
		},
		"narrative_droplet_dash_win_context": {
			"en": "Every drop caught!\nThe glass is full! ✨",
			"tl": "Nasalo ang bawat patak!\nPuno na ang baso! ✨"
		},
		"narrative_droplet_dash_lose_context": {
			"en": "Last drop waves goodbye\nGlass stays empty!",
			"tl": "Kumaway pa ang huling patak\nWalang laman ang baso!"
		},
		"narrative_water_memory_win_context": {
			"en": "All pairs matched!\nNever waste water again! ✨",
			"tl": "Tugma lahat ng pares!\nHuwag nang mag-aksaya ng tubig! ✨"
		},
		"narrative_water_memory_lose_context": {
			"en": "Memory failed!\nTry to remember next time!",
			"tl": "Nakalimutan mo!\nTandaan mo sa susunod!"
		},
		"narrative_cloud_catcher_win_context": {
			"en": "All clouds collected!\nSky is grateful! ✨",
			"tl": "Nakolekta lahat ng ulap!\nNagpapasalamat ang langit! ✨"
		},
		"narrative_cloud_catcher_lose_context": {
			"en": "Clouds drifted away\nWater uncaptured!",
			"tl": "Lumipad ang mga ulap\nWalang nasalong tubig!"
		},
		"mp_role_water_filterer": {
			"en": "Water Filterer",
			"tl": "Taga-filter ng Tubig"
		},
		# ── Filter materials (FilterBuilder chips and solution guides)
		# The four names appear twice per round: on the draggable chip and on the faint
		# numbered guide inside each slot. Terms match filter_builder_instructions above.
		"material_cloth": {
			"en": "Cloth",
			"tl": "Tela"
		},
		"material_charcoal": {
			"en": "Charcoal",
			"tl": "Uling"
		},
		"material_sand": {
			"en": "Sand",
			"tl": "Buhangin"
		},
		"material_gravel": {
			"en": "Gravel",
			"tl": "Graba"
		},
		# ── VegetableBath failure quips (0.4s on screen, so two or three words)
		"veg_quip_still_muddy": {
			"en": "STILL MUDDY! 🥕",
			"tl": "MAY PUTIK PA! 🥕"
		},
		"veg_quip_rinse_first": {
			"en": "RINSE IT FIRST! 💧",
			"tl": "BANLAWAN MUNA! 💧"
		},
		"veg_quip_thats_soil": {
			"en": "THAT'S SOIL! 🌱",
			"tl": "LUPA 'YAN! 🌱"
		},
		# ── ToiletTankFix grading quips (same budget: two or three words above the tank)
		"ttf_quip_overflow": {
			"en": "OVERFLOW! 🌊",
			"tl": "UMAAPAW! 🌊"
		},
		"ttf_quip_gusher": {
			"en": "GUSHER! 💦",
			"tl": "BUMUBUGA! 💦"
		},
		"ttf_quip_flood_mode": {
			"en": "FLOOD MODE! 🚽",
			"tl": "BAHA NA! 🚽"
		},
		"ttf_quip_too_shy": {
			"en": "TOO SHY! 💧",
			"tl": "KULANG PA! 💧"
		},
		"ttf_quip_half_flush": {
			"en": "HALF A FLUSH! 🚽",
			"tl": "KALAHATI LANG! 🚽"
		},
		"ttf_quip_more_more": {
			"en": "MORE, MORE! ⬆️",
			"tl": "DAGDAG PA! ⬆️"
		},
		# ── MP_WashCar panels. Kept short: the caption sits inside a 150-unit panel, so a
		# long Filipino gloss ("Takip ng Makina") would run past the panel edge.
		"mp_car_hood": {
			"en": "Hood",
			"tl": "Hood"
		},
		"mp_car_roof": {
			"en": "Roof",
			"tl": "Bubong"
		},
		"mp_car_door_l": {
			"en": "Door L",
			"tl": "Pinto K"
		},
		"mp_car_door_r": {
			"en": "Door R",
			"tl": "Pinto D"
		},
		"mp_car_trunk": {
			"en": "Trunk",
			"tl": "Bagahe"
		},
		# ── MP_WashVegetables and MP_WaterPlants chips: the emoji is part of the value so a
		# translator can reorder glyph and noun without touching the game script.
		"mp_veg_carrot": {
			"en": "🥕 Carrot",
			"tl": "🥕 Karot"
		},
		"mp_veg_lettuce": {
			"en": "🥬 Lettuce",
			"tl": "🥬 Litsugas"
		},
		"mp_veg_tomato": {
			"en": "🍅 Tomato",
			"tl": "🍅 Kamatis"
		},
		"mp_veg_cucumber": {
			"en": "🥒 Cucumber",
			"tl": "🥒 Pipino"
		},
		"mp_plant_sunflower": {
			"en": "🌻 Sunflower",
			"tl": "🌻 Mirasol"
		},
		"mp_plant_rose": {
			"en": "🌹 Rose",
			"tl": "🌹 Rosas"
		},
		"mp_plant_herb": {
			"en": "🌿 Herb",
			"tl": "🌿 Damong Gamot"
		},
		"mp_plant_hibiscus": {
			"en": "🌺 Hibiscus",
			"tl": "🌺 Gumamela"
		},
		# ── Session leaderboard columns (MultiplayerLobby). The Round header reuses "round";
		# the point cells reuse "score_points".
		"mp_lb_col_p1": {
			"en": "Player 1",
			"tl": "Player 1"
		},
		"mp_lb_col_p2": {
			"en": "Player 2",
			"tl": "Player 2"
		},
		"mp_lb_col_team": {
			"en": "Team",
			"tl": "Pangkat"
		},
		"mp_lb_col_result": {
			"en": "Result",
			"tl": "Resulta"
		},
		"mp_lb_round_num": {
			"en": "Round %d",
			"tl": "Round %d"
		},
		"mp_lb_total": {
			"en": "TOTAL",
			"tl": "KABUUAN"
		},
		# ── Cutscene flavour lines (SimpleCutscenePlayer._get_scene_data "text" fields).
		# Composed at the render site as cutscene_line_<game>_<win|fail>; the English in the
		# scene table stays as the fallback, so a missing row degrades to readable copy.
		"cutscene_line_catch_the_rain_win": {
			"en": "The drum overflows with glory!",
			"tl": "Umaapaw sa tagumpay ang drum!"
		},
		"cutscene_line_catch_the_rain_fail": {
			"en": "Mystery liquid fills the drum. A plant dies.",
			"tl": "Misteryosong likido ang napuno sa drum. May halamang namatay."
		},
		"cutscene_line_cover_the_drum_win": {
			"en": "Mosquitoes hold a sad little funeral.",
			"tl": "Nagluksa ang mga lamok sa maliit na libing."
		},
		"cutscene_line_cover_the_drum_fail": {
			"en": "A mosquito the size of a fist claims the drum as a condo.",
			"tl": "Isang lamok na kasinlaki ng kamao ang nag-condo sa drum."
		},
		"cutscene_line_droplet_dash_win": {
			"en": "Every drop caught. The droplets look betrayed.",
			"tl": "Nasalo lahat ng patak. Parang na-traydor ang mga patak."
		},
		"cutscene_line_droplet_dash_fail": {
			"en": "The last droplet waves goodbye. Glass is empty.",
			"tl": "Kumaway ng paalam ang huling patak. Walang laman ang baso."
		},
		"cutscene_line_filter_builder_win": {
			"en": "Sparkling clean water. A child drinks gratefully.",
			"tl": "Kumikinang na malinis na tubig. May batang nagpasalamat sa paglagok."
		},
		"cutscene_line_filter_builder_fail": {
			"en": "Wrong order. It looks like gravy. No one drinks that.",
			"tl": "Maling sunod-sunod. Parang sarsa ang kinalabasan. Walang lalagok niyan."
		},
		"cutscene_line_fix_leak_win": {
			"en": "Silence. Peace. A single drip salutes you.",
			"tl": "Katahimikan. Kapayapaan. May isang tulo na sumaludo sa iyo."
		},
		"cutscene_line_fix_leak_fail": {
			"en": "Three more burst open. The room is now a splash park!",
			"tl": "Tatlo pa ang bumuka. Splash park na ang kuwarto!"
		},
		"cutscene_line_plug_the_leak_win": {
			"en": "Silence. Peace. A single drip salutes you.",
			"tl": "Katahimikan. Kapayapaan. May isang tulo na sumaludo sa iyo."
		},
		"cutscene_line_plug_the_leak_fail": {
			"en": "Three more burst open. The room is now a splash park!",
			"tl": "Tatlo pa ang bumuka. Splash park na ang kuwarto!"
		},
		"cutscene_line_greywater_sorter_win": {
			"en": "Every bucket sorted. The garden blooms!",
			"tl": "Nabukod lahat ng timba. Namumukadkad ang hardin!"
		},
		"cutscene_line_greywater_sorter_fail": {
			"en": "Soapy water hits the tomatoes. The tomatoes had a name.",
			"tl": "Tinamaan ng sabon ang mga kamatis. May pangalan pa ang mga kamatis na iyon."
		},
		"cutscene_line_bucket_brigade_win": {
			"en": "TEAMWORK! — someone shouts it unironically.",
			"tl": "TEAMWORK! — sinigaw ito ng isang tao, seryoso talaga."
		},
		"cutscene_line_bucket_brigade_fail": {
			"en": "Third person eats a sandwich. The plant writes a letter.",
			"tl": "Kumakain ng sandwich ang pangatlo. Sumulat ng liham ang halaman."
		},
		"cutscene_line_quick_shower_win": {
			"en": "Clean. Efficient. The water meter gives a thumbs up.",
			"tl": "Malinis. Mabilis. Thumbs up ang metro ng tubig."
		},
		"cutscene_line_quick_shower_fail": {
			"en": "The meter explodes. You're clean but the planet is not.",
			"tl": "Sumabog ang metro. Malinis ka nga, pero hindi ang planeta."
		},
		"cutscene_line_rice_wash_rescue_win": {
			"en": "Precious starchy water saved. The plants are very happy.",
			"tl": "Nailigtas ang mahalagang hugas-bigas. Tuwang-tuwa ang mga halaman."
		},
		"cutscene_line_rice_wash_rescue_fail": {
			"en": "A single grain of rice rolls away in disappointment.",
			"tl": "Isang butil ng bigas ang gumulong palayo sa lungkot."
		},
		"cutscene_line_scrub_to_save_win": {
			"en": "Spotless! A fork nearby applauds.",
			"tl": "Kinis-kinis! Pumalakpak ang tinidor sa tabi."
		},
		"cutscene_line_scrub_to_save_fail": {
			"en": "The dish does not sparkle. It judges you.",
			"tl": "Hindi kumikinang ang plato. Hinuhusgahan ka nito."
		},
		"cutscene_line_spot_the_speck_win": {
			"en": "All impurities spotted. Add it to your resume.",
			"tl": "Nahanap lahat ng dumi. Isama mo na sa resume mo."
		},
		"cutscene_line_spot_the_speck_fail": {
			"en": "You don't want to know what happens next.",
			"tl": "Ayaw mong malaman ang susunod na mangyayari."
		},
		"cutscene_line_swipe_the_soap_win": {
			"en": "Clean hands! The soap bar is impressed.",
			"tl": "Malinis na kamay! Impressed ang sabon."
		},
		"cutscene_line_swipe_the_soap_fail": {
			"en": "The soap lands somewhere outside.",
			"tl": "Napunta sa labas ang sabon."
		},
		"cutscene_line_thirsty_plant_win": {
			"en": "Correct bucket! It grows noticeably. It seems grateful.",
			"tl": "Tamang timba! Tumangkad agad. Mukhang nagpapasalamat."
		},
		"cutscene_line_thirsty_plant_fail": {
			"en": "Wrong bucket. The real green one watches silently.",
			"tl": "Maling timba. Tahimik lang na nakatingin ang totoong luntian."
		},
		"cutscene_line_timing_tap_win": {
			"en": "Perfect fill! The container does a little shimmy.",
			"tl": "Perpektong puno! Kaunting shimmy pa ang lalagyan."
		},
		"cutscene_line_timing_tap_fail": {
			"en": "It overflows. The floor is now a small lake.",
			"tl": "Umapaw. Maliit na lawa na ang sahig."
		},
		"cutscene_line_toilet_tank_fix_win": {
			"en": "Peace returns to the household.",
			"tl": "Bumalik ang kapayapaan sa bahay."
		},
		"cutscene_line_toilet_tank_fix_fail": {
			"en": "The toilet overflows. The Tuesday leak was less bad.",
			"tl": "Umapaw ang inodoro. Mas mabuti pa ang tagas noong Martes."
		},
		"cutscene_line_trace_pipe_path_win": {
			"en": "Pipe connected correctly. The neighborhood cheers!",
			"tl": "Tamang koneksyon ng tubo. Nagsaya ang buong barangay!"
		},
		"cutscene_line_trace_pipe_path_fail": {
			"en": "Water goes through the kitchen ceiling. Everyone showers.",
			"tl": "Dumaan ang tubig sa kisame ng kusina. Naligo ang lahat."
		},
		"cutscene_line_turn_off_tap_win": {
			"en": "All taps off. The water bill sighs with relief.",
			"tl": "Sarado lahat ng gripo. Nakahinga ng maluwag ang bill ng tubig."
		},
		"cutscene_line_turn_off_tap_fail": {
			"en": "The house is now a fountain. Kind of beautiful. But wrong.",
			"tl": "Fountain na ang bahay. Medyo maganda. Pero mali."
		},
		"cutscene_line_vegetable_bath_win": {
			"en": "Dinner is saved. You're actually useful.",
			"tl": "Nailigtas ang hapunan. May pakinabang ka rin pala."
		},
		"cutscene_line_vegetable_bath_fail": {
			"en": "Wrong basket. The carrot is ashamed.",
			"tl": "Maling basket. Napahiya ang karot."
		},
		"cutscene_line_water_memory_win": {
			"en": "All pairs matched! You will never waste water again.",
			"tl": "Tugma lahat ng pares! Hindi ka na magsasayang ng tubig."
		},
		"cutscene_line_water_memory_fail": {
			"en": "You match 'Don't waste water' with 'Turtle.'",
			"tl": "Naitugma mo ang 'Huwag magsayang ng tubig' sa 'Pagong.'"
		},
		"cutscene_line_water_plant_win": {
			"en": "Basin full. The water goes to the garden!",
			"tl": "Puno ang planggana. Sa hardin na papunta ang tubig!"
		},
		"cutscene_line_water_plant_fail": {
			"en": "Three drops in the basin. The garden sulks.",
			"tl": "Tatlong patak lang sa planggana. Nagtampo ang hardin."
		},
		"cutscene_line_wring_it_out_win": {
			"en": "Basin full. The water goes to the garden!",
			"tl": "Puno ang planggana. Sa hardin na papunta ang tubig!"
		},
		"cutscene_line_wring_it_out_fail": {
			"en": "Three drops in the basin. The garden sulks.",
			"tl": "Tatlong patak lang sa planggana. Nagtampo ang hardin."
		},
		"cutscene_line_mud_pie_maker_win": {
			"en": "Structurally sound mud pie! A child is delighted.",
			"tl": "Matibay ang pagkakagawa ng mud pie! Tuwang-tuwa ang bata."
		},
		"cutscene_line_mud_pie_maker_fail": {
			"en": "Too much water. You have failed mud.",
			"tl": "Sobrang tubig. Bigo ka sa putik."
		},
		"mp_react_win_water_plants": {
			"en": "Revived on reused water. Green team!",
			"tl": "Bumangon sa muling-gamit na tubig. Galing!"
		}
	}

## Returns true when `key` exists in the translation table.
##
## Callers that have their own hardcoded fallback (see MiniGameBase._loc) should
## check this instead of comparing get_text()'s return against the key: those
## lookups are *optional by design*, so routing them through get_text() emitted
## a "Missing translation key" warning for every intentional fallback.
func has_text(key: String) -> bool:
	return translations.has(key)

func get_text(key: String) -> String:
	if not translations.has(key):
		push_warning("Missing translation key: " + key)
		return key
	
	var lang_code = "tl" if current_language == Language.FILIPINO else "en"
	
	if translations[key].has(lang_code):
		return translations[key][lang_code]

	push_warning(
		"Missing translation for key '%s' in language '%s'"
		% [key, lang_code]
	)
	return translations[key].get("en", key)

## Alias for get_text (shorter function name) - use translate() not tr() to avoid conflict
func translate(key: String) -> String:
	return get_text(key)

func set_language(lang: Language) -> void:
	if current_language != lang:
		current_language = lang
		_save_settings()
		language_changed.emit(get_language_code())
		print("🌐 Language changed to: %s" % get_language_name())

func toggle_language() -> void:
	if current_language == Language.FILIPINO:
		set_language(Language.ENGLISH)
	else:
		set_language(Language.FILIPINO)

func get_language_code() -> String:
	return "tl" if current_language == Language.FILIPINO else "en"

func get_language_name() -> String:
	return "Filipino" if current_language == Language.FILIPINO else "English"

func is_filipino() -> bool:
	return current_language == Language.FILIPINO

func is_english() -> bool:
	return current_language == Language.ENGLISH

func _save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("Settings", "language", current_language)
	config.save(SAVE_PATH)

func _load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		var saved_lang = config.get_value("Settings", "language", Language.FILIPINO)
		# Validate that the saved value is a valid enum
		if saved_lang == Language.ENGLISH or saved_lang == Language.FILIPINO:
			current_language = saved_lang
			# We don't emit signal here because _ready calls this before anyone connects
