#define EMPTY 0
#define WIRED 1
#define READY 2

/obj/item/weapon/grenade/chem_grenade
	name = "granada vazia"
	desc = "Uma granada vazia pra voce mesmo fazer a sua!"
	icon_state = "chemg"
	item_state = "flashbang"
	var/bomb_state = "chembomb"
	var/payload_name = null // used for spawned grenades
	w_class = WEIGHT_CLASS_SMALL
	force = 2
	var/prime_sound = 'sound/items/Screwdriver2.ogg'
	var/stage = EMPTY
	var/list/beakers = list()
	var/list/allowed_containers = list(/obj/item/weapon/reagent_containers/glass/beaker, /obj/item/weapon/reagent_containers/glass/bottle)
	var/affected_area = 3
	var/obj/item/device/assembly_holder/nadeassembly = null
	var/label = null
	var/assemblyattacher
	var/ignition_temp = 10 // The amount of heat added to the reagents when this grenade goes off.
	var/threatscale = 1 // Used by advanced grenades to make them slightly more worthy.
	var/no_splash = FALSE //If the grenade deletes even if it has no reagents to splash with. Used for slime core reactions.

/obj/item/weapon/grenade/chem_grenade/New()
	create_reagents(1000)
	if(payload_name)
		payload_name += " " // formatting, ignore me
	update_icon()

/obj/item/weapon/grenade/chem_grenade/Destroy()
	QDEL_NULL(nadeassembly)
	QDEL_LIST(beakers)
	return ..()

/obj/item/weapon/grenade/chem_grenade/examine(mob/user)
	..(user)
	display_timer = (stage == READY && !nadeassembly)	//show/hide the timer based on assembly state



/obj/item/weapon/grenade/chem_grenade/proc/get_trigger()
	if(!nadeassembly) return null
	for(var/obj/O in list(nadeassembly.a_left, nadeassembly.a_right))
		if(!O || istype(O,/obj/item/device/assembly/igniter)) continue
		return O
	return null


/obj/item/weapon/grenade/chem_grenade/proc/update_overlays()
	underlays = list()
	if(nadeassembly)
		underlays += "[nadeassembly.a_left.icon_state]_left"
		for(var/O in nadeassembly.a_left.attached_overlays)
			underlays += "[O]_l"
		underlays += "[nadeassembly.a_right.icon_state]_right"
		for(var/O in nadeassembly.a_right.attached_overlays)
			underlays += "[O]_r"

/obj/item/weapon/grenade/chem_grenade/update_icon()
	if(nadeassembly)
		icon = 'icons/obj/assemblies/new_assemblies.dmi'
		icon_state = bomb_state
		update_overlays()
		var/obj/item/device/assembly/A = get_trigger()
		if(stage != READY)
			name = "bomb casing[label]"
		else
			if(!A)
				name = "[payload_name]de-fused bomb[label]" // this should not actually happen
			else
				name = payload_name + A.bomb_name + label // time bombs, remote mines, etc
	else
		icon = 'icons/obj/grenade.dmi'
		icon_state = initial(icon_state)
		overlays = list()
		switch(stage)
			if(EMPTY)
				name = "granada vazia[label]"
			if(WIRED)
				icon_state += "_ass"
				name = "granada vazia[label]"
			if(READY)
				if(active)
					icon_state += "_active"
				else
					icon_state += "_locked"
				name = payload_name + "granada" + label


