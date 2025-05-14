--[[
================================================================================
Script Name: All Score Processing.lua
Author: Tyler
Created: May 11, 2025
Last Modified: May 14, 2025

Description:
This master script orchestrates the complete sports scorebug workflow by running
three specialized scripts in sequence, handling all aspects of score tracking,
highlight generation, and timeline organization.

The workflow consists of three sequential operations:
1. Set Scorebug.lua - Processes all score events and updates the scorebug with:
   - Team names and score tallies
   - Game time indicators (halftime, fulltime, etc.)
   - Keyframed animations for score changes and game time elapsed

2. Score Highlights.lua - Converts score markers into highlight regions:
   - Shifts markers back in time to create lead-up regions
   - Sets appropriate durations for highlight selection

3. Whiteout Markers.lua - Creates a clean timeline appearance:
   - Converts all colored markers to a uniform cream color 
   - Preserves original color data in marker notes
   - Maintains the ability to restore colors if needed with Restore Marker Colors.lua

Usage:
1. Place appropriate colored markers for scores and time periods
2. Run this script from the Fusion Scripts menu
3. All three processes execute in sequence with progress reports
4. If any script fails, an error is reported but the sequence continues

================================================================================
--]]

-- Import utility functions
local utils = dofile(app:MapPath("Scripts:\\Utility\\utils.lua"))
local CONFIG = utils.CONFIG

-- Function to run a script by loading it from the scripts directory
local function RunScript(scriptName)
    print("\n========================================")
    print("RUNNING: " .. scriptName)
    print("========================================\n")
    
    -- The dofile function executes a Lua script and returns any value it returns
    local scriptPath = app:MapPath("Scripts:\\Comp\\" .. scriptName .. ".lua")
    local success, scriptReturn = pcall(dofile, scriptPath)
    
    if not success then
        print("ERROR running script '" .. scriptName .. "':")
        print(scriptReturn) -- scriptReturn here is the error message from pcall
        return false
    end
    
    -- Check the actual return value from the script itself
    -- If dofile was successful, scriptReturn is the value returned by the executed script
    if scriptReturn == false then
        print("ERROR: Script '" .. scriptName .. "' executed but reported an internal failure.")
        return false
    end
    
    print("\n✓ Completed: " .. scriptName)
    return true
end

-- Main execution
function Main()
    -- Get/Ensure Fusion Composition using the utility function
    local composition = utils.ensureFusionComposition()
    if not composition then
        print("[ERROR] Failed to get or create Fusion composition via utility function in All Score Processing.lua.")
        return false
    end

    print("Starting All Score Processing workflow...")
    composition:StartUndo("All Score Processing")
    
    -- Step 1: Set the scorebug based on markers
    local step1 = RunScript("Set Scorebug")
    if not step1 then 
        composition:EndUndo(false) 
        return false
    end
    
    -- Step 2: Adjust markers to create highlight regions
    local step2 = RunScript("Score Highlights")
    if not step2 then 
        composition:EndUndo(false) 
        return false
    end
    
    -- Step 3: Convert all markers to white for a clean timeline
    local step3 = RunScript("Whiteout Markers")
    if not step3 then 
        composition:EndUndo(false) 
        return false
    end
    
    composition:EndUndo(true)
    print("\n===========================================")
    print("✓ ALL SCORE PROCESSING COMPLETE")
    print("===========================================")
    return true
end

-- Execute the main function
Main()