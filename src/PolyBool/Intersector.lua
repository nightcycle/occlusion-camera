--!strict

-- (c) Copyright 2016, Sean Connelly (@voidqk), http:--syntheti.cc
-- MIT License
-- Project Home: https:--github.com/voidqk/polybooljs
-- Converted to Lua by EgoMoose

--
-- this is the core work-horse
--

-- Services
-- Packages
-- Modules
local Types = require(script.Parent:WaitForChild("Types"))
local LinkedList = require(script.Parent:WaitForChild("LinkedList"))
local Epsilon = require(script.Parent:WaitForChild("Epsilon"))

-- Types
type BuildLog = Types.BuildLog
type EpsilonHandler = Epsilon.EpsilonHandler
type Segment = Types.Segment
type Transition = LinkedList.Transition
type Node = Types.Node
type NodeContent = Types.NodeContent
type Point = Types.Point
type PolygonRegion = Types.PolygonRegion
type Polygon = Types.Polygon
export type IntersectionHandler = {
	addRegion: (region: PolygonRegion) -> (),
	calculate: (segments1: {[number]: Segment}, 
	inverted1: boolean, 
	segments2: {[number]: Segment}, 
	inverted2: boolean) -> {[number]: Segment},
	selfCalculate: (inverted: boolean) -> {[number]: Segment}
}
-- Constants
-- Variables
-- References
-- Private Functions
-- Class

