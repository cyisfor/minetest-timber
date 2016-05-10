A heavy reworking of the “timber” mod from xyzz’s modpack.

Cuts the _entire_ tree, not just the wood above. Goes up some, then searches around for nearby uncut wood. Should eliminate the ugly floating leaf clusters when a single tree block is hanging out from the main trunk, as some mods like to do. Prioritizes from high to low, so if you hit the limit for 1 chop, it will leave the lowest blocks uncut in the trunk, not all the highest pieces uncut and scattered around. TODO: name this mod tree_melting? 

Should be a relatively lightweight algorithm. Uses core.after() to postpone work if too many trees are being cut at once.

No config file, just edit init.lua for now.

Cuts all trees, cactus and papyrus.

TODO:
* config file in core.get_modpath("timber")
* use an item to fell trees this way, limit trunks chopped by durability
* items for specific types of timber: chopping the big main trunk, or trimming the floating tree blocks.
* AOE leaf destruction?
