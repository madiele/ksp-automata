
parameter aptarget, pertarget, inclination.
runoncepath("libs.ks"). // load libraries if not done already

// horizontal speed needed for orbit, see vis-viva.
set spdAtAp to sqrt(body:mu * (2/(aptarget + body:radius) - 1/(((aptarget + body:radius) + (pertarget + body:radius)) / 2))).


CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
set terminal:height to 30.
set terminal:width to 60.
set Terminal:CHARHEIGHT to 20.
clearscreen.

function inst_az { // correct error for the inclination
	parameter
		inc. // target inclination
		
		if inc = 0
			set inc to 0.1.
	
	// find orbital velocity for a circular orbit at the current altitude.
	local V_orb is sqrt( body:mu / ( ship:altitude + body:radius)).
	
	// project desired orbit onto surface heading
	local az_orb is arcsin ( cos(inc) / cos(ship:latitude)).
	if (inc < 0) {
		set az_orb to 180 - az_orb.
	}
	
	// create desired orbit velocity vector
	local V_star is heading(az_orb, 0)*v(0, 0, V_orb).

	// find horizontal component of current orbital velocity vector
	local V_ship_h is ship:velocity:orbit - vdot(ship:velocity:orbit, up:vector)*up:vector.
	
	// calculate difference between desired orbital vector and current (this is the direction we go)
	local V_corr is V_star - V_ship_h.
	
	// project the velocity correction vector onto north and east directions
	local vel_n is vdot(V_corr, ship:north:vector).
	local vel_e is vdot(V_corr, heading(90,0):vector).
	
	// calculate compass heading
	local az_corr is arctan2(vel_e, vel_n).
	return az_corr.
}

function setup {
	sas off.
	rcs off.
	gear off.
	lights off.
	lock throttle to 1.
	LOCK STEERING TO UP.
}

function liftOff {
	
	local sound is getvoice(0).
	
	FROM {local countdown is 3.} UNTIL countdown = 0 STEP {SET countdown to countdown - 1.} DO {
		sound:play(note(700,0.3)).
		printer("LIFTOFF IN T - " + countdown).
		WAIT 1.
	}


	UNTIL SHIP:MAXTHRUST > 0 {
		sound:play(note(1300,1)).
		STAGE.
		printer("LIFTOFF SUCCESSFUL").
	}
}

function gravityTurn {
	parameter ap, per, inclination.
	
	local wantedTWR is 2.
	local startingAngle is 50.
	local startingAlititude is 3000.
	local g is getg().
	
	
	lock throttle to wantedTWR * Ship:Mass * g / (Ship:AvailableThrust+0.00001)..

	
	wait until ship:altitude > startingAlititude.
	
	until ship:apoapsis > ap {
		local srfProgradeInclination is vang(up:vector, srfprograde:vector).
		local targetPitch is max( 5, min(startingAngle,90 - srfProgradeInclination)). 
		lock steering to heading (inst_az(inclination), targetPitch). 
		
		
		
		if (ship:altitude > 70000) lock throttle to 1.
		wait 0.01.
	}

	lock throttle to 0.
}

function orbitTurn {
	parameter ap, per, inclination.
	
	lock throttle to 0.
	lock steering to prograde:vector + up:vector * 0.
	local currentApSpd is (sqrt(body:mu * (2/(ship:apoapsis + body:radius) - 1/(((ship:apoapsis + body:radius) + (ship:periapsis + body:radius)) / 2)))).
	local deltaVNeeded is spdAtAp - currentApSpd.
	local secondsNeeded is burnTime(deltaVNeeded) * 1.
	local firstETAJump is true.
	local malus is 0.
	
	wait until eta:apoapsis < secondsNeeded.
	local oldeccentricity is ship:orbit:eccentricity.
	
	// se sotto lo 0.001 ci accontentiamo, aspettare un altro salto è molto rischioso
	until round(ship:orbit:eccentricity, 3) > round(oldeccentricity, 3) or ship:orbit:eccentricity < 0.001 { // si arrotonda per evitare strani bug
		if eta:apoapsis < secondsNeeded {
				lock throttle to max(0.4, 1 - malus). // se stiamo troppo larghi riduciamo il gas, ma non di troppo
				set secondsNeeded to eta:apoapsis.
				set firstETAJump to true.
			} else if firstETAJump { // quando c'è un salto grande di ETA controlliamo e decidiamo se è il caso di raffinare
				lock throttle to 0.	
				if (eta:apoapsis - secondsNeeded)/secondsNeeded > 0.1 // evita che ci sia un feedback negativo continuo
					set malus to eta:apoapsis/secondsNeeded.
			} else {
				lock throttle to 0.
			}
		set oldeccentricity to ship:orbit:eccentricity.
		wait 0.01.
	}
	lock throttle to 0.
}

// COMMANDS TO EXECUTE MISSION
if ship:apoapsis < aptarget {
setup().

liftOff().

deltaVstage(true).

when deltaVstage() = 0 then { // stage if the fuel is empty in the current stage
	stage.
	if deltaVstage(true) = 0 // if the new stage has no fuel drop the trigger
		false.
	else
		true.
}

printer("PREPARING GRAVITY TURN").

gravityTurn(apTarget,perTarget,inclination).

}

orbitTurn(apTarget,perTarget,inclination).
