--[[
================================================================================
Script Name: RestoreMarkerColors.lua
Author: Tyler
Created: May 11, 2025
Last Modified: May 11, 2025

Description:
This script restores the original colors of timeline markers that were previously
converted to white by the WhiteMarkers.lua script. It reads the color information
stored in each marker's note field and reverts the marker to that color.

The script:
1. Scans the timeline for white markers with "[Original color: X]" in their notes
2. Extracts the original color information 
3. Restores each marker to its original color
4. Removes the color information from the note field
5. Provides a summary of how many markers of each color were restored

Usage:
1. Run this script from the Fusion Scripts menu after having used WhiteMarkers.lua
2. All white markers with stored color information will be restored to their original colors

All operations are wrapped in an undo group for easy reversal if needed.
================================================================================
--]]

-- Import utility functions
local utils = dofile(app:MapPath("Scripts:\\Comp\\utils\\utils.lua"))
local CONFIG = utils.CONFIG

--[[
  Extracts original color information from a marker note
  
  @param note string - The marker note text
  @return string, string - The original color and the cleaned note text
]]
local function ExtractColorInfo(note)
    if not note then return nil, "" end
    
    -- Look for the color tag in the note
    local originalColor = note:match("%[Original color: ([^%]]+)%]")
    
    -- Remove the color tag from the note
    local cleanedNote = note:gsub("%[Original color: [^%]]+%]", ""):gsub("^%s*(.-)%s*$", "%1")
    
    return originalColor, cleanedNote
end

--[[
  Restores the original color of all white markers that contain color information in notes
  
  @return table - Contains counts of restored markers by color
]]
local function RestoreMarkerColors()
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
    
    -- Track how many markers of each color we restore
    local restored = {}
    
    -- Process each marker
    for frame, marker in pairs(allMarkers) do
        -- Only process white markers
        if marker.color == CONFIG.COLORS.CREAM then
            local originalColor, cleanedNote = ExtractColorInfo(marker.note)
            
            -- If we found color information, restore the marker
            if originalColor then
                -- Update the count for this color
                restored[originalColor] = (restored[originalColor] or 0) + 1
                
                -- Delete the white marker
                tl:DeleteMarkerAtFrame(frame)
                
                -- Create a new marker with the original color
                tl:AddMarker(
                    frame,            -- frameId
                    originalColor,    -- color (restored from note)
                    marker.name,      -- name
                    cleanedNote,      -- note (with color tag removed)
                    marker.duration,  -- duration
                    marker.customData -- customData (if any)
                )
                
                print(string.format("Restored marker at frame %d to %s", frame, originalColor))
            end
        end
    end
    
    return restored
end

--[[
  Prints a summary of the markers restored to their original colors
  
  @param restored table - Contains counts of restored markers by color
]]
local function PrintSummary(restored)
    print("\n========= RESTORED MARKERS =========")
    
    local total = 0
    local colorNames = {}
    
    -- Collect color names for sorting
    for color, count in pairs(restored) do
        table.insert(colorNames, color)
        total = total + count
    end
    
    -- Sort color names alphabetically
    table.sort(colorNames)
    
    -- Print count for each color
    for _, color in ipairs(colorNames) do
        print(color .. ": " .. restored[color])
    end
    
    print("--------------------------------")
    print("Total markers restored: " .. total)
    print("================================")
    
    if total == 0 then
        print("No markers with stored color information were found.")
        print("Make sure you've run WhiteMarkers.lua before using this script.")
    end
end

-- Main execution
print("Restoring original marker colors...")
comp:StartUndo("Restore Marker Colors")

local restored = RestoreMarkerColors()
PrintSummary(restored)

comp:EndUndo(true)

if next(restored) then
    print("Done! All markers have been restored to their original colors.")
end