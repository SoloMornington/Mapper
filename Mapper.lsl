// Mapper
//
// A thingie by Solo Mornington

// License: This is a no-license-at-all license. Use it and be happy.

// Credit:
//
// This script uses a web API set up by Lex Mars.
//
// It's also super-ultra-heavily-modified from a script by Runay Roussel
// though I doubt Runay would recognize any of it at this point.

// How To:
//
// Make an object with enough prims for the number of regions you want to
// map, plus two. So if you want to map 10 regions, make an object with 12
// prims.
//
// Make a notecard called Regions, with the names of the regions you want to
// map, one per line.
//
// Put the notecard in the object.
//
// Put this script in the object.
//
// Gaze in awe as the map makes itself.
//
// It will make itself on the top (0-th face) of the root prim. Map tiles
// will be scaled to fit into this face, including taper.
//
// If the map is in one of the regions being displayed, it will show a
// 'You Are Here' pointer for that region.

// Important Note:
//
// There is a bug in the llRequestRegionInfo()/dataserver somewhere, and it
// results in map tiles being put in the wrong place.
//
// You can work around this by putting a Regions.json notecard in the map
// object. This notecard should contain region information in a JSON format.
//
// This bug will likely not be an issue for most users, but if you find it
// happening, you can store location info in Regions.json and it will override
// whatever llRequestRegionInfo() says.

// Feb. 7, 2014
// Solo Mornington


string gNotecardName = "Regions";
string gDatabaseNotecardName = "Regions.json";

float gMapResetTime = 86400.0;  // timer interval = 24 hours
//float gMapResetTime = 30.0;  // timer interval = 24 hours
float gTimeout = 360.0;
key request; // handle for HTTP request
string gSubnovaUrl = "http://www.subnova.com/secondlife/api/map.php";  // URL of PHP script

integer gCurrentTile; // which prim are we getting the map for?

list gSimNames; // as derived from prim descs
list gSimPrims;

key gDSRequest;
string gDSRequestRegion;
integer gDSIndex;

// Indexes for reading notecards through LSL's idiotic
// notecard reader.
integer gCurrentDatabaseLine;
key gDSDatabaseRequest;
integer gDSDatabaseIndex;
integer gCurrentInfoLine;

// DB loaded from .json notecard.
string gRegionDatabaseJson;
// JSON database for all the stuff.
string gRegionInfoJson;

// Vector of the origin point. Smallest x and smallest y from any region location.
// 3.402823466E+38 is max float value.
vector gOrigin = <3.402823466E+38, 3.402823466E+38, 0>;
vector gAntiOrigin = <0,0,0>;

float gMapMargin = 0.9;

string gMysterySim = "89f68ffb-e4c7-9390-cff7-ee64ce9a185c"; // unknown map tile
string gDefaultTexture = "29167591-7579-40c0-a387-3b4560d92ef5"; // border soft

// This script stores an origin offset in gOrigin.
// This is the lower-left corner of the map we'll be
// generating. We determine this location by comparing
// all the global x and y coordinates of all map tiles.
// AntiOrigin is the top right corner.
geometry_setOrigin(vector location) {
  if (location.x < gOrigin.x) gOrigin.x = location.x;
  if (location.y < gOrigin.y) gOrigin.y = location.y;

  if (location.x > gAntiOrigin.x) gAntiOrigin.x = location.x;
  if (location.y > gAntiOrigin.y) gAntiOrigin.y = location.y;
}

// Return a vector with the number of tiles in x and y.
vector geometry_tileExtent() {
  vector result = <0,0,0>;
  result.x = 1 + ((gAntiOrigin.x - gOrigin.x) / 256.0);
  result.y = 1 + ((gAntiOrigin.y - gOrigin.y) / 256.0);
  return result;
}

// Given a boundary dimension, figure out the best-fit
// dimention for a tile. Tiles are square so we only need
// to return a float.
float geometry_tileSize(vector boundaryDim) {
  vector extent = geometry_tileExtent();
  float tileSize = boundaryDim.x / extent.x;
  float ySize = boundaryDim.y / extent.y;
  if (ySize < tileSize) tileSize = ySize;
  return tileSize;
}

