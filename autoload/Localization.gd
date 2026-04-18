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
		
		# Settings
		"language": {
			"en": "Language / Wika",
			"tl": "Language / Wika"
		},
		"english": {
			"en": "English",
			"tl": "English"
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
			"tl": "🎨 Colorblind Mode"
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
			"tl": "🔊 Audio Cues"
		},
		"settings_haptic_feedback": {
			"en": "📳 Haptic Feedback",
			"tl": "📳 Haptic Feedback"
		},
		"settings_screen_shake": {
			"en": "📳 Screen Shake",
			"tl": "📳 Screen Shake"
		},
		"settings_particles_effects": {
			"en": "✨ Particles/Effects",
			"tl": "✨ Particle/Epekto"
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
		"settings_show": {
			"en": "Show",
			"tl": "Ipakita"
		},
		"settings_dev_note": {
			"en": "Use toggles on mobile (same as F11/F12 on PC).",
			"tl": "Gamitin ang toggles sa mobile (kapareho ng F11/F12 sa PC)."
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
			"en": "The Thirsty Plant",
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
			"en": "SLIDE TO POUR WATER!\nMIX PERFECT MUD!",
			"tl": "I-SLIDE PARA BUHOS NG TUBIG!\nHALUIN ANG PERPEKTONG PUTIK!"
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
			"tl": "TAP ANG MGA DRUM PARA ISARA ANG TAKIP!\nPigilan ANG MGA LAMOK!"
		},
		"spot_the_speck": {
			"en": "Spot The Speck",
			"tl": "Tukuyin ang Dumi"
		},
		"speck_instruction": {
			"en": "DIRTY? SWIPE DOWN\nCLEAN? SWIPE UP",
			"tl": "MARUMI? SWIPE PABABA\nMALINIS? SWIPE PATAAS"
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
			"tl": "TAP PARA AYUSIN ANG TAGAS!\nSAVE WATER FAST!"
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
			"en": (
				"DRAG filter layers to the correct slots!"
				+ "\nBuild: Gravel → Sand → Charcoal → Cloth 🏾"
			),
			"tl": (
				"I-DRAG ang mga layer ng filter sa tamang "
				+ "posisyon!\nBuuin: Graba → Buhangin → Uling → Tela 🏾"
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
		"bucket_brigade_instructions": {
			"en": "TAP when bucket reaches target!\nPass buckets down the line! 🪣",
			"tl": "TAP kapag ang timba ay nasa target!\nIpasa ang mga timba! 🪣"
		},
		"timing_tap_instructions": {
			"en": "HOLD to fill container!\nStop at the TARGET line! 💧",
			"tl": "I-HOLD para punuin ang lalagyan!\nIhinto sa TARGET na linya! 💧"
		},
		"turn_off_tap_instructions": {
			"en": "TAP running faucets to turn them off!\nDon't waste water! 🚿",
			"tl": "TAP ang mga bukas na gripo para isara!\nHuwag mag-aksaya ng tubig! 🚿"
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
			"en": "✓ PASSING",
			"tl": "✓ PUMASA"
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
		"posttest_interpretation_line": {
			"en": "[CHECK] %s",
			"tl": "[CHECK] %s"
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
			"tl": "Cool Shades"
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
			"tl": "Bow"
		},
		"accessory_safety_helmet": {
			"en": "Safety Helmet",
			"tl": "Safety Helmet"
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
			"tl": "TEAM EFFORT!"
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
			"tl": "ROUND %d COMPLETE!"
		},
		"round_transition_p1_gain": {
			"en": "Player 1: +%d",
			"tl": "Player 1: +%d"
		},
		"round_transition_p2_gain": {
			"en": "Player 2: +%d",
			"tl": "Player 2: +%d"
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
			"tl": "🗺️ WATER JOURNEY"
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
			"tl": "💧 Water Drop Village"
		},
		"stage_1_desc": {
			"en": "Learn the basics of water conservation",
			"tl": "Alamin ang mga batayan ng pagtitipid ng tubig"
		},
		"stage_2_title": {
			"en": "🔧 Pipe Puzzle District",
			"tl": "🔧 Pipe Puzzle District"
		},
		"stage_2_desc": {
			"en": "Trace and repair the water network",
			"tl": "Sundan at ayusin ang network ng tubig"
		},
		"stage_3_title": {
			"en": "🧪 Water Sorting Lab",
			"tl": "🧪 Water Sorting Lab"
		},
		"stage_3_desc": {
			"en": "Sort clean and reusable water correctly",
			"tl": "Ihiwalay nang tama ang malinis at reusable na tubig"
		},
		"stage_4_title": {
			"en": "🚿 Leak Fix Zone",
			"tl": "🚿 Leak Fix Zone"
		},
		"stage_4_desc": {
			"en": "Stop waste in daily home routines",
			"tl": "Pigilan ang aksaya sa pang-araw-araw na gawain"
		},
		"stage_5_title": {
			"en": "❓ Water Wisdom Corner",
			"tl": "❓ Water Wisdom Corner"
		},
		"stage_5_desc": {
			"en": "Use quick thinking for water-saving choices",
			"tl": "Gamitin ang mabilis na pag-iisip sa pagtitipid ng tubig"
		},
		"stage_6_title": {
			"en": "🪣 Bucket Relay Park",
			"tl": "🪣 Bucket Relay Park"
		},
		"stage_6_desc": {
			"en": "Teamwork and timing save every drop",
			"tl": "Teamwork at timing ang susi sa bawat patak"
		},
		"stage_7_title": {
			"en": "🎉 Fun Games Pier",
			"tl": "🎉 Fun Games Pier"
		},
		"stage_7_desc": {
			"en": "Bonus challenges for mastery and memory",
			"tl": "Bonus challenges para sa mastery at memory"
		},
		"stage_8_title": {
			"en": "🏆 Waterville Champion Path",
			"tl": "🏆 Waterville Champion Path"
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
		}
	}

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
