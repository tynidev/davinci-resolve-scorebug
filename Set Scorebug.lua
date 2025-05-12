--[[
================================================================================
Script Name: Set Scores.lua
Author: Tyler Nichols
Created: 2025
Last Modified: May 11, 2025

Description:
This script automates the updating of sports scores and time markers in DaVinci
Resolve projects. It works by scanning timeline markers of specific colors and
updating a scorebug Fusion composition:
- Blue markers: Increment the left team score
- Red markers: Increment the right team score
- Cream markers: Set time indicators (first half, halftime, second half, full time)

The script expects a Fusion composition named "Fusion Composition 1" containing
a tool called "MLS_Scorebug_1" with text elements "LEFT_SCORE_2" and "RIGHT_SCORE_2".

Usage:
1. Create colored markers at frames where scores change or time periods occur
    - Blue for left team scores
    - Red for right team scores
    - Cream for time markers (first half, halftime, second half, full time)
2. Run this script from the Fusion Scripts menu
3. The script will automatically update all score values based on marker positions

All operations are wrapped in an undo group for easy reversal if needed.
================================================================================
--]]

-- Import utility functions
local utils = dofile(app:MapPath("Scripts:\\Comp\\utils\\utils.lua"))
local dump = utils.dump
local GetMarkersByColor = utils.GetMarkersByColor
local CONFIG = utils.CONFIG

--[[
  Finds the scorebug Fusion composition in the timeline
  
  @return fusion_composition or nil if not found
]]
local function findScorebug() 
    local pm = resolve:GetProjectManager()
    local pr = pm:GetCurrentProject()
    if not pr then
        print("Error: No project is currently open")
        return nil
    end
    
    local tl = pr:GetCurrentTimeline()
    if not tl then
        print("Error: No timeline is currently active")
        return nil
    end
    
    for i = 1, tl:GetTrackCount("video"), 1 do
        local tli = tl:GetItemListInTrack("video", i)
        for x = 1, #tli, 1 do
            if(tli[x]:GetName() == CONFIG.COMPOSITION_NAME) then
                return tli[x]
            end
        end
    end
    print("Warning: Could not find '" .. CONFIG.COMPOSITION_NAME .. "' in timeline")
    return nil
end

--[[
  Sets the score for either left or right team at a specific frame
  
  @param side string - Either "LEFT" or "RIGHT"
  @param score number - The score value to set
  @param frame number - The frame number to set the score at
  @return boolean - True if successful, false otherwise
]]
local function SetScore(side, score, frame)
    local elementName = (side:upper() == "LEFT") and CONFIG.LEFT_SCORE_ELEMENT or CONFIG.RIGHT_SCORE_ELEMENT
    
    local sb = findScorebug()
    if not sb then return false end
    
    local scomp = sb:GetFusionCompByIndex(1)
    local tool = scomp:FindTool(CONFIG.SCOREBUG_TOOL)
    if not tool then
        print("Error: Could not find tool '" .. CONFIG.SCOREBUG_TOOL .. "'")
        return false
    end
    
    for i, t in pairs(tool:GetChildrenList()) do
        if(t.Name == elementName) then
            t:SetInput("StyledText", score, frame)
            return true
        end
    end
    
    print("Warning: Could not find element '" .. elementName .. "'")
    return false
end

--[[
  Processes all score markers for the specified team
  
  @param side string - Either "LEFT" or "RIGHT" 
  @param color string - The marker color to look for
  @return number - The final score
]]
local function ProcessScores(side, color)
    print("----------------- " .. side .. " -----------------")
    local markers = GetMarkersByColor(color)
    local score = 0
    local tkeys = {}
    
    -- Sort markers by frame
    for frame in pairs(markers) do table.insert(tkeys, frame) end
    table.sort(tkeys)
    
    -- Process each marker
    for _, frame in ipairs(tkeys) do 
        score = score + 1
        
        local success = SetScore(side:upper(), score, frame)
        if success then
            print("Frame: " .. frame .. ", Score: " .. score .. ", Name: " .. (markers[frame].name or "Unnamed"))
        end
    end
    
    return score
end

--[[
  Sets global time markers (cream)
  @return number - The number of time markers found
]]
local function SetGlobalTimes()
    print("----------------- TIMES -----------------")
    local markers = GetMarkersByColor(CONFIG.GAME_MARKERS.TIME_MARKERS) 
    local tkeys = {}
    
    for frame in pairs(markers) do table.insert(tkeys, frame) end
    table.sort(tkeys)
    
    TIMES = {}
    for i, frame in ipairs(tkeys) do 
        TIMES[i] = frame
        print("Frame: " .. frame .. ", Name: " .. 
              (markers[frame].name or "Unnamed") .. 
              ", Index: " .. i)
    end
    
    -- Generate formatted string with validation
    local formatted = "Times: "
    local labels = {"first", "half", "second", "full"}
    
    for i = 1, 4 do
        if TIMES[i] then
            formatted = formatted .. labels[i] .. "=" .. TIMES[i] .. "; "
        else
            formatted = formatted .. labels[i] .. "=missing; "
            print("Warning: Missing time marker #" .. i)
        end
    end
    
    print(formatted)
    return #tkeys
end

-- Main execution
local timeMarkersFound = SetGlobalTimes()
comp:StartUndo('Set Scores')

local leftFinalScore = ProcessScores("LEFT", CONFIG.GAME_MARKERS.LEFT_TEAM)
local rightFinalScore = ProcessScores("RIGHT", CONFIG.GAME_MARKERS.RIGHT_TEAM)

comp:EndUndo(true)

-- Show summary
print("\n========= SUMMARY =========")
print("Left team final score: " .. leftFinalScore)
print("Right team final score: " .. rightFinalScore)  
print("Time markers found: " .. timeMarkersFound)
print("============================")