// Put all the prims where they should be.
// Also colorizes according to maturity rating
// and places a 'you are here' pointer where appropriate.
geometry_arrangePrims(float tileSize, float tileZ) {
  string thisRegion = llGetRegionName();
  integer i;
  integer count = llGetListLength(gSimNames);
  vector extent = geometry_tileExtent();
  float originOffsetX = ((extent.x * tileSize) / 2.0) - (tileSize / 2.0);
  float originOffsetY = ((extent.y * tileSize) / 2.0) - (tileSize / 2.0);
  for (i=0; i<=count; ++i) {
    string regionName = llList2String(gSimNames, i);
    vector regionLocation = (vector)llJsonGetValue(gRegionInfoJson, [regionName, "location"]);
    integer regionPrim = (integer)llJsonGetValue(gRegionInfoJson, [regionName, "prim"]);
    vector tileLocation = <
      (((regionLocation.x - gOrigin.x) / 256.0) * tileSize) - originOffsetX,
      (((regionLocation.y - gOrigin.y) / 256.0) * tileSize) - originOffsetY,
      tileZ
    >;
    if (regionName == thisRegion) {
      setYouAreHere(tileLocation, tileSize);
    }
    llSetLinkPrimitiveParamsFast(regionPrim, 
      tilePrimParams(regionName, tileLocation, tileSize));
  }
}

// Generates a tile prim parameter list given a few pieces of info.
list tilePrimParams(string regionName, vector tileLocation, float tileSize) {
    string regionTexture = llJsonGetValue(gRegionInfoJson, [regionName, "texture"]);
    string regionMaturity = llJsonGetValue(gRegionInfoJson, [regionName, "maturity"]);
    // Default to grey for Moderate.
    vector tileColor = <0.8,0.8,0.8>;
    if(regionMaturity == "PG") tileColor = <0.0, 0.0, 1.0>;
    if(regionMaturity == "ADULT") tileColor = <1.0, 0.0, 0.0>;
    list params = [
      PRIM_TYPE, PRIM_TYPE_BOX,
      PRIM_HOLE_DEFAULT, <0,1,0>, 0.0, <0,0,0>, <0.97, 0.97, 0>, <0,0,0>,
      PRIM_POS_LOCAL, tileLocation,
      PRIM_SIZE, <tileSize, tileSize, tileSize / 10.0>,
      PRIM_COLOR, ALL_SIDES, tileColor, 1.0,
      PRIM_TEXTURE, 0, regionTexture, <1,1,0>, <0,0,0>, 0.0,
      PRIM_COLOR, 0, <1,1,1>, 1.0,
      PRIM_BUMP_SHINY, 0, 0, 0,
      PRIM_FULLBRIGHT, 0, TRUE,
      PRIM_TEXT, regionName, <1,1,1>, 1.0
    ];
    return params;
}

// Add the 'you are here' prim where appropriate.
setYouAreHere(vector tileLocation, float tileSize) {
  float baseSize = tileSize / 4.0;
  vector primSize = <baseSize, baseSize, baseSize * 2.0>;
  tileLocation.z = tileLocation.z + (baseSize * 2.2);
  llSetLinkPrimitiveParamsFast(2, [
    PRIM_TYPE, PRIM_TYPE_CYLINDER, PRIM_HOLE_DEFAULT, <0,1,0>, 0.0,
      <0,0,0>, <2,2,0>, <0, -0.5, 0>,
    PRIM_POS_LOCAL, tileLocation,
    PRIM_SIZE, primSize,
    PRIM_TEXTURE, 1, TEXTURE_BLANK, <1,1,0>, <0,0,0>, 0.0,
    PRIM_COLOR, 1, <1,0,0>, 1.0,
    PRIM_FULLBRIGHT, 1, FALSE,
    PRIM_BUMP_SHINY, 0, 0, 0,
    // 'You are here' text.
    PRIM_TEXTURE, 0, "377c7087-48fc-603c-09b5-42832de377c9", <1,1,0>, <0,0,0>, 0.0,
    PRIM_COLOR, 0, <1,1,1>, 1.0,
    PRIM_FULLBRIGHT, 0, TRUE
  ]);
}