/obj/item/weapon/grenade/chem_grenade/attack_self(mob/user)
	if(stage == READY &&  !active)
		var/turf/bombturf = get_turf(src)
		var/area/A = get_area(bombturf)
		if(nadeassembly)
			nadeassembly.attack_self(user)
			update_icon()
		else if(clown_check(user))
			// This used to go before the assembly check, but that has absolutely zero to do with priming the damn thing.  You could spam the admins with it.
			message_admins("[key_name_admin(usr)] has primed a [name] for detonation at <A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[bombturf.x];Y=[bombturf.y];Z=[bombturf.z]'>[A.name] (JMP)</a>")
			log_game("[key_name(usr)] has primed a [name] for detonation at [A.name] ([bombturf.x],[bombturf.y],[bombturf.z])")
			bombers += "[key_name(usr)] has primed a [name] for detonation at [A.name] ([bombturf.x],[bombturf.y],[bombturf.z])"
			to_chat(user, "<span class='warning'>You prime the [name]! [det_time / 10] second\s!</span>")
			playsound(user.loc, 'sound/weapons/armbomb.ogg', 60, 1)
			active = 1
			update_icon()
			if(iscarbon(user))
				var/mob/living/carbon/C = user
				C.throw_mode_on()
			spawn(det_time)
				prime()

/obj/item/weapon/grenade/hit_reaction(mob/living/carbon/human/owner, attack_text, final_block_chance, damage, attack_type)
	if(damage && attack_type == PROJECTILE_ATTACK && prob(15))
		owner.visible_message("<span class='danger'>[attack_text] hits [owner]'s [src], setting it off! What a shot!</span>")
		prime()
		return 1 //It hit the grenade, not them

/obj/item/weapon/grenade/chem_grenade/attackby(obj/item/I, mob/user, params)
	if(istype(I,/obj/item/weapon/hand_labeler))
		var/obj/item/weapon/hand_labeler/HL = I
		if(length(HL.label))
			label = " ([HL.label])"
			return 0
		else
			if(label)
				label = null
				update_icon()
				to_chat(user, "Voce remove o rotulo de/da [src].")
				return 1
	if(istype(I, /obj/item/weapon/screwdriver))
		if(stage == WIRED)
			if(beakers.len)
				to_chat(user, "<span class='notice'>Voce bloqueia a montagem.</span>")
				playsound(loc, prime_sound, 25, -3)
				stage = READY
				update_icon()
				var/contained = ""
				var/cores = ""
				for(var/obj/O in beakers)
					if(!O.reagents) continue
					if(istype(O,/obj/item/slime_extract))
						cores += " [O]"
					for(var/reagent in O.reagents.reagent_list)
						contained += " [reagent] "
				if(contained)
					if(cores)
						contained = "\[[cores];[contained]\]"
					else
						contained = "\[[contained]\]"
				var/turf/bombturf = get_turf(loc)
				var/area/A = bombturf.loc
				message_admins("[key_name_admin(usr)] completou [name] at <A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[bombturf.x];Y=[bombturf.y];Z=[bombturf.z]'>[A.name] (JMP)</a> [contained].")
				log_game("[key_name(usr)] completou [name] at [bombturf.x], [bombturf.y], [bombturf.z]. [contained]")
			else
				to_chat(user, "<span class='notice'>Voce precisa adicionar pelo menos um beaker antes de bloquear a montagem.</span>")
		else if(stage == READY && !nadeassembly)
			det_time = det_time == 50 ? 30 : 50	//toggle between 30 and 50
			to_chat(user, "<span class='notice'>Voce modifica o delay. Esta na posiçao de detonaçao de [det_time / 10] second\s.</span>")
		else if(stage == EMPTY)
			to_chat(user, "<span class='notice'>Voce precisa adicionar um mechanismo de detonaçao.</span>")

	else if(stage == WIRED && is_type_in_list(I, allowed_containers))
		if(beakers.len == 2)
			to_chat(user, "<span class='notice'>[src] nao consegue aguentar mais beakers.</span>")
			return
		else
			if(I.reagents.total_volume)
				to_chat(user, "<span class='notice'>Voce adiciona [I] para a montagem.</span>")
				user.drop_item()
				I.loc = src
				beakers += I
			else
				to_chat(user, "<span class='notice'>[I] esta vazio.</span>")

	else if(stage == EMPTY && istype(I, /obj/item/device/assembly_holder))
		var/obj/item/device/assembly_holder/A = I
		if(!A.secured)
			return
		if(isigniter(A.a_left) == isigniter(A.a_right))	//Check if either part of the assembly has an igniter, but if both parts are igniters, then fuck it
			return

		user.drop_item()
		nadeassembly = A
		A.master = src
		A.loc = src
		assemblyattacher = user.ckey
		stage = WIRED
		to_chat(user, "<span class='notice'>Voce adiciona [A] para [src]!</span>")
		update_icon()

	else if(stage == EMPTY && istype(I, /obj/item/stack/cable_coil))
		var/obj/item/stack/cable_coil/C = I
		C.use(1)

		stage = WIRED
		to_chat(user, "<span class='notice'>You rig [src].</span>")
		update_icon()

	else if(stage == READY && istype(I, /obj/item/weapon/wirecutters))
		to_chat(user, "<span class='notice'>Voce desbloqueia a montagem.</span>")
		stage = WIRED
		update_icon()

	else if(stage == WIRED && istype(I, /obj/item/weapon/wrench))
		to_chat(user, "<span class='notice'>Voce abre a granada e remove os conteudos.</span>")
		stage = EMPTY
		payload_name = null
		label = null
		if(nadeassembly)
			nadeassembly.loc = get_turf(src)
			nadeassembly.master = null
			nadeassembly = null
		if(beakers.len)
			for(var/obj/O in beakers)
				O.loc = get_turf(src)
			beakers = list()
		update_icon()


