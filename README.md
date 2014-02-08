Mapper
======

Mapper is a script in LSL that will generate a prim-based map from a list of region names in Second Life.

How To
------

You make an object with enough prims for all the regions you want to display, plus two.

The root prim will be the map background. You can resize it to whatever size you prefer, decorate it however you want. The top face (face 0) will be the map side.

Add a notecard named 'Regions'. This notecard should contain a list of region names, one per line.

Add the Mapper.lsl script.

The object will take some time to make a number of queries and then re-arrange itself into a map.

You can click on the tiles of the map to get a teleport offer in chat. Click the URL in chat and you'll be teleported to that region.

More How To
-----------

It turns out that LSL is buggy. A shocker, I know. But llRequestRegionInfo() can return the wrong information for some regions.

To work around this glaring bug, we can add another notecard called 'Regions.json'. This notecard must contain valid JSON which describes the accurate location of the regions in question. You can look at resources/Regions.json to see what this looks like.

Hopefully soon this bug will be fixed, and no one will need to know how to use the Regions.json card.

