--[[
================================================================================
Script Name: utils.lua
Author: Tyler
Created: May 11, 2025
Last Modified: May 14, 2025

Description:
A comprehensive utility library for DaVinci Resolve scripting that provides
standardized functions for common operations in Resolve and Fusion.

Core Function Categories:

1. Resolve Object Management
   - initializeCoreResolveObjects(): Creates standard Resolve objects (PM, Project, Timeline)
   - ensureFusionComposition(): Gets current Fusion comp or creates a new one
   - findNamedFusionCompOnTimeline(): Finds a Fusion comp by name on the timeline

2. Timeline Marker Operations
   - GetTimelineMarkers(): Gets markers with advanced filtering options
   - UpdateTimelineMarker(): Modifies marker properties while preserving others

3. Time and Display Formatting
   - formatTimeDisplay(): Formats frames as timecode with configurable options

4. Debugging Utilities
   - dump(): Converts tables to readable string format
   - inspectObject(): Provides detailed output of object properties

This library aims to provide consistent interfaces and robust error handling
for all common DaVinci Resolve scripting operations used by the score automation
script collection.
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
  Updates properties of an existing marker on the timeline.
  Deletes the old marker and creates a new one with updated values.

  @param tl table - The timeline object.
  @param existingMarker table - The marker object to update. Must contain a 'frame' field.
  @param updates table - A table containing the marker properties to update.
                         Example: { name = "New Name", note = "Updated note", color = "Green" }
                         Valid keys: "name", "note", "color", "duration", "customData", "frameId" (to move the marker).
  @return boolean - True if successful, false otherwise.
]]
function utils.UpdateTimelineMarker(tl, existingMarker, updates)
    if not tl then
        print("[ERROR] utils.UpdateTimelineMarker: Timeline object is nil.")
        return false
    end
    if not existingMarker or type(existingMarker) ~= "table" or existingMarker.frame == nil then
        print("[ERROR] utils.UpdateTimelineMarker: existingMarker is invalid or missing .frame field.")
        return false
    end
    if not updates or type(updates) ~= "table" then
        print("[ERROR] utils.UpdateTimelineMarker: Updates argument must be a table.")
        return false
    end

    -- Prepare new marker data, starting with existing values from existingMarker
    local newMarkerData = {
        frame      = updates.frame or existingMarker.frame, -- Use the frame from updates if provided
        color      = existingMarker.color,
        name       = existingMarker.name,
        note       = existingMarker.note,
        duration   = existingMarker.duration,
        customData = existingMarker.customData
    }

    -- Apply updates from the 'updates' table
    if updates.name       ~= nil then newMarkerData.name = updates.name end
    if updates.note       ~= nil then newMarkerData.note = updates.note end
    if updates.color      ~= nil then newMarkerData.color = updates.color end
    if updates.duration   ~= nil then newMarkerData.duration = updates.duration end
    if updates.customData ~= nil then newMarkerData.customData = updates.customData end
    
    -- Delete the original marker.
    if not tl:DeleteMarkerAtFrame(existingMarker.frame) then
        print("[ERROR] utils.UpdateTimelineMarker: Failed to delete original marker at frame " .. existingMarker.frame .. ". It might have been already deleted or changed.")
        return false
    end
    
    -- Create a new marker with the updated properties
    if not tl:AddMarker(
        newMarkerData.frame,       -- frame for placement
        newMarkerData.color,       -- color
        newMarkerData.name,        -- name
        newMarkerData.note,        -- note
        newMarkerData.duration,    -- duration
        newMarkerData.customData   -- customData (if any)
    ) then
        print("[ERROR] utils.UpdateTimelineMarker: Failed to add new/updated marker at frame " .. newMarkerData.frame)
        -- Attempt to restore the original marker if addition fails and original was successfully fetched
        -- This is complex as the original might have been deleted. For now, just error out.
        tl:AddMarker(
            existingMarker.frame,       -- frame for placement
            existingMarker.color,       -- color
            existingMarker.name,        -- name
            existingMarker.note,        -- note
            existingMarker.duration,    -- duration
            existingMarker.customData   -- customData (if any)
        )
        return false
    end
    
    return true
end

