--!strict
local _Package = script.Parent
local _Packages = _Package.Parent
-- Services
-- Packages
local TableUtil = require(_Packages:WaitForChild("TableUtil"))

-- Modules
-- Types
export type FillType = "Line" | "Inner" | "Empty"
type IntersectionData = {
	Intersection: Vector2,
	A: Vector2,
	B: Vector2
}
-- Constants
local BIG = 100000
-- Variables
-- References
-- Private Functions
local function getIfFits(container: Rect, item: Rect): boolean
	return container.Min.X <= item.Min.X and container.Max.X >= item.Max.X and container.Min.Y <= item.Min.Y and container.Max.Y >= item.Max.Y
end
-- local function getIfOverlaps(a: Rect, b: Rect): boolean
-- 	return (a.Min.X < b.Min.X + b.Width) and
--            (a.Min.X + a.Width > b.Min.X) and
--            (a.Min.Y < b.Min.Y + b.Height) and
--            (a.Min.Y + a.Height > b.Min.Y)
-- end

-- Class
local Util = {}

function Util.getLineIntersection(origin: Vector2, direction: Vector2, a: Vector2, b: Vector2): Vector2?
	local x1: number, y1: number = origin.X, origin.Y
	local x2: number, y2: number = x1 + direction.X, y1 + direction.Y
	local x3: number, y3: number = a.X, a.Y
	local x4: number, y4: number = b.X, b.Y

	-- Calculate determinants
	local det = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)

	-- Lines are parallel if determinant is 0
	if det == 0 then
		return nil
	end

	-- Calculate intersection point
	local px = ((x1 * y2 - y1 * x2) * (x3 - x4) - (x1 - x2) * (x3 * y4 - y3 * x4)) / det
	local py = ((x1 * y2 - y1 * x2) * (y3 - y4) - (y1 - y2) * (x3 * y4 - y3 * x4)) / det
 
	if px >= math.min(x1, x2) and px <= math.max(x1, x2) and
	   py >= math.min(y1, y2) and py <= math.max(y1, y2) and
	   px >= math.min(x3, x4) and px <= math.max(x3, x4) and
	   py >= math.min(y3, y4) and py <= math.max(y3, y4) then
	    return Vector2.new(px, py)
	else
	    return nil
	end
end

-- function Util._getInnerBoundRegions(perimeter: {[number]: Vector2}, vSize: Vector2): {[Rect]: FillType}
-- 	local center = Vector2.zero
-- 	for i, v in ipairs(perimeter) do
-- 		center += Vector2.new(
-- 			math.clamp(v.X, 0, vSize.X),
-- 			math.clamp(v.Y, 0, vSize.Y)
-- 		)
-- 	end

-- 	center /= #perimeter

-- 	local function renderPoint(point: Vector2, size: number): Rect
-- 		return Rect.new(
-- 			point - Vector2.one * size,
-- 			point + Vector2.one * size
-- 		)
-- 	end

-- 	local function getIntersection(origin: Vector2, normal: Vector2): IntersectionData?
-- 		for i, v in ipairs(perimeter) do
-- 			local nV = perimeter[i+1] or perimeter[1]
-- 			local intersection = Util.getLineIntersection(
-- 				origin,
-- 				normal * BIG,
-- 				v,
-- 				nV
-- 			)
-- 			if intersection then
-- 				return {
-- 					Intersection = intersection,
-- 					A = v,
-- 					B = nV
-- 				}
-- 			end
-- 		end
-- 		return nil
-- 	end

-- 	local out: {[Rect]: FillType} = {
-- 		[renderPoint(center, 10)] = "Line",
-- 	}

-- 	local minV2: Vector2?

-- 	do
-- 		local hit = getIntersection(center, Vector2.new(1,0))
-- 		if hit then
-- 			minV2 = Vector2.new(
-- 				math.min(hit.A.X, hit.B.X),
-- 				math.min(hit.A.Y, hit.B.Y)
-- 			)
-- 		end
-- 	end