//assembly stuff
/obj/item/weapon/grenade/chem_grenade/receive_signal()
	prime()

/obj/item/weapon/grenade/chem_grenade/HasProximity(atom/movable/AM)
	if(nadeassembly)
		nadeassembly.HasProximity(AM)

/obj/item/weapon/grenade/chem_grenade/Move() // prox sensors and infrared care about this
	..()
	if(nadeassembly)
		nadeassembly.process_movement()

/obj/item/weapon/grenade/chem_grenade/pickup()
	..()
	if(nadeassembly)
		nadeassembly.process_movement()

/obj/item/weapon/grenade/chem_grenade/Crossed(atom/movable/AM)
	if(nadeassembly)
		nadeassembly.Crossed(AM)

/obj/item/weapon/grenade/chem_grenade/on_found(mob/finder)
	if(nadeassembly)
		nadeassembly.on_found(finder)

/obj/item/weapon/grenade/chem_grenade/hear_talk(mob/living/M, msg)
	if(nadeassembly)
		nadeassembly.hear_talk(M, msg)

/obj/item/weapon/grenade/chem_grenade/hear_message(mob/living/M, msg)
	if(nadeassembly)
		nadeassembly.hear_message(M, msg)

/obj/item/weapon/grenade/chem_grenade/Bump()
	..()
	if(nadeassembly)
		nadeassembly.process_movement()

/obj/item/weapon/grenade/chem_grenade/throw_impact() // called when a throw stops
	..()
	if(nadeassembly)
		nadeassembly.process_movement()


/obj/item/weapon/grenade/chem_grenade/prime()
	if(stage != READY)
		return

	var/list/datum/reagents/reactants = list()
	for(var/obj/item/weapon/reagent_containers/glass/G in beakers)
		reactants += G.reagents

	if(!chem_splash(get_turf(src), affected_area, reactants, ignition_temp, threatscale) && !no_splash)
		playsound(loc, 'sound/items/Screwdriver2.ogg', 50, 1)
		if(beakers.len)
			for(var/obj/O in beakers)
				O.forceMove(get_turf(src))
			beakers = list()
		stage = EMPTY
		update_icon()
		return

	if(nadeassembly)
		var/mob/M = get_mob_by_ckey(assemblyattacher)
		var/mob/last = get_mob_by_ckey(nadeassembly.fingerprintslast)
		var/turf/T = get_turf(src)
		var/area/A = get_area(T)
		message_admins("grenade primed by an assembly, attached by [key_name_admin(M)]<A HREF='?_src_=holder;adminmoreinfo=\ref[M]'>(?)</A> ([admin_jump_link(M)]) and last touched by [key_name_admin(last)]<A HREF='?_src_=holder;adminmoreinfo=\ref[last]'>(?)</A> ([admin_jump_link(last)]) ([nadeassembly.a_left.name] and [nadeassembly.a_right.name]) at <A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[T.x];Y=[T.y];Z=[T.z]'>[A.name] (JMP)</a>.")
		log_game("grenade primed by an assembly, attached by [key_name(M)] and last touched by [key_name(last)] ([nadeassembly.a_left.name] and [nadeassembly.a_right.name]) at [A.name] ([T.x], [T.y], [T.z])")

	update_mob()

	qdel(src)

