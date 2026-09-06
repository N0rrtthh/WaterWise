extends Node

## ═══════════════════════════════════════════════════════════════════
## TUTORIALMANAGER.GD - First-Time Player Instructions & Hints
## ═══════════════════════════════════════════════════════════════════
## Provides:
## - Welcome popups for first-time players
## - Game-specific tutorials
## - Contextual hints
## - Progress-aware guidance
## ═══════════════════════════════════════════════════════════════════

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SIGNALS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

signal tutorial_started(game_id: String)
signal tutorial_completed(game_id: String)
signal hint_shown(hint_text: String)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TUTORIAL DATA (English + Filipino)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var tutorials: Dictionary = {
	"CatchTheRain": {
		"en": {
			"title": "Catch The Rain",
			"steps": [
				{ "text": "Move your bucket left and right to catch falling raindrops! 🌧️", "image": "" },
				{ "text": "Blue drops = +1 point ✅\nRed drops = -1 life ❌", "image": "" },
				{ "text": "Save as much rainwater as you can before time runs out!", "image": "" }
			],
			"tip": "Focus on the center - most drops fall there!"
		},
		"tl": {
			"title": "Saluhin ang Ulan",
			"steps": [
				{ "text": "Igalaw ang balde pakaliwa at pakanan para saluhin ang ulan! 🌧️", "image": "" },
				{ "text": "Asul na patak = +1 puntos ✅\nPula na patak = -1 buhay ❌", "image": "" },
				{ "text": "Mag-ipon ng maraming tubig-ulan bago maubos ang oras!", "image": "" }
			],
			"tip": "Tumuon sa gitna - karamihan ng patak ay nahuhulog doon!"
		}
	},
	"FixLeak": {
		"en": {
			"title": "Fix The Leak",
			"steps": [
				{ "text": "Tap on leaking pipes to fix them before water is wasted! 💧", "image": "" },
				{ "text": "Fix leaks quickly - they get worse over time!", "image": "" },
				{ "text": "Watch for new leaks appearing around the screen.", "image": "" }
			],
			"tip": "Prioritize the biggest leaks first!"
		},
		"tl": {
			"title": "Ayusin ang Tagas",
			"steps": [
				{ "text": "I-tap ang tumatagas na tubo para ayusin bago masayang ang tubig! 💧", "image": "" },
				{ "text": "Mabilis na ayusin - lumalala ang tagas sa oras!", "image": "" },
				{ "text": "Bantayan ang bagong tagas na lumilitaw.", "image": "" }
			],
			"tip": "Unahin ang malalaking tagas!"
		}
	},
	"GreywaterSorter": {
		"en": {
			"title": "Greywater Sorter",
			"steps": [
				{ "text": "Sort items by swiping! ⬆️⬇️", "image": "" },
				{ "text": "Swipe UP for items that can use GREYWATER 🌿", "image": "" },
				{ "text": "Swipe DOWN for items needing CLEAN water 🚿", "image": "" }
			],
			"tip": "Plants and gardens love greywater!"
		},
		"tl": {
			"title": "Pag-uuri ng Greywater",
			"steps": [
				{ "text": "Pag-uri-uriin sa pamamagitan ng pag-swipe! ⬆️⬇️", "image": "" },
				{ "text": "Swipe PATAAS para sa pwedeng gumamit ng GREYWATER 🌿", "image": "" },
				{ "text": "Swipe PABABA para sa kailangan ng MALINIS na tubig 🚿", "image": "" }
			],
			"tip": "Gusto ng mga halaman ang greywater!"
		}
	},
	"PlugTheLeak": {
		"en": {
			"title": "Plug The Leak",
			"steps": [
				{ "text": "Drag the correct plugs to seal leaking holes! 🔌", "image": "" },
				{ "text": "Match the plug shape to the hole shape.", "image": "" },
				{ "text": "Work fast before too much water escapes!", "image": "" }
			],
			"tip": "Look at the hole shape before grabbing a plug!"
		},
		"tl": {
			"title": "Takpan ang Tagas",
			"steps": [
				{ "text": "I-drag ang tamang takip para isara ang butas! 🔌", "image": "" },
				{ "text": "Itugma ang hugis ng takip sa hugis ng butas.", "image": "" },
				{ "text": "Bilisan bago masyadong maraming tubig ang masayang!", "image": "" }
			],
			"tip": "Tingnan muna ang hugis ng butas!"
		}
	},
	"SwipeTheSoap": {
		"en": {
			"title": "Swipe The Soap",
			"steps": [
				{ "text": "Swipe in patterns to wash efficiently! 🧼", "image": "" },
				{ "text": "Follow the arrow directions for bonus points!", "image": "" },
				{ "text": "Complete patterns quickly to save water!", "image": "" }
			],
			"tip": "Smooth, continuous swipes work best!"
		},
		"tl": {
			"title": "I-swipe ang Sabon",
			"steps": [
				{ "text": "Mag-swipe sa pattern para maghugas nang maayos! 🧼", "image": "" },
				{ "text": "Sundin ang direksyon ng arrow para sa bonus!", "image": "" },
				{ "text": "Kumpletuhin ang pattern nang mabilis para makatipid ng tubig!", "image": "" }
			],
			"tip": "Ang maayos at tuloy-tuloy na swipe ang pinakamabisa!"
		}
	},
	"QuickShower": {
		"en": {
			"title": "Quick Shower",
			"steps": [
				{ "text": "Tap body parts to wash them before time runs out! 🚿", "image": "" },
				{ "text": "Each part needs to be scrubbed 3 times.", "image": "" },
				{ "text": "Shorter showers save more water!", "image": "" }
			],
			"tip": "Start from top to bottom for efficiency!"
		},
		"tl": {
			"title": "Mabilis na Paligo",
			"steps": [
				{ "text": "I-tap ang bahagi ng katawan para hugasan bago maubos ang oras! 🚿", "image": "" },
				{ "text": "Bawat bahagi ay kailangang hugasan 3 beses.", "image": "" },
				{ "text": "Mas maikling paligo = mas maraming tubig na naiipon!", "image": "" }
			],
			"tip": "Magsimula sa itaas pababa para sa efficiency!"
		}
	},
	"TimingTap": {
		"en": {
			"title": "Timing Tap",
			"steps": [
				{ "text": "Tap when the indicator is in the GREEN zone! 🎯", "image": "" },
				{ "text": "Perfect timing = maximum water saved!", "image": "" },
				{ "text": "Miss the zone = water wasted.", "image": "" }
			],
			"tip": "Watch the rhythm - it gets faster!"
		},
		"tl": {
			"title": "Tamang Timing",
			"steps": [
				{ "text": "I-tap kapag nasa BERDE na zone ang indicator! 🎯", "image": "" },
				{ "text": "Perpektong timing = maximum na tubig na naiipon!", "image": "" },
				{ "text": "Sumala = nasayang na tubig.", "image": "" }
			],
			"tip": "Panoorin ang ritmo - bumibilis ito!"
		}
	},
	"TurnOffTap": {
		"en": {
			"title": "Turn Off The Tap",
			"steps": [
				{ "text": "Spot running taps and turn them off! 🚰", "image": "" },
				{ "text": "Tap the faucet handle to close it.", "image": "" },
				{ "text": "Don't let water run unnecessarily!", "image": "" }
			],
			"tip": "Check all corners of the room!"
		},
		"tl": {
			"title": "Isara ang Gripo",
			"steps": [
				{ "text": "Hanapin ang bukas na gripo at isara! 🚰", "image": "" },
				{ "text": "I-tap ang hawakan ng gripo para isara.", "image": "" },
				{ "text": "Huwag hayaang tumatakbo ang tubig nang walang saysay!", "image": "" }
			],
			"tip": "Tingnan ang lahat ng sulok ng kwarto!"
		}
	},
	## MULTIPLAYER: the first-play how-to-play beat
	## Keyed "mp_<game key>", where the game key is what
	## MultiplayerMiniGameBase._mp_game_key() derives from the script filename
	## (MP_WashCar.gd -> "wash_car"). Namespaced so it cannot collide with the eight
	## PascalCase singleplayer keys above, and so should_show_tutorial() /
	## mark_tutorial_shown() can hold both families in one shown_tutorials list.
	##
	## Three steps, in the same order for every game, because a first-timer needs them in
	## that order: what YOU do, what your PARTNER does with it, and what costs a life. The
	## middle one is the whole reason these exist - the every-round instruction blurb
	## already covers the action and the numbers, but nothing told a new player that the
	## thing they are catching is the thing the other player is waiting for, and a co-op
	## round where neither side knows that reads as two unrelated games.
	##
	## No emoji anywhere in this block, deliberately. The singleplayer entries above are
	## full of them and they render as "unknown character" boxes on the Android 8 test
	## phone; new copy does not add to that pile.
	"mp_catch_the_rain": {
		"en": {
			"title": "Catch The Rain",
			"steps": [
				{ "text": "Drag anywhere to slide your bucket under the falling raindrops. Left and right arrows work too.", "image": "" },
				{ "text": "Every drop you catch becomes water your partner filters clean. Their points and yours go to the same team meter.", "image": "" },
				{ "text": "Drops that reach the ground are misses. Too many and the team loses one of its three shared lives.", "image": "" }
			],
			"tip": "Park the bucket where the next drop will land instead of chasing the one already falling."
		},
		"tl": {
			"title": "Saluhin ang Ulan",
			"steps": [
				{ "text": "I-drag kahit saan para isalya ang timba sa ilalim ng bumabagsak na patak. Pwede rin ang kaliwa at kanan.", "image": "" },
				{ "text": "Bawat patak na masasalo ay tubig na sasalain ng kapareha mo. Isang team meter lang ang puntos ninyong dalawa.", "image": "" },
				{ "text": "Ang patak na tumama sa lupa ay miss. Kapag sumobra, mababawasan ang tatlong buhay ng team.", "image": "" }
			],
			"tip": "Ipwesto ang timba kung saan babagsak ang susunod na patak, huwag habulin ang kasalukuyang bumabagsak."
		}
	},
	"mp_filter_water": {
		"en": {
			"title": "Filter The Water",
			"steps": [
				{ "text": "Tap each speck of dirt in the water to filter it out. Every speck is points for the team.", "image": "" },
				{ "text": "The water arrives from your partner catching rain, so there is nothing to filter until they catch some.", "image": "" },
				{ "text": "Nothing is lost here if you are slow, but the team target needs both of you, so clear each unit fully.", "image": "" }
			],
			"tip": "Clearing every speck in one unit pays a bonus on top of the specks themselves."
		},
		"tl": {
			"title": "Salain ang Tubig",
			"steps": [
				{ "text": "I-tap ang bawat dumi sa tubig para masala. Bawat dumi ay puntos para sa team.", "image": "" },
				{ "text": "Galing sa kaparehang sumasalo ng ulan ang tubig, kaya wala pang sasalain hangga't wala siyang nasasalo.", "image": "" },
				{ "text": "Walang mawawala kung mabagal ka, pero kailangan kayong dalawa sa team target, kaya linisin nang buo ang yunit.", "image": "" }
			],
			"tip": "May dagdag na bonus kapag nalinis ang lahat ng dumi sa isang yunit."
		}
	},
	"mp_catch_rain_aquarium": {
		"en": {
			"title": "Catch Rain For The Aquarium",
			"steps": [
				{ "text": "Drag anywhere to slide your bucket under the raindrops before they reach the ground.", "image": "" },
				{ "text": "Every drop you catch is a load your partner pours into the aquarium. One team meter, both of your points.", "image": "" },
				{ "text": "Missed drops cost the team a shared life once enough of them have hit the ground.", "image": "" }
			],
			"tip": "Stay near the middle of the screen: most drops fall there."
		},
		"tl": {
			"title": "Salo ng Ulan para sa Aquarium",
			"steps": [
				{ "text": "I-drag kahit saan para isalya ang timba sa ilalim ng patak bago tumama sa lupa.", "image": "" },
				{ "text": "Bawat patak na masasalo ay ibubuhos ng kapareha mo sa aquarium. Isang team meter, puntos ninyong dalawa.", "image": "" },
				{ "text": "May mababawas na buhay ng team kapag sumobra ang patak na tumama sa lupa.", "image": "" }
			],
			"tip": "Manatili sa gitna ng screen: doon bumabagsak ang karamihan."
		}
	},
	"mp_fill_aquarium": {
		"en": {
			"title": "Fill The Aquarium",
			"steps": [
				{ "text": "Tap the aquarium to pour in one load of the rainwater your partner caught.", "image": "" },
				{ "text": "You cannot pour what has not arrived, so watch for your partner's water and pour it the moment it lands.", "image": "" },
				{ "text": "The water evaporates. If the tank sits empty for too long the team loses a shared life.", "image": "" }
			],
			"tip": "Pour as soon as a load arrives; saving them up is what lets the tank run dry."
		},
		"tl": {
			"title": "Punuin ang Aquarium",
			"steps": [
				{ "text": "I-tap ang aquarium para ibuhos ang tubig-ulang nasalo ng kapareha mo.", "image": "" },
				{ "text": "Hindi mo maibubuhos ang wala pa, kaya abangan ang tubig ng kapareha at ibuhos agad pagdating.", "image": "" },
				{ "text": "Nasisingaw ang tubig. Kapag matagal na walang laman, may mababawas na buhay ng team.", "image": "" }
			],
			"tip": "Ibuhos agad pagdating ng tubig; ang pag-iimbak ang nagpapatuyo sa tangke."
		}
	},
	"mp_collect_shower_water": {
		"en": {
			"title": "Collect Shower Water",
			"steps": [
				{ "text": "You have four buckets. Drag them under the shower water so none of it lands on the floor.", "image": "" },
				{ "text": "A full bucket sends its load to your partner, who needs it to flush the toilets.", "image": "" },
				{ "text": "A bucket left under the water after it fills overflows, and enough overflows cost the team a life.", "image": "" }
			],
			"tip": "Move a full bucket out of the stream first; an overflowing one is worse than an empty one."
		},
		"tl": {
			"title": "Kolektahin ang Tubig-Shower",
			"steps": [
				{ "text": "Apat ang timba mo. I-drag ang mga ito sa ilalim ng tubig-shower para walang matapon sa sahig.", "image": "" },
				{ "text": "Ang punong timba ay ipapadala sa kapareha mo, na kailangan iyon para maka-flush ng kubeta.", "image": "" },
				{ "text": "Umaapaw ang timbang puno na pero nasa ilalim pa ng tubig, at may mababawas na buhay kapag sumobra.", "image": "" }
			],
			"tip": "Ilabas muna sa buhos ang punong timba; mas masama ang umaapaw kaysa sa walang laman."
		}
	},
	"mp_flush_toilets": {
		"en": {
			"title": "Flush The Toilets",
			"steps": [
				{ "text": "Tap a dirty toilet to flush it. Each flush spends one load of your partner's shower water.", "image": "" },
				{ "text": "No water means no flush, so if nothing happens when you tap, your partner has not sent any yet.", "image": "" },
				{ "text": "A new toilet gets dirty every few seconds. Let too many pile up unflushed and the team loses a life.", "image": "" }
			],
			"tip": "Flush the one that has been dirty longest, not the one nearest your thumb."
		},
		"tl": {
			"title": "I-flush ang mga Kubeta",
			"steps": [
				{ "text": "I-tap ang maruming kubeta para i-flush. Bawat flush ay isang tubig-shower ng kapareha mo.", "image": "" },
				{ "text": "Walang tubig, walang flush. Kapag walang nangyari sa tap mo, wala pa siyang naipadala.", "image": "" },
				{ "text": "Tuwing ilang segundo may bagong kubetang dumudumi. Kapag nagsalansan ang hindi na-flush, mababawasan ng buhay.", "image": "" }
			],
			"tip": "Unahin ang pinakamatagal nang marumi, hindi ang pinakamalapit sa hinlalaki mo."
		}
	},
	"mp_collect_laundry_water": {
		"en": {
			"title": "Collect Laundry Water",
			"steps": [
				{ "text": "Slide your containers under the washing machine streams to catch the water coming out.", "image": "" },
				{ "text": "Every catch is water your partner mops the floor with, and points on the shared team meter.", "image": "" },
				{ "text": "A stream you do not catch is a miss, and enough misses cost the team a shared life.", "image": "" }
			],
			"tip": "Watch which machine is about to drain and be under it before it starts."
		},
		"tl": {
			"title": "Kolektahin ang Tubig-Labada",
			"steps": [
				{ "text": "Isalya ang mga lalagyan sa ilalim ng buga ng washing machine para masalo ang tubig.", "image": "" },
				{ "text": "Bawat salo ay tubig na ipapangmap ng kapareha mo, at puntos sa team meter.", "image": "" },
				{ "text": "Ang bugang hindi nasalo ay miss, at may mababawas na buhay ng team kapag sumobra.", "image": "" }
			],
			"tip": "Tingnan kung aling makina ang malapit nang magbuga at pumwesto na bago ito magsimula."
		}
	},
	"mp_mop_floor": {
		"en": {
			"title": "Mop The Floor",
			"steps": [
				{ "text": "Tap a dirty tile to mop it. Each tile costs one load of your partner's laundry water.", "image": "" },
				{ "text": "If a tap does nothing, there is no water yet - your partner is still collecting it.", "image": "" },
				{ "text": "Another tile gets dirty every few seconds. Too many dirty at once and the team loses a life.", "image": "" }
			],
			"tip": "Clear the tiles that went dirty first; the newest one has the most time left."
		},
		"tl": {
			"title": "Mapin ang Sahig",
			"steps": [
				{ "text": "I-tap ang maruming tiles para mapunasan. Bawat tiles ay isang tubig-labada ng kapareha mo.", "image": "" },
				{ "text": "Kapag walang nangyari sa tap, wala pang tubig - nagko-kolekta pa ang kapareha mo.", "image": "" },
				{ "text": "Tuwing ilang segundo may bagong tiles na dumudumi. Kapag sabay-sabay na marumi, mababawasan ng buhay.", "image": "" }
			],
			"tip": "Unahin ang tiles na naunang dumumi; mas maluwag pa ang oras ng pinakabago."
		}
	},
	"mp_collect_dish_water": {
		"en": {
			"title": "Collect Dish Water",
			"steps": [
				{ "text": "Drag your buckets under the drops coming off the dishes so none of them spill.", "image": "" },
				{ "text": "The water you catch goes straight to your partner, who is washing the car with it.", "image": "" },
				{ "text": "Every drop that hits the floor is a spill, and enough spills cost the team a shared life.", "image": "" }
			],
			"tip": "Keep one bucket under the busiest tap instead of moving all of them at once."
		},
		"tl": {
			"title": "Kolektahin ang Hugas-Plato",
			"steps": [
				{ "text": "I-drag ang mga timba sa ilalim ng tumutulo mula sa hugas-plato para walang matapon.", "image": "" },
				{ "text": "Ang tubig na masasalo mo ay dumidiretso sa kaparehang naghuhugas ng kotse.", "image": "" },
				{ "text": "Bawat patak na tumama sa sahig ay tapon, at may mababawas na buhay ng team kapag sumobra.", "image": "" }
			],
			"tip": "Iwan ang isang timba sa ilalim ng pinakamabilis na tulo, huwag igalaw lahat sabay-sabay."
		}
	},
	"mp_wash_car": {
		"en": {
			"title": "Wash The Car",
			"steps": [
				{ "text": "Tap a dirty section of the car to scrub it with your partner's dish water.", "image": "" },
				{ "text": "No water means the tap does nothing, so give your partner a moment to collect some.", "image": "" },
				{ "text": "A section left dirty for too long costs the team a shared life.", "image": "" }
			],
			"tip": "Finish one section before starting the next; a half-scrubbed panel still counts as dirty."
		},
		"tl": {
			"title": "Hugasan ang Kotse",
			"steps": [
				{ "text": "I-tap ang maruming parte ng kotse para kuskusin gamit ang hugas-plato ng kapareha mo.", "image": "" },
				{ "text": "Walang tubig, walang mangyayari sa tap. Bigyan ng sandali ang kapareha mong makasalo.", "image": "" },
				{ "text": "Ang parteng matagal nang marumi ay nagpapabawas ng buhay ng team.", "image": "" }
			],
			"tip": "Tapusin ang isang parte bago lumipat; ang kalahating kuskos ay marumi pa rin."
		}
	},
	"mp_wash_vegetables": {
		"en": {
			"title": "Wash The Vegetables",
			"steps": [
				{ "text": "Drag each vegetable into the sink to wash the dirt off it.", "image": "" },
				{ "text": "The dirty water from the sink goes to your partner, who uses it on the plants.", "image": "" },
				{ "text": "A vegetable you never wash is a miss, and enough misses cost the team a shared life.", "image": "" }
			],
			"tip": "Drag in a straight line to the sink; the long way round is what runs the clock out."
		},
		"tl": {
			"title": "Hugasan ang mga Gulay",
			"steps": [
				{ "text": "I-drag ang bawat gulay papunta sa lababo para maalis ang dumi.", "image": "" },
				{ "text": "Ang hugas sa lababo ay napupunta sa kaparehang gumagamit nito sa halaman.", "image": "" },
				{ "text": "Ang gulay na hindi nahugasan ay miss, at may mababawas na buhay ng team kapag sumobra.", "image": "" }
			],
			"tip": "I-drag nang diretso sa lababo; ang paliku-liko ang nag-uubos ng oras."
		}
	},
	"mp_water_plants": {
		"en": {
			"title": "Water The Plants",
			"steps": [
				{ "text": "Tap a plant to pour on it the water your partner sent over.", "image": "" },
				{ "text": "With no water in hand a tap does nothing, so wait for your partner's next load.", "image": "" },
				{ "text": "Plants wilt if they are ignored for a few seconds, and enough wilted plants cost the team a life.", "image": "" }
			],
			"tip": "Water the plant that is closest to wilting, not the one closest to your thumb."
		},
		"tl": {
			"title": "Diligan ang mga Halaman",
			"steps": [
				{ "text": "I-tap ang halaman para ibuhos ang tubig na ipinadala ng kapareha mo.", "image": "" },
				{ "text": "Kapag walang hawak na tubig, walang mangyayari sa tap. Hintayin ang susunod na padala.", "image": "" },
				{ "text": "Nalalanta ang halamang napapabayaan ng ilang segundo, at may mababawas na buhay kapag sumobra.", "image": "" }
			],
			"tip": "Diligan ang pinakamalapit nang malanta, hindi ang pinakamalapit sa hinlalaki mo."
		}
	}
}