-- 	local maxV2: Vector2?

-- 	do
-- 		local hit = getIntersection(center, Vector2.new(-1,0))
-- 		if hit then
-- 			maxV2 = Vector2.new(
-- 				math.max(hit.A.X, hit.B.X),
-- 				math.max(hit.A.Y, hit.B.Y)
-- 			)
-- 		end
-- 	end

-- 	if minV2 and maxV2 then
-- 		local maxX = maxV2.X
-- 		local maxY = maxV2.Y
-- 		local minX = minV2.X
-- 		local minY = minV2.Y
-- 		do
-- 			local maxYR: number?
-- 			do
-- 				out[renderPoint(
-- 					Vector2.new(
-- 						minV2.X,
-- 						center.Y
-- 					), 
-- 					15
-- 				)] = "Line"
				
-- 				local hit = getIntersection(Vector2.new(
-- 					minV2.X,
-- 					center.Y
-- 				), Vector2.new(0, 1))

-- 				if hit then
-- 					out[renderPoint(
-- 						hit.Intersection, 
-- 						15
-- 					)] = "Empty"
-- 					maxYR = hit.Intersection.Y
-- 				end
-- 			end
	
-- 			local maxYL: number?
-- 			do
-- 				out[renderPoint(
-- 					Vector2.new(
-- 						maxV2.X,
-- 						center.Y
-- 					), 
-- 					15
-- 				)] = "Line"

-- 				local hit = getIntersection(Vector2.new(
-- 					maxV2.X,
-- 					center.Y
-- 				), Vector2.new(0, 1))

-- 				if hit then
-- 					out[renderPoint(
-- 						hit.Intersection, 
-- 						15
-- 					)] = "Empty"
-- 					maxYL = hit.Intersection.Y
-- 				end
-- 			end

-- 			if maxYL and maxYR then
-- 				maxY = math.min(maxYL, maxYR)
-- 			elseif maxYL then
-- 				maxY = maxYL
-- 			elseif maxYR then
-- 				maxY = maxYR
-- 			end
-- 		end
-- 		do
-- 			local minYR: number?
-- 			do
-- 				out[renderPoint(
-- 					Vector2.new(
-- 						minV2.X,
-- 						center.Y
-- 					), 
-- 					15
-- 				)] = "Line"
				
-- 				local hit = getIntersection(Vector2.new(
-- 					minV2.X,
-- 					center.Y
-- 				), Vector2.new(0, -1))

-- 				if hit then
-- 					out[renderPoint(
-- 						hit.Intersection, 
-- 						15
-- 					)] = "Empty"
-- 					minYR = hit.Intersection.Y
-- 				end
-- 			end
	
-- 			local minYL: number?
-- 			do
-- 				out[renderPoint(
-- 					Vector2.new(
-- 						maxV2.X,
-- 						center.Y
-- 					), 
-- 					15
-- 				)] = "Line"

-- 				local hit = getIntersection(Vector2.new(
-- 					maxV2.X,
-- 					center.Y
-- 				), Vector2.new(0, -1))

-- 				if hit then
-- 					out[renderPoint(
-- 						hit.Intersection, 
-- 						15
-- 					)] = "Empty"
-- 					minYL = hit.Intersection.Y
-- 				end
-- 			end

-- 			if minYL and minYR then
-- 				minY = math.max(minYL, minYR)
-- 			elseif minYL then
-- 				minY = minYL
-- 			elseif minYR then
-- 				minY = minYR
-- 			end
-- 		end
-- 	end
-- 	return out
-- end