/obj/item/weapon/grenade/chem_grenade/proc/CreateDefaultTrigger(var/typekey)
	if(ispath(typekey,/obj/item/device/assembly))
		nadeassembly = new(src)
		nadeassembly.a_left = new /obj/item/device/assembly/igniter(nadeassembly)
		nadeassembly.a_left.holder = nadeassembly
		nadeassembly.a_left.secured = 1
		nadeassembly.a_right = new typekey(nadeassembly)
		if(!nadeassembly.a_right.secured)
			nadeassembly.a_right.toggle_secure() // necessary because fuxing prock_sensors
		nadeassembly.a_right.holder = nadeassembly
		nadeassembly.secured = 1
		nadeassembly.master = src
		nadeassembly.update_icon()
		stage = READY
		update_icon()


//Large chem grenades accept slime cores and use the appropriately.
/obj/item/weapon/grenade/chem_grenade/large
	name = "large grenade casing"
	desc = "Uma granada vazia bem grande, Ela afeta uma area maior."
	icon_state = "large_grenade"
	bomb_state = "largebomb"
	allowed_containers = list(/obj/item/weapon/reagent_containers/glass,/obj/item/weapon/reagent_containers/food/condiment,
								/obj/item/weapon/reagent_containers/food/drinks)
	origin_tech = "combat=3;engineering=3"
	affected_area = 5
	ignition_temp = 25 // Large grenades are slightly more effective at setting off heat-sensitive mixtures than smaller grenades.
	threatscale = 1.1	// 10% more effective.

/obj/item/weapon/grenade/chem_grenade/large/prime()
	if(stage != READY)
		return

	for(var/obj/item/slime_extract/S in beakers)
		if(S.Uses)
			for(var/obj/item/weapon/reagent_containers/glass/G in beakers)
				G.reagents.trans_to(S, G.reagents.total_volume)

			//If there is still a core (sometimes it's used up)
			//and there are reagents left, behave normally,
			//otherwise drop it on the ground for timed reactions like gold.

			if(S)
				if(S.reagents && S.reagents.total_volume)
					for(var/obj/item/weapon/reagent_containers/glass/G in beakers)
						S.reagents.trans_to(G, S.reagents.total_volume)
				else
					S.forceMove(get_turf(src))
					no_splash = TRUE
	..()


	//I tried to just put it in the allowed_containers list but
	//if you do that it must have reagents.  If you're going to
	//make a special case you might as well do it explicitly. -Sayu
/obj/item/weapon/grenade/chem_grenade/large/attackby(obj/item/I, mob/user, params)
	if(istype(I, /obj/item/slime_extract) && stage == WIRED)
		to_chat(user, "<span class='notice'>You add [I] to the assembly.</span>")
		user.drop_item()
		I.loc = src
		beakers += I
	else
		return ..()

/obj/item/weapon/grenade/chem_grenade/cryo // Intended for rare cryogenic mixes. Cools the area moderately upon detonation.
	name = "granada cryogenica"
	desc = "Uma granada cryogenica, Ela rapidamente esfria quaisquer conteudos na detonaçao."
	icon_state = "cryog"
	affected_area = 2
	ignition_temp = -100

/obj/item/weapon/grenade/chem_grenade/pyro // Intended for pyrotechnical mixes. Produces a small fire upon detonation, igniting potentially flammable mixtures.
	name = "granada pyrotechnica"
	desc = "Uma granada pyrotechnica, Ela aquece e ativa quaisquer conteudos na detonaçao."
	icon_state = "pyrog"
	origin_tech = "combat=4;engineering=4"
	affected_area = 3
	ignition_temp = 500 // This is enough to expose a hotspot.

