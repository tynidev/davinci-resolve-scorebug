--[[
================================================================================
Script Name: Set Scorebug.lua
Author: Tyler Nichols
Created: 2025
Last Modified: May 14, 2025

Description:
This script automatically updates a scorebug in DaVinci Resolve using timeline
markers. It performs three main functions:

1. Processes team score markers (blue/red) to:
   - Increment the appropriate team's score for each marker
   - Update marker names with team name, when available, and score
   - Create keyframes for the score displays

2. Processes game time markers (cream colored) to:
   - Rename them to standard labels (FIRST, HALF, SECOND, FULL)
   - Set up keyframes for the game timer display showing elapsed time
   - Add special labels at halftime and fulltime

Requirements:
- A Fusion composition named "Fusion Composition 1" 
- Text+ elements in composition: "LEFT_SCORE_2", "RIGHT_SCORE_2", "GAME_TIME_2"
- Timeline markers: 
    - Blue (left team scores) 
    - Red (right team scores)
    - 4 Cream markers for game time periods (First, Half, Second, Full)

Usage:
1. Create timeline markers at points where scores change or time periods occur
2. Run this script from the Fusion Scripts menu
3. View the results in the scorebug composition and timeline

All operations are wrapped in an undo group for easy reversal if needed.
================================================================================
--]]

-- Import utility functions
local utils = dofile(app:MapPath("Scripts:\\Utility\\utils.lua"))

--[[
  Main function to execute the script
  This function initializes all required objects and variables, processes game time
  and score markers, and updates the scorebug accordingly.
  
  @return boolean - True if successful, false otherwise
]]
local function Main()
    -- Initialize all required objects and variables
    local deps = Initialize()
    if deps then -- if we have everything we need, start making changes
        deps.sbcomp:StartUndo('Set Scores')
    
        -- Add left team keyframes for every score marker
        local leftFinalScore = ProcessScores(
            deps.tl,
            deps.sbcomp,
            deps.leftScoreMarkers,
            deps.leftScoreNode,
            GetTeamName(deps.leftNameNode, "Home")
            )
        
        -- Add Right team keyframes for every score marker
        local rightFinalScore = ProcessScores(
            deps.tl,
            deps.sbcomp,
            deps.rightScoreMarkers,
            deps.rightScoreNode,
            GetTeamName(deps.rightNameNode, "Away")
            )
        
        -- Add game time keyframes for each second AND each game period
        ProcessGamePeriods(deps.tl, deps.fps, deps.sbcomp, deps.timeMarkers, deps.gameTimeNode)

        deps.sbcomp:EndUndo(true)

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

--[[
  Processes all score markers for the specified team
  @param timeline - The timeline object in resolve
  @param sbcomp - The scorebug Fusion composition
  @param markers - The score markers for the team
  @param teamName - The name of the team
  @param scoreNode - The score node in the Fusion composition
  @return number - The final score
]]
local function ProcessScores(timeline, sbcomp, markers, scoreNode, teamName)
    print("[SECTION] " .. teamName .. " UPDATE TEAM SCORES")
    
    -- Clear existing keyframes
    scoreNode.StyledText = nil
    scoreNode.StyledText = sbcomp:BezierSpline({})
    
    -- Set initial score to 0
    local score = 0; -- Initialize score to 0
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
        if utils.UpdateTimelineMarker(timeline,  marker, {name = newMarkerName}) then 
            print("Frame: " .. frame .. ", Score: " .. score .. ", Updated name: " .. newMarkerName)
        else
            print("[ERROR] Frame: " .. frame .. ", Score: " .. score .. ", Failed to update marker name")
        end
    end
    
    return score
end

--[[
  Sets global time markers (cream) and adds keyframes for the game time display
  
  @param timeline - The timeline object in resolve
  @param fps - The frames per second of the timeline
  @param sbcomp - The scorebug Fusion composition
  @param timeMarkers - The time markers
  @param gameTimeNode - The game time node
  @return number - The number of time markers found
]]
local function ProcessGamePeriods(timeline, fps, sbcomp, timeMarkers, gameTimeNode)
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
        if utils.UpdateTimelineMarker(timeline, marker, {name = timeLabels[i]}) then 
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
    local framesPerSecond = math.floor(fps)
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

