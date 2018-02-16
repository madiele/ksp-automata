
parameter aptarget, pertarget, inclination, ANNode.

runoncepath("libs.ks"). // load libraries if not done already

// horizontal speed needed for orbit, see vis-viva.
set spdAtAp to sqrt(body:mu * (2/(aptarget + body:radius) - 1/(((aptarget + body:radius) + (pertarget + body:radius)) / 2))).

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

 function waitForLunchWindow {
	parameter ANNode.
	
	set currentANNode to mod(longitude + BODY:ROTATIONANGLE, 180).
	
	set annode to mod(annode - 1,180).
	
	until floor(mod((longitude + BODY:ROTATIONANGLE),180)) = floor(ANNode) {
	
		set currentANNode to mod(longitude + BODY:ROTATIONANGLE, 180).
		
		if annode - currentANNode > 5 or annode - currentANNode < 0
			set kuniverse:timewarp:rate to 1000.
		else if annode - currentANNode > 1
			set kuniverse:timewarp:rate to 100.
		else if annode - currentANNode > 0.5
			set kuniverse:timewarp:rate to 50.
		else if annode - currentANNode > 0.1
			set kuniverse:timewarp:rate to 10.
		else if annode - currentANNode > 0.05
			set kuniverse:timewarp:rate to 1.
			
		
		printer("annode",annode,1).
		printer("currentANNode",floor(mod((longitude + BODY:ROTATIONANGLE),180)),2).
		printer("annode - ...",annode - mod(longitude + BODY:ROTATIONANGLE, 180),3).
		wait 0.0.1.
	}
	
 }

function liftOff {
	
	local sound is getvoice(0).
	
	
	// countdown to 0 with sound attached
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
	
	// the maximum TWR that we want while in atmoshpere
	local wantedTWR is 2.
	// the angle in which we beging our turn
	local startingAngle is 50.
	// the altitude in which we beging our turn
	local startingAlititude is 3000.
	
	// lock the throttle to the desired TWR, the 0.00001 is to be sure of not dividing by 0
	lock throttle to wantedTWR * Ship:Mass * getg() / (Ship:AvailableThrust+0.00001)..

	
	wait until ship:altitude > startingAlititude.
	printer("ENGAGING GRAVITY TURN").
	
	
	until ship:apoapsis > ap {
		local srfProgradeInclination is vang(up:vector, srfprograde:vector).
		// set pitch of the craft to the inclination of the surface prograde vector after the startingAngle is passed
		local targetPitch is max( 5, min(startingAngle,90 - srfProgradeInclination)). 
		// we correct to the real azimoth using inst_az
		lock steering to heading (inclination, targetPitch). 
		
		
		// if we are out of the atmoshpere forget about the TWR locking
		if (ship:altitude > 70000) lock throttle to 1.
		wait 0.01.
	}

	lock throttle to 0.
}

function orbitTurn {
	parameter ap, per.
	
	printer("PREPARING FOR ORBIT CIRCULARIZATION").
	
	lock throttle to 0.
	lock steering to prograde:vector.
	// our speed at the apoapsis
	local currentApSpd is (sqrt(body:mu * (2/(ship:apoapsis + body:radius) - 1/(((ship:apoapsis + body:radius) + (ship:periapsis + body:radius)) / 2)))).
	// how much horizontal delta v we need to achive our orbit
	local deltaVNeeded is spdAtAp - currentApSpd.
	// for how much we need to floor the gas to get in orbit
	local secondsNeeded is burnTime(deltaVNeeded) * 1.
	// see later for this
	local firstETAJump is true.
	local malus is 0.
	
	wait until ship:altitude > 70000.
	
	kuniverse:timewarp:warpto(time:seconds + eta:apoapsis - 60).

	wait until eta:apoapsis < secondsNeeded.
	printer("ENGAGING ORBIT CIRCULARIZATION").
	local oldeccentricity is ship:orbit:eccentricity.
	
	// if our eccentricity is lower of 0.001 I found that is generaly better to call it done
	until round(ship:orbit:eccentricity, 3) > round(oldeccentricity, 3) or ship:orbit:eccentricity < 0.001 { // rounding due to some weird glitches i encountered
		if eta:apoapsis < secondsNeeded {
				lock throttle to max(0.5, 1 - malus).
				set secondsNeeded to eta:apoapsis. // update the minimum ETA at witch we can throttle up to this one, we never want to increse our ETA
				set firstETAJump to true.
			} else if firstETAJump { // for the first time the ETA goes up we check by how much and decide if we need to apply less throttle
				lock throttle to 0.	
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


// COMMANDS TO EXECUTE MISSION

setup().

setTerminal(30,60,20).


waitForLunchWindow(annode).

liftOff().

deltaVstage(true). // see the function definition for explanation

when deltaVstage() = 0 then { // stage if the fuel is empty in the current stage
	stage.
	if deltaVstage(true) = 0 // if the new stage has no fuel drop the trigger
		false.
	else
		true.
}

printer("PREPARING GRAVITY TURN").

gravityTurn(apTarget,perTarget,inclination).

printer("GRAVITY TURN COMPLETED").

wait until ship:altitude > 70000.

orbitTurn(apTarget,perTarget).


printer("LUNCH IN TO ORBIT COMPLETED").
