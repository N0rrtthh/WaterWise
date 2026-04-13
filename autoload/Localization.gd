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
			"en": "WATERWISE",
			"tl": "WATERWISE"
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
			"en": "💧 Water Conservation Journey",
			"tl": "💧 Paglalakbay sa Pagtitipid ng Tubig"
		},
		"stage_locked": {
			"en": "🔒 LOCKED",
			"tl": "🔒 NAKA-LOCK"
		},
		"stage_1_title": {
			"en": "💧 Start",
			"tl": "💧 Simula"
		},
		"stage_1_desc": {
			"en": "Begin your water-saving journey!",
			"tl": "Simulan ang iyong paglalakbay!"
		},
		"stage_2_title": {
			"en": "🍚 Rice Wash",
			"tl": "🍚 Hugas-Bigas"
		},
		"stage_2_desc": {
			"en": "Learn to reuse rice wash water",
			"tl": "Matutong gamitin muli ang hugas-bigas"
		},
		"stage_3_title": {
			"en": "🥬 Veggie Bath",
			"tl": "🥬 Hugas Gulay"
		},
		"stage_3_desc": {
			"en": "Wash vegetables efficiently",
			"tl": "Hugasan ang gulay nang tama"
		},
		"stage_4_title": {
			"en": "♻️ Greywater",
			"tl": "♻️ Greywater"
		},
		"stage_4_desc": {
			"en": "Sort water for reuse",
			"tl": "Pagbukud-bukurin ang tubig"
		},
		"stage_5_title": {
			"en": "👕 Wring Out",
			"tl": "👕 Pigain"
		},
		"stage_5_desc": {
			"en": "Save laundry water",
			"tl": "Tipirin ang tubig sa labahan"
		},
		"stage_6_title": {
			"en": "🌱 Thirsty Plant",
			"tl": "🌱 Uhaw na Halaman"
		},
		"stage_6_desc": {
			"en": "Water plants wisely",
			"tl": "Diligan ang halaman nang tama"
		},
		"stage_7_title": {
			"en": "🌧️ Catch Rain",
			"tl": "🌧️ Saluhin ang Ulan"
		},
		"stage_7_desc": {
			"en": "Harvest rainwater",
			"tl": "Mag-ipon ng tubig-ulan"
		},
		"stage_8_title": {
			"en": "🪣 Cover Drum",
			"tl": "🪣 Takpan ang Drum"
		},
		"stage_8_desc": {
			"en": "Protect stored water",
			"tl": "Protektahan ang naka-imbak na tubig"
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
