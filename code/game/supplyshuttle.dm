//Config stuff
#define SUPPLY_DOCKZ 2          //Z-level of the Dock.
#define SUPPLY_STATIONZ 1       //Z-level of the Station.
#define SUPPLY_STATION_AREATYPE "/area/supply/station" //Type of the supply shuttle area for station
#define SUPPLY_DOCK_AREATYPE "/area/supply/dock"	//Type of the supply shuttle area for dock
#define SUPPLY_COST_MULTIPLIER 1.08
#define ASRS_COST_MULTIPLIER 1.2

var/datum/controller/supply/supply_controller = new()

var/list/mechtoys = list(
	/obj/item/toy/prize/ripley,
	/obj/item/toy/prize/fireripley,
	/obj/item/toy/prize/deathripley,
	/obj/item/toy/prize/gygax,
	/obj/item/toy/prize/durand,
	/obj/item/toy/prize/honk,
	/obj/item/toy/prize/marauder,
	/obj/item/toy/prize/seraph,
	/obj/item/toy/prize/mauler,
	/obj/item/toy/prize/odysseus,
	/obj/item/toy/prize/phazon
)

/area/supply/station //DO NOT TURN THE lighting_use_dynamic STUFF ON FOR SHUTTLES. IT BREAKS THINGS.
	name = "Supply Shuttle"
	icon_state = "shuttle3"
	luminosity = 1
	lighting_use_dynamic = 0
	requires_power = 0

/area/supply/dock //DO NOT TURN THE lighting_use_dynamic STUFF ON FOR SHUTTLES. IT BREAKS THINGS.
	name = "Supply Shuttle"
	icon_state = "shuttle3"
	luminosity = 1
	lighting_use_dynamic = 0
	requires_power = 0

//SUPPLY PACKS MOVED TO /code/defines/obj/supplypacks.dm

/obj/structure/plasticflaps //HOW DO YOU CALL THOSE THINGS ANYWAY
	name = "\improper plastic flaps"
	desc = "Completely impassable - or are they?"
	icon = 'icons/obj/stationobjs.dmi' //Change this.
	icon_state = "plasticflaps"
	density = 0
	anchored = 1
	layer = MOB_LAYER
	explosion_resistance = 5

/obj/structure/plasticflaps/CanPass(atom/A, turf/T)
	if(istype(A) && A.checkpass(PASSGLASS))
		return prob(60)

	var/obj/structure/bed/B = A
	if (istype(A, /obj/structure/bed) && B.buckled_mob)//if it's a bed/chair and someone is buckled, it will not pass
		return 0

	if(istype(A, /obj/vehicle))	//no vehicles
		return 0

	if(istype(A, /mob/living)) // You Shall Not Pass!
		var/mob/living/M = A
		if(!M.lying && !istype(M, /mob/living/carbon/monkey) && !istype(M, /mob/living/simple_animal/mouse) && !istype(M, /mob/living/silicon/robot/drone))  //If your not laying down, or a small creature, no pass.
			return 0
	return ..()

/obj/structure/plasticflaps/ex_act(severity)
	switch(severity)
		if(0 to EXPLOSION_THRESHOLD_LOW)
			if (prob(5))
				cdel(src)
		if(EXPLOSION_THRESHOLD_LOW to EXPLOSION_THRESHOLD_MEDIUM)
			if (prob(50))
				cdel(src)
		if(EXPLOSION_THRESHOLD_MEDIUM to INFINITY)
			cdel(src)

/obj/structure/plasticflaps/mining //A specific type for mining that doesn't allow airflow because of them damn crates
	name = "\improper Airtight plastic flaps"
	desc = "Heavy duty, airtight, plastic flaps."


/obj/machinery/computer/supplycomp
	name = "ASRS console"
	desc = "A console for an Automated Storage and Retrieval System"
	icon = 'icons/obj/machines/computer.dmi'
	icon_state = "supply"
	req_access = list(ACCESS_MARINE_CARGO)
	circuit = "/obj/item/circuitboard/computer/supplycomp"
	var/temp = null
	var/reqtime = 0 //Cooldown for requisitions - Quarxink
	var/hacked = 0
	var/can_order_contraband = 0
	var/last_viewed_group = "categories"

/obj/machinery/computer/ordercomp
	name = "Supply ordering console"
	icon = 'icons/obj/machines/computer.dmi'
	icon_state = "request"
	circuit = "/obj/item/circuitboard/computer/ordercomp"
	var/temp = null
	var/reqtime = 0 //Cooldown for requisitions - Quarxink
	var/last_viewed_group = "categories"

/obj/machinery/computer/supply_drop_console
	name = "Supply Drop Console"
	desc = "An old fashioned computer hooked into the nearby Supply Drop system."
	icon_state = "security_cam"
	circuit = null
	req_access = list(ACCESS_MARINE_CARGO)
	var/x_supply = 0
	var/y_supply = 0
	var/datum/squad/current_squad = null
	var/busy = 0 //The computer is busy launching a drop, lock controls
	var/drop_cooldown = 5000
	var/can_pick_squad = TRUE

