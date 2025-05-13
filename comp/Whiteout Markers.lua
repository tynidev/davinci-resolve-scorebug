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
  
  @return table - Contains counts of converted markers by original color
]]
local function WhiteOutMarkers()
    -- Access the current project and timeline
    local pm = resolve:GetProjectManager()
    local pr = pm:GetCurrentProject()
    
    if not pr then
        print("Error: No project is currently open")
        return {}
    end
    
    local tl = pr:GetCurrentTimeline()
    if not tl then
        print("Error: No timeline is currently active")
        return {}
    end
    
    -- Get all markers
    local allMarkers = tl:GetMarkers()
    
    -- Track how many markers of each color we convert
    local converted = {}
    
    -- Process each marker
    for frame, marker in pairs(allMarkers) do
        local originalColor = marker.color

        -- Skip already white markers
        if originalColor ~= CONFIG.COLORS.CREAM then
            -- Update the count for this color
            converted[originalColor] = (converted[originalColor] or 0) + 1
            
            -- Add color info to the note
            local newNote = "[Original color: " .. originalColor .. "]"
            
            -- Delete the original marker
            tl:DeleteMarkerAtFrame(frame)
            
            -- Create a new white marker with updated note
            tl:AddMarker(
                frame,            -- frameId
                CONFIG.COLORS.CREAM,  -- Using CREAM color instead of hardcoded value
                marker.name,      -- name
                newNote,          -- note (now contains original color info)
                marker.duration,  -- duration
                marker.customData -- customData (if any)
            )
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

-- Main execution
print("Converting colored markers to white...")
comp:StartUndo("Convert Markers to White")

local converted = WhiteOutMarkers()
PrintSummary(converted)

comp:EndUndo(true)
print("Done! All markers have been converted to white with their original colors preserved in notes.")