class_name LocalHost
extends WorldHost

## Solo host: one player, coins from market sales, saved to a file on the device.
## Every change writes a new file and swaps it in, so a crash never leaves half
## a save. Nothing reports success before the save succeeds.

const C = preload("res://scripts/game/catalogue.gd")
var path := "user://tuvlo-world-save.json"
var data := {}

func _ready() -> void:
	reload()

func reload() -> void:
	data = {"version": 1, "coins": C.SOLO_STARTING_COINS, "earned": 0, "records": [], "receipts": {}}
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary and int(parsed.get("version", 0)) == 1 and parsed.get("records") is Array:
			data = parsed
		else:
			# Keep an unreadable save aside instead of overwriting it.
			DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".unreadable-%d" % Time.get_unix_time_from_system()))
	changed.emit()

func _save(next: Dictionary) -> bool:
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(next))
	file.close()
	if file.get_error() != OK: return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(path)) != OK: return false
	data = next
	changed.emit()
	return true

func wallet() -> int: return int(data.coins)
func progress() -> int: return int(data.earned) / C.SOLO_SALES_PER_LEVEL
func features() -> Dictionary: return {"market": true}
func load_records() -> Array: return data.records.duplicate(true)

func append_records(records: Array) -> bool:
	var next := data.duplicate(true)
	next.records.append_array(records)
	return _save(next)

func commit_purchase(request_id: String, price: int, records: Array) -> Dictionary:
	if data.receipts.has(request_id): return {"ok": true, "receipt": data.receipts[request_id]}
	if price < 0: return {"ok": false, "error": "invalid"}
	if int(data.coins) < price: return {"ok": false, "error": "short"}
	var next := data.duplicate(true)
	var receipt := {"id": request_id, "price": price, "at": Time.get_unix_time_from_system()}
	next.coins = int(next.coins) - price
	next.receipts[request_id] = receipt
	next.records.append_array(records)
	return {"ok": true, "receipt": receipt} if _save(next) else {"ok": false, "error": "save"}

func grant(request_id: String, amount: int, records: Array) -> Dictionary:
	if data.receipts.has(request_id): return {"ok": true, "receipt": data.receipts[request_id]}
	if amount < 0: return {"ok": false, "error": "invalid"}
	var next := data.duplicate(true)
	var receipt := {"id": request_id, "amount": amount, "at": Time.get_unix_time_from_system()}
	next.coins = int(next.coins) + amount
	next.earned = int(next.earned) + amount
	next.receipts[request_id] = receipt
	next.records.append_array(records)
	return {"ok": true, "receipt": receipt} if _save(next) else {"ok": false, "error": "save"}
