---!strict
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
local function getIfOverlaps(a: Rect, b: Rect): boolean
	return (a.Min.X < b.Min.X + b.Width) and
           (a.Min.X + a.Width > b.Min.X) and
           (a.Min.Y < b.Min.Y + b.Height) and
           (a.Min.Y + a.Height > b.Min.Y)
end

function getOverlapArea(rectA: Rect, rectB: Rect): number
	if (rectA.Min.X < rectB.Min.X + rectB.Width) and
	   (rectA.Min.X + rectA.Width > rectB.Min.X) and
	   (rectA.Min.Y < rectB.Min.Y + rectB.Height) and
	   (rectA.Min.Y + rectA.Height > rectB.Min.Y) then
	    -- Calculate the overlapping rect's dimensions
	    local overlapWidth = math.min(rectA.Min.X + rectA.Width, rectB.Min.X + rectB.Width) - 
						math.max(rectA.Min.X, rectB.Min.X)
						
	    local overlapHeight = math.min(rectA.Min.Y + rectA.Height, rectB.Min.Y + rectB.Height) - 
						 math.max(rectA.Min.Y, rectB.Min.Y)
						 
	    return overlapWidth * overlapHeight
	else
	    return 0
	end
 end

-- Class
-- Types
export type Directory<T> = {
	Rect: Rect,
	Item: T,
	SubDirectories: {[Rect]: Directory<T>}
}
export type RTree<T> = {
	__index: RTree<T>,
	_Master: Directory<T>,
	_Add: (self: RTree<T>, rect: Rect, payload: T, directory: Directory<T>) -> (),
	Add: (self: RTree<T>, rect: Rect, payload: T) -> (),
	_Search: (self: RTree<T>, rect: Rect, directory: Directory<T>, areaRegistry: {[unknown]: number}) -> (),
	Search: (self: RTree<T>, rect: Rect) -> {[number]: T},
	new: () -> RTree<T>,
}

-- Class
local RTree = {} :: RTree<any>
RTree.__index = RTree

function RTree:_Add(rect: Rect, payload: unknown, directory: Directory<unknown>)
	
	-- add payload to sub-directory
	local subDirectory: Directory<unknown>?
	for subRegion, dir in pairs(directory.SubDirectories) do
		if getIfFits(subRegion, rect) then
			subDirectory = dir
			break
		end
	end
	-- if sub-directory, add under current directory
	if subDirectory then
		self:_Add(rect, payload, subDirectory)
	else -- if no sub-directory is found, create one
		local freshDirectory = {
			Rect = rect,
			Item = payload,
			SubDirectories = {}
		} :: Directory<unknown>

		for r, v in pairs(directory.SubDirectories) do
			if getIfFits(freshDirectory.Rect, r) then
				directory.SubDirectories[r] = nil
				freshDirectory.SubDirectories[r] = v
			end
		end

		directory.SubDirectories[freshDirectory.Rect] = freshDirectory
	end
end

function RTree:Add(rect: Rect, payload: unknown)
	self:_Add(rect, payload, self._Master)
end

function RTree:_Search(rect: Rect, directory: Directory<unknown>, areaRegistry: {[unknown]: number}): ()
	local area = 0
	if getIfFits(directory.Rect, rect) then
		area = directory.Rect.Width * directory.Rect.Height
	elseif getIfOverlaps(rect, directory.Rect) then
		area = getOverlapArea(rect, directory.Rect)
	end
	if area > 0 then
		if directory.Item ~= nil then
			areaRegistry[directory.Item] = area
		end
		for subReg, subDir in pairs(directory.SubDirectories) do
			self:_Search(rect, subDir, areaRegistry)
		end
	end
end

function RTree:Search(rect: Rect): {[number]: unknown}
	local areaRegistry: {[unknown]: number} = {}
	self:_Search(rect, self._Master, areaRegistry)

	local out: {[number]: unknown} = TableUtil.keys(areaRegistry)
	table.sort(out, function(a: unknown, b: unknown)
		return areaRegistry[a] < areaRegistry[b]
	end)
	return out
end

function RTree.new(): RTree<unknown>

	local self: RTree<unknown> = setmetatable({}, RTree) :: any
	self._Master = {
		Rect = Rect.new(
			-math.huge,
			-math.huge, 
			math.huge,
			math.huge
		),
		Items = {},
		RegionList = {},
		SubDirectories = {}
	}

	return self
end

return RTree