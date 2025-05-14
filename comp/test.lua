-- Import utility functions
local utils = dofile(app:MapPath("Scripts:\\Utility\\utils.lua"))
local udump = utils.dump
local inspectObject = utils.inspectObject
local GetMarkersByColor = utils.GetMarkersByColor
local formatTimeDisplay = utils.formatTimeDisplay
local GetTimelineMarkers = utils.GetTimelineMarkers -- Import GetTimelineMarkers
local CONFIG = utils.CONFIG

pm = resolve:GetProjectManager()
if not pm then
    print("[ERROR] Failed to get Project Manager")
    return false
end

pr = pm:GetCurrentProject()
if not pr then
    print("[ERROR] No project is currently open")
    return false
end

tl = pr:GetCurrentTimeline()
if not tl then
    print("[ERROR] No timeline is currently active")
    return false
end

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