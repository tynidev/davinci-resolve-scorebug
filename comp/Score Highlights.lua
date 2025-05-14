--[[
================================================================================
Script Name: Score Highlights.lua
Author: Tyler
Created: May 11, 2025
Last Modified: May 14, 2025

Description:
This script creates highlight regions for sport score events by modifying timeline
markers. It automatically converts single-point markers into regions that show the
lead-up to each scoring event.

For each scoring marker (blue and red), the script:
1. Shifts the marker's position backwards by 15 seconds
2. Sets a 15-second duration for the marker
3. The original marker position becomes the end point of the highlight region

Key Features:
- Works with the colored markers created by Set Scorebug.lua
- Preserves marker names, colors and other attributes
- Creates consistent highlight durations suitable for sports highlight reels
- Processes all markers of specified colors in a single operation

Usage:
1. Run Set Scorebug.lua first to set up score markers at exact score moments
2. Run this script to convert point markers into highlight regions
3. Use Resolve's marker navigation to quickly locate and edit highlight segments

This script is typically run as part of the All Score Processing.lua workflow
but can be used independently if needed.
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