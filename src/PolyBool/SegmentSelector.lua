--!strict

-- (c) Copyright 2016, Sean Connelly (@voidqk), http:--syntheti.cc
-- MIT License
-- Project Home: https:--github.com/voidqk/polybooljs
-- Converted to Lua by EgoMoose

--
-- filter a list of segments based on boolean operations
--

-- Services
-- Packages
-- Modules
local Types = require(script.Parent:WaitForChild("Types"))
-- Types
type Segment = Types.Segment
type Selection = Types.Selection
type BuildLog = Types.BuildLog
type Shape = Types.Shape
type CombineData = Types.CombineData
export type SelectionProcessor = (segments: {[number]: Segment}, buildLog: BuildLog?) -> {[number]: Segment}
export type SegmentSelector = {
	union: SelectionProcessor,
	intersect: SelectionProcessor,
	difference: SelectionProcessor,
	differenceRev: SelectionProcessor,
	xor: SelectionProcessor
}
-- Constants
-- Variables
-- References
-- Private Functions

local function select(segments: {[number]: Segment}, selection: Selection, buildLog: BuildLog?): {[number]: Segment}
	local result: {[number]: Segment} = {}
	for _, seg in next, segments do
		local index =
			(if seg.myFill.above then 8 else 0) +
			(if seg.myFill.below then 4 else 0) +
			(if (seg.otherFill and seg.otherFill.above) then 2 else 0) +
			(if seg.otherFill and seg.otherFill.below then 1 else 0) + 1
		if (selection[index] ~= 0) then
			-- copy the segment to the results, while also calculating the fill status
			table.insert(result, {
				id = buildLog and buildLog.segmentId() or -1,
				start = seg.start,
				finish = seg.finish,
				myFill = {
					above = selection[index] == 1, -- 1 if filled above
					below = selection[index] == 2  -- 2 if filled below
				},
				otherFill = nil
			})
		end
	end

	if (buildLog) then
		buildLog.selected(result)
	end

	return result
end