/obj/machinery/computer/supply_drop_console/attack_hand(mob/user)
	if(..())  //Checks for power outages
		return
	if(!allowed(user))
		user << "<span class='warning'>Access denied.</span>"
		return 1
	user.set_interaction(src)
	var/dat = "<head><title>Supply Drop Console Console</title></head><body>"

	if(can_pick_squad)
		if(!current_squad) //No squad has been set yet. Pick one.
			dat += "Current Squad: <A href='?src=\ref[src];operation=pick_squad'>----------</A><BR>"
		else
			dat += "Current Squad: [current_squad.name] Squad</A><A href='?src=\ref[src];operation=pick_squad'>\[Change\]</A><BR>"

	dat += "<BR><B>Supply Drop Control</B><BR><BR>"
	if(!current_squad)
		dat += "No squad selected!"
	else
		dat += "<B>Current Supply Drop Status:</B> "
		var/cooldown_left = (current_squad.supply_cooldown + drop_cooldown) - world.time
		if(cooldown_left > 0)
			dat += "Launch tubes resetting ([round(cooldown_left/10)] seconds)<br>"
		else
			dat += "<font color='green'>Ready!</font><br>"
		dat += "<B>Launch Pad Status:</b> "
		var/obj/structure/closet/crate/C = locate() in current_squad.drop_pad.loc
		if(C)
			dat += "<font color='green'>Supply crate loaded</font><BR>"
		else
			dat += "Empty<BR>"
		dat += "<B>Longitude:</B> [x_supply] <A href='?src=\ref[src];operation=supply_x'>\[Change\]</a><BR>"
		dat += "<B>Latitude:</B> [y_supply] <A href='?src=\ref[src];operation=supply_y'>\[Change\]</a><BR><BR>"
		dat += "<A href='?src=\ref[src];operation=dropsupply'>\[LAUNCH!\]</a>"
	dat += "<BR><BR>----------------------<br>"
	dat += "<A href='?src=\ref[src];operation=refresh'>{Refresh}</a><br>"

	user << browse(dat, "window=overwatch;size=550x550")
	return

/obj/machinery/computer/supply_drop_console/Topic(href, href_list)
	if(..())  //Checks for power outages
		return
	if(!href_list["operation"])
		return
	switch(href_list["operation"])
		if("pick_squad")
			if(can_pick_squad)
				var/list/squad_list = list()
				for(var/datum/squad/S in RoleAuthority.squads)
					if(S.usable)
						squad_list += S.name

				var/name_sel = input("Which squad would you like to claim for Overwatch?") as null|anything in squad_list
				if(!name_sel) return
				var/datum/squad/selected = get_squad_by_name(name_sel)
				if(selected)
					current_squad = selected
					attack_hand(usr)
					if(!current_squad.drop_pad) //Why the hell did this not link?
						for(var/obj/structure/supply_drop/S in item_list)
							S.force_link() //LINK THEM ALL!
				else
					usr << "\icon[src] <span class='warning'>Invalid input. Aborting.</span>"
		if("supply_x")
			var/input = input(usr,"What longitude should be targetted? (Increments towards the east)", "X Coordinate", 0) as num
			usr << "\icon[src] <span class='notice'>Longitude is now [input].</span>"
			x_supply = input
		if("supply_y")
			var/input = input(usr,"What latitude should be targetted? (Increments towards the north)", "Y Coordinate", 0) as num
			usr << "\icon[src] <span class='notice'>Latitude is now [input].</span>"
			y_supply = input
		if("refresh")
			src.attack_hand(usr)
		if("dropsupply")
			if(current_squad)
				if((current_squad.supply_cooldown + drop_cooldown) > world.time)
					usr << "\icon[src] <span class='warning'>Supply drop not yet available!</span>"
				else
					handle_supplydrop()
	src.attack_hand(usr) //Refresh

/obj/machinery/computer/supply_drop_console/proc/handle_supplydrop()
	if(busy)
		usr << "\icon[src] <span class='warning'>The [name] is busy processing another action!</span>"
		return

	var/obj/structure/closet/crate/C = locate() in current_squad.drop_pad.loc //This thing should ALWAYS exist.
	if(!istype(C))
		usr << "\icon[src] <span class='warning'>No crate was detected on the drop pad. Get Requisitions on the line!</span>"
		return

	var/x_coord = deobfuscate_x(x_supply)
	var/y_coord = deobfuscate_y(y_supply)

	var/turf/T = locate(x_coord, y_coord, 1)
	if(!T)
		usr << "\icon[src] <span class='warning'>Error, invalid coordinates.</span>"
		return

	var/area/A = get_area(T)
	if(A && A.ceiling >= CEILING_UNDERGROUND)
		usr << "\icon[src] <span class='warning'>The landing zone is underground. The supply drop cannot reach here.</span>"
		return

	if(istype(T, /turf/open/space) || T.density)
		usr << "\icon[src] <span class='warning'>The landing zone appears to be obstructed or out of bounds. Package would be lost on drop.</span>"
		return

	busy = 1

	visible_message("\icon[src] <span class='boldnotice'>'[C.name]' supply drop is now loading into the launch tube! Stand by!</span>")
	C.visible_message("<span class='warning'>\The [C] begins to load into a launch tube. Stand clear!</span>")
	C.anchored = TRUE //To avoid accidental pushes
	send_to_squad("'[C.name]' supply drop incoming. Heads up!")
	var/datum/squad/S = current_squad //in case the operator changes the overwatched squad mid-drop
	spawn(100)
		if(!C || C.loc != S.drop_pad.loc) //Crate no longer on pad somehow, abort.
			if(C) C.anchored = FALSE
			usr << "\icon[src] <span class='warning'>Launch aborted! No crate detected on the drop pad.</span>"
			return
		S.supply_cooldown = world.time

		playsound(C.loc,'sound/effects/bamf.ogg', 50, 1)  //Ehh
		C.anchored = FALSE
		C.z = T.z
		C.x = T.x
		C.y = T.y
		var/turf/TC = get_turf(C)
		TC.ceiling_debris_check(3)
		playsound(C.loc,'sound/effects/bamf.ogg', 50, 1)  //Ehhhhhhhhh.
		C.visible_message("\icon[C] <span class='boldnotice'>The '[C.name]' supply drop falls from the sky!</span>")
		visible_message("\icon[src] <span class='boldnotice'>'[C.name]' supply drop launched! Another launch will be available in five minutes.</span>")
		busy = 0


