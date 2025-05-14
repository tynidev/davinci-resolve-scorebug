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

-- Global variables declaration
local resolveObjs                                       -- Initialized Resolve objects
local sbcomp                                            -- The scorebug Fusion composition
local leftScoreNode, rightScoreNode, gameTimeNode       -- Score nodes for left and right teams and game time
local leftNameNode, rightNameNode                       -- Team name nodes
local timeMarkers, leftScoreMarkers, rightScoreMarkers  -- Timeline markers for game time and team scores

--[[
  Initializes all required objects and variables
  
  @return boolean - True if initialization successful, false otherwise
]]
local function Initialize()
    print("[SECTION] INITIALIZATION")
    -- Initialize core Resolve objects using the utility function
    resolveObjs = utils.initializeCoreResolveObjects()
    if not resolveObjs then
        return false -- Exit if initialization failed
    end
    
    -- Find and store scorebug composition using the utility function
    sbcomp = utils.findNamedFusionCompOnTimeline(resolveObjs.tl, utils.CONFIG.COMPOSITION_NAME)
    if not sbcomp then
        print("[ERROR] Could not find scorebug composition named '" .. utils.CONFIG.COMPOSITION_NAME .. "' using utility function.")
        return false
    end
    
    -- Find and store required tools in the scorebug composition
    leftScoreNode = sbcomp:FindTool(utils.CONFIG.LEFT_SCORE_ELEMENT)
    if not leftScoreNode then
        print("[ERROR] Could not find left score element '" .. utils.CONFIG.LEFT_SCORE_ELEMENT .. "'")
        return false
    end
    
    rightScoreNode = sbcomp:FindTool(utils.CONFIG.RIGHT_SCORE_ELEMENT)
    if not rightScoreNode then
        print("[ERROR] Could not find right score element '" .. utils.CONFIG.RIGHT_SCORE_ELEMENT .. "'")
        return false
    end
    
    gameTimeNode = sbcomp:FindTool(utils.CONFIG.GAME_TIME_ELEMENT)
    if not gameTimeNode then
        print("[ERROR] Could not find game time element '" .. utils.CONFIG.GAME_TIME_ELEMENT .. "'")
        return false
    end
    
    -- Find and store team name elements
    leftNameNode = sbcomp:FindTool(utils.CONFIG.LEFT_NAME_ELEMENT)
    if not leftNameNode then
        print("[WARNING] Could not find left team name element '" .. utils.CONFIG.LEFT_NAME_ELEMENT .. "'")
    end
    
    rightNameNode = sbcomp:FindTool(utils.CONFIG.RIGHT_NAME_ELEMENT)
    if not rightNameNode then
        print("[WARNING] Could not find right team name element '" .. utils.CONFIG.RIGHT_NAME_ELEMENT .. "'")
    end
    
    -- Get markers by color
    print("Loading time markers...")
    timeMarkers = utils.GetTimelineMarkers(resolveObjs.tl, { color = utils.CONFIG.GAME_MARKERS.TIME_MARKERS })
    if #timeMarkers < 4 then
        print("[ERROR] Found only " .. #timeMarkers .. " time markers. Need at least 4 time markers (First half, Half time, Second half, Full time)")
        return false
    end
    print("Found " .. #timeMarkers .. " time markers")
    
    print("Loading left team score markers...")
    leftScoreMarkers = utils.GetTimelineMarkers(resolveObjs.tl, { color = utils.CONFIG.GAME_MARKERS.LEFT_TEAM })
    print("Found " .. #leftScoreMarkers .. " left team score markers")
    
    print("Loading right team score markers...")
    rightScoreMarkers = utils.GetTimelineMarkers(resolveObjs.tl, { color = utils.CONFIG.GAME_MARKERS.RIGHT_TEAM })
    print("Found " .. #rightScoreMarkers .. " right team score markers")
    
    return true
end

--[[
  Gets the team name from the scorebug
  
  @param side string - Either "LEFT" or "RIGHT"
  @return string - The team name or a default value if not found
]]
local function GetTeamName(side)
    local defaultName = (side:upper() == "LEFT") and "Home" or "Away"
    local tool = (side:upper() == "LEFT") and leftNameNode or rightNameNode
    
    -- Return default if the tool wasn't found during initialization
    if not tool then
        return defaultName
    end

    local teamName = tool.StyledText[0]
    -- If it's nil or empty, return the default
    if not teamName or teamName == "" then return defaultName end
    -- If it's an expression, return default
    if type(teamName) == "string" and teamName:match("^=<.*>$") then return defaultName end
    return tostring(teamName)
end

--[[
  Processes all score markers for the specified team
  
  @param side string - Either "LEFT" or "RIGHT" 
  @param color string - The marker color to look for
  @return number - The final score
]]
local function ProcessScores(side, color)
    print("[SECTION] " .. side .. " TEAM SCORES")
    
    -- Use pre-loaded score markers
    local markers = side:upper() == "LEFT" and leftScoreMarkers or rightScoreMarkers
    local scoreNode = side:upper() == "LEFT" and leftScoreNode or rightScoreNode
    local score = 0
    
    -- Get the team name from the scorebug
    local teamName = GetTeamName(side)
    print("Team name from scorebug: " .. teamName)

    -- Clear existing keyframes
    scoreNode.StyledText = nil
    scoreNode.StyledText = sbcomp:BezierSpline({})
    
    -- Set initial score to 0
    scoreNode:SetInput("StyledText", score, 0)

    -- Increment score for each marker found
    for i = 1, #markers do
        local frame = markers[i].frame
        local marker = markers[i]

        score = score + 1
        scoreNode:SetInput("StyledText", score, frame)

         -- Format the marker name with team name and score
        local newMarkerName = teamName .. " " .. score
        
        -- Update the marker name in the timeline
        if utils.UpdateTimelineMarker(resolveObjs.tl,  marker, {name = newMarkerName}) then 
            print("Frame: " .. frame .. ", Score: " .. score .. ", Updated name: " .. newMarkerName)
        else
            print("[ERROR] Frame: " .. frame .. ", Score: " .. score .. ", Failed to update marker name")
        end
    end
    
    return score
end

--[[
  Sets global time markers (cream) and adds keyframes for the game time display
  @return number - The number of time markers found
]]
local function ProcessGamePeriods()
    print("[SECTION] GAME TIME MARKERS")
    
    -- Use pre-loaded time markers
    local markers = timeMarkers
    
    -- Standard time marker labels
    local timeLabels = {"FIRST", "HALF", "SECOND", "FULL"}
    
    -- Rename the markers
    for i = 1, #markers do
        local frame = markers[i].frame
        local marker = markers[i]

        -- Update the marker name with standard label
        if utils.UpdateTimelineMarker(resolveObjs.tl, marker, {name = timeLabels[i]}) then 
            print("Frame " .. frame .. ": Updated time marker name to: " .. timeLabels[i])
        else
            print("[ERROR] Frame " .. frame .. ": Failed to update time marker name")
        end
    end
    
    -- Set keyframes for the GAME_TIME_2 Text+ tool
    print("Setting up time display keyframes...")

    -- Clear existing keyframes
    gameTimeNode.StyledText = nil;
    gameTimeNode.StyledText = sbcomp:BezierSpline({})

    -- Set initial time to "00:00"
    gameTimeNode:SetInput("StyledText", "00:00", 0)
    
    -- First half: 00:00 to HALF
    local firstHalfStart = markers[1].frame
    local halfTimeFrame = markers[2].frame
    
    -- Second half: Continue from previous time to FULL
    local secondHalfStart = markers[3].frame
    local fullTimeFrame = markers[4].frame
    
    -- Set "00:00" at first marker
    gameTimeNode:SetInput("StyledText", "00:00", firstHalfStart)
    print("Frame " .. firstHalfStart .. ": Set time to 00:00")
    
    -- Add keyframes for each second between first marker and halftime
    local framesPerSecond = math.floor(resolveObjs.fps)
    local totalSeconds = math.floor((halfTimeFrame - firstHalfStart) / framesPerSecond)
    
    for i = 1, totalSeconds do
        local currentFrame = firstHalfStart + (i * framesPerSecond)
        
        -- Stop if we've gone past halftime
        if currentFrame >= halfTimeFrame then break end
        
        -- Format time using the utility function
        local timeDisplay = utils.formatTimeDisplay(i)
        
        gameTimeNode:SetInput("StyledText", timeDisplay, currentFrame)
    end
    
    -- Set "HALF" at second marker
    gameTimeNode:SetInput("StyledText", "HALF", halfTimeFrame)
    print("Frame " .. halfTimeFrame .. ": Set time to HALF")

    -- Set time to last value at second half start
    local timeDisplay = utils.formatTimeDisplay(totalSeconds)
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
        local timeDisplay = utils.formatTimeDisplay(lastTimeSeconds + i)
        
        gameTimeNode:SetInput("StyledText", timeDisplay, currentFrame)
    end
    
    -- Set "FULL" at fourth marker
    gameTimeNode:SetInput("StyledText", "FULL", fullTimeFrame)
    print("Frame " .. fullTimeFrame .. ": Set time to FULL")
    return #markers
end

-- Main execution

local function Main()
    -- Initialize all required objects and variables
    if Initialize() then
        -- if we have everything we need, start making changes
        sbcomp:StartUndo('Set Scores')
        ProcessGamePeriods()
        local leftFinalScore = ProcessScores("LEFT", utils.CONFIG.GAME_MARKERS.LEFT_TEAM)
        local rightFinalScore = ProcessScores("RIGHT", utils.CONFIG.GAME_MARKERS.RIGHT_TEAM)
        sbcomp:EndUndo(true)

        -- Show summary
        print("[SECTION] EXECUTION SUMMARY")
        print("Left team final score: " .. leftFinalScore)
        print("Right team final score: " .. rightFinalScore)
        return true
    else
        print("[ERROR] Set Scorebug: Failed to initialize required components")
        print("Check the error messages above for details")
        return false
    end
end

return Main() -- Execute Main and return its status
