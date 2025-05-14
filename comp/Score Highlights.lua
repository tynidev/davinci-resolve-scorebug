--[[
================================================================================
Script Name: Adjust Score Markers.lua
Author: Tyler
Created: May 11, 2025
Last Modified: May 12, 2025

Description:
This script automatically adjusts sport score markers in DaVinci Resolve to create
highlight regions. It takes each existing score marker and:

1. Moves the marker start point back by 15 seconds
2. Sets the marker duration to 15 seconds
3. This positions the end of each marker exactly where the original marker was

The result is a set of markers that represent the lead-up to each scoring event,
creating easy-to-navigate highlight regions. Editors can quickly jump between
these extended markers to review and edit key moments in the game.

The script processes markers by color, matching the same color scheme as Set Scores.lua:
- Blue markers: Left team scoring events
- Red markers: Right team scoring events

Usage:
1. First place markers at the exact frames where scores occur
    - Blue for left team scores
    - Red for right team scores
2. Run this script to convert them into highlight regions
3. Use Resolve's marker navigation to jump between highlight segments

All operations are wrapped in undo groups for easy reversal if needed.
================================================================================
--]]

-- Import utility functions
local utils = dofile(app:MapPath("Scripts:\\Utility\\utils.lua"))

--[[
  Adjusts a marker's start time to 15 seconds prior and sets its duration to 15 seconds
  This makes the marker end exactly where it originally started
  
  @param markerFrame number - The original frame where the marker is placed
  @param fps number - The project's frame rate (frames per second)
  @return table - Contains the new start frame and duration in frames
]]
local function ComputeNewMarkerTiming(markerFrame, fps)
    -- Set the duration to 15 seconds in frames
    local durationFrames = math.floor(15 * fps)
    
    -- Calculate the new start frame by subtracting 15 seconds in frames
    local newStartFrame = math.floor(markerFrame - durationFrames)
    if(newStartFrame < 0) then
        newStartFrame = 0 -- Ensure we don't go below frame 0
    end
    
    return {
        startFrame = newStartFrame,
        duration = durationFrames
    }
end

--[[
  Applies the marker timing adjustment to all markers of a specific color
  
  @param resolveObjs table - Table containing initialized Resolve objects from utils.initializeCoreResolveObjects()
  @param color string - The marker color to adjust (e.g. "Red", "Blue")
  @return number - The number of markers adjusted
]]
local function AdjustColoredMarkers(resolveObjs, color)
    -- Validate input
    if not resolveObjs or not resolveObjs.tl then
        print("[ERROR] AdjustColoredMarkers: Invalid or missing resolveObjs parameter")
        return 0
    end
    
    print("Adjusting " .. color .. " markers...")
    
    local markers = utils.GetTimelineMarkers(resolveObjs.tl, {color = color})
    local adjusted = 0
    
    -- Process markers in frame order
    for i = 1, #markers do
        local marker = markers[i]
        local originalFrame = marker.frame
        local newTiming = ComputeNewMarkerTiming(originalFrame, resolveObjs.fps)
        
        if utils.UpdateTimelineMarker(resolveObjs.tl, marker, {
            frame = newTiming.startFrame,
            duration = newTiming.duration
        }) then
            print(string.format("Adjusted marker '%s' (originally at frame %d) → now starts at frame %d with %d frame duration", 
                marker.name or "Unnamed", originalFrame, newTiming.startFrame, newTiming.duration))
            adjusted = adjusted + 1
        else
            print(string.format("[ERROR] Failed to adjust marker '%s' (originally at frame %d)", 
                marker.name or "Unnamed", originalFrame))
        end
    end
    
    print("Total " .. color .. " markers adjusted: " .. adjusted)
    return adjusted
end

-- Main execution
local function Main()
    -- Initialize core Resolve objects
    resolveObjs = utils.initializeCoreResolveObjects() -- Ensure resolveObjs is local or assigned if not already
    if not resolveObjs then
        print("[ERROR] Score Highlights: Failed to initialize Resolve objects.")
        return false
    end

    composition = utils.ensureFusionComposition() -- Ensure composition is local or assigned
    if not composition then
        print("[ERROR] Score Highlights: Failed to get or create Fusion composition via utility function.")
        return false
    end    composition:StartUndo("Adjust Markers")
    local leftMarkers = AdjustColoredMarkers(resolveObjs, utils.CONFIG.GAME_MARKERS.LEFT_TEAM)
    local rightMarkers = AdjustColoredMarkers(resolveObjs, utils.CONFIG.GAME_MARKERS.RIGHT_TEAM)
    composition:EndUndo(true)

    -- Summary
    print("\n========= SUMMARY =========")
    print("Left team markers adjusted: " .. leftMarkers)
    print("Right team markers adjusted: " .. rightMarkers)
    print("Total markers adjusted: " .. (leftMarkers + rightMarkers))
    print("============================")
    return true
end

return Main() -- Execute Main and return its status