/obj/item/weapon/grenade/chem_grenade/adv_release // Intended for weaker, but longer lasting effects. Could have some interesting uses.
	name = "advanced release grenade"
	desc = "A custom made advanced release grenade. It is able to be detonated more than once. Can be configured using a multitool."
	icon_state = "timeg"
	origin_tech = "combat=3;engineering=4"
	var/unit_spread = 10 // Amount of units per repeat. Can be altered with a multitool.

/obj/item/weapon/grenade/chem_grenade/adv_release/attackby(obj/item/I, mob/user, params)
	if(ismultitool(I))
		switch(unit_spread)
			if(0 to 24)
				unit_spread += 5
			if(25 to 99)
				unit_spread += 25
			else
				unit_spread = 5
		to_chat(user, "<span class='notice'> You set the time release to [unit_spread] units per detonation.</span>")
		return
	..()

/obj/item/weapon/grenade/chem_grenade/adv_release/prime()
	if(stage != READY)
		return

	var/total_volume = 0
	for(var/obj/item/weapon/reagent_containers/RC in beakers)
		total_volume += RC.reagents.total_volume
	if(!total_volume)
		qdel(src)
		qdel(nadeassembly)
		return
	var/fraction = unit_spread/total_volume
	var/datum/reagents/reactants = new(unit_spread)
	reactants.my_atom = src
	for(var/obj/item/weapon/reagent_containers/RC in beakers)
		RC.reagents.trans_to(reactants, RC.reagents.total_volume*fraction, threatscale, 1, 1)
	chem_splash(get_turf(src), affected_area, list(reactants), ignition_temp, threatscale)

	if(nadeassembly)
		var/mob/M = get_mob_by_ckey(assemblyattacher)
		var/mob/last = get_mob_by_ckey(nadeassembly.fingerprintslast)
		var/turf/T = get_turf(src)
		var/area/A = get_area(T)
		message_admins("grenade primed by an assembly, attached by [key_name_admin(M)]<A HREF='?_src_=holder;adminmoreinfo=\ref[M]'>(?)</A> (<A HREF='?_src_=holder;adminplayerobservefollow=\ref[M]'>FLW</A>) and last touched by [key_name_admin(last)]<A HREF='?_src_=holder;adminmoreinfo=\ref[last]'>(?)</A> (<A HREF='?_src_=holder;adminplayerobservefollow=\ref[last]'>FLW</A>) ([nadeassembly.a_left.name] and [nadeassembly.a_right.name]) at <A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[T.x];Y=[T.y];Z=[T.z]'>[A.name] (JMP)</a>.")
		log_game("grenade primed by an assembly, attached by [key_name(M)] and last touched by [key_name(last)] ([nadeassembly.a_left.name] and [nadeassembly.a_right.name]) at [A.name] ([T.x], [T.y], [T.z])")
	else
		addtimer(src, "prime", det_time)
	var/turf/DT = get_turf(src)
	var/area/DA = get_area(DT)
	log_game("A grenade detonated at [DA.name] ([DT.x], [DT.y], [DT.z])")

/obj/item/weapon/grenade/chem_grenade/metalfoam
	payload_name = "granada espumenta"
	desc = "Usado para selar quaisquer brechas."
	stage = READY

	New()
		..()
		var/obj/item/weapon/reagent_containers/glass/beaker/B1 = new(src)
		var/obj/item/weapon/reagent_containers/glass/beaker/B2 = new(src)

		B1.reagents.add_reagent("aluminum", 30)
		B2.reagents.add_reagent("fluorosurfactant", 10)
		B2.reagents.add_reagent("sacid", 10)

		beakers += B1
		beakers += B2
		update_icon()


/obj/item/weapon/grenade/chem_grenade/incendiary
	payload_name = "granada incendiaria"
	desc = "Limpa tudo que e vivo."
	stage = READY

	New()
		..()
		var/obj/item/weapon/reagent_containers/glass/beaker/large/B1 = new(src)
		var/obj/item/weapon/reagent_containers/glass/beaker/large/B2 = new(src)

		B1.reagents.add_reagent("phosphorus", 25)
		B2.reagents.add_reagent("plasma", 25)
		B2.reagents.add_reagent("sacid", 25)


		beakers += B1
		beakers += B2
		update_icon()