function Util.getInnerBounds(perimeter: {[number]: Vector2}, vSize: Vector2): Rect
	local center = Vector2.zero
	for i, v in ipairs(perimeter) do
		center += Vector2.new(
			math.clamp(v.X, 0, vSize.X),
			math.clamp(v.Y, 0, vSize.Y)
		)
	end

	center /= #perimeter

	local function renderPoint(point: Vector2, size: number): Rect
		return Rect.new(
			point - Vector2.one * size,
			point + Vector2.one * size
		)
	end

	local function getIntersection(origin: Vector2, normal: Vector2): IntersectionData?
		for i, v in ipairs(perimeter) do
			local nV = perimeter[i+1] or perimeter[1]
			local intersection = Util.getLineIntersection(
				origin,
				normal * BIG,
				v,
				nV
			)
			if intersection then
				return {
					Intersection = intersection,
					A = v,
					B = nV
				}
			end
		end
		return nil
	end

	local out: {[Rect]: FillType} = {
		[renderPoint(center, 10)] = "Line",
	}

	local minV2: Vector2?

	do
		local hit = getIntersection(center, Vector2.new(1,0))
		if hit then
			minV2 = Vector2.new(
				math.min(hit.A.X, hit.B.X),
				math.min(hit.A.Y, hit.B.Y)
			)
		end
	end

	local maxV2: Vector2?

	do
		local hit = getIntersection(center, Vector2.new(-1,0))
		if hit then
			maxV2 = Vector2.new(
				math.max(hit.A.X, hit.B.X),
				math.max(hit.A.Y, hit.B.Y)
			)
		end
	end

	if minV2 and maxV2 then
		local maxX = maxV2.X
		local maxY = maxV2.Y
		local minX = minV2.X
		local minY = minV2.Y
		do
			local maxYR: number?
			do
				out[renderPoint(
					Vector2.new(
						minV2.X,
						center.Y
					), 
					15
				)] = "Line"
				
				local hit = getIntersection(Vector2.new(
					minV2.X,
					center.Y
				), Vector2.new(0, 1))

				if hit then
					out[renderPoint(
						hit.Intersection, 
						15
					)] = "Empty"
					maxYR = hit.Intersection.Y
				end
			end
	
			local maxYL: number?
			do
				out[renderPoint(
					Vector2.new(
						maxV2.X,
						center.Y
					), 
					15
				)] = "Line"

				local hit = getIntersection(Vector2.new(
					maxV2.X,
					center.Y
				), Vector2.new(0, 1))

				if hit then
					out[renderPoint(
						hit.Intersection, 
						15
					)] = "Empty"
					maxYL = hit.Intersection.Y
				end
			end

			if maxYL and maxYR then
				maxY = math.min(maxYL, maxYR)
			elseif maxYL then
				maxY = maxYL
			elseif maxYR then
				maxY = maxYR
			end
		end
		do
			local minYR: number?
			do
				out[renderPoint(
					Vector2.new(
						minV2.X,
						center.Y
					), 
					15
				)] = "Line"
				
				local hit = getIntersection(Vector2.new(
					minV2.X,
					center.Y
				), Vector2.new(0, -1))

				if hit then
					out[renderPoint(
						hit.Intersection, 
						15
					)] = "Empty"
					minYR = hit.Intersection.Y
				end
			end
	
			local minYL: number?
			do
				out[renderPoint(
					Vector2.new(
						maxV2.X,
						center.Y
					), 
					15
				)] = "Line"

				local hit = getIntersection(Vector2.new(
					maxV2.X,
					center.Y
				), Vector2.new(0, -1))

				if hit then
					out[renderPoint(
						hit.Intersection, 
						15
					)] = "Empty"
					minYL = hit.Intersection.Y
				end
			end

			if minYL and minYR then
				minY = math.max(minYL, minYR)
			elseif minYL then
				minY = minYL
			elseif minYR then
				minY = minYR
			end
		end

		return Rect.new(
			Vector2.new(
				math.round(minX), 
				math.round(minY)
			), 
			Vector2.new(
				math.round(maxX), 
				math.round(maxY)
			)
		)
	else
		return Rect.new(Vector2.zero, Vector2.zero)
	end
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

	local allRects: {[number]: Rect} = table.clone(filters)
	table.insert(allRects, focus)


	local xLineRegistry: {[number]: true} = {}
	local yLineRegistry: {[number]: true} = {}

	for i, rect in ipairs(allRects) do
		xLineRegistry[rect.Min.X] = true
		xLineRegistry[rect.Max.X] = true
		yLineRegistry[rect.Min.Y] = true
		yLineRegistry[rect.Max.Y] = true
	end

	local xList = TableUtil.keys(xLineRegistry)
	local yList = TableUtil.keys(yLineRegistry)
	table.sort(xList)
	table.sort(yList)

	local function getIfFiltered(rect: Rect): boolean
		local isFiltered = false
		for i, filter in ipairs(filters) do
			if getIfFits(filter, rect) then
				isFiltered = true
				break
			end
		end
		return isFiltered
	end

	local focusCells: {[number]: Rect} = {}
	for i, x in ipairs(xList) do
		for j, y in ipairs(yList) do
			local nX = xList[i+1]
			local nY = yList[j+1]
			if nX and nY then
				local rect = Rect.new(
					Vector2.new(x,y),
					Vector2.new(nX,nY)
				)
				if getIfFits(focus, rect) then
					if not getIfFiltered(rect) then
						table.insert(focusCells, rect)					
					end
				end
			end
		end
	end

	return focusCells
