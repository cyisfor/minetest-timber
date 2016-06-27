A heavy reworking of the “timber” mod from xyzz’s modpack.

This mod makes cutting trees easier. Install this mod, then take an axe and try cutting the very base of a tree. Timber! It turns the nightmare of moretrees into something manageable. Or something too easy, some might say. But if you wish to not cut down the trees, and crawl among their branches risking death as you painstakingly harvest them, then just use your fists instead of an axe, and this mod won’t help you at all. Doesn’t that sound like fun?

Cuts the _entire_ tree, not just the trunk above. Goes up some, then searches around for nearby uncut trunks. Should eliminate the ugly floating leaf clusters, when a single tree block is hanging out from the main trunk, as some mods like to do. Prioritizes from high to low, so if you hit the limit for 1 chop, it will leave the lowest blocks uncut in the trunk, not all the highest pieces uncut and scattered around. TODO: name this mod tree_melting? 

Should be a relatively lightweight algorithm. Uses coroutines and core.after() to postpone work if too many trees are being cut at once.

No config file, just edit init.lua for now.

Cuts all trees, cactus and papyrus.

TODO:
* config file in core.get_modpath("timber")
* items for specific types of timber: chopping the big main trunk, or trimming the floating tree blocks.
* AOE leaf destruction?
