--[[
================================================================================
Script Name: Restore Marker Colors.lua
Author: Tyler
Created: May 11, 2025
Last Modified: May 14, 2025

Description:
This script reverses the process performed by Whiteout Markers.lua, restoring
timeline markers to their original colors based on the information stored in
their note fields.

The script performs the following actions:
1. Scans all timeline markers for cream (white) markers 
2. For each cream marker with "[Original color: X]" in its notes:
   - Extracts the original color information
   - Restores the marker to that original color
   - Removes the color annotation from the note field
3. Provides a detailed summary of markers restored by color

Usage:
1. Run this script when you need to restore original marker colors
2. All cream markers with stored color information will be restored

================================================================================
--]]

-- Import utility functions
local utils = dofile(app:MapPath("Scripts:\\Utility\\utils.lua"))

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
  
  @param resolveObjs table - Table containing initialized Resolve objects from utils.initializeCoreResolveObjects()
  @return table - Contains counts of restored markers by color
]]
local function RestoreMarkerColors(resolveObjs)
    -- Validate input
    if not resolveObjs or not resolveObjs.tl then
        print("[ERROR] RestoreMarkerColors: Invalid or missing resolveObjs parameter")
        return {}
    end

    -- Get all CREAM colored markers
    local creamMarkers = utils.GetTimelineMarkers(resolveObjs.tl, {color = utils.CONFIG.COLORS.CREAM})
    
    -- Track how many markers of each color we restore
    local restored = {}
    
    -- Process each cream marker
    for _, marker in ipairs(creamMarkers) do
        local originalColor, cleanedNote = ExtractColorInfo(marker.note)
        
        -- If we found color information, restore the marker
        if originalColor then
            -- Update the count for this color
            restored[originalColor] = (restored[originalColor] or 0) + 1
            
            -- Prepare the updates for UpdateTimelineMarker
            local updates = {
                color = originalColor,
                note = cleanedNote
            }
            
            if utils.UpdateTimelineMarker(resolveObjs.tl, marker, updates) then
                print(string.format("Restored marker at frame %d to %s", marker.frame, originalColor))
            else
                print(string.format("[ERROR] Failed to restore marker at frame %d to %s", marker.frame, originalColor))
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
local function Main()
    -- Access core Resolve objects for RestoreMarkerColors function
    local resolveObjs = utils.initializeCoreResolveObjects()
    if not resolveObjs then
        print("[ERROR] Restore Marker Colors: Failed to initialize Resolve objects.")
        return false
    end

    -- Get/Ensure Fusion Composition
    local composition = utils.ensureFusionComposition()
    if not composition then
        print("[ERROR] Restore Marker Colors: Failed to get or create Fusion composition via utility function.")
        return false
    end

    print("Restoring original marker colors...")

    composition:StartUndo("Restore Marker Colors")
    local restored = RestoreMarkerColors(resolveObjs)
    composition:EndUndo(true)

    PrintSummary(restored)

    if next(restored) then
        print("Done! All markers have been restored to their original colors.")
    end

    return true
end

return Main() -- Execute Main and return its status