--[[
  Gets the team name from the scorebug
  
  @param nameNode - The team name node
  @param defaultName string - The default name to return if the team name is not found
  @return string - The team name or a default value if not found
]]
local function GetTeamName(nameNode, defaultName)
    -- Return default if the tool wasn't found during initialization
    if not nameNode then
        return defaultName
    end

    local teamName = nameNode.StyledText[0]
    -- If it's nil or empty, return the default
    if not teamName or teamName == "" then return defaultName end
    -- If it's an expression, return default
    if type(teamName) == "string" and teamName:match("^=<.*>$") then return defaultName end
    return tostring(teamName)
end

--[[
  Initializes all required objects and variables
  
  @return table - Table containing all necessary objects and variables, or nil if initialization failed
]]
local function Initialize()
    print("[SECTION] INITIALIZATION")
    local deps = {}
    
    -- Initialize core Resolve objects using the utility function
    local resolveObjs = utils.initializeCoreResolveObjects()
    if not resolveObjs then
        return nil -- Exit if initialization failed
    end
    deps.tl = resolveObjs.tl
    deps.fps = resolveObjs.fps
    
    -- Find and store scorebug composition using the utility function
    deps.sbcomp = utils.findNamedFusionCompOnTimeline(deps.tl, utils.CONFIG.COMPOSITION_NAME)
    if not deps.sbcomp then
        print("[ERROR] Could not find scorebug composition named '" .. utils.CONFIG.COMPOSITION_NAME .. "' using utility function.")
        return nil
    end
    
    -- Find and store required tools in the scorebug composition
    deps.leftScoreNode = deps.sbcomp:FindTool(utils.CONFIG.LEFT_SCORE_ELEMENT)
    if not deps.leftScoreNode then
        print("[ERROR] Could not find left score element '" .. utils.CONFIG.LEFT_SCORE_ELEMENT .. "'")
        return nil
    end
    
    deps.rightScoreNode = deps.sbcomp:FindTool(utils.CONFIG.RIGHT_SCORE_ELEMENT)
    if not deps.rightScoreNode then
        print("[ERROR] Could not find right score element '" .. utils.CONFIG.RIGHT_SCORE_ELEMENT .. "'")
        return nil
    end
    
    deps.gameTimeNode = deps.sbcomp:FindTool(utils.CONFIG.GAME_TIME_ELEMENT)
    if not deps.gameTimeNode then
        print("[ERROR] Could not find game time element '" .. utils.CONFIG.GAME_TIME_ELEMENT .. "'")
        return nil
    end
    
    -- Find and store team name elements
    deps.leftNameNode = deps.sbcomp:FindTool(utils.CONFIG.LEFT_NAME_ELEMENT)
    if not deps.leftNameNode then
        print("[WARNING] Could not find left team name element '" .. utils.CONFIG.LEFT_NAME_ELEMENT .. "'")
    end
    
    deps.rightNameNode = deps.sbcomp:FindTool(utils.CONFIG.RIGHT_NAME_ELEMENT)
    if not deps.rightNameNode then
        print("[WARNING] Could not find right team name element '" .. utils.CONFIG.RIGHT_NAME_ELEMENT .. "'")
    end
    
    -- Get markers by color
    print("Loading time markers...")
    deps.timeMarkers = utils.GetTimelineMarkers(deps.tl, { color = utils.CONFIG.GAME_MARKERS.TIME_MARKERS })
    if #deps.timeMarkers < 4 then
        print("[ERROR] Found only " .. #deps.timeMarkers .. " time markers. Need at least 4 time markers (First half, Half time, Second half, Full time)")
        return nil
    end
    print("Found " .. #deps.timeMarkers .. " time markers")
    
    print("Loading left team score markers...")
    deps.leftScoreMarkers = utils.GetTimelineMarkers(deps.tl, { color = utils.CONFIG.GAME_MARKERS.LEFT_TEAM })
    print("Found " .. #deps.leftScoreMarkers .. " left team score markers")
    
    print("Loading right team score markers...")
    deps.rightScoreMarkers = utils.GetTimelineMarkers(deps.tl, { color = utils.CONFIG.GAME_MARKERS.RIGHT_TEAM })
    print("Found " .. #deps.rightScoreMarkers .. " right team score markers")
    
    return deps
end

return Main() -- Execute Main and return its status