//Sends a string to our currently selected squad.
/obj/machinery/computer/supply_drop_console/proc/send_to_squad(var/txt = "", var/plus_name = 0, var/only_leader = 0)
	if(txt == "" || !current_squad) return //Logic

	var/text = copytext(sanitize(txt), 1, MAX_MESSAGE_LEN)
	var/nametext = ""
	if(plus_name)
		nametext = "[usr.name] transmits: "
		text = "<font size='3'><b>[text]<b></font>"

	for(var/mob/living/carbon/human/M in current_squad.marines_list)
		if(!M.stat && M.client) //Only living and connected people in our squad
			if(!only_leader)
				if(plus_name)
					M << sound('sound/effects/radiostatic.ogg')
				M << "\icon[src] <font color='blue'><B>\[Overwatch\]:</b> [nametext][text]</font>"
			else
				if(current_squad.squad_leader == M)
					if(plus_name)
						M << sound('sound/effects/radiostatic.ogg')
					M << "\icon[src] <font color='blue'><B>\[SL Overwatch\]:</b> [nametext][text]</font>"
					return

//A limited version of the above console
//Can't pick squads, drops less often
//Uses Echo squad as a placeholder to access its own drop pad
/obj/machinery/computer/supply_drop_console/limited
	drop_cooldown = 10000 //higher cooldown than usual
	can_pick_squad = FALSE//Can't pick squads

/obj/machinery/computer/supply_drop_console/limited/New()
	current_squad = get_squad_by_name("Echo") //Hardwired into Echo

/obj/machinery/computer/supply_drop_console/limited/attack_hand(mob/user)
	if(!current_squad)
		current_squad = get_squad_by_name("Echo") //Hardwired into Echo
	. = ..()

/*
/obj/effect/marker/supplymarker
	icon_state = "X"
	icon = 'icons/misc/mark.dmi'
	name = "X"
	invisibility = 101
	anchored = 1
	opacity = 0
*/

/datum/supply_order
	var/ordernum
	var/datum/supply_packs/object = null
	var/orderedby = null
	var/comment = null

/datum/controller/supply
	var/processing = 1
	var/processing_interval = 300
	var/iteration = 0
	//supply points
	var/points = 120
	var/points_per_process = 0
	var/points_per_slip = 1
	var/points_per_crate = 1
	var/min_random_crate_amount = 0 //Minimum amount of crates spawned.
	var/base_random_crate_interval = 10 //Every how many processing intervals do we get a random crates.
	var/xeno_per_crate = 2 //Amount of xenos needed to spawn a crate
	var/crate_iteration = 0
	var/points_per_platinum = 5
	var/points_per_phoron = 0
	//control
	var/ordernum
	var/list/shoppinglist = list()
	var/list/requestlist = list()
	var/list/supply_packs = list()
	var/list/random_supply_packs = list()
	//shuttle movement
	var/datum/shuttle/ferry/supply/shuttle

	//dropship part fabricator's points, so we can reference them globally (mostly for DEFCON)
	var/dropship_points = 0 //gains roughly 18 points per minute

	New()
		ordernum = rand(1,9000)

//Supply shuttle ticker - handles supply point regenertion and shuttle travelling between centcomm and the station
/datum/controller/supply/proc/process()
	for(var/typepath in (typesof(/datum/supply_packs) - /datum/supply_packs - /datum/supply_packs/asrs))
		var/datum/supply_packs/P = new typepath()
		supply_packs[P.name] = P
	for(var/typepath in (typesof(/datum/supply_packs) - /datum/supply_packs - /datum/supply_packs/asrs))
		var/datum/supply_packs/P = new typepath()
		if(P.cost > 1 && P.buyable == 0)
			random_supply_packs[P.name] = P

	spawn(0)
		set background = 1
		while(1)
			if(processing)
				iteration++
				points += points_per_process
				if(iteration == 1 || iteration % base_random_crate_interval == 0 && supply_controller.shoppinglist.len <= 20)
					add_random_crates()
					crate_iteration += 1
			sleep(processing_interval)
//This adds function adds the amount of crates that calculate_crate_amount returns
/datum/controller/supply/proc/add_random_crates()
	for(var/I=0, I<calculate_crate_amount(), I++)
		add_random_crate()
