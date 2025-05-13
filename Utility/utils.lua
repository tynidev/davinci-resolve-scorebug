--[[
================================================================================
Script Name: utils.lua
Author: Tyler
Created: May 11, 2025
Last Modified: May 12, 2025

Description:
A utility library containing helper functions for use in DaVinci Resolve scripts.
================================================================================
--]]

local utils = {}

-- Converts Lua tables to strings for debugging purposes
function utils.dump(o)
    if type(o) == 'table' then
       local s = '{ '
       for k,v in pairs(o) do
          if type(k) ~= 'number' then k = '"'..k..'"' end
          s = s .. '['..k..'] = ' .. utils.dump(v) .. ','
       end
       return s .. '} '
    else
       return tostring(o)
    end
end

--[[
  Returns the length of a table
  
  @param t table - The table to measure
  @return number - The number of key-value pairs in the table
]]
function utils.tableLength(t)
    local count = 0
    for _ in pairs(t) do
      count = count + 1
    end
    return count
  end

--[[
  Gets all markers of a specific color from the timeline
  
  @param tl object - The timeline object
  @param color string - The marker color to filter by
  @return table - A table of markers with frame numbers as keys, sorted by frame
]]
function utils.GetMarkersByColor(tl, color)
    if not tl then
        print("Error: No timeline provided to GetMarkersByColor")
        return {}
    end
    
    local ml = tl:GetMarkers()
    local markers = {}
    local frameNumbers = {}
    
    -- Collect markers of specified color
    for t, m in pairs(ml) do
        if(m.color == color) then
            markers[t] = m
            table.insert(frameNumbers, t)
        end
    end
    
    -- Sort the frame numbers
    table.sort(frameNumbers)
    
    -- Return both the markers table and sorted frame numbers
    return markers, frameNumbers
end

--[[
  Converts elapsed seconds into a formatted time display string
  
  @param seconds number - Total elapsed seconds
  @param format string - Optional format string: "MM:SS" (default), "M:SS", "MM:SS.FF", or "custom"
  @param customFormatFn function - Optional custom formatting function when format is "custom"
  @return string - Formatted time display string
]]
function utils.formatTimeDisplay(seconds, format, customFormatFn)
    -- Handle invalid input
    if type(seconds) ~= "number" then
        return "00:00"
    end
    
    -- Default format is "MM:SS" if not specified
    format = format or "MM:SS"
    
    -- Calculate minutes and seconds
    local totalSeconds = math.floor(seconds)
    local minutes = math.floor(totalSeconds / 60)
    local remainingSeconds = totalSeconds % 60
    
    -- Format based on requested format
    if format == "MM:SS" then
        -- Standard format with leading zeros: 05:09
        return string.format("%02d:%02d", minutes, remainingSeconds)
    elseif format == "M:SS" then
        -- No leading zero on minutes: 5:09
        return string.format("%d:%02d", minutes, remainingSeconds)
    elseif format == "MM:SS.FF" then
        -- Format with frames (assuming seconds is in seconds.frames format)
        local frames = math.floor((seconds - totalSeconds) * 100)
        return string.format("%02d:%02d.%02d", minutes, remainingSeconds, frames)
    elseif format == "custom" and type(customFormatFn) == "function" then
        -- Use custom formatting function if provided
        return customFormatFn(minutes, remainingSeconds, seconds)
    else
        -- Default to standard format
        return string.format("%02d:%02d", minutes, remainingSeconds)
    end
end

