--[[
================================================================================
Script Name: WhiteMarkers.lua
Author: Tyler
Created: May 11, 2025
Last Modified: May 11, 2025

Description:
This script converts all colored timeline markers to white while preserving their 
original color information in the marker notes. This is useful for creating a 
clean, uniform look in the timeline while maintaining the ability to restore 
the original color scheme later if needed.

The script:
1. Scans the timeline for all markers
2. Records each marker's original color in its note field
3. Changes all markers to white
4. Provides a summary of how many markers of each color were converted

Usage:
1. Run this script from the Fusion Scripts menu
2. All markers will be converted to white with their original colors noted

All operations are wrapped in an undo group for easy reversal if needed.
================================================================================
--]]

-- Import utility functions
local utils = dofile(app:MapPath("Scripts:\\Utility\\utils.lua"))
local CONFIG = utils.CONFIG

--[[
  Converts all timeline markers to white while preserving their original color in notes
  
  @param resolveObjs table - Table containing initialized Resolve objects from utils.initializeCoreResolveObjects()
  @return table - Contains counts of converted markers by original color
]]
local function WhiteOutMarkers(resolveObjs)
    -- Validate input
    if not resolveObjs or not resolveObjs.tl then
        print("[ERROR] WhiteOutMarkers: Invalid or missing resolveObjs parameter")
        return {}
    end
    local tl = resolveObjs.tl

    -- Get all markers using the utility function
    local allMarkersArray = utils.GetTimelineMarkers(tl)
    
    -- Track how many markers of each color we convert
    local converted = {}
    
    -- Process each marker
    for _, marker in ipairs(allMarkersArray) do
        local originalColor = marker.color

        -- Skip already white markers
        if originalColor ~= CONFIG.COLORS.CREAM then
            -- Update the count for this color
            converted[originalColor] = (converted[originalColor] or 0) + 1
            
            -- Add color info to the note
            local newNote = "[Original color: " .. originalColor .. "]" .. (marker.note or "")
            
            -- Update the marker to white and prepend original color to note
            utils.UpdateTimelineMarker(tl, marker, {
                color = CONFIG.COLORS.CREAM,
                note = newNote
            })
        end
    end
    
    return converted
end

--[[
  Prints a summary of the markers converted to white
  
  @param converted table - Contains counts of converted markers by original color
]]
local function PrintSummary(converted)
    print("\n========= CONVERTED MARKERS =========")
    
    local total = 0
    local colorNames = {}
    
    -- Collect color names for sorting
    for color, count in pairs(converted) do
        table.insert(colorNames, color)
        total = total + count
    end
    
    -- Sort color names alphabetically
    table.sort(colorNames)
    
    -- Print count for each color
    for _, color in ipairs(colorNames) do
        print(color .. ": " .. converted[color])
    end
    
    print("--------------------------------")
    print("Total markers converted: " .. total)
    print("==================================")
end

local function Main()
    -- Get/Ensure Fusion Composition using the utility function
    local composition = utils.ensureFusionComposition()
    if not composition then
        print("[ERROR] Whiteout Markers: Failed to get or create Fusion composition via utility function.")
        return false
    end

    -- Access core Resolve objects for WhiteOutMarkers function
    local resolveObjs = utils.initializeCoreResolveObjects()
    if not resolveObjs then
        print("[ERROR] Whiteout Markers: Failed to initialize Resolve objects.")
        return false
    end    print("Converting colored markers to white...")
    composition:StartUndo("Convert Markers to White")

    -- Pass resolveObjs to WhiteOutMarkers directly
    local converted = WhiteOutMarkers(resolveObjs) -- Now taking resolveObjs as parameter

    PrintSummary(converted)

    composition:EndUndo(true)
    print("Done! All markers have been converted to white with their original colors preserved in notes.")
    return true
end

return Main()