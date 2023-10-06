--!strict
--[[
 * @copyright 2016 Sean Connelly (@voidqk), http://syntheti.cc
 * @license MIT
 * @preserve Project Home: https://github.com/voidqk/polybooljs

   Converted to Lua by EgoMoose
   Edits made by Nightcycle
--]]
-- Services
-- Packages
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


return PolyBool