# Welcome screens shown once per game
var shown_tutorials: Array[String] = []
const SHOWN_TUTORIALS_KEY := "shown_tutorials"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _get_save_manager() -> Node:
	return get_node_or_null("/root/SaveManager")

func _ready() -> void:
	_load_shown_tutorials()

func _load_shown_tutorials() -> void:
	var save_mgr = _get_save_manager()
	if save_mgr:
		var saved = save_mgr.get_setting(SHOWN_TUTORIALS_KEY, [])
		if saved is Array:
			for item in saved:
				shown_tutorials.append(str(item))

func _save_shown_tutorials() -> void:
	var save_mgr = _get_save_manager()
	if save_mgr:
		save_mgr.set_setting(SHOWN_TUTORIALS_KEY, shown_tutorials)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TUTORIAL DISPLAY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func should_show_tutorial(game_id: String) -> bool:
	# Check if tutorial should be shown for this game
	var save_mgr = _get_save_manager()
	if not save_mgr:
		return true
	return game_id not in shown_tutorials and save_mgr.get_setting("show_hints", true)

func mark_tutorial_shown(game_id: String) -> void:
	# Mark tutorial as shown (won't show again)
	if game_id not in shown_tutorials:
		shown_tutorials.append(game_id)
		_save_shown_tutorials()

