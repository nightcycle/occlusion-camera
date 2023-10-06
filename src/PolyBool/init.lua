--!strict
--[[
 * @copyright 2016 Sean Connelly (@voidqk), http://syntheti.cc
 * @license MIT
 * @preserve Project Home: https://github.com/voidqk/polybooljs

   Converted to Lua by EgoMoose
   Edits made by Nightcycle
--]]
local _Package = script.Parent
local _Packages = _Package.Parent
-- Services
-- Packages
local GeometryUtil = require(_Packages:WaitForChild("GeometryUtil"))
-- Modules

local Epsilon = require(script:WaitForChild("Epsilon"))
local Intersecter = require(script:WaitForChild("Intersector"))
local SegmentChainer = require(script:WaitForChild("SegmentChainer"))
local SegmentSelector = require(script:WaitForChild("SegmentSelector"))
local Types = require(script:WaitForChild("Types"))

-- Types
export type Polygon = Types.Polygon
export type PolygonRegion = Types.PolygonRegion
export type EpsilonHandler = Epsilon.EpsilonHandler
export type Selector = SegmentSelector.SegmentSelector
type SelectionProcessor = SegmentSelector.SelectionProcessor
export type Segment = Types.Segment
export type Shape = Types.Shape
export type CombineData = Types.CombineData
-- Constants
-- Variables
-- References
local EpsilonHandler: EpsilonHandler = Epsilon()
-- Private Functions

function drawTriangle(
	a: Vector2, 
	b: Vector2, 
	c: Vector2
): (ImageLabel, ImageLabel)
	local HALF = Vector2.new(0.5, 0.5);
	
	local RIGHT = "rbxassetid://319692151";
	local LEFT = "rbxassetid://319692171";

	local ab, ac, bc = b - a, c - a, c - b;
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc);
	
	if (abd > acd and abd > bcd) then
		c, a = a, c;
	elseif (acd > bcd and acd > abd) then
		a, b = b, a;
	end
	
	ab, ac, bc = b - a, c - a, c - b;
	
	local unit = bc.Unit;
	local height = unit:Cross(ab);
	local flip = (height >= 0);
	local theta = math.deg(math.atan2(unit.Y, unit.X)) + (flip and 0 or 180);
	
	local m1 = (a + b)/2;
	local m2 = (a + c)/2;

	local w1 = Instance.new("ImageLabel");
	w1.BackgroundTransparency = 1;
	w1.AnchorPoint = HALF;
	w1.BorderSizePixel = 0;
	w1.Image = flip and RIGHT or LEFT;
	w1.AnchorPoint = HALF;
	w1.Size = UDim2.new(0, math.abs(unit:Dot(ab)), 0, height);
	w1.Position = UDim2.fromOffset(m1.X, m1.Y);
	w1.Rotation = theta;
	
	local w2 = Instance.new("ImageLabel"); 		
	w2.BackgroundTransparency = 1;
	w2.AnchorPoint = HALF;
	w2.BorderSizePixel = 0;
	w2.Image = flip and LEFT or RIGHT;
	w2.AnchorPoint = HALF;
	w2.Size = UDim2.new(0, math.abs(unit:Dot(ac)), 0, height);
	w2.Position = UDim2.fromOffset(m2.X, m2.Y);
	w2.Rotation = theta;
	
	return w1, w2;
end

-- Class


local PolyBool = {}

function operate(poly1: Polygon, poly2: Polygon, shapeProcessor: (combineData: CombineData) -> Shape): Polygon
	local seg1 = PolyBool.segments(poly1)
	local seg2 = PolyBool.segments(poly2)
	local comb = PolyBool.combine(seg1, seg2)
	local seg3 = shapeProcessor(comb)
	return PolyBool.polygon(seg3)
end

-- getter/setter for epsilon
function PolyBool.setEpsilon(v: number?): number
	return EpsilonHandler.set(v)
end

-- core API
function PolyBool.segments(poly: Polygon): Shape
	local i = Intersecter(true, EpsilonHandler)
	for _, reg in next, poly.regions do
		i.addRegion(reg)
	end
	return {
		segments = i.selfCalculate(poly.inverted),
		inverted = poly.inverted
	}