// send a request for the next tile
// we return TRUE if a request was sent
// FALSE otherwise.
integer getNextTile()
{
    // snooze first so subnova doesn't hate us as much.
    llSleep(0.5);
    ++gCurrentTile;
    if (gCurrentTile < llGetListLength(gSimNames))
    {
        string simName = llList2String(gSimNames,gCurrentTile);
        // Set json to the default texture.
        gRegionInfoJson = llJsonSetValue(gRegionInfoJson, [simName, "texture"], gMysterySim);
        string fullUrl = gSubnovaUrl + "?sim=" + llEscapeURL(simName);
        request = llHTTPRequest(fullUrl, [], "");
        llSetTimerEvent(gTimeout);
        return TRUE;
    }
    return FALSE;
}

// put all non-root prims into a zeroed state, at ZERO_VECTOR,
// transparent, and as small as possible
zeroAllPrimsExcept(integer exception)
{
    integer i;
    integer count = llGetObjectPrimCount(llGetKey());
    for (i=2; i<=count; ++i)
    {
        if (i != exception)
        {
             llSetLinkPrimitiveParamsFast(i,[
               PRIM_POSITION, ZERO_VECTOR,
               PRIM_SIZE, ZERO_VECTOR,
               PRIM_ROT_LOCAL, ZERO_ROTATION,
               PRIM_COLOR, ALL_SIDES, <1,1,1>, 0.0,
               PRIM_TEXT, "", <1,1,1>, 0.0
             ]);
         }
    }
}

// Convenience function to determine if the map should reset
// given certain events. Most states use the same logic so we
// have it here as a function.
resetOnChanged(integer what) {
  if (what &
    (
      CHANGED_INVENTORY |
      //CHANGED_SCALE |
      CHANGED_LINK |
      CHANGED_OWNER |
      CHANGED_REGION |
      CHANGED_TELEPORT |
      CHANGED_REGION_START
    )
  ) {
    llSleep(10.0);
    state default;
  }
}

default
{

  state_entry() {
    gRegionInfoJson = "";
    gSimNames = [];
    zeroAllPrimsExcept(1);
    state readRegionsJsonNotecard;
  }

}

state readRegionsJsonNotecard
{

    state_entry()
    {
      //llOwnerSay("reading notecard...");
      gRegionDatabaseJson = "";
      gDSIndex = 0;
      // Check the notecard exists, and has been saved
      if (llGetInventoryKey(gDatabaseNotecardName) == NULL_KEY) {
        //llOwnerSay("no json");
        gRegionDatabaseJson = llJsonSetValue(gRegionDatabaseJson, ["loaded"], "TRUE");
        state readRegionsNotecard;
      }
      // say("reading notecard named '" + notecardName + "'.");
      gDSRequest = llGetNotecardLine(gDatabaseNotecardName, gDSIndex);
    }
 
    dataserver(key query_id, string data)
    {
        if (query_id == gDSRequest)
        {
            if (data == EOF) {
                state readRegionsNotecard;
            }
            else
            {
                if (data != "") {
                  gRegionDatabaseJson = gRegionDatabaseJson + "\n" + data;
                }
                ++gDSIndex;
                gDSRequest = llGetNotecardLine(gDatabaseNotecardName, gDSIndex);
            }
        }
    }

    changed(integer what)
    { resetOnChanged(what); }

}

