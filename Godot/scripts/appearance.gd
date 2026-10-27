class_name HomesteadAppearance
extends RefCounted
const DEFAULT={"skin":2,"face":0,"eyes":0,"eye_color":0,"hair":0,"hair_color":1,"glasses":0,"freckles":0,"height":1,"build":1,"outfit":0,"top":0,"bottom":0,"shoes":0,"scarf":0,"hat":0,"pattern":0,"expression":0,"accessory":0}
const SKINS=["FFE0B8","F6BE8C","E8A56A","C67A42","9A5C38","60402E"]
const HAIR_COLORS=["282839","684735","B8703D","E8BF69","A58BCD"]
const EYES=["423b33","5c7869","5b7488","8a6242"]
const TOPS=["3B8FFF","B090F0","FF6B78","2EBF8A","FFC53D","FF8A3D"]
const BOTTOMS=["b59562","657e9a","9c7c9a","8caa7f","ba856e","e2c3a6"]
const SHOES=["975f48","586a66","798db0","e6d8bc"]
const SCARVES=["c58462","d9b468","7c9da6","b293ab"]
const FIELDS={
 "hat":{"options":["None","Baseball","Backwards"]},
 "pattern":{"options":["Plain","Stripes","Star","Flower","Dots"]},
 "expression":{"options":["Smile","Grin","Freckles","Dimples"]},
 "accessory":{"options":["None","Neckerchief"]},
 "skin":{"label":"Skin tone","options":["Porcelain","Peach","Honey","Caramel","Chestnut","Cocoa"],"tab":0},
 "face":{"label":"Face shape","options":["Soft","Round","Oval","Square"],"tab":0},
 "eyes":{"label":"Eye shape","options":["Round","Wide","Soft almond"],"tab":0},
 "eye_color":{"label":"Eye color","options":["Brown","Green","Blue","Amber"],"tab":0},
 "hair":{"label":"Hairstyle","options":["Crop","Swoop","Curls","Long","Bob","Ponytail","Pigtails","Afro","Braids","Wavy","Bun","Spiky","Side part"],"tab":0},
 "hair_color":{"label":"Hair color","options":["Ink","Walnut","Copper","Golden","Silver"],"tab":0},
 "glasses":{"label":"Glasses","options":["None","Round frames"],"tab":0},
 "freckles":{"label":"Freckles","options":["None","A few freckles"],"tab":0},
 "height":{"label":"Height","options":["Short","Medium","Tall"],"tab":1},
 "build":{"label":"Body shape","options":["Slim","Soft","Broad"],"tab":1},
 "outfit":{"label":"Outfit","options":["T-shirt","Hoodie","Dress","Polo","Overalls","Cardigan"],"tab":2},
 "top":{"label":"Top color","options":["Sage","Sky","Coral","Lilac","Sunflower","Linen"],"tab":2},
 "bottom":{"label":"Bottom / dress color","options":["Sand","Denim","Plum","Fern","Terracotta","Peach"],"tab":2},
 "shoes":{"label":"Shoe color","options":["Clay","Forest","Blue","Cream"],"tab":2},
 "scarf":{"label":"Neckerchief","options":["Rust","Honey","Teal","Lavender"],"tab":2}
}
static func normalize(raw: Dictionary) -> Dictionary:
 var result=DEFAULT.duplicate()
 for key in DEFAULT:
  var value=raw.get(key,DEFAULT[key])
  if value is int or value is float:
   result[key]=clampi(int(value),0,FIELDS[key].options.size()-1)
 return result
