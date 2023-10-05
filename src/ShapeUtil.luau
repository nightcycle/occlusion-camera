--!strict
local _Package = script.Parent
local _Packages = _Package.Parent
-- Services
-- Packages
local GeometryUtil = require(_Packages:WaitForChild("GeometryUtil"))
-- Modules
-- Types
-- Constants
-- Variables
-- References
-- Private Functions

-- Class
local Util = {}

function Util.getBounds(perimeter: {[number]: Vector2}): Rect
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

-- -- http://cgm.cs.mcgill.ca/~athens/cs507/Projects/2003/DanielSud/
-- function Util.getLargestRectWithinConvexShape(perimeter: {[number]: Vector2}): Rect
-- 	assert(#perimeter > 3)

-- 	local angles: {[Vector2]: number} = {}
-- 	local sortedPerimeter = table.clone(perimeter)

-- 	for i, v in ipairs(perimeter) do
-- 		local pV = perimeter[i-1] or perimeter[#perimeter]
-- 		local nV = perimeter[i+1] or perimeter[1]
-- 		local abLen = (pV - v).Magnitude
-- 		local bcLen = (nV - v).Magnitude
-- 		local caLen = (nV - pV).Magnitude

-- 		local angle: number

-- 		-- law of cos
-- 		if math.round(1000 * (abLen + bcLen)) == math.round(1000 * caLen) then
-- 			angle = 0
-- 		else
-- 			-- print("A", a, "B", b, "C", c)
-- 			local numerator = (abLen ^ 2) + (bcLen ^ 2) - (caLen ^ 2)
-- 			local denominator = (2 * abLen * bcLen)
-- 			local frac = numerator / denominator
-- 			angle = math.acos(frac)
-- 		end

-- 		angles[v] = angle

-- 	end

-- 	table.sort(sortedPerimeter, function(a: Vector2, b: Vector2)
-- 		local aAngle = angles[a]
-- 		local bAngle = angles[b]
-- 		return aAngle > bAngle
-- 	end)

-- 	local vertexA: Vector2
-- 	local vertexB: Vector2


-- end

return Util