func get_tutorial(game_id: String) -> Dictionary:
	# Get tutorial data for a specific game
	var lang := "en"
	if Localization and not Localization.is_english():
		lang = "tl"
	
	if tutorials.has(game_id):
		return tutorials[game_id].get(lang, tutorials[game_id].en)
	
	return {}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TUTORIAL POPUP CREATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func create_tutorial_popup(game_id: String, parent: Node) -> Control:
	# Create and return a tutorial popup for the given game
	var tutorial_data = get_tutorial(game_id)
	if tutorial_data.is_empty():
		return null
	
	tutorial_started.emit(game_id)
	
	# Create overlay
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.name = "TutorialOverlay"
	
	# Create panel
	#
	# NO set_anchors_preset(PRESET_CENTER) here. It used to be, and it is what put the
	# tutorial in the corner of a phone screen. PRESET_CENTER sets the four anchors to
	# 0.5 and then derives offsets from the CURRENT rect - and at this point the panel is
	# not in the tree and has no rect, so the offsets stayed 0. Anchors 0.5 with offsets 0
	# pin the panel's TOP-LEFT to the viewport centre and let the body grow right and
	# down from there. Measured with the geometry probe before the fix, at three shapes:
	#   1920x1080 -> panel at (960, 540), centre off by (300, 235)
	#   2400x1080 -> panel at (1200, 540), centre off by (300, 235)   <- the test phone
	#   1080x2400 -> panel at (960, 2133), centre off by (300, 235)
	# The offset is always exactly half the panel, i.e. the whole panel hangs off centre;
	# on the 2400-wide phone that is the far right, which is what was reported. The
	# overlay above escapes it only because PRESET_FULL_RECT writes zero offsets, which
	# happen to be the right answer, so it is correct out of the tree too.
	# It is centred by a CenterContainer further down instead - the same idiom
	# MultiplayerMiniGameBase already uses for its instruction overlay - which computes
	# the position from the real size at sort time and re-centres on every resize, so
	# device rotation and longer Tagalog strings cannot push it off screen again.
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 400)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.95)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_bottom", 25)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "📚 " + tutorial_data.title
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.2, 0.4, 0.8))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Steps container
	var steps_container = VBoxContainer.new()
	steps_container.add_theme_constant_override("separation", 12)
	vbox.add_child(steps_container)
	
	var steps = tutorial_data.get("steps", [])
	for i in range(steps.size()):
		var step = steps[i]
		var step_label = Label.new()
		step_label.text = str(i + 1) + ". " + step.text
		step_label.add_theme_font_size_override("font_size", 22)
		step_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
		step_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		steps_container.add_child(step_label)
	
	# Tip
	if tutorial_data.has("tip"):
		var tip_box = PanelContainer.new()
		var tip_style = StyleBoxFlat.new()
		tip_style.bg_color = Color(1.0, 0.95, 0.8)
		tip_style.corner_radius_top_left = 10
		tip_style.corner_radius_top_right = 10
		tip_style.corner_radius_bottom_left = 10
		tip_style.corner_radius_bottom_right = 10
		tip_box.add_theme_stylebox_override("panel", tip_style)
		
		var tip_margin = MarginContainer.new()
		tip_margin.add_theme_constant_override("margin_left", 15)
		tip_margin.add_theme_constant_override("margin_right", 15)
		tip_margin.add_theme_constant_override("margin_top", 10)
		tip_margin.add_theme_constant_override("margin_bottom", 10)
		tip_box.add_child(tip_margin)
		
		var tip_label = Label.new()
		tip_label.text = Localization.get_text("tutorial_tip_prefix") + tutorial_data.tip
		tip_label.add_theme_font_size_override("font_size", 18)
		tip_label.add_theme_color_override("font_color", Color(0.6, 0.4, 0.1))
		tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip_margin.add_child(tip_label)
		
		vbox.add_child(tip_box)
	
	# Start button
	var start_btn = Button.new()
	start_btn.text = Localization.get_text("start_game")
	start_btn.custom_minimum_size = Vector2(200, 60)
	start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.7, 0.3)
	btn_style.corner_radius_top_left = 15
	btn_style.corner_radius_top_right = 15
	btn_style.corner_radius_bottom_left = 15
	btn_style.corner_radius_bottom_right = 15
	start_btn.add_theme_stylebox_override("normal", btn_style)
	start_btn.add_theme_stylebox_override("hover", btn_style)
	start_btn.add_theme_font_size_override("font_size", 24)
	start_btn.add_theme_color_override("font_color", Color.WHITE)
	
	start_btn.pressed.connect(func():
		mark_tutorial_shown(game_id)
		tutorial_completed.emit(game_id)
		overlay.queue_free()
	)
	
	vbox.add_child(start_btn)
	
	# FULL_RECT is safe to preset before entering the tree (zero offsets), so the centring
	# frame is correct from the first frame and the panel gets a real centred rect on the
	# first sort. Named so a harness can find it.
	var centre: CenterContainer = CenterContainer.new()
	centre.name = "TutorialCentre"
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.add_child(panel)
	overlay.add_child(centre)
	parent.add_child(overlay)
	
	# Entrance animation
	overlay.modulate.a = 0
	panel.scale = Vector2(0.8, 0.8)
	# Scale about the panel's middle, not its top-left corner. pivot_offset defaults to 0,
	# so the 0.8 -> 1.0 entrance used to grow out of the corner; that was invisible while
	# the panel was mis-anchored and would be obvious now that it is centred. Driven off
	# resized rather than set once because the size is not known until the CenterContainer
	# sorts, and it changes again on rotation or a language switch.
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size * 0.5)
	var tween = overlay.create_tween()
	tween.set_parallel(true)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.3)
	# .from() is load-bearing, not decoration. A Container sort pass rewrites its child's
	# rect AND resets scale to (1,1); the first sort is queued the moment the panel is
	# added and runs before this tweener takes its first step, so a tweener that reads its
	# start value from the property found scale already back at (1,1) and animated 1 -> 1.
	# Measured: the alpha half ran (a0.00 -> a0.04 over 87ms at 0.1x time scale) while the
	# scale half read 1.000 on every one of 14 samples, at all three viewport shapes.
	# Pinning the start value makes the tween the sole author from frame 1; a later sort can
	# still clip a single frame, but its rest value (1,1) is this tween's end value, so it
	# cannot leave residue.
	var pop_in: PropertyTweener = tween.tween_property(panel, "scale", Vector2(1, 1), 0.3)
	pop_in.from(Vector2(0.8, 0.8))
	pop_in.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	return overlay

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONTEXTUAL HINTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Four bilingual coaching lines, one per performance state. NOTHING CALLS
## get_contextual_hint() BELOW, so none of these ever reaches a player today.
##
## They are kept rather than deleted with the rest of this file's dead code because they are
## authored educational content, not code: the same reachability gap that left the whole
## tutorial API uncalled until MiniGameBase._show_first_play_tutorial() was wired to it (see
## tools/VerifyFirstPlayTutorial). The states are already computed every round -
## _complete_game() has accuracy, reaction_time and mistakes_made, and AdaptiveDifficulty
## already derives the same signals for its own use - so the missing piece is a delivery
## surface, and that is a UI change, not a deletion. The old delivery function,
## show_hint_popup(), was removed: it built a background ColorRect it never added to the
## tree (an unparented Node, leaked on every call), sized it from label.size.x before
## layout so it was always 40 px wide, and tweened raw 0.3s durations that no reduced-motion
## setting could shorten.
var gameplay_hints: Dictionary = {
	"low_accuracy": {
		"en": "Take your time! Accuracy is more important than speed.",
		"tl": "Dahan-dahan lang! Mas importante ang tamang sagot kaysa sa bilis."
	},
	"too_slow": {
		"en": "Try to pick up the pace a little!",
		"tl": "Subukang bilisan ng kaunti!"
	},
	"losing_streak": {
		"en": "Don't give up! Practice makes perfect! 💪",
		"tl": "Huwag sumuko! Ang pagsasanay ang susi sa tagumpay! 💪"
	},
	"perfect_game": {
		"en": "Amazing! You're a water conservation expert! ⭐",
		"tl": "Kahanga-hanga! Ikaw ay eksperto sa pagtitipid ng tubig! ⭐"
	}
}

func get_contextual_hint(hint_type: String) -> String:
	# Get a hint based on player performance
	var lang := "en"
	if Localization and not Localization.is_english():
		lang = "tl"
	
	if gameplay_hints.has(hint_type):
		var hint = gameplay_hints[hint_type].get(lang, gameplay_hints[hint_type].en)
		hint_shown.emit(hint)
		return hint
	
	return ""