-- Class
local SegmentSelector: SegmentSelector = {
	union = function(segments: {[number]: Segment}, buildLog: BuildLog?): {[number]: Segment} -- primary | secondary
		-- above1 below1 above2 below2    Keep?               Value
		--    0      0      0      0   =>   no                  0
		--    0      0      0      1   =>   yes filled below    2
		--    0      0      1      0   =>   yes filled above    1
		--    0      0      1      1   =>   no                  0
		--    0      1      0      0   =>   yes filled below    2
		--    0      1      0      1   =>   yes filled below    2
		--    0      1      1      0   =>   no                  0
		--    0      1      1      1   =>   no                  0
		--    1      0      0      0   =>   yes filled above    1
		--    1      0      0      1   =>   no                  0
		--    1      0      1      0   =>   yes filled above    1
		--    1      0      1      1   =>   no                  0
		--    1      1      0      0   =>   no                  0
		--    1      1      0      1   =>   no                  0
		--    1      1      1      0   =>   no                  0
		--    1      1      1      1   =>   no                  0
		return select(segments, {
			0, 2, 1, 0,
			2, 2, 0, 0,
			1, 0, 1, 0,
			0, 0, 0, 0
		}, buildLog)
	end,
	intersect = function(segments: {[number]: Segment}, buildLog: BuildLog?): {[number]: Segment} -- primary & secondary
		-- above1 below1 above2 below2    Keep?               Value
		--    0      0      0      0   =>   no                  0
		--    0      0      0      1   =>   no                  0
		--    0      0      1      0   =>   no                  0
		--    0      0      1      1   =>   no                  0
		--    0      1      0      0   =>   no                  0
		--    0      1      0      1   =>   yes filled below    2
		--    0      1      1      0   =>   no                  0
		--    0      1      1      1   =>   yes filled below    2
		--    1      0      0      0   =>   no                  0
		--    1      0      0      1   =>   no                  0
		--    1      0      1      0   =>   yes filled above    1
		--    1      0      1      1   =>   yes filled above    1
		--    1      1      0      0   =>   no                  0
		--    1      1      0      1   =>   yes filled below    2
		--    1      1      1      0   =>   yes filled above    1
		--    1      1      1      1   =>   no                  0
		return select(segments, {
			0, 0, 0, 0,
			0, 2, 0, 2,
			0, 0, 1, 1,
			0, 2, 1, 0
		}, buildLog)
	end,
	difference = function(segments: {[number]: Segment}, buildLog: BuildLog?): {[number]: Segment} -- primary - secondary
		-- above1 below1 above2 below2    Keep?               Value
		--    0      0      0      0   =>   no                  0
		--    0      0      0      1   =>   no                  0
		--    0      0      1      0   =>   no                  0
		--    0      0      1      1   =>   no                  0
		--    0      1      0      0   =>   yes filled below    2
		--    0      1      0      1   =>   no                  0
		--    0      1      1      0   =>   yes filled below    2
		--    0      1      1      1   =>   no                  0
		--    1      0      0      0   =>   yes filled above    1
		--    1      0      0      1   =>   yes filled above    1
		--    1      0      1      0   =>   no                  0
		--    1      0      1      1   =>   no                  0
		--    1      1      0      0   =>   no                  0
		--    1      1      0      1   =>   yes filled above    1
		--    1      1      1      0   =>   yes filled below    2
		--    1      1      1      1   =>   no                  0
		return select(segments, {
			0, 0, 0, 0,
			2, 0, 2, 0,
			1, 1, 0, 0,
			0, 1, 2, 0
		}, buildLog)
	end,
	differenceRev = function(segments: {[number]: Segment}, buildLog: BuildLog?): {[number]: Segment} -- secondary - primary
		-- above1 below1 above2 below2    Keep?               Value
		--    0      0      0      0   =>   no                  0
		--    0      0      0      1   =>   yes filled below    2
		--    0      0      1      0   =>   yes filled above    1
		--    0      0      1      1   =>   no                  0
		--    0      1      0      0   =>   no                  0
		--    0      1      0      1   =>   no                  0
		--    0      1      1      0   =>   yes filled above    1
		--    0      1      1      1   =>   yes filled above    1
		--    1      0      0      0   =>   no                  0
		--    1      0      0      1   =>   yes filled below    2
		--    1      0      1      0   =>   no                  0
		--    1      0      1      1   =>   yes filled below    2
		--    1      1      0      0   =>   no                  0
		--    1      1      0      1   =>   no                  0
		--    1      1      1      0   =>   no                  0
		--    1      1      1      1   =>   no                  0
		return select(segments, {
			0, 2, 1, 0,
			0, 0, 1, 1,
			0, 2, 0, 2,
			0, 0, 0, 0
		}, buildLog)
	end,
	xor = function(segments: {[number]: Segment}, buildLog: BuildLog?): {[number]: Segment} -- primary ^ secondary
		-- above1 below1 above2 below2    Keep?               Value
		--    0      0      0      0   =>   no                  0
		--    0      0      0      1   =>   yes filled below    2
		--    0      0      1      0   =>   yes filled above    1
		--    0      0      1      1   =>   no                  0
		--    0      1      0      0   =>   yes filled below    2
		--    0      1      0      1   =>   no                  0
		--    0      1      1      0   =>   no                  0
		--    0      1      1      1   =>   yes filled above    1
		--    1      0      0      0   =>   yes filled above    1
		--    1      0      0      1   =>   no                  0
		--    1      0      1      0   =>   no                  0
		--    1      0      1      1   =>   yes filled below    2
		--    1      1      0      0   =>   no                  0
		--    1      1      0      1   =>   yes filled above    1
		--    1      1      1      0   =>   yes filled below    2
		--    1      1      1      1   =>   no                  0
		return select(segments, {
			0, 2, 1, 0,
			2, 0, 0, 1,
			1, 0, 0, 2,
			0, 1, 2, 0
		}, buildLog)
	end
}

return SegmentSelector