end

-- function Util.getVisibleRects(focus: Rect, filters: {[number]: Rect}): {[number]: Rect}

-- 	local constrainedFilters: {[number]: Rect} = {}
-- 	for i, filter in ipairs(filters) do
-- 		if getIfFits(filter, focus) then
-- 			return {}
-- 		end
-- 		local min = Vector2.new(
-- 			math.max(focus.Min.X, filter.Min.X),
-- 			math.max(focus.Min.Y, filter.Min.Y)
-- 		)
-- 		local max = Vector2.new(
-- 			math.min(focus.Max.X, filter.Max.X),
-- 			math.min(focus.Max.Y, filter.Max.Y)
-- 		)
-- 		if max.X > min.X and max.Y > min.Y then
-- 			table.insert(constrainedFilters, Rect.new(min, max))
-- 		end
-- 	end

-- 	local xLineRegistry: {[number]: {[number]: Rect}} = {
-- 		[focus.Max.X] = {},
-- 		[focus.Min.X] = {},
-- 	}
-- 	local yLineRegistry: {[number]: {[number]: Rect}} = {
-- 		[focus.Max.Y] = {},
-- 		[focus.Min.Y] = {},
-- 	}
	

-- 	for i, filter in ipairs(constrainedFilters) do
-- 		xLineRegistry[filter.Min.X] = {}
-- 		xLineRegistry[filter.Max.X] = {}
-- 		yLineRegistry[filter.Min.Y] = {}
-- 		yLineRegistry[filter.Max.Y] = {}
-- 	end

-- 	local xList = TableUtil.keys(xLineRegistry)
-- 	local yList = TableUtil.keys(yLineRegistry)
-- 	table.sort(xList)
-- 	table.sort(yList)

-- 	local cellRegistry: {[Rect]: true} = {}
-- 	for i, x in ipairs(xList) do
-- 		for j, y in ipairs(yList) do
-- 			local nX = xList[i+1]
-- 			local nY = yList[j+1]
-- 			if nX and nY then
-- 				local rect = Rect.new(
-- 					Vector2.new(x,y),
-- 					Vector2.new(nX,nY)
-- 				)
-- 				cellRegistry[rect] = true
-- 			end
-- 		end
-- 	end

-- 	for i, filter in ipairs(constrainedFilters) do
-- 		for cell, _ in pairs(cellRegistry) do
-- 			if getIfFits(filter, cell) then
-- 				cellRegistry[cell] = nil
-- 			end
-- 		end
-- 	end

-- 	return TableUtil.keys(cellRegistry)
-- end

return Util