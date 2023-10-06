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

return Util