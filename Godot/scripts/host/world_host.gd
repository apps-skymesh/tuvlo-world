class_name WorldHost
extends Node

## The host interface (docs/ARCHITECTURE.md). The game asks the host for money,
## progress and saving, and never reaches past it. Subclasses: LocalHost (solo
## game on Mac, iPhone and iPad, saved on the device); later a native bridge for
## Tuvlo and for StoreKit purchases.

signal changed

func player() -> Dictionary: return {"id": "local", "name": "", "reduced_motion": false}
func wallet() -> int: return 0
func currency() -> String: return "coins"
## Lifetime count that gates unlocks. Never decreases.
func progress() -> int: return 0
## What the game may show: "market", "speed_ups", "missions_link".
func features() -> Dictionary: return {}
## "full" or "read_only".
func access() -> String: return "full"
func load_records() -> Array: return []
## Free actions (planting, collecting). Returns false if nothing was saved.
func append_records(_records: Array) -> bool: return false
## Atomic debit plus records. Retrying the same request_id never charges twice.
## Returns {"ok": true, "receipt": {...}} or {"ok": false, "error": "..."}.
func commit_purchase(_request_id: String, _price: int, _records: Array) -> Dictionary: return {"ok": false, "error": "unsupported"}
## Adds currency with records (for example a market sale). Hosts may refuse.
func grant(_request_id: String, _amount: int, _records: Array) -> Dictionary: return {"ok": false, "error": "unsupported"}