//Here we calculate the amount of crates to spawn. 
//Marines get one crate for each the amount of marines on the surface devided by the amount of marines per crate. 
//They always get the mincrates amount.
/datum/controller/supply/proc/calculate_crate_amount()
	//Please never ever tell anyone this is based upon xeno amounts.
	var/crate_amount = round(max(min_random_crate_amount,(ticker.mode.count_xenos(SURFACE_Z_LEVELS)/xeno_per_crate)))
	//if it's not yet the 6th wave you only get 5 crates
	if(crate_iteration<=5)
		crate_amount = 5
	return crate_amount
//Here we pick what crate type to send to the marines.
/datum/controller/supply/proc/add_random_crate()
	var/randpick = rand(1,100)
	switch(randpick)
		if(1 to 35)
			pickcrate("Defence")
		if(36 to 65)
			pickcrate("Munition")
		if(66 to 85)
			pickcrate("Offence")
		if(86 to 90)
			pickcrate("Utility")
		if(91 to 100)
			pickcrate("Everything")
//Here we pick the exact crate from the crate types to send to the marines.
//This is a weighted pick based upon their cost.
//Their cost will go up if the crate is picked
/datum/controller/supply/proc/pickcrate(var/T = "Everything")
	var/list/pickfrom = list()
	for(var/supply_name in supply_controller.random_supply_packs)
		var/datum/supply_packs/N = supply_controller.random_supply_packs[supply_name]
		if((T == "Everything" || N.group == T)  && !N.buyable)
			pickfrom += N
	var/datum/supply_packs/C = supply_controller.pick_weighted_crate(pickfrom)
	C.cost = round(C.cost * ASRS_COST_MULTIPLIER) //We still do this to raise the weight
	//We have to create a supply order to make the system spawn it. Here we transform a crate into an order.
	var/datum/supply_order/O = new /datum/supply_order()
	O.ordernum = supply_controller.ordernum
	O.object = C
	O.orderedby = "ASRS"
	//We add the order to the shopping list
	supply_controller.shoppinglist += O
//Here we weigh the crate based upon it's cost
/datum/controller/supply/proc/pick_weighted_crate(list/cratelist)
	var/weighted_crate_list[]
	for(var/datum/supply_packs/crate in cratelist)
		var/crate_to_add[0]
		var/weight = (round(10000/crate.cost))
		if(iteration > crate.iteration_needed)
			crate_to_add[crate] = weight
			weighted_crate_list += crate_to_add	
	return pickweight(weighted_crate_list)
//To stop things being sent to centcomm which should not be sent to centcomm. Recursively checks for these types.
/datum/controller/supply/proc/forbidden_atoms_check(atom/A)
	if(istype(A,/mob/living))
		return 1
	if(istype(A,/obj/item/disk/nuclear))
		return 1
	if(istype(A,/obj/item/device/radio/beacon))
		return 1
	if(istype(A,/obj/item/stack/sheet/mineral/phoron))
		return 1

	for(var/i=1, i<=A.contents.len, i++)
		var/atom/B = A.contents[i]
		if(.(B))
			return 1

//Sellin
/datum/controller/supply/proc/sell()
	var/area/area_shuttle = shuttle.get_location_area()
	if(!area_shuttle)	return

	var/phoron_count = 0
	var/plat_count = 0

	for(var/atom/movable/MA in area_shuttle)
		if(MA.anchored)	continue

		// Must be in a crate!
		if(istype(MA,/obj/structure/closet/crate))
			callHook("sell_crate", list(MA, area_shuttle))

			points += points_per_crate
			var/find_slip = 1

			for(var/atom in MA)
				// Sell manifests
				var/atom/A = atom
				if(find_slip && istype(A,/obj/item/paper/manifest))
					var/obj/item/paper/slip = A
					if(slip.stamped && slip.stamped.len) //yes, the clown stamp will work. clown is the highest authority on the station, it makes sense
						points += points_per_slip
						find_slip = 0
					continue

				// Sell phoron
			/*	if(istype(A, /obj/item/stack/sheet/mineral/phoron))
					var/obj/item/stack/sheet/mineral/phoron/P = A
					phoron_count += P.get_amount()*/

				// Sell platinum
				if(istype(A, /obj/item/stack/sheet/mineral/platinum))
					var/obj/item/stack/sheet/mineral/platinum/P = A
					plat_count += P.get_amount()

		cdel(MA)

	if(phoron_count)
		points += phoron_count * points_per_phoron

	if(plat_count)
		points += plat_count * points_per_platinum

