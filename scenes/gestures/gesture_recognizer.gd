extends RefCounted

class_name GestureRecognizer

# Recognises a mouse stroke as "circle", "triangle", "zigzag" or "line" ("" = unrecognised).
#
# Lines are detected by straightness (start-to-end distance / path length), keeping the drawn
# direction for the laser. Everything else uses the $1 Unistroke Recognizer (Wobbrock, Wilson
# & Li, 2007): resample to N points, rotate so the first point sits at angle 0 around the
# centroid, scale to a square, centre on the origin, then find the template with the smallest
# average point distance (searching +/-45 degrees of rotation by golden-section search).
# Templates are generated in code, in both drawing directions.

const N = 64
const SQUARE = 250.0
const HALF_DIAGONAL = 0.5 * sqrt(2.0 * SQUARE * SQUARE)
const ANGLE_RANGE = PI / 4.0
const ANGLE_PRECISION = PI / 90.0
const PHI = 0.6180339887
const MIN_SCORE = 0.80          # below this the stroke fizzles
const LINE_STRAIGHTNESS = 0.92  # start-end distance / path length for a line
const MIN_LENGTH = 60.0         # pixels; shorter strokes are ignored

var templates: Array = []   # [[name, normalised points], ...]


func _init():
	var circle = PackedVector2Array()
	for i in 33:
		circle.append(Vector2.from_angle(TAU * i / 32.0) * 100.0)
	_add("circle", circle)

	var triangle = PackedVector2Array([Vector2(0, -100), Vector2(87, 50), Vector2(-87, 50), Vector2(0, -100)])
	_add("triangle", triangle)

	# zigzags: saw-tooth lines with 3 to 6 strokes, plus a "Z"
	for strokes in range(3, 7):
		var saw = PackedVector2Array()
		for k in strokes + 1:
			saw.append(Vector2(k * 50.0, (k % 2) * 100.0))
		_add("zigzag", saw)
	_add("zigzag", PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(0, 100), Vector2(100, 100)]))


# Adds the shape in both drawing directions.
func _add(shape_name: String, points: PackedVector2Array):
	templates.append([shape_name, normalize(points)])
	var reversed = points.duplicate()
	reversed.reverse()
	templates.append([shape_name, normalize(reversed)])


# Returns {"name": String, "score": float, "direction": Vector2}
func recognize(points: PackedVector2Array) -> Dictionary:
	var result = {"name": "", "score": 0.0, "direction": Vector2.ZERO}
	if points.size() < 2:
		return result
	var length = path_length(points)
	if length < MIN_LENGTH:
		return result
	var start = points[0]
	var end = points[points.size() - 1]
	var straightness = start.distance_to(end) / length
	if straightness >= LINE_STRAIGHTNESS:
		return {"name": "line", "score": straightness, "direction": (end - start).normalized()}

	# Zigzags are recognised structurally (see is_zigzag): random scribbles score up to ~0.83
	# against zigzag templates, so template matching alone can't separate them.
	if is_zigzag(points):
		return {"name": "zigzag", "score": 1.0, "direction": (end - start).normalized()}

	var candidate = normalize(points)
	var best = INF
	for template in templates:
		if template[0] == "zigzag":
			continue
		var d = _distance_at_best_angle(candidate, template[1])
		if d < best:
			best = d
			result.name = template[0]
	result.score = 1.0 - best / HALF_DIAGONAL
	result["best"] = result.name   # closest shape even when below the threshold (snap assist)
	if result.score < MIN_SCORE:
		result.name = ""
	return result


# A zigzag keeps moving forward along its start->end axis while swinging sideways at least
# twice, and doesn't end where it started (unlike circles/triangles). A swing only counts when
# the sideways leg before it was substantial (>= SWING_FRACTION of the forward length), so hand
# jitter and random scribbles don't qualify.
const SWING_FRACTION = 0.12