/obj/item/weapon/grenade/chem_grenade/antiweed
	payload_name = "weed killer"
	desc = "Used for purging large areas of invasive plant species. Contents under pressure. Do not directly inhale contents."
	stage = READY

	New()
		..()
		var/obj/item/weapon/reagent_containers/glass/beaker/B1 = new(src)
		var/obj/item/weapon/reagent_containers/glass/beaker/B2 = new(src)

		B1.reagents.add_reagent("atrazine", 30)
		B1.reagents.add_reagent("potassium", 20)
		B2.reagents.add_reagent("phosphorus", 20)
		B2.reagents.add_reagent("sugar", 20)
		B2.reagents.add_reagent("atrazine", 10)

		beakers += B1
		beakers += B2
		update_icon()


/obj/item/weapon/grenade/chem_grenade/cleaner
	payload_name = "granada purificadora"
	desc = "BLAM!-space cleaner em forma de granada. em um aplicador especial para limpagem rapida em areas grandes."
	stage = READY

	New()
		..()
		var/obj/item/weapon/reagent_containers/glass/beaker/B1 = new(src)
		var/obj/item/weapon/reagent_containers/glass/beaker/B2 = new(src)

		B1.reagents.add_reagent("fluorosurfactant", 40)
		B2.reagents.add_reagent("cleaner", 10)
		B2.reagents.add_reagent("water", 40) //when you make pre-designed foam reactions that carry the reagents, always add water last

		beakers += B1
		beakers += B2
		update_icon()


/obj/item/weapon/grenade/chem_grenade/teargas
	payload_name = "gas lacrimogenio"
	desc = "Usado para controle nao letal. Conteudo sobre pressao. Nao inale o conteudo diretamente."
	stage = READY

	New()
		..()
		var/obj/item/weapon/reagent_containers/glass/beaker/B1 = new(src)
		var/obj/item/weapon/reagent_containers/glass/beaker/B2 = new(src)

		B1.reagents.add_reagent("condensedcapsaicin", 25)
		B1.reagents.add_reagent("potassium", 25)
		B2.reagents.add_reagent("phosphorus", 25)
		B2.reagents.add_reagent("sugar", 25)

		beakers += B1
		beakers += B2
		update_icon()

/obj/item/weapon/grenade/chem_grenade/facid
	name = "granada acida"
	desc = "Usado para derreter oponentes armadurados."
	stage = READY

/obj/item/weapon/grenade/chem_grenade/facid/New()
	..()
	var/obj/item/weapon/reagent_containers/glass/beaker/bluespace/B1 = new(src)
	var/obj/item/weapon/reagent_containers/glass/beaker/bluespace/B2 = new(src)

	B1.reagents.add_reagent("facid", 280)
	B1.reagents.add_reagent("potassium", 20)
	B2.reagents.add_reagent("phosphorus", 20)
	B2.reagents.add_reagent("sugar", 20)
	B2.reagents.add_reagent("facid", 260)

	beakers += B1
	beakers += B2
	update_icon()

/obj/item/weapon/grenade/chem_grenade/saringas
	payload_name = "saringas"
	desc = "Contains sarin gas; extremely deadly and fast acting; use with extreme caution."
	stage = READY

	New()
		..()
		var/obj/item/weapon/reagent_containers/glass/beaker/B1 = new(src)
		var/obj/item/weapon/reagent_containers/glass/beaker/B2 = new(src)

		B1.reagents.add_reagent("sarin", 25)
		B1.reagents.add_reagent("potassium", 25)
		B2.reagents.add_reagent("phosphorus", 25)
		B2.reagents.add_reagent("sugar", 25)

		beakers += B1
		beakers += B2
		update_icon()

#undef EMPTY
#undef WIRED
#undef READY
