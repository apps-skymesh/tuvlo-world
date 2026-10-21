class_name HomesteadHabitat
extends RefCounted
const NEARBY=4.25
const FLOWERS_NEEDED=3
static func best(data: HomesteadWorldData) -> Dictionary:
	var result={"count":0,"pond":{},"flowers":[]}
	for item in data.items:
		if item.kind!="pond": continue
		var nearby=[]
		for flower in data.items:
			if flower.kind=="flowers" and HomesteadItems.item_center(item).distance_to(HomesteadItems.item_center(flower))<=NEARBY:
				nearby.append(flower.id)
		if result.pond.is_empty() or nearby.size()>result.count:
			result={"count":nearby.size(),"pond":item,"flowers":nearby}
	return result