func is_zigzag(points: PackedVector2Array) -> bool:
	var pts = resample(points, 40)
	var axis = pts[pts.size() - 1] - pts[0]
	var forward_length = axis.length()
	if forward_length < 0.2 * path_length(pts):
		return false
	axis = axis.normalized()
	var normal = axis.orthogonal()
	var forward_steps = 0
	var switches = 0
	var leg = 0.0        # sideways distance covered in the current direction
	var leg_side = 0
	for i in range(1, pts.size()):
		var step = pts[i] - pts[i - 1]
		var step_length = step.length()
		if step_length < 0.001:
			continue
		if step.dot(axis) >= -0.15 * step_length:
			forward_steps += 1
		var sideways = step.dot(normal)
		var side = 1 if sideways > 0.0 else -1
		if side == leg_side or leg_side == 0:
			leg += absf(sideways)
			leg_side = side
		elif absf(sideways) > 0.3 * step_length:
			if leg >= SWING_FRACTION * forward_length:
				switches += 1
			leg = absf(sideways)
			leg_side = side
	return forward_steps >= 0.8 * (pts.size() - 1) and switches >= 2


func normalize(points: PackedVector2Array) -> PackedVector2Array:
	var pts = resample(points, N)
	pts = rotate_by(pts, -indicative_angle(pts))
	pts = scale_to_square(pts, SQUARE)
	return translate_to(pts, Vector2.ZERO)


static func path_length(pts: PackedVector2Array) -> float:
	var d = 0.0
	for i in range(1, pts.size()):
		d += pts[i - 1].distance_to(pts[i])
	return d


static func resample(points: PackedVector2Array, n: int) -> PackedVector2Array:
	var pts = points.duplicate()
	var interval = path_length(pts) / (n - 1)
	var accumulated = 0.0
	var out = PackedVector2Array([pts[0]])
	var i = 1
	while i < pts.size():
		var d = pts[i - 1].distance_to(pts[i])
		if d > 0.0 and accumulated + d >= interval:
			var q = pts[i - 1] + (interval - accumulated) / d * (pts[i] - pts[i - 1])
			out.append(q)
			pts.insert(i, q)
			accumulated = 0.0
		else:
			accumulated += d
		i += 1
	while out.size() < n:   # rounding can leave us one short
		out.append(points[points.size() - 1])
	return out.slice(0, n)


static func centroid(pts: PackedVector2Array) -> Vector2:
	var c = Vector2.ZERO
	for p in pts:
		c += p
	return c / pts.size()


static func indicative_angle(pts: PackedVector2Array) -> float:
	var c = centroid(pts)
	return atan2(c.y - pts[0].y, c.x - pts[0].x)


static func rotate_by(pts: PackedVector2Array, angle: float) -> PackedVector2Array:
	var c = centroid(pts)
	var out = PackedVector2Array()
	for p in pts:
		out.append((p - c).rotated(angle) + c)
	return out


static func scale_to_square(pts: PackedVector2Array, size: float) -> PackedVector2Array:
	var min_p = pts[0]
	var max_p = pts[0]
	for p in pts:
		min_p = min_p.min(p)
		max_p = max_p.max(p)
	var box = (max_p - min_p).max(Vector2(0.001, 0.001))
	var out = PackedVector2Array()
	for p in pts:
		out.append(Vector2(p.x * size / box.x, p.y * size / box.y))
	return out


static func translate_to(pts: PackedVector2Array, target: Vector2) -> PackedVector2Array:
	var offset = target - centroid(pts)
	var out = PackedVector2Array()
	for p in pts:
		out.append(p + offset)
	return out


static func path_distance(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var d = 0.0
	for i in a.size():
		d += a[i].distance_to(b[i])
	return d / a.size()


func _distance_at_angle(pts: PackedVector2Array, template: PackedVector2Array, angle: float) -> float:
	return path_distance(rotate_by(pts, angle), template)


func _distance_at_best_angle(pts: PackedVector2Array, template: PackedVector2Array) -> float:
	var a = -ANGLE_RANGE
	var b = ANGLE_RANGE
	var x1 = PHI * a + (1.0 - PHI) * b
	var f1 = _distance_at_angle(pts, template, x1)
	var x2 = (1.0 - PHI) * a + PHI * b
	var f2 = _distance_at_angle(pts, template, x2)
	while absf(b - a) > ANGLE_PRECISION:
		if f1 < f2:
			b = x2
			x2 = x1
			f2 = f1
			x1 = PHI * a + (1.0 - PHI) * b
			f1 = _distance_at_angle(pts, template, x1)
		else:
			a = x1
			x1 = x2
			f1 = f2
			x2 = (1.0 - PHI) * a + PHI * b
			f2 = _distance_at_angle(pts, template, x2)
	return min(f1, f2)
