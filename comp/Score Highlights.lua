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
local dump = utils.dump
local GetTimelineMarkers = utils.GetTimelineMarkers
local CONFIG = utils.CONFIG

-- Initialize core Resolve objects
local pm = resolve:GetProjectManager()
if not pm then
    print("[ERROR] Failed to get Project Manager")
    return
end

local pr = pm:GetCurrentProject()
if not pr then
    print("[ERROR] No project is currently open")
    return
end

local tl = pr:GetCurrentTimeline()
if not tl then
    print("[ERROR] No timeline is currently active")
    return
end

-- Get the project frame rate
local fps = pr:GetSetting("timelineFrameRate")
if not fps or fps == 0 then 
    print("[ERROR] Unable to determine project frame rate, using default of 24fps")
    return
else
    print("Project frame rate: " .. fps .. " fps")
end

--[[
  Adjusts a marker's start time to 15 seconds prior and sets its duration to 15 seconds
  This makes the marker end exactly where it originally started
  
  @param markerFrame number - The original frame where the marker is placed
  @param fps number - The project's frame rate (frames per second)
  @return table - Contains the new start frame and duration in frames
]]
local function AdjustMarkerTiming(markerFrame, fps)
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
  
  @param color string - The marker color to adjust (e.g. "Red", "Blue")
  @return number - The number of markers adjusted
]]
local function AdjustColoredMarkers(color)
    print("Adjusting " .. color .. " markers...")
    
    local markers = GetTimelineMarkers(tl, {color = color})
    local adjusted = 0
    
    -- Process markers in frame order
    for i = 1, #markers do
        local frame = markers[i].frame
        local marker = markers[i]
        local newTiming = AdjustMarkerTiming(frame, fps)
        
        -- Delete the original marker
        tl:DeleteMarkerAtFrame(frame)
        
        -- Create a new marker with the adjusted timing
        tl:AddMarker(
            newTiming.startFrame,         -- frameId
            marker.color,                 -- color
            marker.name,                  -- name
            marker.note,                  -- note
            newTiming.duration,           -- duration
            marker.customData             -- customData (if any)
        )
        
        print(string.format("Adjusted marker at frame %d → now starts at frame %d with %d frame duration", 
            frame, newTiming.startFrame, newTiming.duration))
        
        adjusted = adjusted + 1
    end
    
    print("Total " .. color .. " markers adjusted: " .. adjusted)
    return adjusted
end

local composition = comp
if not composition then
    local fusion = resolve:Fusion()
    if not fusion then
        print("[ERROR] Failed to get Fusion")
        return false
    end

    composition = fusion:NewComp()
    if not composition then
        print("[ERROR] could not create a new composition")
        return false
    end
end

-- Main execution
composition:StartUndo("Adjust Markers")
local leftMarkers = AdjustColoredMarkers(CONFIG.GAME_MARKERS.LEFT_TEAM)
local rightMarkers = AdjustColoredMarkers(CONFIG.GAME_MARKERS.RIGHT_TEAM)
composition:EndUndo(true)

-- Summary
print("\n========= SUMMARY =========")
print("Left team markers adjusted: " .. leftMarkers)
print("Right team markers adjusted: " .. rightMarkers)
print("Total markers adjusted: " .. (leftMarkers + rightMarkers))
print("============================")