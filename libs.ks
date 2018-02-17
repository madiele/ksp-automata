// some of those are taken here and there from /r/kos with some modifications

declare global _debug to false.
declare global _FoundedParts to list().

function setTerminal {
	if not _debug { // check if debug tools are activated
		return.
	}
	
	parameter H, W, font.
	set terminal:height to H.
	set terminal:width to W.
	set Terminal:CHARHEIGHT to font.
	CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
	clearscreen.
}

declare function ListScienceModules { // https://www.reddit.com/r/Kos/comments/5vu67i/updated_script_to_automate_science_collection/
    declare local scienceModules to list().
    declare local partList to ship:parts.

    for thePart in partList {
        declare local moduleList to thePart:modules.
        from {local i is 0.} until i = moduleList:length step {set i to i+1.} do {
            set theModule to moduleList[i].
            // just check for the Module Name. This might be extended in the future.
            if (theModule = "ModuleScienceExperiment") or (theModule = "DMModuleScienceAnimate") {
                scienceModules:add(thePart:getModuleByIndex(i)). // add it to the list
            }
        }
    }
    // LOG scienceModules TO SciMods.
    return scienceModules.
}


FUNCTION deltaVstage{    // needs to be called with true after each new stage 
	declare parameter newstage is false.
	if (newstage) set _FoundedParts to list(). // crea una lista globale dove mettiamo le parti con fuel dello stage per ridurre il tempo di uso della cpu
    // fuel name list
    LOCAL fuels IS list().
    fuels:ADD("LiquidFuel").
    fuels:ADD("Oxidizer").
    fuels:ADD("SolidFuel").
    fuels:ADD("MonoPropellant").

    // fuel density list (order must match name list)
    LOCAL fuelsDensity IS list().
    fuelsDensity:ADD(0.005).
    fuelsDensity:ADD(0.005).
    fuelsDensity:ADD(0.0075).
    fuelsDensity:ADD(0.004).

    // initialize fuel mass sums
    LOCAL fuelMass IS 0.
	
	if newstage { // seek parts with fuel and store for future quick reference
		FOR r IN STAGE:RESOURCES
		{
			LOCAL iter is 0.
			FOR f in fuels
			{
				IF f = r:NAME
				{
					_FoundedParts:add(r).
				}.
				SET iter TO iter+1.
			}.
		}.  
	}
    // calculate total fuel mass
    FOR r IN _FoundedParts
    {
        LOCAL iter is 0.
        FOR f in fuels
        {
            IF f = r:NAME
            {
                SET fuelMass TO fuelMass + fuelsDensity[iter]*r:AMOUNT.
            }.
            SET iter TO iter+1.
        }.
    }.

    // deltaV calculation as Isp*g0*ln(m0/m1).
    LOCAL deltaV IS currentISP()*9.81*ln(SHIP:MASS / (SHIP:MASS-fuelMass)).

    RETURN deltaV.
}.

function currentISP { // note for future self, we can find also find the current ISP by changing MAXTHROTTLE to the current one
	LOCAL thrustTotal IS 0.
    LOCAL mDotTotal IS 0.
    LIST ENGINES IN engList. 
    FOR eng in engList
    {
        IF eng:IGNITION
        {
            LOCAL t IS eng:maxthrust*eng:thrustlimit/100. // if multi-engine with different thrust limiters
            SET thrustTotal TO thrustTotal + t.
            IF eng:ISP = 0 SET mDotTotal TO 1. // shouldn't be possible, but ensure avoiding divide by 0
            ELSE SET mDotTotal TO mDotTotal + t / eng:ISP.
        }.
    }.
    IF mDotTotal = 0 LOCAL avgIsp IS 0.
    ELSE LOCAL avgIsp IS thrustTotal/mDotTotal.
	return avgisp.
}

function getG { // find g for the current body and altitude
	return body:mu / (ship:altitude + body:radius)^2.
}

declare function printer {
	declare parameter name, value is 0, position is terminal:height.
	
	if not _debug { // check if debug tools are activated
		return.
	}
	print "":padright(terminal:width - 1) at (0, 0). // clear line
	print "name" at (terminal:width/4 - 2,0).
	print "|" at (terminal:width / 2 ,0).
	print "value" at (terminal:width* 3/4 - 2, 0).
	
	print "":padright(terminal:width - 1) at (0, position). 
	
	if position = terminal:height {
		print name at (0, position). 
		return.
	}
	
	print name at (0,position).
	print "|" at (terminal:width / 2,position).
	print value at (terminal:width/2 + 1, position).
}

function orbitTurn {
	parameter ap, per, ecc is 0.001. //target apoapsis, target periapsis, target eccentricity
	
	printer("PREPARING FOR ORBIT CIRCULARIZATION").
	
	lock throttle to 0.
	lock steering to prograde:vector.
	
	// horizontal speed needed for orbit, see vis-viva.
	local spdAtAp is sqrt(body:mu * (2/(ap + body:radius) - 1/(((ap + body:radius) + (per + body:radius)) / 2))).
	// our speed at the apoapsis
	local currentApSpd is (sqrt(body:mu * (2/(ship:apoapsis + body:radius) - 1/(((ship:apoapsis + body:radius) + (ship:periapsis + body:radius)) / 2)))).
	// how much horizontal delta v we need to achive our orbit
	local deltaVNeeded is spdAtAp - currentApSpd.
	// for how much we need to floor the gas to get in orbit
	local secondsNeeded is burnTime(deltaVNeeded) * 1.
	// see later for this
	local firstETAJump is false.
	local malus is 0.

	wait until eta:apoapsis < secondsNeeded.
	printer("ENGAGING ORBIT CIRCULARIZATION").
	local oldeccentricity is ship:orbit:eccentricity.
	
	until round(ship:orbit:eccentricity, 3) > round(oldeccentricity, 3) or ship:orbit:eccentricity < ecc { // rounding due to some weird glitches i encountered
		if eta:apoapsis < secondsNeeded {
				lock throttle to max(0.2, 1 - malus).
				set secondsNeeded to eta:apoapsis. // update the minimum ETA at witch we can throttle up to this one, we never want to increse our ETA
				if firstETAJump // if this is true here then we are not jumping anymore so full throttle is best
					set malus to 0.
				set firstETAJump to true.
			} else if firstETAJump { // for the first time the ETA goes up we check by how much and decide if we need to apply less throttle
				lock throttle to 0.	
				set firstETAJump to false.
				if (eta:apoapsis - secondsNeeded)/secondsNeeded > 0.1 // this is to make sure there is no feedback loop
					set malus to eta:apoapsis/secondsNeeded.
			} else {
				lock throttle to 0.
			}			
			
		set oldeccentricity to ship:orbit:eccentricity.
		wait 0.01.
	}
	lock throttle to 0.
}

FUNCTION burnTime { // takes a dv and gives the seconds to achive it
  PARAMETER dV.
	
	local f is 0.
	list engines in en.
	for ens in en {
		if ens:IGNITION {
			set f to f + ens:maxthrust * 1000.
		}
	}
	
	LOCAL m IS SHIP:MASS * 1000.        // Starting mass (kg)
	LOCAL e IS CONSTANT():E.            // Base of natural log
	local p is currentISP().				// our current total ISP
	LOCAL g IS 9.80665.                 // Gravitational acceleration constant (m/s²)

	RETURN g * m * p * (1 - e^(-dV/(g*p))) / f.
}