local function Intersecter(
	selfIntersection: boolean, 
	eps: EpsilonHandler, 
	buildLog: BuildLog?
): IntersectionHandler
	-- selfIntersection is true/false depending on the phase of the overall algorithm

	--
	-- segment creation
	--

	local function segmentNew(start: Point, finish: Point): Segment
		return {
			id = buildLog and buildLog.segmentId() or -1,
			start = start,
			finish = finish,
			myFill = {
				above = nil, -- is there fill above us?
				below = nil  -- is there fill below us?
			},
			otherFill = nil
		} :: Segment
	end

	local function segmentCopy(start: Point, finish: Point, seg: Segment): Segment
		return {
			id = buildLog and buildLog.segmentId() or -1,
			start = start,
			finish = finish,
			myFill = {
				above = seg.myFill.above,
				below = seg.myFill.below
			},
			otherFill = nil
		}
	end

	--
	-- event logic
	--

	local event_root = LinkedList.create()

	local function eventCompare(p1_isStart: boolean, p1_1: Point, p1_2: Point, p2_isStart: boolean, p2_1: Point, p2_2: Point): number
		-- compare the selected points first
		local comp = eps.pointsCompare(p1_1, p2_1)
		if (comp ~= 0) then
			return comp
		end
		-- the selected points are the same

		if (eps.pointsSame(p1_2, p2_2)) then -- if the non-selected points are the same too...
			return 0 -- then the segments are equal
		end

		if (p1_isStart ~= p2_isStart) then -- if one is a start and the other isn't...
			return if p1_isStart then 1 else -1 -- favor the one that isn't the start
		end

		-- otherwise, we'll have to calculate which one is below the other manually
		return (if eps.pointAboveOrOnLine(
				p1_2,
				(if p2_isStart then p2_1 else p2_2), -- order matters
				(if p2_isStart then p2_2 else p2_1)
			) then 1 else -1
		)
	end

	local function eventAdd(ev: Node, other_pt: Point): ()
		event_root.insertBefore(ev, function(here: Node): boolean
			-- should ev be inserted before here?
			local other = assert(here.other)
			local comp = eventCompare(
				ev.isStart, ev.pt, other_pt,
				here.isStart, here.pt, other.pt
			)
			return comp < 0
		end)
	end

	local function eventAddSegmentStart(seg: Segment, primary: boolean): Node
		local ev_start = LinkedList.node({
			isStart = true,
			pt = seg.start,
			seg = seg,
			primary = primary,
			other = nil,
			status = nil
		})
		eventAdd(ev_start, seg.finish)
		return ev_start
	end

	local function eventAddSegmentEnd(ev_start: Node, seg: Segment, primary: boolean)
		local ev_end: Node = LinkedList.node({
			isStart = false,
			pt = seg.finish,
			seg = seg,
			primary = primary,
			other = ev_start,
			status = nil
		} :: any)
		ev_start.other = ev_end
		eventAdd(ev_end, ev_start.pt)
	end

	local function eventAddSegment(seg: Segment, primary: boolean)
		local ev_start = eventAddSegmentStart(seg, primary)
		eventAddSegmentEnd(ev_start, seg, primary)
		return ev_start
	end

	local function eventUpdateEnd(ev: Node, finish: Point)
		-- slides an finish backwards
		--   (start)------------(finish)    to:
		--   (start)---(finish)

		if (buildLog) then
			buildLog.segmentChop(ev.seg, finish)
		end

		local other = ev.other
		assert(other)
		other.remove()
		ev.seg.finish = finish
		other.pt = finish
		eventAdd(other, ev.pt)
	end

	local function eventDivide(ev: Node, pt: Point): Node
		local ns = segmentCopy(pt, ev.seg.finish, ev.seg)
		eventUpdateEnd(ev, pt)
		return eventAddSegment(ns, ev.primary)
	end

	local function calculate(primaryPolyInverted: boolean, secondaryPolyInverted: boolean): {[number]: Segment}
		-- if selfIntersection is true then there is no secondary polygon, so that isn't used

		--
		-- status logic
		--

		local status_root = LinkedList.create()

		local function statusCompare(ev1: Node, ev2: Node): number
			local a1 = ev1.seg.start
			local a2 = ev1.seg.finish
			local b1 = ev2.seg.start
			local b2 = ev2.seg.finish

			if (eps.pointsCollinear(a1, b1, b2)) then
				if (eps.pointsCollinear(a2, b1, b2)) then
					return 1;--eventCompare(true, a1, a2, true, b1, b2);
				end
				return if eps.pointAboveOrOnLine(a2, b1, b2) then 1 else -1
			end
			return if eps.pointAboveOrOnLine(a1, b1, b2) then 1 else -1
		end

		local function statusFindSurrounding(ev): Transition
			return status_root.findTransition(function(here: Node): boolean
				local ev2 = here.ev
				assert(ev2)
				local comp = statusCompare(ev, ev2)
				return comp > 0
			end)
		end

		local function checkIntersection(ev1: Node, ev2: Node): Node?
			-- returns the segment equal to ev1, or false if nothing equal

			local seg1 = ev1.seg
			local seg2 = ev2.seg
			local a1 = seg1.start
			local a2 = seg1.finish
			local b1 = seg2.start
			local b2 = seg2.finish

			if (buildLog) then
				buildLog.checkIntersection(seg1, seg2)
			end

			local i = eps.linesIntersect(a1, a2, b1, b2)

			if (i == nil) then
				-- segments are parallel or coincident

				-- if points aren't collinear, then the segments are parallel, so no intersections
				if (not eps.pointsCollinear(a1, a2, b1)) then
					return nil
				end
				-- otherwise, segments are on top of each other somehow (aka coincident)

				if (eps.pointsSame(a1, b2) or eps.pointsSame(a2, b1)) then
					return nil -- segments touch at endpoints... no intersection
				end

				local a1_equ_b1 = eps.pointsSame(a1, b1)
				local a2_equ_b2 = eps.pointsSame(a2, b2)

				if (a1_equ_b1 and a2_equ_b2) then
					return ev2 -- segments are exactly equal
				end

				local a1_between = not a1_equ_b1 and eps.pointBetween(a1, b1, b2)
				local a2_between = not a2_equ_b2 and eps.pointBetween(a2, b1, b2)

				-- handy for debugging:
				-- buildLog.log({
				--	a1_equ_b1: a1_equ_b1,
				--	a2_equ_b2: a2_equ_b2,
				--	a1_between: a1_between,
				--	a2_between: a2_between
				-- });

				if (a1_equ_b1) then
					if (a2_between) then
						--  (a1)---(a2)
						--  (b1)----------(b2)
						eventDivide(ev2, a2)
					else
						--  (a1)----------(a2)
						--  (b1)---(b2)
						eventDivide(ev1, b2)
					end
					return ev2
				elseif (a1_between) then
					if (not a2_equ_b2) then
						-- make a2 equal to b2
						if (a2_between) then
							--         (a1)---(a2)
							--  (b1)-----------------(b2)
							eventDivide(ev2, a2)
						else
							--         (a1)----------(a2)
							--  (b1)----------(b2)
							eventDivide(ev1, b2)
						end
					end

					--         (a1)---(a2)
					--  (b1)----------(b2)
					eventDivide(ev2, a1)
				end
			else
				-- otherwise, lines intersect at i.pt, which may or may not be between the endpoints
				
				-- is A divided between its endpoints? (exclusive)
				if (i.alongA == 0) then
					if (i.alongB == -1) then -- yes, at exactly b1
						eventDivide(ev1, b1)
					elseif (i.alongB == 0) then -- yes, somewhere between B's endpoints
						eventDivide(ev1, i.pt)
					elseif (i.alongB == 1) then -- yes, at exactly b2
						eventDivide(ev1, b2)
					end
				end

				-- is B divided between its endpoints? (exclusive)
				if (i.alongB == 0) then
					if (i.alongA == -1) then -- yes, at exactly a1
						eventDivide(ev2, a1)
					elseif (i.alongA == 0) then -- yes, somewhere between A's endpoints (exclusive)
						eventDivide(ev2, i.pt)
					elseif (i.alongA == 1) then -- yes, at exactly a2
						eventDivide(ev2, a2)
					end
				end
			end
			return nil
		end

		--
		-- main event loop
		--
		local segments = {}
		while (not event_root.isEmpty()) do
			local ev = event_root.getHead()
			assert(ev)
			if (buildLog) then
				buildLog.vert(ev.pt[1])
			end

			if (ev.isStart) then

				if (buildLog) then
					buildLog.segmentNew(ev.seg, ev.primary)
				end

				local surrounding = statusFindSurrounding(ev)
				local above = if surrounding.before then surrounding.before.ev else nil
				local below = if surrounding.after then surrounding.after.ev else nil

				if (buildLog) then
					buildLog.tempStatus(
						ev.seg,
						if above then above.seg else nil,
						if below then below.seg else nil
					)
				end

				local function checkBothIntersections(): Node?
					if (above) then
						local eve = checkIntersection(ev, above)
						if (eve) then
							return eve
						end
					end
					if (below) then
						return checkIntersection(ev, below)
					end
					return nil
				end

				local eve = checkBothIntersections()
				if (eve) then
					-- ev and eve are equal
					-- we'll keep eve and throw away ev

					-- merge ev.seg's fill information into eve.seg

					if (selfIntersection) then
						local toggle -- are we a toggling edge?
						if (ev.seg.myFill.below == nil) then
							toggle = true
						else
							toggle = ev.seg.myFill.above ~= ev.seg.myFill.below
						end

						-- merge two segments that belong to the same polygon
						-- think of this as sandwiching two segments together, where `eve.seg` is
						-- the bottom -- this will cause the above fill flag to toggle
						if (toggle) then
							eve.seg.myFill.above = not eve.seg.myFill.above
						end
					else
						-- merge two segments that belong to different polygons
						-- each segment has distinct knowledge, so no special logic is needed
						-- note that this can only happen once per segment in this phase, because we
						-- are guaranteed that all self-intersections are gone
						eve.seg.otherFill = ev.seg.myFill
					end

					if (buildLog) then
						buildLog.segmentUpdate(eve.seg)
					end

					local other = ev.other
					assert(other)
					other.remove()
					ev.remove()
				end

				if (event_root.getHead() ~= ev) then
					-- something was inserted before us in the event queue, so loop back around and
					-- process it before continuing
					if (buildLog) then
						buildLog.rewind(ev.seg)
					end
					continue;
				end

				--
				-- calculate fill flags
				--
				if (selfIntersection) then
					local toggle -- are we a toggling edge?
					if (ev.seg.myFill.below == nil) then -- if we are a new segment...
						toggle = true -- then we toggle
					else -- we are a segment that has previous knowledge from a division
						toggle = ev.seg.myFill.above ~= ev.seg.myFill.below -- calculate toggle
					end

					-- next, calculate whether we are filled below us
					if (not below) then -- if nothing is below us...
						-- we are filled below us if the polygon is inverted
						ev.seg.myFill.below = primaryPolyInverted
					else
						-- otherwise, we know the answer -- it's the same if whatever is below
						-- us is filled above it
						ev.seg.myFill.below = below.seg.myFill.above
					end

					-- since now we know if we're filled below us, we can calculate whether
					-- we're filled above us by applying toggle to whatever is below us
					if (toggle) then
						ev.seg.myFill.above = not ev.seg.myFill.below;
					else
						ev.seg.myFill.above = ev.seg.myFill.below;
					end
				else
					-- now we fill in any missing transition information, since we are all-knowing
					-- at this point

					if (ev.seg.otherFill == nil) then
						-- if we don't have other information, then we need to figure out if we're
						-- inside the other polygon
						local inside: boolean?
						if (not below) then
							-- if nothing is below us, then we're inside if the other polygon is
							-- inverted
							inside = if ev.primary then secondaryPolyInverted else primaryPolyInverted
						else -- otherwise, something is below us
							-- so copy the below segment's other polygon's above
							if (ev.primary == below.primary) then
								inside = if below.seg.otherFill then below.seg.otherFill.above else nil
							else
								inside = below.seg.myFill.above
							end
						end
						ev.seg.otherFill = {
							above = inside,
							below = inside
						}
					end
				end

				if (buildLog) then
					buildLog.status(
						ev.seg,
						if above then above.seg else nil,
						if below then below.seg else nil
					)
				end

				-- insert the status and remember it for later removal
				local other = ev.other
				assert(other)
				other.status = surrounding.insert(LinkedList.node({ ev = ev } :: any))
			else
				local st = ev.status

				if (st == nil) then
					error('PolyBool: Zero-length segment detected; your epsilon is probably too small or too large')
				end
				assert(st)

				-- removing the status will create two new adjacent edges, so we'll need to check
				-- for those
				if (status_root.exists(st.prev) and status_root.exists(st.next)) then
					local p = st.prev
					assert(p)
					local n = st.next
					assert(n)
					local pe = p.ev
					assert(pe)
					local ne = n.ev
					assert(ne)
					checkIntersection(pe, ne)
				end

				if (buildLog) then
					local stev = st.ev
					assert(stev)
					buildLog.statusRemove(stev.seg)
				end

				-- remove the status
				st.remove()

				-- if we've reached this point, we've calculated everything there is to know, so
				-- save the segment for reporting
				if (not ev.primary) then
					-- make sure `seg.myFill` actually points to the primary polygon though
					local s = ev.seg.myFill
					local other = ev.seg.otherFill
					assert(other)
					ev.seg.myFill = other
					ev.seg.otherFill = s
				end
				table.insert(segments, ev.seg)
			end

			-- remove the event and continue
			local head = event_root.getHead()
			assert(head)
			head.remove()
		end

		if (buildLog) then
			buildLog.done()
		end

		return segments
	end

	-- return the appropriate API depending on what we're doing
	if (not selfIntersection) then
		-- performing combination of polygons, so only deal with already-processed segments
		return {
			calculate = function(
				segments1: {[number]: Segment}, 
				inverted1: boolean, 
				segments2: {[number]: Segment}, 
				inverted2: boolean
			): {[number]: Segment}
				-- segmentsX come from the self-intersection API, or this API
				-- invertedX is whether we treat that list of segments as an inverted polygon or not
				-- returns segments that can be used for further operations
				for _, seg in next, segments1 do
					eventAddSegment(segmentCopy(seg.start, seg.finish, seg), true)
				end
				for _, seg in next, segments2 do
					eventAddSegment(segmentCopy(seg.start, seg.finish, seg), false)
				end
				return calculate(inverted1, inverted2)
			end,
			addRegion = function() end,
			selfCalculate = function() return {} end,
		}
	end

	-- otherwise, performing self-intersection, so deal with regions
	return {
		addRegion = function(region: PolygonRegion): ()
			-- regions are a list of points:
			--  [ [0, 0], [100, 0], [50, 100] ]
			-- you can add multiple regions before running calculate
			local pt1
			local pt2 = region[#region]
			for i = 1, #region do
				pt1 = pt2
				pt2 = region[i]

				local forward = eps.pointsCompare(pt1, pt2)
				if (forward == 0) then -- points are equal, so we have a zero-length segment
					continue -- just skip it
				end

				eventAddSegment(
					segmentNew(
						if forward < 0 then pt1 else pt2,
						if forward < 0 then pt2 else pt1
					),
					true
				)
			end
		end,
		calculate = function()
			return {}
		end,
		selfCalculate = function(inverted: boolean): {[number]: Segment}
			-- is the polygon inverted?
			-- returns segments
			return calculate(inverted, false);
		end
	}
end

return Intersecter