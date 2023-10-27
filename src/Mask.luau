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
	OuterRect: Rect,
	InnerRect: Rect,
	Polygon: Polygon
}
export type Mask<V> = {
	__index: Mask<V>,
	_Tree: RTree<V>,
	_Items: {[V]: MaskData?},
	_OcclusionCache: {[V]: boolean?},
	GetIfOccluded: (self: Mask<V>, key: unknown) -> boolean,
	Register: (self: Mask<V>, key: V, innerRect: Rect, outerRect: Rect, shape: {[number]: Vector2}, priority: number, isOccluder: boolean) -> (),
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
	for i, blocker in ipairs(self._Tree:Search(maskData.InnerRect)) do
		local blockerData = self._Items[blocker]
		assert(blockerData)
		if blocker ~= key and blockerData.Priority >= maskData.Priority then
			table.insert(blockers, blocker)
		end
	end
	local isOccluded = false

	local focus = maskData.OuterRect

	local filters = {}
	for i, blocker in ipairs(blockers) do
		local blockerData = self._Items[blocker]
		assert(blockerData)
		table.insert(filters, blockerData.InnerRect)
	end

	local visibleRects = ShapeUtil.getVisibleRects(focus, filters)

	isOccluded = #visibleRects == 0

	self._OcclusionCache[key] = isOccluded
	return isOccluded
end

function Mask:Register(key: unknown, innerRect: Rect, outerRect: Rect, shape: {[number]: Vector2}, priority: number, isOccluder: boolean): ()
	
	self._Items[key] = {
		Priority = priority,
		IsOccluder = isOccluder,
		InnerRect = innerRect,
		OuterRect = outerRect,
		Polygon = PolyBool.new(shape)
	}

	if isOccluder then
		self._Tree:Add(innerRect, key)
	end
end

function Mask.new()

	local self: Mask<any> = setmetatable({}, Mask) :: any
	self._Tree = RTree.new()
	self._Items = {}
	self._OcclusionCache = {}

	return self
end

return Mask