state readRegionsNotecard
{

    state_entry()
    {
      //llOwnerSay("reading notecard...");
      gRegionInfoJson = "";
      gSimNames = [];
      gDSIndex = 0;
      // Check the notecard exists, and has been saved
      if (llGetInventoryKey(gNotecardName) == NULL_KEY) {
        llOwnerSay( "Notecard '" + gNotecardName + "' missing or unwritten");
        state iAmDead;
      }
      // say("reading notecard named '" + notecardName + "'.");
      gDSRequest = llGetNotecardLine(gNotecardName, gDSIndex);
    }
 
    dataserver(key query_id, string data)
    {
        if (query_id == gDSRequest)
        {
            if (data == EOF) {
                state gatherTextures;
            }
            else
            {
                if (data != "") {
                  gSimNames += [data];
                  //llOwnerSay(llJsonGetValue(gRegionInfoJson, [data]));
                }
                ++gDSIndex;
                gDSRequest = llGetNotecardLine(gNotecardName, gDSIndex);
            }
        }
    }

    changed(integer what)
    { resetOnChanged(what); }

}

state gatherTextures
{
    state_entry()
    {
    //state gatherLocations;
      //llOwnerSay("gathering textures...");
      gSimPrims = [];
      gCurrentTile = -1;
      llSetTimerEvent(gTimeout);
      if (!getNextTile()) state gatherLocations;
    }

    on_rez(integer start_param)
    {
        llResetScript();
    }

    http_response(key request_id, integer status, list metadata, string body)
    {
        if (status == 200) {
            if ((key)body) {
                string simName = llList2String(gSimNames,gCurrentTile);
                gRegionInfoJson = llJsonSetValue(gRegionInfoJson, [simName, "texture"], body);
                integer currentPrim = gCurrentTile + 3;
                gRegionInfoJson = llJsonSetValue(gRegionInfoJson, [simName, "prim"], (string)(currentPrim));
                gSimPrims += [currentPrim];
                //llOwnerSay(llJsonGetValue(gRegionInfoJson, [simName]));
            }
        }
        else {
          llOwnerSay("Unknown region: " + llList2String(gSimNames,gCurrentTile));
        }
        if (!getNextTile()) state gatherLocations;
    }
    
    timer()
    {
        // this ridiculously obtuse process (thanks, linden lab!)
        // timed out. So let's tell the user and bail.
        llSetTimerEvent(0.0);
        llSay(0, "Unable to gather all the map tiles before time ran out. Click to try again.");
        state iAmDead;
    }

    changed(integer what)
    { resetOnChanged(what); }
}

state gatherLocations
{

  state_entry() {
    //llOwnerSay("gathering locations...");
    gOrigin = <3.402823466E+38, 3.402823466E+38, 0>;
    gAntiOrigin = <0,0,0>;
    if (llGetListLength(gSimNames) > 0) {
      gDSRequestRegion = llList2String(gSimNames, 0);
      //llOwnerSay("requesting: " + gDSRequestRegion);
      gDSRequest = llRequestSimulatorData(gDSRequestRegion, DATA_SIM_POS);
      llSetTimerEvent(gTimeout);
    }
    else {
      state iAmDead;
    }
  }

  dataserver(key query, string data) {
    if (query == gDSRequest) {
      if (data != "") {
        gRegionInfoJson = llJsonSetValue(gRegionInfoJson, [gDSRequestRegion, "location"], data);
        // Check if this location defines a new origin/anti-origin.
        geometry_setOrigin((vector)data);
      }
      integer simIndex = llListFindList(gSimNames, [gDSRequestRegion]);
      ++simIndex;
      //llOwnerSay((string)simIndex);
      if (simIndex < llGetListLength(gSimNames)) {
        gDSRequestRegion = llList2String(gSimNames, simIndex);
        //llSleep(0.5);
        gDSRequest = llRequestSimulatorData(gDSRequestRegion, DATA_SIM_POS);
      }
      else {
        state correctLocations;
      }
    }
  }

  timer() {
    llSetTimerEvent(0.0);
    state iAmDead;
  }

    changed(integer what)
    { resetOnChanged(what); }

}

// Use notecard database to correct locations that LSL SCREWED UP.
state correctLocations
{
  state_entry() {
    integer i;
    integer count = llGetListLength(gSimNames);
    string region;
    string location;
    for (i=0; i<count; ++i) {
      region = llList2String(gSimNames, i);
      location = llJsonGetValue(gRegionDatabaseJson, [region, "location"]);
      if ((location != "") && (location != JSON_INVALID)) {
        //llOwnerSay("correcting: " + region);
        gRegionInfoJson = llJsonSetValue(gRegionInfoJson, [region, "location"], location);
      }
    }
    state gatherMaturityRatings;
  }
}

