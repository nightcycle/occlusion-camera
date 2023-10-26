--!strict
local _Package = script.Parent
local _Packages = _Package.Parent
-- Services
-- Packages
local TableUtil = require(_Packages:WaitForChild("TableUtil"))

-- Modules
-- Types
export type FillType = "Line" | "Inner" | "Empty"
-- Constants
-- Variables
-- References
-- Private Functions
local function getIfFits(container: Rect, item: Rect): boolean
	return container.Min.X <= item.Min.X and container.Max.X >= item.Max.X and container.Min.Y <= item.Min.Y and container.Max.Y >= item.Max.Y
end
local function getIfOverlaps(a: Rect, b: Rect): boolean
	return (a.Min.X < b.Min.X + b.Width) and
           (a.Min.X + a.Width > b.Min.X) and
           (a.Min.Y < b.Min.Y + b.Height) and
           (a.Min.Y + a.Height > b.Min.Y)
end
-- Class
local Util = {}

function Util.getInnerBoundSubdivisions(perimeter: {[number]: Vector2}): {[Rect]: FillType}


	do
		local xRegistry: {[number]: true} = {}
		local yRegistry: {[number]: true} = {}
	
		local edgeRectRegistry: {[Rect]: FillType} = {}

		local minX = math.huge
		local maxX = -math.huge
		local minY = math.huge
		local maxY = -math.huge


		local function getIfLineRect(rect: Rect): boolean
			for edgeRect, _ in pairs(edgeRectRegistry) do
				if getIfOverlaps(edgeRect, rect) then
					return true
				end
			end
			return false
		end
	
		local prevLineRegistry: {[string]: Vector2} = {}
		local nextLineRegistry: {[string]: Vector2} = {}
		local pointRegistry: {[string]: Vector2} = {}
	
		local maxXLine: NumberRange?
		local minXLine: NumberRange?
		local maxYLine: NumberRange?
		local minYLine: NumberRange?

		for i, v in ipairs(perimeter) do
			local nextPoint = perimeter[i+1] or perimeter[1]

			edgeRectRegistry[Rect.new(v, nextPoint)] = true
		
			minX = math.min(minX, v.X)
			maxX = math.max(maxX, v.X)

			minY = math.min(minY, v.Y)
			maxY = math.max(maxY, v.Y)

			perimeter[i] = Vector2.new(
				math.round(v.X),
				math.round(v.Y)
			)
		end

		
		-- for i, v in ipairs(perimeter) do
		-- 	local nextPoint = perimeter[i+1] or perimeter[1]
		-- 	if v.X == nextPoint.X then
		-- 		if v.X == maxX then
		-- 			if v.Y > nextPoint.Y then
		-- 				maxXLine = NumberRange.new(nextPoint.Y, v.Y)
		-- 			else
		-- 				maxXLine = NumberRange.new(v.Y, nextPoint.Y)
		-- 			end
		-- 		else
		-- 			if v.Y > nextPoint.Y then
		-- 				minXLine = NumberRange.new(nextPoint.Y, v.Y)
		-- 			else
		-- 				minXLine = NumberRange.new(v.Y, nextPoint.Y)
		-- 			end
		-- 		end
		-- 	elseif v.Y == nextPoint.Y then
		-- 		if v.Y == maxY then
		-- 			if v.X > nextPoint.X then
		-- 				maxYLine = NumberRange.new(nextPoint.X, v.X)
		-- 			else
		-- 				maxYLine = NumberRange.new(v.X, nextPoint.X)
		-- 			end
		-- 		else
		-- 			if v.X > nextPoint.X then
		-- 				minYLine = NumberRange.new(nextPoint.X, v.X)
		-- 			else
		-- 				minYLine = NumberRange.new(v.X, nextPoint.X)
		-- 			end
		-- 		end
		-- 	end
		-- end
		-- if not (#perimeter >= 2) then return {} end
		-- assert(#perimeter >= 2)
		-- for i, v in ipairs(perimeter) do
		-- 	local pV = perimeter[i-1] or perimeter[#perimeter]
		-- 	local nV = perimeter[i+1] or perimeter[1]
	
		-- 	prevLineRegistry[tostring(v)] = pV
		-- 	nextLineRegistry[tostring(v)] = nV
		-- 	pointRegistry[tostring(v)] = v
	
		-- 	xRegistry[v.X] = true
		-- 	yRegistry[v.Y] = true
		-- end
	
		-- local xList = TableUtil.keys(xRegistry)
		-- local yList = TableUtil.keys(yRegistry)
		-- table.sort(xList)
		-- table.sort(yList)
	
		-- local cellRegistry: {[Rect]: FillType} = {}
		-- for i, x in ipairs(xList) do
		-- 	for j, y in ipairs(yList) do
		-- 		local nX = xList[i+1]
		-- 		local nY = yList[j+1]
	
		-- 		if nX and nY then
	
		-- 			local rect = Rect.new(
		-- 				Vector2.new(x,y),
		-- 				Vector2.new(nX,nY)
		-- 			)


		-- 			local fillType: FillType = "Inner"
		-- 			if getIfLineRect(rect) then
		-- 				fillType = "Line"
		-- 			else
		-- 				local xBorderCount = 0
		-- 				if minX == rect.Min.X then
		-- 					if not minXLine then
		-- 						xBorderCount += 1 
		-- 					end
		-- 				end
		-- 				if maxX == rect.Min.X then 
		-- 					if not maxXLine then
		-- 						xBorderCount += 1 
		-- 					end
		-- 				end
		-- 				if minX == rect.Max.X then 
		-- 					if not minXLine then
		-- 						xBorderCount += 1 
		-- 					end
		-- 				end
		-- 				if maxX == rect.Max.X then 
		-- 					if not maxXLine then
		-- 						xBorderCount += 1 
		-- 					end
		-- 				end
	
		-- 				local yBorderCount = 0

		-- 				if minY == rect.Min.Y then 
		-- 					if not minYLine then
		-- 						yBorderCount += 1 
		-- 					end	
		-- 				end
		-- 				if maxY == rect.Min.Y then 
		-- 					if not maxYLine then
		-- 						yBorderCount += 1 
		-- 					end
		-- 				end
		-- 				if minY == rect.Max.Y then 
		-- 					if not minYLine then
		-- 						yBorderCount += 1 
		-- 					end
		-- 				end
		-- 				if maxY == rect.Max.Y then 
		-- 					if not maxYLine then
		-- 						yBorderCount += 1 
		-- 					end
		-- 				end

		-- 				if xBorderCount >= 1 or yBorderCount >= 1 then
		-- 					fillType = "Empty"
		-- 				end
		-- 			end
		-- 			cellRegistry[rect] = fillType
		-- 		end
		-- 	end
		-- end
		return edgeRectRegistry
		-- return cellRegistry
	end
	-- local edgeRectRegistry: {[Rect]: FillType} = {}
	-- for i, point in ipairs(perimeter) do
	-- 	local nextPoint = perimeter[i+1] or perimeter[1]
	-- 	local rect = Rect.new(
	-- 		point,
	-- 		nextPoint
	-- 	)
	-- 	edgeRectRegistry[rect] = "Line"
	-- end
	-- return edgeRectRegistry
end


function Util.getInnerBounds(perimeter: {[number]: Vector2}): Rect
	Util.getInnerBoundSubdivisions(perimeter)
	return Rect.new(Vector2.zero, Vector2.one)
end

function Util.getOuterBounds(perimeter: {[number]: Vector2}): Rect
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
	-- print(`\nviewport: {viewportSize}`)
	assert(#perimeter > 0)
	for i, pos in ipairs(perimeter) do
		-- compare(Vector2.new(
		-- 	math.clamp(pos.X, 0, viewportSize.X),
		-- 	math.clamp(pos.Y, 0, viewportSize.Y)
		-- ))
		compare(pos)
	end

	assert(minX == minX)
	assert(maxX == maxX)
	assert(maxY == maxY)

	local r = Rect.new(
		Vector2.new(minX, minY),
		Vector2.new(maxX, maxY)
	)
	-- print(`r: {r}`)
	return r
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