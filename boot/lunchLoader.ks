
set ap to 72000.
set per to 72000.
set inc to 90.
set ANNode to 0.



set _debug to true.
if _debug {
	copypath("0:/ksp-automata/lunch.ks","1:").
	copypath("0:/ksp-automata/libs.ks","1:").
	runoncepath("libs.ks").
	set _debug to true.
	if ship:status = "PRELAUNCH"
		runpath("lunch", ap, per, inc, ANNode).
} else {
	compile "0:/ksp-automata/lunch.ks" to "1:/lunch.ksm".
	compile "0:/ksp-automata/libs.ks" to "1:/libs.ksm".
	runoncepath("libs.ksm").
	if ship:status = "PRELAUNCH"
		runpath("lunch", "buggedParameter", ap , per , inc, ANNode). //for some weird reason if you compile you are then asked for 1 extra parameter, don't know why
}