--[[
  Inspects an object and prints its methods, properties, and common function calls
  
  @param obj - The object to inspect
  @param label string - A label to use when printing information about the object
]]
function utils.inspectObject(obj, label)
    label = label or "OBJECT"
    print("\n--- INSPECTING " .. label .. " ---")
    
    if obj == nil then
        print("Object is nil")
        print("------------------------\n")
        return
    end
    
    -- Print the object type
    print("Type: " .. type(obj))
    
    -- Try to get methods and properties through the metatable
    local mt = getmetatable(obj)
    if mt and mt.__index then
        if type(mt.__index) == "table" then
            print("\nMethods/Properties from metatable:")
            for k, v in pairs(mt.__index) do
                print(string.format("  %s (%s)", k, type(v)))
            end
        end
    end
    
    -- Try direct inspection - BUT SAFELY CHECK OBJECT TYPE FIRST
    print("\nDirect properties:")
    if type(obj) == "table" then  -- Only use pairs() on actual tables
        print(dump(obj))
    else
        print("  Cannot iterate: object is " .. type(obj) .. ", not a table")
    end
    
    -- Try common methods used in Fusion
    local commonMethods = {
        -- Basic Tool Methods
        "GetAttrs", "SetAttrs", "GetInput", "SetInput", 
        "ConnectInput", "DisconnectInput", "GetInputList", 
        "GetOutput", "GetOutputList", "FindMainInput",
        
        -- Animation and Keyframe Methods
        "GetKeyFrames", "AddKey", "AddPoint", "DeleteKey", 
        "DeleteKeyFrame", "DeleteKeyFrames", "GetKeyFrameTime", 
        "SetKeyFrameValue", "GetKeyFrameValue", "BezierSpline",
        
        -- Hierarchy and Navigation
        "GetParent", "GetChild", "GetChildren", "GetChildrenList",
        "GetNextNode", "GetPrevNode", "GetToolList",
        
        -- Flow Methods
        "GetFlow", "GetFlowView", "SetPos", "GetPos", "SetScale", "GetScale",
        
        -- Text-specific Methods (for Text+ tools)
        "StyledText", "Font", "Style", "Size", "VerticalJustification",
        
        -- State and Identification
        "GetName", "SetName", "GetID", "GetToolID", "IsSelected",
        "IsPlaying", "IsRendering", "IsTime", "IsLocked",
        
        -- Time-related Methods
        "GetTime", "SetTime", "GetCurrentTime", "SetCurrentTime",
        "TimeToFrame", "FrameToTime", "GetFrameRate",
        
        -- Spline-specific Methods
        "GetSpline", "SetSpline", "GetSplineValue", "SetSplineValue",
        
        -- Composition Methods
        "GetComp", "GetFusion", "StartUndo", "EndUndo",
        "Play", "Stop", "Pause", "Render",
        
        -- Event Methods
        "AddNotify", "RemoveNotify", "AddObserver", "RemoveObserver"
    }
    
    print("\nTesting common methods:")
    for _, method in ipairs(commonMethods) do
        local success, result = pcall(function() 
            return obj[method] ~= nil 
        end)
        if(success and result) then
            print(string.format("  %s", method))
        end
    end
    
    print("------------------------\n")
end

-- Configuration
utils.CONFIG = {
    -- Color settings for markers (direct color names)
    COLORS = {
        BLUE = "Blue",
        RED = "Red",
        CREAM = "Cream"
    },
    -- Game-specific marker mappings
    GAME_MARKERS = {
        LEFT_TEAM = "Blue",  -- Maps to COLORS.BLUE
        RIGHT_TEAM = "Red",  -- Maps to COLORS.RED
        TIME_MARKERS = "Cream"  -- Maps to COLORS.CREAM
    },
    -- Fusion composition name to look for
    COMPOSITION_NAME = "Fusion Composition 1",
    -- Tool and text element names
    SCOREBUG_TOOL = "MLS_Scorebug",
    LEFT_SCORE_ELEMENT = "LEFT_SCORE_2",
    RIGHT_SCORE_ELEMENT = "RIGHT_SCORE_2",
    LEFT_NAME_ELEMENT = "LEFT_NAME_2",
    RIGHT_NAME_ELEMENT = "RIGHT_NAME_2",
    GAME_TIME_ELEMENT = "GAME_TIME_2"
}

return utils