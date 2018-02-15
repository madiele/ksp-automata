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

function currentISP { // possibile trovare quello attuale sostituiendo maxthrust con thrust
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

function getG {
	return body:mu / (ship:altitude + body:radius)^2.
}

declare function printer {

	declare parameter name, value is 0, position is terminal:height.
	
	print "                                         " at (0, position).
	if position = terminal:height {
		print name at (0, terminal:height). return.
	}
	print "name" at (round(terminal:width)/4 - 2,0).
	print "|" at (round(terminal:width),0).
	print "value" at (round(terminal:width)* 3/4 - 2, 0).
	
	
	print name at (0,position).
	print "|" at (round(terminal:width),position).
	print value at (round(terminal:width) + 1, position).
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
	local p is currentISP().
	LOCAL g IS 9.80665.                 // Gravitational acceleration constant (m/s²)

	RETURN g * m * p * (1 - e^(-dV/(g*p))) / f.
}