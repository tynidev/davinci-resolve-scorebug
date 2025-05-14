--[[
================================================================================
Script Name: All Score Processing.lua
Author: GitHub Copilot (based on Tyler's scripts)
Created: May 11, 2025

Description:
This script automates the complete workflow for processing sports scores by calling
three scripts in sequence:
1. Set Scorebug - Updates the scorebug with team scores based on colored markers
2. Score Highlights - Adjusts markers to create highlight regions around scoring events
3. Whiteout Markers - Converts all colored markers to white for a clean timeline look

Usage:
1. Ensure all prerequisite scripts are in the correct locations
2. Run this script from the Fusion Scripts menu
3. All three processes will execute in sequence

All operations are wrapped in an undo group for easy reversal if needed.
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
    local success, result = pcall(dofile, scriptPath)
    
    if not success then
        print("ERROR running script '" .. scriptName .. "':")
        print(result)
        return false
    end
    
    print("\n✓ Completed: " .. scriptName)
    return true
end

-- Main execution
function Main()
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