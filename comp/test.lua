-- Import utility functions
local utils = dofile(app:MapPath("Scripts:\\Utility\\utils.lua"))
local udump = utils.dump
local inspectObject = utils.inspectObject
local GetMarkersByColor = utils.GetMarkersByColor
local formatTimeDisplay = utils.formatTimeDisplay
local CONFIG = utils.CONFIG

dump(comp:FindTool("GAME_TIME_2")