//Buyin
/datum/controller/supply/proc/buy()
	if(!shoppinglist.len) return

	var/area/area_shuttle = shuttle.get_location_area()
	if(!area_shuttle)	return

	var/list/clear_turfs = list()

	for(var/turf/T in area_shuttle)
		if(T.density || T.contents.len)	continue
		clear_turfs += T

	for(var/S in shoppinglist)
		if(!clear_turfs.len)	break
		var/i = rand(1,clear_turfs.len)
		var/turf/pickedloc = clear_turfs[i]
		clear_turfs.Cut(i,i+1)

		var/datum/supply_order/SO = S
		var/datum/supply_packs/SP = SO.object

		var/atom/A = new SP.containertype(pickedloc)
		A.name = "[SP.containername][SO.comment ? " ([SO.comment])" : ""]"

		//supply manifest generation begin

		var/obj/item/paper/manifest/slip = new /obj/item/paper/manifest(A)
		slip.info = "<h3>Automatic Storage Retrieval Manifest</h3><hr><br>"
		slip.info +="Order #[SO.ordernum]<br>"
		slip.info +="[shoppinglist.len] PACKAGES IN THIS SHIPMENT<br>"
		slip.info +="CONTENTS:<br><ul>"

		//spawn the stuff, finish generating the manifest while you're at it
		if(SP.access)
			A:req_access = list()
			A:req_access += text2num(SP.access)

		var/list/contains
		if(SP.randomised_num_contained)
			contains = list()
			if(SP.contains.len)
				for(var/j=1,j<=SP.randomised_num_contained,j++)
					contains += pick(SP.contains)
		else
			contains = SP.contains

		for(var/typepath in contains)
			if(!typepath)	continue
			var/atom/B2 = new typepath(A)
			if(SP.amount && B2:amount) B2:amount = SP.amount
			slip.info += "<li>[B2.name]</li>" //add the item to the manifest

		//manifest finalisation
		slip.info += "</ul><br>"
		slip.info += "CHECK CONTENTS AND STAMP BELOW THE LINE TO CONFIRM RECEIPT OF GOODS<hr>"
		if (SP.contraband) slip.loc = null	//we are out of blanks for Form #44-D Ordering Illicit Drugs.

	shoppinglist.Cut()
	return

/obj/item/paper/manifest
	name = "Supply Manifest"


/obj/machinery/computer/ordercomp/attack_ai(var/mob/user as mob)
	return attack_hand(user)

/obj/machinery/computer/ordercomp/attack_paw(var/mob/user as mob)
	return attack_hand(user)

/obj/machinery/computer/supplycomp/attack_ai(var/mob/user as mob)
	return attack_hand(user)

/obj/machinery/computer/supplycomp/attack_paw(var/mob/user as mob)
	return attack_hand(user)

