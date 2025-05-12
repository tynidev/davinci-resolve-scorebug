--[[
================================================================================
Script Name: utils.lua
Author: Tyler
Created: May 11, 2025
Last Modified: May 11, 2025

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
  Gets all markers of a specific color from the timeline
  
  @param color string - The marker color to filter by
  @return table - A table of markers with frame numbers as keys
]]
function utils.GetMarkersByColor(color)
    local pm = resolve:GetProjectManager()
    local pr = pm:GetCurrentProject()
    local tl = pr:GetCurrentTimeline()
    local ml = tl:GetMarkers()
    local markers = {}
    local i = 1
    for t, m in pairs(ml) do
        if(m.color == color) then
            markers[t] = m
            i = i + 1
        end
    end
    return markers
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
    RIGHT_SCORE_ELEMENT = "RIGHT_SCORE_2"
}

return utils