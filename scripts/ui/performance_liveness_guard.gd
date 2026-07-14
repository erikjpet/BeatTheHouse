class_name PerformanceLivenessGuard
extends RefCounted


static func evaluate(surface: String, counter: String, floor: int, measured: int) -> Dictionary:
	var minimum := maxi(0, floor)
	var actual := maxi(0, measured)
	if actual >= minimum:
		return {
			"passed": true,
			"surface": surface,
			"counter": counter,
			"floor": minimum,
			"measured": actual,
			"message": "",
		}
	return {
		"passed": false,
		"surface": surface,
		"counter": counter,
		"floor": minimum,
		"measured": actual,
		"message": "%s liveness counter %s advanced %d time(s), below floor %d." % [
			surface,
			counter,
			actual,
			minimum,
		],
	}