end
function PolyBool.combine(segments1: Shape, segments2: Shape): CombineData
	local i3 = Intersecter(false, EpsilonHandler)
	return {
		combined = i3.calculate(
			segments1.segments, segments1.inverted,
			segments2.segments, segments2.inverted
		),
		inverted1 = segments1.inverted,
		inverted2 = segments2.inverted
	}
end
function PolyBool.selectUnion(combined: CombineData): Shape
	return {
		segments = SegmentSelector.union(combined.combined),
		inverted = combined.inverted1 or combined.inverted2
	}
end
function PolyBool.selectIntersect(combined: CombineData)
	return {
		segments = SegmentSelector.intersect(combined.combined),
		inverted = combined.inverted1 and combined.inverted2
	}
end
function PolyBool.selectDifference(combined: CombineData)
	return {
		segments = SegmentSelector.difference(combined.combined),
		inverted = combined.inverted1 and not combined.inverted2
	}
end
function PolyBool.selectDifferenceRev(combined: CombineData): Shape
	return {
		segments = SegmentSelector.differenceRev(combined.combined),
		inverted = not combined.inverted1 and combined.inverted2
	}
end
function PolyBool.selectXor(combined: CombineData): Shape
	return {
		segments = SegmentSelector.xor(combined.combined),
		inverted = combined.inverted1 ~= combined.inverted2
	}
end
function PolyBool.polygon(segments: Shape): Polygon
	return {
		regions = SegmentChainer(segments.segments, EpsilonHandler),
		inverted = segments.inverted
	}
end

-- helper functions for common operations
function PolyBool.union(poly1: Polygon, poly2: Polygon): Polygon
	return operate(poly1, poly2, PolyBool.selectUnion)
end
function PolyBool.intersect(poly1: Polygon, poly2: Polygon): Polygon
	return operate(poly1, poly2, PolyBool.selectIntersect)
end
function PolyBool.difference(poly1: Polygon, poly2: Polygon): Polygon
	return operate(poly1, poly2, PolyBool.selectDifference)
end
function PolyBool.differenceRev(poly1: Polygon, poly2: Polygon): Polygon
	return operate(poly1, poly2, PolyBool.selectDifferenceRev)
end
function PolyBool.xor(poly1: Polygon, poly2: Polygon): Polygon
	return operate(poly1, poly2, PolyBool.selectXor)
end
function PolyBool.copy(poly: Polygon): Polygon
	local regions = {}
	for i, region in ipairs(poly.regions) do
		local regCopy = {}
		for j, point in ipairs(region) do
			regCopy[j] = table.clone(point)
		end
		regions[i] = region
	end
	return {
		regions = regions,
		inverted = poly.inverted
	}
end

function PolyBool.new(perimeter: {[number]: Vector2}): Polygon
	local out = {
		regions = {},
		inverted = false,
	}
	local region = {}
	for i, v2 in ipairs(perimeter) do
		region[i] = {v2.X, v2.Y}
	end
	table.insert(out.regions, region)
	return out
end

function PolyBool.getIfEmpty(polygon: Polygon): boolean
	return #polygon.regions <= 0
end

function PolyBool.draw(polygon: Polygon ,color: Color3, transparency: number): ScreenGui
	local screenGui = Instance.new("ScreenGui")

	for i, region in ipairs(polygon.regions) do
		local perimeter: {[number]: Vector2} = {}
		for j, point in ipairs(region) do
			perimeter[j] = Vector2.new(point[1], point[2])
		end
		for i, tri in ipairs(GeometryUtil.triangulate2D(perimeter, {})) do
			local w1, w2 = drawTriangle(tri[1], tri[2], tri[3])
			w1.ImageColor3 = color
			w2.ImageColor3 = color
			w1.ImageTransparency = transparency
			w2.ImageTransparency = transparency
			w1.Parent = screenGui
			w2.Parent = screenGui
		end
	end

	return screenGui
end

return PolyBool