-- Import utility functions
local utils = dofile(app:MapPath("Scripts:\\Utility\\utils.lua"))
local udump = utils.dump
local inspectObject = utils.inspectObject
-- local GetMarkersByColor = utils.GetMarkersByColor -- This was not used, and GetTimelineMarkers is preferred
local formatTimeDisplay = utils.formatTimeDisplay
local GetTimelineMarkers = utils.GetTimelineMarkers -- Import GetTimelineMarkers
local CONFIG = utils.CONFIG

-- Initialize Resolve objects using the new utility function
local resolveObjs = utils.initializeCoreResolveObjects()
if not resolveObjs then
    return false -- Exit if initialization failed
end
local pm = resolveObjs.pm
local pr = resolveObjs.pr
local tl = resolveObjs.tl
-- local fps = resolveObjs.fps -- fps is not used in this script

print("--- All Markers ---")
dump(GetTimelineMarkers(tl, {}))

print("--- Markers named HALF ---")
dump(GetTimelineMarkers(tl, {name = "HALF"}))

local half = GetTimelineMarkers(tl, {name = "HALF"})[1];
utils.UpdateTimelineMarker(half, {
    frame = half.frame + 1,
    name = "HALF2",
    note = "Updated Marker"
})