--[[
================================================================================
Script Name: Set Scores.lua
Author: Tyler Nichols
Created: 2025
Last Modified: May 12, 2025

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
local utils = dofile(app:MapPath("Scripts:\\Utility\\utils.lua"))
local udump = utils.dump
local inspectObject = utils.inspectObject
local GetMarkersByColor = utils.GetMarkersByColor
local formatTimeDisplay = utils.formatTimeDisplay
local CONFIG = utils.CONFIG

-- Initialize core Resolve objects
local pm = resolve:GetProjectManager()
if not pm then
    print("Error: Failed to get Project Manager")
    return
end

local pr = pm:GetCurrentProject()
if not pr then
    print("Error: No project is currently open")
    return
end

local tl = pr:GetCurrentTimeline()
if not tl then
    print("Error: No timeline is currently active")
    return
end

-- Calculate project frame rate (used for time calculations)
local fps = pr:GetSetting("timelineFrameRate")
if not fps or fps == 0 then 
    fps = 24  -- Default to 24fps if unable to get setting
    print("Warning: Unable to determine project frame rate, using default of 24fps")
else
    print("Project frame rate: " .. fps .. " fps")
end

--[[
  Finds the scorebug Fusion composition in the timeline
  
  @return fusion_composition or nil if not found
]]
local function findScorebugComp()     
    for i = 1, tl:GetTrackCount("video"), 1 do
        local tli = tl:GetItemListInTrack("video", i)
        for x = 1, #tli, 1 do
            if(tli[x]:GetName() == CONFIG.COMPOSITION_NAME) then
                return tli[x]:GetFusionCompByIndex(1)
            end
        end
    end
    
    print("Warning: Could not find '" .. CONFIG.COMPOSITION_NAME .. "' in timeline")
    return nil
end

local sbcomp = findScorebugComp()
if not sbcomp then
    print("Error: Could not find scorebug composition")
    return
end

--[[
  Gets the team name from the scorebug
  
  @param side string - Either "LEFT" or "RIGHT"
  @return string - The team name or a default value if not found
]]
local function GetTeamName(side)
    local elementName = (side:upper() == "LEFT") and CONFIG.LEFT_NAME_ELEMENT or CONFIG.RIGHT_NAME_ELEMENT
    local defaultName = (side:upper() == "LEFT") and "Home" or "Away"
    
    local tool = sbcomp:FindTool(elementName)
    if not tool then
        print("Error: Could not find tool '" .. elementName .. "'")
        return false
    end

    local teamName = tool:GetInput("StyledText")
    -- If it's nil or empty, return the default
    if not teamName or teamName == "" then return defaultName end
    -- If it's an expression, return default
    if type(teamName) == "string" and teamName:match("^=<.*>$") then return defaultName end
    return tostring(teamName)
end

--[[
  Updates a marker's name in the timeline
  
  @param frame number - The frame where the marker is located
  @param marker table - The marker data
  @param newName string - The new name for the marker
  @return boolean - True if successful, false otherwise
]]
local function UpdateMarkerName(frame, marker, newName)
    -- Delete the original marker
    if not tl:DeleteMarkerAtFrame(frame) then
        print("Error: Failed to delete marker at frame " .. frame)
        return false
    end
    
    -- Create a new marker with updated name
    if not tl:AddMarker(
        frame,              -- frameId
        marker.color,       -- color
        newName,            -- name
        marker.note,        -- note
        marker.duration,    -- duration
        marker.customData   -- customData (if any)
    ) then
        print("Error: Failed to add marker at frame " .. frame)
        return false
    end
    
    return true
end

--[[
  Processes all score markers for the specified team
  
  @param side string - Either "LEFT" or "RIGHT" 
  @param color string - The marker color to look for
  @return number - The final score
]]
local function ProcessScores(side, color)
    print("----------------- " .. side .. " -----------------")
    local markers, frameNumbers = GetMarkersByColor(tl, color)
    local score = 0
    
    -- Get the team name from the scorebug
    local teamName = GetTeamName(side)
    print("Team name from scorebug: " .. teamName)
    
    local elementName = (side:upper() == "LEFT") and CONFIG.LEFT_SCORE_ELEMENT or CONFIG.RIGHT_SCORE_ELEMENT
    
    local tool = sbcomp:FindTool(elementName)
    if not tool then
        print("Error: Could not find tool '" .. elementName .. "'")
        return false
    end

    -- Clear existing keyframes
    tool.StyledText = nil
    tool.StyledText = sbcomp:BezierSpline({})

    -- Process each marker in order
    for _, frame in ipairs(frameNumbers) do 
        score = score + 1
        tool:SetInput("StyledText", score, frame)
        if success then
            -- Format the marker name with team name and score
            local newMarkerName = teamName .. " " .. score
            
            -- Update the marker name in the timeline
            if UpdateMarkerName(frame, markers[frame], newMarkerName) then
                print("Frame: " .. frame .. ", Score: " .. score .. ", Updated name: " .. newMarkerName)
            else
                print("Frame: " .. frame .. ", Score: " .. score .. ", Failed to update marker name")
            end
        end
    end
    
    return score
end

--[[
  Sets global time markers (cream) and adds keyframes for the game time display
  @return number - The number of time markers found
]]
local function SetGlobalTimes()
    print("----------------- TIMES -----------------")
    local markers, frameNumbers = GetMarkersByColor(tl, CONFIG.GAME_MARKERS.TIME_MARKERS) 
    
    -- Standard time marker labels
    local timeLabels = {"FIRST", "HALF", "SECOND", "FULL"}
    
    TIMES = {}
    -- First pass: collect the times
    for i, frame in ipairs(frameNumbers) do 
        TIMES[i] = frame
        print("Time marker found at frame: " .. frame.. ", Name: "..(markers[frame].name or "Unnamed")..", Index: "..i)
    end
    
    -- Second pass: rename the markers
    if #frameNumbers >= 4 then
        for i, frame in ipairs(frameNumbers) do
            if i <= 4 then -- Only process the first four markers
                -- Update the marker name with standard label
                if UpdateMarkerName(frame, markers[frame], timeLabels[i]) then
                    print("Frame: " .. frame .. ", Updated time marker name to: " .. timeLabels[i])
                else
                    print("Frame: " .. frame .. ", Failed to update time marker name")
                end
            end
        end
    else
        print("Warning: Found fewer than 4 time markers. Need exactly 4 for proper labeling.")
    end
    
    -- Set keyframes for the GAME_TIME_2 Text+ tool
    -- Find the GAME_TIME_2 text node
    local gameTimeNode = sbcomp:FindTool("GAME_TIME_2")
    if gameTimeNode then
        print("Setting up time display keyframes...")

        -- Clear existing keyframes
        gameTimeNode.StyledText = nil;
        gameTimeNode.StyledText = sbcomp:BezierSpline({})

        -- Set initial time to "00:00"
        gameTimeNode:SetInput("StyledText", "00:00", 0)
        
        -- Check if we have at least the required 4 time markers
        if #TIMES >= 4 then
            -- First half: 00:00 to HALF
            local firstHalfStart = TIMES[1]
            local halfTimeFrame = TIMES[2]
            
            -- Second half: Continue from previous time to FULL
            local secondHalfStart = TIMES[3]
            local fullTimeFrame = TIMES[4]
            
            -- Set "00:00" at first marker
            gameTimeNode:SetInput("StyledText", "00:00", firstHalfStart)
            print("Frame " .. firstHalfStart .. ": Set time to 00:00")
            
            -- Add keyframes for each second between first marker and halftime
            local framesPerSecond = math.floor(fps)
            local totalSeconds = math.floor((halfTimeFrame - firstHalfStart) / framesPerSecond)
            
            for i = 1, totalSeconds do
                local currentFrame = firstHalfStart + (i * framesPerSecond)
                
                -- Stop if we've gone past halftime
                if currentFrame >= halfTimeFrame then break end
                
                -- Format time using the utility function
                local timeDisplay = formatTimeDisplay(i)
                
                gameTimeNode:SetInput("StyledText", timeDisplay, currentFrame)
            end
            
            -- Set "HALF" at second marker
            gameTimeNode:SetInput("StyledText", "HALF", halfTimeFrame)
            print("Frame " .. halfTimeFrame .. ": Set time to HALF")

            -- Set time to last value at second half start
            local timeDisplay = formatTimeDisplay(totalSeconds)
            gameTimeNode:SetInput("StyledText", timeDisplay, secondHalfStart)
            print("Frame " .. secondHalfStart .. ": Set time to " .. timeDisplay)
            
            -- Continue time from where we left off for second half
            local lastTimeSeconds = totalSeconds
            totalSeconds = math.floor((fullTimeFrame - secondHalfStart) / framesPerSecond)
            
            for i = 1, totalSeconds do
                local currentFrame = secondHalfStart + (i * framesPerSecond)
                
                -- Stop if we've gone past fulltime
                if currentFrame >= fullTimeFrame then break end
                
                -- Continue from previous time value using utility function
                local timeDisplay = formatTimeDisplay(lastTimeSeconds + i)
                
                gameTimeNode:SetInput("StyledText", timeDisplay, currentFrame)
            end
            
            -- Set "FULL" at fourth marker
            gameTimeNode:SetInput("StyledText", "FULL", fullTimeFrame)
            print("Frame " .. fullTimeFrame .. ": Set time to FULL")
            
            print("Time display keyframes created successfully!")
        else
            print("Error: Need at least 4 time markers to set up game time display properly")
        end
    else
        print("Warning: Could not find element 'GAME_TIME_2'")
    end
    
    return #frameNumbers
end

-- Main execution
comp:StartUndo('Set Scores')

local timeMarkersFound = SetGlobalTimes()
local leftFinalScore = ProcessScores("LEFT", CONFIG.GAME_MARKERS.LEFT_TEAM)
local rightFinalScore = ProcessScores("RIGHT", CONFIG.GAME_MARKERS.RIGHT_TEAM)

comp:EndUndo(true)

-- Show summary
print("\n================ SUMMARY ================")
print("Left team final score: " .. leftFinalScore)
print("Right team final score: " .. rightFinalScore)  
print("Time markers found: " .. timeMarkersFound)
print("================ SUMMARY ================")