/obj/machinery/computer/ordercomp/attack_hand(var/mob/user as mob)
	if(..())
		return
	user.set_interaction(src)
	var/dat
	if(temp)
		dat = temp
	else
		var/datum/shuttle/ferry/supply/shuttle = supply_controller.shuttle
		if (shuttle)
			dat += {"<BR><B>Automated Storage and Retrieval System</B><HR>
			Location: [shuttle.has_arrive_time() ? "Raising platform":shuttle.at_station() ? "Raised":"Lowered"]<BR>
			<HR>Supply points: [supply_controller.points]<BR>
		<BR>\n<A href='?src=\ref[src];order=categories'>Request items</A><BR><BR>
		<A href='?src=\ref[src];vieworders=1'>View approved orders</A><BR><BR>
		<A href='?src=\ref[src];viewrequests=1'>View requests</A><BR><BR>
		<A href='?src=\ref[user];mach_close=computer'>Close</A>"}

	user << browse(dat, "window=computer;size=575x450")
	onclose(user, "computer")
	return

/obj/machinery/computer/ordercomp/Topic(href, href_list)
	if(..())
		return

	if( isturf(loc) && (in_range(src, usr) || ishighersilicon(usr)) )
		usr.set_interaction(src)

	if(href_list["order"])
		if(href_list["order"] == "categories")
			//all_supply_groups
			//Request what?
			last_viewed_group = "categories"
			temp = "<b>Supply points: [supply_controller.points]</b><BR>"
			temp += "<A href='?src=\ref[src];mainmenu=1'>Main Menu</A><HR><BR><BR>"
			temp += "<b>Select a category</b><BR><BR>"
			for(var/supply_group_name in all_supply_groups )
				temp += "<A href='?src=\ref[src];order=[supply_group_name]'>[supply_group_name]</A><BR>"
		else
			last_viewed_group = href_list["order"]
			temp = "<b>Supply points: [supply_controller.points]</b><BR>"
			temp += "<A href='?src=\ref[src];order=categories'>Back to all categories</A><HR><BR><BR>"
			temp += "<b>Request from: [last_viewed_group]</b><BR><BR>"
			for(var/supply_name in supply_controller.supply_packs )
				var/datum/supply_packs/N = supply_controller.supply_packs[supply_name]
				if(N.hidden || N.contraband || N.group != last_viewed_group || !N.buyable) continue								//Have to send the type instead of a reference to
				temp += "<A href='?src=\ref[src];doorder=[supply_name]'>[supply_name]</A> Cost: [round(N.cost)]<BR>"		//the obj because it would get caught by the garbage

	else if (href_list["doorder"])
		if(world.time < reqtime)
			for(var/mob/V in hearers(src))
				V.show_message("<b>[src]</b>'s monitor flashes, \"[world.time - reqtime] seconds remaining until another requisition form may be printed.\"")
			return

		//Find the correct supply_pack datum
		var/datum/supply_packs/P = supply_controller.supply_packs[href_list["doorder"]]
		if(!istype(P))	return

		var/timeout = world.time + 600
		var/reason = copytext(sanitize(input(usr,"Reason:","Why do you require this item?","") as null|text),1,MAX_MESSAGE_LEN)
		if(world.time > timeout)	return
		if(!reason)	return

		var/idname = "*None Provided*"
		var/idrank = "*None Provided*"
		if(ishuman(usr))
			var/mob/living/carbon/human/H = usr
			idname = H.get_authentification_name()
			idrank = H.get_assignment()
		else if(ishighersilicon(usr))
			idname = usr.real_name

		supply_controller.ordernum++
		var/obj/item/paper/reqform = new /obj/item/paper(loc)
		reqform.name = "Requisition Form - [P.name]"
		reqform.info += "<h3>[station_name] Supply Requisition Form</h3><hr>"
		reqform.info += "INDEX: #[supply_controller.ordernum]<br>"
		reqform.info += "REQUESTED BY: [idname]<br>"
		reqform.info += "RANK: [idrank]<br>"
		reqform.info += "REASON: [reason]<br>"
		reqform.info += "SUPPLY CRATE TYPE: [P.name]<br>"
		reqform.info += "ACCESS RESTRICTION: [oldreplacetext(get_access_desc(P.access))]<br>"
		reqform.info += "CONTENTS:<br>"
		reqform.info += P.manifest
		reqform.info += "<hr>"
		reqform.info += "STAMP BELOW TO APPROVE THIS REQUISITION:<br>"

		reqform.update_icon()	//Fix for appearing blank when printed.
		reqtime = (world.time + 5) % 1e5

		//make our supply_order datum
		var/datum/supply_order/O = new /datum/supply_order()
		O.ordernum = supply_controller.ordernum
		O.object = P
		O.orderedby = idname
		supply_controller.requestlist += O

		temp = "Thanks for your request. The cargo team will process it as soon as possible.<BR>"
		temp += "<BR><A href='?src=\ref[src];order=[last_viewed_group]'>Back</A> <A href='?src=\ref[src];mainmenu=1'>Main Menu</A>"

	else if (href_list["vieworders"])
		temp = "Current approved orders: <BR><BR>"
		for(var/S in supply_controller.shoppinglist)
			var/datum/supply_order/SO = S
			temp += "[SO.object.name] approved by [SO.orderedby] [SO.comment ? "([SO.comment])":""]<BR>"
		temp += "<BR><A href='?src=\ref[src];mainmenu=1'>OK</A>"

	else if (href_list["viewrequests"])
		temp = "Current requests: <BR><BR>"
		for(var/S in supply_controller.requestlist)
			var/datum/supply_order/SO = S
			temp += "#[SO.ordernum] - [SO.object.name] requested by [SO.orderedby]<BR>"
		temp += "<BR><A href='?src=\ref[src];mainmenu=1'>OK</A>"

	else if (href_list["mainmenu"])
		temp = null

	add_fingerprint(usr)
	updateUsrDialog()
	return

/obj/machinery/computer/supplycomp/attack_hand(var/mob/user as mob)
	if(z != MAIN_SHIP_Z_LEVEL) return
	if(!allowed(user))
		user << "\red Access Denied."
		return

	if(..())
		return
	user.set_interaction(src)
	post_signal("supply")
	var/dat
	if (temp)
		dat = temp
	else
		var/datum/shuttle/ferry/supply/shuttle = supply_controller.shuttle
		if (shuttle)
			dat += "<BR><B>Automated Storage and Retrieval System</B><HR>"
			dat += "\nPlatform position: "
			if (shuttle.has_arrive_time())
				dat += "Moving<BR>"
			else
				if (shuttle.at_station())
					if (shuttle.docking_controller)
						switch(shuttle.docking_controller.get_docking_status())
							if ("docked") dat += "Raised<BR>"
							if ("undocked") dat += "Lowered<BR>"
							if ("docking") dat += "Raising [shuttle.can_force()? "<span class='warning'><A href='?src=\ref[src];force_send=1'>Force</A></span>" : ""]<BR>"
							if ("undocking") dat += "Lowering [shuttle.can_force()? "<span class='warning'><A href='?src=\ref[src];force_send=1'>Force</A></span>" : ""]<BR>"
					else
						dat += "Raised<BR>"

					if (shuttle.can_launch())
						dat += "<A href='?src=\ref[src];send=1'>Lower platform</A>"
					else if (shuttle.can_cancel())
						dat += "<A href='?src=\ref[src];cancel_send=1'>Cancel</A>"
					else
						dat += "*ASRS is busy*"
					dat += "<BR>\n<BR>"
				else
					dat += "Lowered<BR>"
					if (shuttle.can_launch())
						dat += "<A href='?src=\ref[src];send=1'>Raise platform</A>"
					else if (shuttle.can_cancel())
						dat += "<A href='?src=\ref[src];cancel_send=1'>Cancel</A>"
					else
						dat += "*ASRS is busy*"
					dat += "<BR>\n<BR>"


		dat += {"<HR>\nSupply points: [supply_controller.points]<BR>\n<BR>
		\n<A href='?src=\ref[src];order=categories'>Order items</A><BR>\n<BR>
		\n<A href='?src=\ref[src];viewrequests=1'>View requests</A><BR>\n<BR>
		\n<A href='?src=\ref[src];vieworders=1'>View orders</A><BR>\n<BR>
		\n<A href='?src=\ref[user];mach_close=computer'>Close</A>"}


	user << browse(dat, "window=computer;size=575x450")
	onclose(user, "computer")
	return

/obj/machinery/computer/supplycomp/attackby(I as obj, user as mob)
	if(istype(I,/obj/item/card/emag) && !hacked)
		user << "\blue Special supplies unlocked."
		hacked = 1
		return
	else
		..()
	return

/obj/machinery/computer/supplycomp/Topic(href, href_list)
	if(z != MAIN_SHIP_Z_LEVEL) return
	if(!supply_controller)
		world.log << "## ERROR: Eek. The supply_controller controller datum is missing somehow."
		return
	var/datum/shuttle/ferry/supply/shuttle = supply_controller.shuttle
	if (!shuttle)
		world.log << "## ERROR: Eek. The supply/shuttle datum is missing somehow."
		return
	if(..())
		return

	if(ismaintdrone(usr))
		return

	if(isturf(loc) && ( in_range(src, usr) || ishighersilicon(usr) ) )
		usr.set_interaction(src)

	//Calling the shuttle
	if(href_list["send"])
		if(shuttle.at_station())
			if (shuttle.forbidden_atoms_check())
				temp = "For safety reasons, the Automated Storage and Retrieval System cannot store live organisms, classified nuclear weaponry or homing beacons.<BR><BR><A href='?src=\ref[src];mainmenu=1'>OK</A>"
			else
				shuttle.launch(src)
				temp = "Lowering platform. \[<span class='warning'><A href='?src=\ref[src];force_send=1'>Force</A></span>\]<BR><BR><A href='?src=\ref[src];mainmenu=1'>OK</A>"
		else
			shuttle.launch(src)
			temp = "Raising platform.<BR><BR><A href='?src=\ref[src];mainmenu=1'>OK</A>"
			post_signal("supply")

	if (href_list["force_send"])
		shuttle.force_launch(src)

	if (href_list["cancel_send"])
		shuttle.cancel_launch(src)

	else if (href_list["order"])
		//if(!shuttle.idle()) return	//this shouldn't be necessary it seems
		if(href_list["order"] == "categories")
			//all_supply_groups
			//Request what?
			last_viewed_group = "categories"
			temp = "<b>Supply points: [supply_controller.points]</b><BR>"
			temp += "<A href='?src=\ref[src];mainmenu=1'>Main Menu</A><HR><BR><BR>"
			temp += "<b>Select a category</b><BR><BR>"
			for(var/supply_group_name in all_supply_groups )
				temp += "<A href='?src=\ref[src];order=[supply_group_name]'>[supply_group_name]</A><BR>"
		else
			last_viewed_group = href_list["order"]
			temp = "<b>Supply points: [supply_controller.points]</b><BR>"
			temp += "<A href='?src=\ref[src];order=categories'>Back to all categories</A><HR><BR><BR>"
			temp += "<b>Request from: [last_viewed_group]</b><BR><BR>"
			for(var/supply_name in supply_controller.supply_packs )
				var/datum/supply_packs/N = supply_controller.supply_packs[supply_name]
				if((N.hidden && !hacked) || (N.contraband && !can_order_contraband) || N.group != last_viewed_group || !N.buyable) continue								//Have to send the type instead of a reference to
				temp += "<A href='?src=\ref[src];doorder=[supply_name]'>[supply_name]</A> Cost: [round(N.cost)]<BR>"		//the obj because it would get caught by the garbage

		/*temp = "Supply points: [supply_controller.points]<BR><HR><BR>Request what?<BR><BR>"

		for(var/supply_name in supply_controller.supply_packs )
			var/datum/supply_packs/N = supply_controller.supply_packs[supply_name]
			if(N.hidden && !hacked) continue
			if(N.contraband && !can_order_contraband) continue
			temp += "<A href='?src=\ref[src];doorder=[supply_name]'>[supply_name]</A> Cost: [N.cost]<BR>"    //the obj because it would get caught by the garbage
		temp += "<BR><A href='?src=\ref[src];mainmenu=1'>OK</A>"*/

	else if (href_list["doorder"])
		if(world.time < reqtime)
			for(var/mob/V in hearers(src))
				V.show_message("<b>[src]</b>'s monitor flashes, \"[world.time - reqtime] seconds remaining until another requisition form may be printed.\"")
			return

		//Find the correct supply_pack datum
		var/datum/supply_packs/P = supply_controller.supply_packs[href_list["doorder"]]
		if(!istype(P))	return

		var/timeout = world.time + 600
		//var/reason = copytext(sanitize(input(usr,"Reason:","Why do you require this item?","") as null|text),1,MAX_MESSAGE_LEN)
		var/reason = "*None Provided*"
		if(world.time > timeout)	return
		if(!reason)	return

		var/idname = "*None Provided*"
		var/idrank = "*None Provided*"
		if(ishuman(usr))
			var/mob/living/carbon/human/H = usr
			idname = H.get_authentification_name()
			idrank = H.get_assignment()
		else if(issilicon(usr))
			idname = usr.real_name

		supply_controller.ordernum++
		var/obj/item/paper/reqform = new /obj/item/paper(loc)
		reqform.name = "Requisition Form - [P.name]"
		reqform.info += "<h3>[station_name] Supply Requisition Form</h3><hr>"
		reqform.info += "INDEX: #[supply_controller.ordernum]<br>"
		reqform.info += "REQUESTED BY: [idname]<br>"
		reqform.info += "RANK: [idrank]<br>"
		reqform.info += "REASON: [reason]<br>"
		reqform.info += "SUPPLY CRATE TYPE: [P.name]<br>"
		reqform.info += "ACCESS RESTRICTION: [oldreplacetext(get_access_desc(P.access))]<br>"
		reqform.info += "CONTENTS:<br>"
		reqform.info += P.manifest
		reqform.info += "<hr>"
		reqform.info += "STAMP BELOW TO APPROVE THIS REQUISITION:<br>"

		reqform.update_icon()	//Fix for appearing blank when printed.
		reqtime = (world.time + 5) % 1e5

		//make our supply_order datum
		var/datum/supply_order/O = new /datum/supply_order()
		O.ordernum = supply_controller.ordernum
		O.object = P
		O.orderedby = idname
		supply_controller.requestlist += O

		temp = "Order request placed.<BR>"
		temp += "<BR><A href='?src=\ref[src];order=[last_viewed_group]'>Back</A>|<A href='?src=\ref[src];mainmenu=1'>Main Menu</A>|<A href='?src=\ref[src];confirmorder=[O.ordernum]'>Authorize Order</A>"

	else if(href_list["confirmorder"])
		//Find the correct supply_order datum
		var/ordernum = text2num(href_list["confirmorder"])
		var/datum/supply_order/O
		var/datum/supply_packs/P
		temp = "Invalid Request"
		temp += "<BR><A href='?src=\ref[src];order=[last_viewed_group]'>Back</A>|<A href='?src=\ref[src];mainmenu=1'>Main Menu</A>"

		if(supply_controller.shoppinglist.len > 20)
			usr << "\red Current retrieval load has reached maximum capacity."
			return

		for(var/i=1, i<=supply_controller.requestlist.len, i++)
			var/datum/supply_order/SO = supply_controller.requestlist[i]
			if(SO.ordernum == ordernum)
				O = SO
				P = O.object
				if(supply_controller.points >= round(P.cost))
					supply_controller.requestlist.Cut(i,i+1)
					supply_controller.points -= round(P.cost)
					supply_controller.shoppinglist += O
					P.cost = P.cost * SUPPLY_COST_MULTIPLIER
					temp = "Thank you for your order.<BR>"
					temp += "<BR><A href='?src=\ref[src];viewrequests=1'>Back</A> <A href='?src=\ref[src];mainmenu=1'>Main Menu</A>"
				else
					temp = "Not enough supply points.<BR>"
					temp += "<BR><A href='?src=\ref[src];viewrequests=1'>Back</A> <A href='?src=\ref[src];mainmenu=1'>Main Menu</A>"
				break

	else if (href_list["vieworders"])
		temp = "Current approved orders: <BR><BR>"
		for(var/S in supply_controller.shoppinglist)
			var/datum/supply_order/SO = S
			temp += "#[SO.ordernum] - [SO.object.name] approved by [SO.orderedby][SO.comment ? " ([SO.comment])":""]<BR>"// <A href='?src=\ref[src];cancelorder=[S]'>(Cancel)</A><BR>"
		temp += "<BR><A href='?src=\ref[src];mainmenu=1'>OK</A>"
/*
	else if (href_list["cancelorder"])
		var/datum/supply_order/remove_supply = href_list["cancelorder"]
		supply_shuttle_shoppinglist -= remove_supply
		supply_shuttle_points += remove_supply.object.cost
		temp += "Canceled: [remove_supply.object.name]<BR><BR><BR>"

		for(var/S in supply_shuttle_shoppinglist)
			var/datum/supply_order/SO = S
			temp += "[SO.object.name] approved by [SO.orderedby][SO.comment ? " ([SO.comment])":""] <A href='?src=\ref[src];cancelorder=[S]'>(Cancel)</A><BR>"
		temp += "<BR><A href='?src=\ref[src];mainmenu=1'>OK</A>"
*/
	else if (href_list["viewrequests"])
		temp = "Current requests: <BR><BR>"
		for(var/S in supply_controller.requestlist)
			var/datum/supply_order/SO = S
			temp += "#[SO.ordernum] - [SO.object.name] requested by [SO.orderedby] <A href='?src=\ref[src];confirmorder=[SO.ordernum]'>Approve</A> <A href='?src=\ref[src];rreq=[SO.ordernum]'>Remove</A><BR>"

		temp += "<BR><A href='?src=\ref[src];clearreq=1'>Clear list</A>"
		temp += "<BR><A href='?src=\ref[src];mainmenu=1'>OK</A>"

	else if (href_list["rreq"])
		var/ordernum = text2num(href_list["rreq"])
		temp = "Invalid Request.<BR>"
		for(var/i=1, i<=supply_controller.requestlist.len, i++)
			var/datum/supply_order/SO = supply_controller.requestlist[i]
			if(SO.ordernum == ordernum)
				supply_controller.requestlist.Cut(i,i+1)
				temp = "Request removed.<BR>"
				break
		temp += "<BR><A href='?src=\ref[src];viewrequests=1'>Back</A> <A href='?src=\ref[src];mainmenu=1'>Main Menu</A>"

	else if (href_list["clearreq"])
		supply_controller.requestlist.Cut()
		temp = "List cleared.<BR>"
		temp += "<BR><A href='?src=\ref[src];mainmenu=1'>OK</A>"

	else if (href_list["mainmenu"])
		temp = null

	add_fingerprint(usr)
	updateUsrDialog()
	return

/obj/machinery/computer/supplycomp/proc/post_signal(var/command)

	var/datum/radio_frequency/frequency = radio_controller.return_frequency(1435)

	if(!frequency) return

	var/datum/signal/status_signal = new
	status_signal.source = src
	status_signal.transmission_method = 1
	status_signal.data["command"] = command

	frequency.post_signal(src, status_signal)
