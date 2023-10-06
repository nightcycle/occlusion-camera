--!strict
local Debris = game:GetService("Debris")
local _Package = script.Parent
local _Packages = _Package.Parent
-- Services
-- Packages
local RTree = require(_Package:WaitForChild("RTree"))
local PolyBool = require(_Package:WaitForChild("PolyBool"))
local ShapeUtil = require(_Package:WaitForChild("ShapeUtil"))
-- Modules
-- Types
-- Constants
local IGNORE_POLYGONS = true
-- Variables
-- References
-- Private Functions
-- Class
-- Types
type Polygon = PolyBool.Polygon
type RTree<V> = RTree.RTree<V>
type MaskData = {
	Priority: number,
	IsOccluder: boolean,
	Rect: Rect,
	Polygon: Polygon
}
export type Mask<V> = {
	__index: Mask<V>,
	_Tree: RTree<V>,
	_Items: {[V]: MaskData?},
	_OcclusionCache: {[V]: boolean?},
	GetIfOccluded: (self: Mask<V>, key: unknown) -> boolean,
	Register: (self: Mask<V>, key: V, rect: Rect, shape: {[number]: Vector2}, priority: number, isOccluder: boolean) -> (),
	new: () -> Mask<V>,
}

-- Class
local Mask = {} :: Mask<any>
Mask.__index = Mask

function Mask:GetIfOccluded(key: unknown): boolean
	if self._OcclusionCache[key] ~= nil then
		local cache = self._OcclusionCache[key]
		assert(cache ~= nil)
		return cache
	end
	local maskData = self._Items[key]
	assert(maskData)

	local blockers = {}
	for i, blocker in ipairs(self._Tree:Search(maskData.Rect)) do
		local blockerData = self._Items[blocker]
		assert(blockerData)
		if blocker ~= key and blockerData.Priority >= maskData.Priority then
			table.insert(blockers, blocker)
		end
	end
	local isOccluded = false

	if IGNORE_POLYGONS then
		local focus = maskData.Rect

		local filters = {}
		for i, blocker in ipairs(blockers) do
			local blockerData = self._Items[blocker]
			assert(blockerData)
			table.insert(filters, blockerData.Rect)
		end

		local visibleRects = ShapeUtil.getVisibleRects(focus, filters)
		-- do
		-- 	local part: BasePart = key :: any
		-- 	if part.Transparency == 0 then
		-- 		local screen = Instance.new("ScreenGui")

		-- 		for i, rect in ipairs(visibleRects) do
		-- 			local frame = Instance.new("Frame")
		-- 			frame.BackgroundTransparency = 0.9
		-- 			frame.ZIndex = 100
		-- 			frame.BorderSizePixel = 5
		-- 			frame.BackgroundColor3 = Color3.new(1,1,1)
		-- 			frame.AnchorPoint = Vector2.new(0.5,0.5)
		-- 			frame.Position = UDim2.fromOffset(rect.Min.X+rect.Width/2, rect.Min.Y+rect.Height/2)
		-- 			frame.Size = UDim2.fromOffset(rect.Width-15, rect.Height-15)
		-- 			frame.Parent = screen
		-- 		end
				
		-- 		if #visibleRects == 0 then
		-- 			part.Color = Color3.new(1,0,0)
		-- 		else
		-- 			part.Color = Color3.new(0,1,0)
		-- 		end
	
		-- 		screen.Parent = game:GetService("CoreGui")
	
		-- 		Debris:AddItem(screen, 1/30)
		-- 	end

		-- end
		isOccluded = #visibleRects == 0
	else
		local polygon = PolyBool.copy(maskData.Polygon)

		for i, blocker in ipairs(blockers) do
			local blockerData = self._Items[blocker]
			assert(blockerData)

			local bPolygon = PolyBool.copy(blockerData.Polygon)
			polygon = PolyBool.difference(polygon, bPolygon)

			if PolyBool.getIfEmpty(polygon) then
				isOccluded = true
				break
			end
		end
	end

	self._OcclusionCache[key] = isOccluded
	return isOccluded
end

function Mask:Register(key: unknown, rect: Rect, shape: {[number]: Vector2}, priority: number, isOccluder: boolean): ()
	
	self._Items[key] = {
		Priority = priority,
		IsOccluder = isOccluder,
		Rect = rect,
		Polygon = PolyBool.new(shape)
	}

	-- if not self:GetIfOccluded(key) then
	if isOccluder then
		self._Tree:Add(rect, key)
	end
	-- 	return true
	-- else
	-- 	return false
	-- end
end

function Mask.new()

	local self: Mask<any> = setmetatable({}, Mask) :: any
	self._Tree = RTree.new()
	self._Items = {}
	self._OcclusionCache = {}

	return self
end

return Mask