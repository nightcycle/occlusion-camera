--!strict
local _Package = script.Parent
local _Packages = _Package.Parent
-- Services
-- Packages
local TableUtil = require(_Packages:WaitForChild("TableUtil"))
-- Modules
-- Types
-- Constants
-- Variables
-- References
-- Private Functions
local function getIfFits(container: Rect, item: Rect): boolean
	return container.Min.X <= item.Min.X and container.Max.X >= item.Max.X and container.Min.Y <= item.Min.Y and container.Max.Y >= item.Max.Y
end

-- Class
local Util = {}

function Util.getBounds(perimeter: {[number]: Vector2}): Rect
	if #perimeter == 0 then return Rect.new(Vector2.zero, Vector2.zero) end
	local minX: number
	local maxX: number
	local minY: number
	local maxY: number
	local function compare(v: Vector2)
		if not minX or v.X < minX then
			minX = v.X
		end
		if not minY or v.Y < minY then
			minY = v.Y
		end
		if not maxX or v.X > maxX then
			maxX = v.X
		end
		if not maxY or v.Y > maxY then
			maxY = v.Y
		end
	end

	assert(#perimeter > 0)
	for i, pos in ipairs(perimeter) do
		compare(pos)
	end

	return Rect.new(
		Vector2.new(minX, minY),
		Vector2.new(maxX, maxY)
	)
end

function Util.getVisibleRects(focus: Rect, filters: {[number]: Rect}): {[number]: Rect}

	local constrainedFilters: {[number]: Rect} = {}
	for i, filter in ipairs(filters) do
		if getIfFits(filter, focus) then
			return {}
		end
		local min = Vector2.new(
			math.max(focus.Min.X, filter.Min.X),
			math.max(focus.Min.Y, filter.Min.Y)
		)
		local max = Vector2.new(
			math.min(focus.Max.X, filter.Max.X),
			math.min(focus.Max.Y, filter.Max.Y)
		)
		if max.X > min.X and max.Y > min.Y then
			table.insert(constrainedFilters, Rect.new(min, max))
		end
	end

	local xLineRegistry: {[number]: {[number]: Rect}} = {
		[focus.Max.X] = {},
		[focus.Min.X] = {},
	}
	local yLineRegistry: {[number]: {[number]: Rect}} = {
		[focus.Max.Y] = {},
		[focus.Min.Y] = {},
	}

	for i, filter in ipairs(constrainedFilters) do
		xLineRegistry[filter.Min.X] = {}
		xLineRegistry[filter.Max.X] = {}
		yLineRegistry[filter.Min.Y] = {}
		yLineRegistry[filter.Max.Y] = {}
	end

	local xList = TableUtil.keys(xLineRegistry)
	local yList = TableUtil.keys(yLineRegistry)
	table.sort(xList)
	table.sort(yList)

	local cellRegistry: {[Rect]: true} = {}
	for i, x in ipairs(xList) do
		for j, y in ipairs(yList) do
			local nX = xList[i+1]
			local nY = yList[j+1]
			if nX and nY then
				local rect = Rect.new(
					Vector2.new(x,y),
					Vector2.new(nX,nY)
				)
				cellRegistry[rect] = true
			end
		end
	end

	for i, filter in ipairs(constrainedFilters) do
		for cell, _ in pairs(cellRegistry) do
			if getIfFits(filter, cell) then
				cellRegistry[cell] = nil
			end
		end
	end

	-- for i, filter in ipairs(constrainedFilters) do

	-- 	local iMinX = table.find(xList, filter.Min.X)
	-- 	local iMaxX = table.find(xList, filter.Max.X)
	-- 	local jMinY = table.find(yList, filter.Min.Y)
	-- 	local jMaxY = table.find(yList, filter.Max.Y)
	-- 	assert(iMinX and iMaxX and jMinY and jMaxY)
		
	-- 	for x=iMinX, iMaxX do
	-- 		for y=jMinY, jMaxY do
	-- 			local rect = Rect.new(
	-- 				Vector2.new(
	-- 					xList[iMinX],
	-- 					yList[jMinY]
	-- 				),
	-- 				Vector2.new(
	-- 					xList[iMaxX],
	-- 					yList[jMaxY]
	-- 				)
	-- 			)
	-- 			cellRegistry[rect] = nil
	-- 		end
	-- 	end
	-- end
	 
	return TableUtil.keys(cellRegistry)
end

return Util