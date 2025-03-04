
#define MAX_RATE 10 * ONE_ATMOSPHERE

/obj/machinery/atmospherics/portable/scrubber
	name = "portable air scrubber"
	icon = 'icons/obj/atmos.dmi'
	icon_state = "pscrubber:0"
	density = TRUE
	volume = 750
	/// The volume of gas that can be scrubbed every time `process_atmos()` is called (0.5 seconds).
	var/volume_rate = 101.325
	/// Is this scrubber acting on the 3x3 area around it.
	var/widenet = FALSE
	resistance_flags = NONE

/obj/machinery/atmospherics/portable/scrubber/examine(mob/user)
	. = ..()
	. += "<span class='notice'>Filters the air, placing harmful gases into the internal gas container. The container can be emptied by \
			connecting it to a connector port, you're unable to have [src] both connected, and on at the same time. \
			Changing the target pressure will result in faster or slower filter speeds, higher pressure is faster. \
			A tank of gas can also be attached, allowing you to remove harmful gases from the attached tank.</span>"

/obj/machinery/atmospherics/portable/scrubber/emp_act(severity)
	if(stat & (BROKEN|NOPOWER))
		..(severity)
		return

	if(prob(50/severity))
		on = !on
		update_icon()

	..(severity)

/obj/machinery/atmospherics/portable/scrubber/update_icon_state()
	if(on)
		icon_state = "pscrubber:1"
	else
		icon_state = "pscrubber:0"

/obj/machinery/atmospherics/portable/scrubber/update_overlays()
	. = ..()
	if(holding_tank)
		. += "scrubber-open"
	if(connected_port)
		. += "scrubber-connector"

/obj/machinery/atmospherics/portable/scrubber/process_atmos()
	..()

	if(!on)
		return
	scrub(loc)
	if(widenet)
		var/turf/T = loc
		if(istype(T))
			for(var/turf/simulated/tile in T.GetAtmosAdjacentTurfs(alldir=1))
				scrub(tile)

/obj/machinery/atmospherics/portable/scrubber/proc/scrub(turf/simulated/tile)
	var/datum/gas_mixture/environment
	if(holding_tank)
		environment = holding_tank.air_contents
	else
		environment = tile.return_air()
	var/transfer_moles = min(1,volume_rate/environment.volume)*environment.total_moles()

	//Take a gas sample
	var/datum/gas_mixture/removed
	if(holding_tank)
		removed = environment.remove(transfer_moles)
	else
		removed = loc.remove_air(transfer_moles)

	//Filter it
	if(removed)
		var/datum/gas_mixture/filtered_out = new

		filtered_out.temperature = removed.temperature


		filtered_out.toxins = removed.toxins
		removed.toxins = 0

		filtered_out.carbon_dioxide = removed.carbon_dioxide
		removed.carbon_dioxide = 0

		filtered_out.sleeping_agent = removed.sleeping_agent
		removed.sleeping_agent = 0

		filtered_out.agent_b = removed.agent_b
		removed.agent_b = 0

	//Remix the resulting gases
		air_contents.merge(filtered_out)

		if(holding_tank)
			environment.merge(removed)
		else
			tile.assume_air(removed)
			tile.air_update_turf()

/obj/machinery/atmospherics/portable/scrubber/return_air()
	RETURN_TYPE(/datum/gas_mixture)
	return air_contents

/obj/machinery/atmospherics/portable/scrubber/attack_ai(mob/user)
	add_hiddenprint(user)
	return attack_hand(user)

/obj/machinery/atmospherics/portable/scrubber/attack_ghost(mob/user)
	return attack_hand(user)

/obj/machinery/atmospherics/portable/scrubber/attack_hand(mob/user)
	ui_interact(user)
	return

/obj/machinery/atmospherics/portable/scrubber/ui_interact(mob/user, ui_key = "main", datum/tgui/ui = null, force_open = FALSE, datum/tgui/master_ui = null, datum/ui_state/state = GLOB.default_state)
	ui = SStgui.try_update_ui(user, src, ui_key, ui, force_open)
	if(!ui)
		ui = new(user, src, ui_key, "PortableScrubber", "Portable Scrubber", 433, 346, master_ui, state)
		ui.open()
		ui.set_autoupdate(TRUE)

/obj/machinery/atmospherics/portable/scrubber/ui_data(mob/user)
	var/list/data = list(
		"on" = on,
		"port_connected" = connected_port ? TRUE : FALSE,
		"max_rate" = MAX_RATE,
		"rate" = round(volume_rate, 0.001),
		"tank_pressure" = air_contents.return_pressure() > 0 ? round(air_contents.return_pressure(), 0.001) : 0
	)
	if(holding_tank)
		data["has_holding_tank"] = TRUE
		data["holding_tank"] = list("name" = holding_tank.name, "tank_pressure" = holding_tank.air_contents.return_pressure() > 0 ? round(holding_tank.air_contents.return_pressure(), 0.001) : 0)
	else
		data["has_holding_tank"] = FALSE

	return data

/obj/machinery/atmospherics/portable/scrubber/ui_act(action, list/params, datum/tgui/ui)
	if(..())
		return

	switch(action)
		if("power")
			if(connected_port)
				to_chat(ui.user, "<span class='warning'>[src] fails to turn on, the port is covered!</span>")
				return
			on = !on
			update_icon()
			return TRUE

		if("remove_tank")
			replace_tank(ui.user, TRUE)
			update_icon()
			return TRUE

		if("set_rate")
			volume_rate = clamp(text2num(params["rate"]), 0, MAX_RATE)
			return TRUE

	add_fingerprint(usr)

/obj/machinery/atmospherics/portable/scrubber/huge
	name = "Huge Air Scrubber"
	icon_state = "scrubber:0"
	anchored = TRUE
	volume = 50000
	volume_rate = 5000
	widenet = TRUE

	var/global/gid = 1
	var/id = 0
	var/stationary = FALSE

/obj/machinery/atmospherics/portable/scrubber/huge/New()
	..()
	id = gid
	gid++

	name = "[name] (ID [id])"

/obj/machinery/atmospherics/portable/scrubber/huge/attack_hand(mob/user)
	to_chat(usr, "<span class='warning'>You can't directly interact with this machine. Use the area atmos computer.</span>")

/obj/machinery/atmospherics/portable/scrubber/huge/update_icon_state()
	icon_state = "scrubber:[on]"

/obj/machinery/atmospherics/portable/scrubber/huge/attackby(obj/item/W, mob/user, params)
	if((istype(W, /obj/item/analyzer)) && get_dist(user, src) <= 1)
		atmosanalyzer_scan(air_contents, user)
		return
	return ..()

/obj/machinery/atmospherics/portable/scrubber/huge/wrench_act(mob/user, obj/item/I)
	. = TRUE
	if(stationary)
		to_chat(user, "<span class='warning'>The bolts are too tight for you to unscrew!</span>")
		return
	if(on)
		to_chat(user, "<span class='warning'>Turn it off first!</span>")
		return
	default_unfasten_wrench(user, I, 4 SECONDS)

/obj/machinery/atmospherics/portable/scrubber/huge/stationary
	name = "Stationary Air Scrubber"
	stationary = TRUE

#undef MAX_RATE