state gatherMaturityRatings
{

  state_entry() {
    //llOwnerSay("gathering maturity ratings...");
    if (llGetListLength(gSimNames) > 0) {
      gDSRequestRegion = llList2String(gSimNames, 0);
      //llOwnerSay("requesting: " + gDSRequestRegion);
      gDSRequest = llRequestSimulatorData(gDSRequestRegion, DATA_SIM_RATING);
      llSetTimerEvent(gTimeout);
    }
    else {
      state iAmDead;
    }
  }

  dataserver(key query, string data) {
    if (query == gDSRequest) {
      if (data != "") {
        gRegionInfoJson = llJsonSetValue(gRegionInfoJson, [gDSRequestRegion, "maturity"], data);
        //llOwnerSay("setting rating: " + gDSRequestRegion + " at " + data);
      }
      integer simIndex = llListFindList(gSimNames, [gDSRequestRegion]);
      ++simIndex;
      //llOwnerSay((string)simIndex);
      if (simIndex < llGetListLength(gSimNames)) {
        gDSRequestRegion = llList2String(gSimNames, simIndex);
        //llSleep(0.5);
        gDSRequest = llRequestSimulatorData(gDSRequestRegion, DATA_SIM_RATING);
      }
      else {
        state arrangePrims;
      }
    }
  }

  timer() {
    llSetTimerEvent(0.0);
    state iAmDead;
  }

    changed(integer what)
    { resetOnChanged(what); }

}

state arrangePrims
{
  state_entry() {
    zeroAllPrimsExcept(1);

    list rootPrimInfo = llGetLinkPrimitiveParams(1, [PRIM_SIZE, PRIM_TYPE]);
    vector rootPrimDim = llList2Vector(rootPrimInfo, 0);
    vector rootPrimTopSize = llList2Vector(rootPrimInfo, 6);
    rootPrimDim.x = (rootPrimDim.x * gMapMargin) * rootPrimTopSize.x;
    rootPrimDim.y = (rootPrimDim.y * gMapMargin) * rootPrimTopSize.y;
    float tileSize = geometry_tileSize(rootPrimDim);
    float z = (rootPrimDim.z / 2.0) + (tileSize / 20);
    geometry_arrangePrims(tileSize, z);
    state clickyMap;
  }
  
    on_rez(integer start_param)
    { llResetScript(); }

    changed(integer what) {
      //absorb changed events.
    }
}

state updateData
{
  state_entry() {
    gRegionInfoJson = "";
    state gatherTextures;
  }
}

state clickyMap
{
    state_entry()
    {
      //llOwnerSay("regions json: " + gRegionInfoJson);
      //llOwnerSay("clicky map.");
      llSetTimerEvent(gMapResetTime);
    }

    on_rez(integer start_param)
    { llResetScript(); }

    changed(integer what)
    { resetOnChanged(what); }

    timer()
    {
        llSetTimerEvent(0.0);
        state updateData;
    }

    touch_start(integer total_number)
    {
      integer i;
      for (i=0; i<total_number; ++i)
      {
        integer link = llDetectedLinkNumber(i);
        integer simIndex = llListFindList(gSimPrims, [link]);
        if (simIndex >= 0) {
          string simName = llList2String(gSimNames, simIndex);
          //llRegionSayTo(llDetectedKey(i), 0, simName + ": " + (string) llJsonGetValue(gRegionInfoJson, [simName, "location"]));
          llRegionSayTo(llDetectedKey(i), 0, "Teleport by clicking here: secondlife:///app/teleport/" + llEscapeURL(simName) + "/128/128/51/");
        }
      }
    }
}

state iAmDead
{
    state_entry()
    {
      llOwnerSay("This map was unable to initialize itself. Click to reset.");
    }
    
    touch_start(integer foo)
    {
        llSay(0,"Restarting...");
        state default;
    }

    changed(integer what)
    { resetOnChanged(what); }
}