--[[
  Gets all timeline markers, optionally filtered by specified properties,
  and returns them as an array sorted by frame number.

  @param tl table - The timeline object.
  @param filters table (optional) - A table of key-value pairs to filter markers.
                                    Example: {color = "Blue", name = "MyMarker"}
                                    Only markers matching all filters will be returned.
  @return table - An array of marker objects, sorted by frame number.
                  Each marker object will have a 'frame' field added to it.
]]
function utils.GetTimelineMarkers(tl, filters)
    if not tl then
        print("[ERROR] utils.GetTimelineMarkers: Timeline object is nil.")
        return {}
    end

    local allTimelineMarkers = tl:GetMarkers()
    if not allTimelineMarkers or utils.tableLength(allTimelineMarkers) == 0 then
        return {}
    end

    local filteredMarkersArray = {}

    for frame, markerData in pairs(allTimelineMarkers) do
        local match = true
        if filters and type(filters) == "table" and utils.tableLength(filters) > 0 then
            for key, expectedValue in pairs(filters) do
                if markerData[key] ~= expectedValue then
                    match = false
                    break
                end
            end
        end

        if match then
            markerData.frame = frame -- Add the frame number as a property to the marker object itself
            table.insert(filteredMarkersArray, markerData)
        end
    end

    -- Sort the array of marker objects by their frame number
    table.sort(filteredMarkersArray, function(a, b)
        return a.frame < b.frame
    end)

    return filteredMarkersArray
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

--[[
  Initializes and returns core DaVinci Resolve objects.

  @return table|nil - A table containing pm, pr, tl, and fps if successful, nil otherwise.
                     { pm: ProjectManager, pr: Project, tl: Timeline, fps: number }
]]
function utils.initializeCoreResolveObjects()
    local resolveObjs = {}
    resolveObjs.pm = resolve:GetProjectManager()
    if not resolveObjs.pm then
        print("[ERROR] utils.initializeCoreResolveObjects: Failed to get Project Manager")
        return nil
    end

    resolveObjs.pr = resolveObjs.pm:GetCurrentProject()
    if not resolveObjs.pr then
        print("[ERROR] utils.initializeCoreResolveObjects: No project is currently open")
        return nil
    end

    resolveObjs.tl = resolveObjs.pr:GetCurrentTimeline()
    if not resolveObjs.tl then
        print("[ERROR] utils.initializeCoreResolveObjects: No timeline is currently active")
        return nil
    end

    resolveObjs.fps = resolveObjs.pr:GetSetting("timelineFrameRate")
    if not resolveObjs.fps or resolveObjs.fps == 0 then
        print("[ERROR] utils.initializeCoreResolveObjects: Unable to determine project frame rate")
        return nil
    end
    print("utils.initializeCoreResolveObjects: Project frame rate: " .. resolveObjs.fps .. " fps")
    return resolveObjs
end

--[[
  Ensures a Fusion composition is available, creating one if necessary.
  Uses the global 'comp' if available, otherwise gets/creates a new one via 'resolve:Fusion()'.

  @return table|nil - The Fusion composition object, or nil if an error occurs.
]]
function utils.ensureFusionComposition()
    local currentComp = comp -- comp is a global variable in Resolve's scripting environment
    if not currentComp then
        local fusion = resolve:Fusion()
        if not fusion then
            print("[ERROR] utils.ensureFusionComposition: Failed to get Fusion object from resolve.")
            return nil
        end
        currentComp = fusion:GetCurrentComp()
        if not currentComp then
            print("utils.ensureFusionComposition: No current Fusion comp. Creating a new one.")
            currentComp = fusion:NewComp()
            if not currentComp then
                print("[ERROR] utils.ensureFusionComposition: Could not create a new Fusion composition.")
                return nil
            end
        end
    end
    return currentComp
end

--[[
  Finds a Fusion composition item on the timeline by its name.

  @param timeline table - The timeline object to search within.
  @param compName string - The name of the Fusion composition item to find.
  @return table|nil - The Fusion composition object if found, otherwise nil.
]]
function utils.findNamedFusionCompOnTimeline(timeline, compName)
    if not timeline then
        print("[ERROR] utils.findNamedFusionCompOnTimeline: Invalid timeline object provided.")
        return nil
    end
    if not compName then
        print("[ERROR] utils.findNamedFusionCompOnTimeline: Invalid compName string provided.")
        return nil
    end

    for i = 1, timeline:GetTrackCount("video") do
        local timelineItems = timeline:GetItemListInTrack("video", i)
        if timelineItems then
            for _, item in ipairs(timelineItems) do
                if item:GetName() == compName then
                    local fusionComp = item:GetFusionCompByIndex(1) -- Assuming the first Fusion comp if multiple exist on the item
                    if fusionComp then
                        print("utils.findNamedFusionCompOnTimeline: Found Fusion composition '" .. compName .. "' on video track " .. i)
                        return fusionComp
                    end
                end
            end
        end
    end
    print("[WARNING] utils.findNamedFusionCompOnTimeline: Could not find Fusion composition item named '" .. compName .. "' on the timeline.")
    return nil
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