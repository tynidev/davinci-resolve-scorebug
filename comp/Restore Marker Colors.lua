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

-- Wrap execution in a Main function that returns success/failure status
local function Main()
    -- Get/Ensure Fusion Composition
    local composition = utils.ensureFusionComposition()
    if not composition then
        print("[ERROR] Restore Marker Colors: Failed to get or create Fusion composition via utility function.")
        return false
    end

-- Main execution
-- Access core Resolve objects for RestoreMarkerColors function
local resolveObjs = utils.initializeCoreResolveObjects()
if not resolveObjs then
    print("[ERROR] Restore Marker Colors: Failed to initialize Resolve objects.")
    return false
end

print("Restoring original marker colors...")
composition:StartUndo("Restore Marker Colors")

local restored = RestoreMarkerColors(resolveObjs) -- Now passing resolveObjs as parameter
PrintSummary(restored)

composition:EndUndo(true)

if next(restored) then
    print("Done! All markers have been restored to their original colors.")
end

    return true
end

return Main() -- Execute Main and return its status