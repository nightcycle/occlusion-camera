--!strict
-- Services
-- Packages
-- Modules
local Epsilon = require(script.Parent:WaitForChild("Epsilon"))
local Types = require(script.Parent:WaitForChild("Types"))
-- Types
type EpsilonHandler = Epsilon.EpsilonHandler
type Segment = Types.Segment
type BuildLog = Types.BuildLog
type PolygonRegion = Types.PolygonRegion
type MatchData = {
	index: number,
	matches_head: boolean,
	matches_pt1: boolean
}
-- Constants
-- Variables
-- References
-- Private Functions
-- Class

-- (c) Copyright 2016, Sean Connelly (@voidqk), http:--syntheti.cc
-- MIT License
-- Project Home: https:--github.com/voidqk/polybooljs
-- Converted to Lua by EgoMoose

--
-- converts a list of segments into a list of regions, while also removing unnecessary verticies
--

local function reverseArray<T>(t: {[number]: T})
	local n = #t
	local i = 1
	while i < n do
		t[i],t[n] = t[n],t[i]
		i = i + 1
		n = n - 1
	end
end

local function concatArray<T>(arr1: {[number]: T}, arr2: {[number]: T}): {[number]: T}
	local c, arr = 0, {}
	for i = 1, #arr1 do c = c + 1; arr[c] = arr1[i] end
	for i = 1, #arr2 do c = c + 1; arr[c] = arr2[i] end
	return arr
end

local function SegmentChainer(segments: {[number]: Segment}, eps: EpsilonHandler, buildLog: BuildLog?): {[number]: PolygonRegion}
	local chains = {}
	local regions = {}

	for _, seg in next, segments do
		local pt1 = seg.start
		local pt2 = seg.finish
		if (eps.pointsSame(pt1, pt2)) then
			warn('PolyBool: Warning: Zero-length segment detected; your epsilon is probably too small or too large');
			return {}
		end

		if (buildLog) then
			buildLog.chainStart(seg)
		end

		-- search for two chains that this segment matches
		local first_match: MatchData = {
			index = 1, -- zero?
			matches_head = false,
			matches_pt1 = false
		}
		local second_match: MatchData = {
			index = 1, -- zero?
			matches_head = false,
			matches_pt1 = false
		}
		local next_match: MatchData? = first_match
		local function setMatch(index: number, matches_head: boolean, matches_pt1: boolean): boolean
			-- return true if we've matched twice
			assert(next_match)
			next_match.index = index
			next_match.matches_head = matches_head
			next_match.matches_pt1 = matches_pt1
			if (next_match == first_match) then
				next_match = second_match
				return false
			end
			next_match = nil
			return true -- we've matched twice, we're done here
		end
		for i = 1, #chains do
			local chain = chains[i];
			local head  = chain[1];
			-- local head2 = chain[2];
			local tail  = chain[#chain];
			-- local tail2 = chain[#chain - 1];
			if (eps.pointsSame(head, pt1)) then
				if (setMatch(i, true, true)) then
					break
				end
			elseif (eps.pointsSame(head, pt2)) then
				if (setMatch(i, true, false)) then
					break
				end
			elseif (eps.pointsSame(tail, pt1)) then
				if (setMatch(i, false, true)) then
					break
				end
			elseif (eps.pointsSame(tail, pt2)) then
				if (setMatch(i, false, false)) then
					break
				end
			end
		end

		if (next_match == first_match) then
			-- we didn't match anything, so create a new chain
			table.insert(chains, {pt1, pt2})
			if (buildLog) then
				buildLog.chainNew(pt1, pt2)
			end
			continue
		end

		if (next_match == second_match) then
			-- we matched a single chain

			if (buildLog) then
				buildLog.chainMatch(first_match.index)
			end

			-- add the other point to the apporpriate finish, and check to see if we've closed the
			-- chain into a loop

			local index = first_match.index
			local pt = if first_match.matches_pt1 then pt2 else pt1 -- if we matched pt1, then we add pt2, etc
			local addToHead = first_match.matches_head -- if we matched at head, then add to the head
			
			local chain = chains[index]
			local grow  = if addToHead then chain[1] else chain[#chain]
			local grow2 = if addToHead then chain[2] else chain[#chain - 1]
			local oppo  = if addToHead then chain[#chain] else chain[1]
			local oppo2 = if addToHead then chain[#chain - 1] else chain[2]
			
			if (eps.pointsCollinear(grow2, grow, pt)) then
				-- grow isn't needed because it's directly between grow2 and pt:
				-- grow2 ---grow---> pt
				if (addToHead) then
					if (buildLog) then
						buildLog.chainRemoveHead(first_match.index, pt)
					end
					table.remove(chain, 1)
				else
					if (buildLog) then
						buildLog.chainRemoveTail(first_match.index, pt)
					end
					table.remove(chain)
				end
				grow = grow2 -- old grow is gone... new grow is what grow2 was
			end
			
			if (eps.pointsSame(oppo, pt)) then
				-- we're closing the loop, so remove chain from chains
				table.remove(chains, index)

				if (eps.pointsCollinear(oppo2, oppo, grow)) then
					-- oppo isn't needed because it's directly between oppo2 and grow:
					-- oppo2 ---oppo--->grow
					if (addToHead) then
						if (buildLog) then
							buildLog.chainRemoveTail(first_match.index, grow)
						end
						table.remove(chain)
					else
						if (buildLog) then
							buildLog.chainRemoveHead(first_match.index, grow)
						end
						table.remove(chain, 1)
					end
				end

				if (buildLog) then
					buildLog.chainClose(first_match.index)
				end
				
				-- we have a closed chain!
				table.insert(regions, chain)
				continue
			end

			-- not closing a loop, so just add it to the apporpriate side
			if (addToHead) then
				if (buildLog) then
					buildLog.chainAddHead(first_match.index, pt)
				end
				table.insert(chain, 1, pt)
			else
				if (buildLog) then
					buildLog.chainAddTail(first_match.index, pt)
				end
				table.insert(chain, pt)
			end
			continue
		end

		-- otherwise, we matched two chains, so we need to combine those chains together

		local function reverseChain(index)
			if (buildLog) then
				buildLog.chainReverse(index)
			end
			reverseArray(chains[index]) -- gee, that's easy
		end

		local function appendChain(index1: number, index2: number)
			-- index1 gets index2 appended to it, and index2 is removed
			local chain1 = chains[index1]
			local chain2 = chains[index2]
			local tail  = chain1[#chain1]
			local tail2 = chain1[#chain1 - 1]
			local head  = chain2[1]
			local head2 = chain2[2]

			if (eps.pointsCollinear(tail2, tail, head)) then
				-- tail isn't needed because it's directly between tail2 and head
				-- tail2 ---tail---> head
				if (buildLog) then
					buildLog.chainRemoveTail(index1, tail)
				end
				table.remove(chain1)
				tail = tail2 -- old tail is gone... new tail is what tail2 was
			end

			if (eps.pointsCollinear(tail, head, head2)) then
				-- head isn't needed because it's directly between tail and head2
				-- tail ---head---> head2
				if (buildLog) then
					buildLog.chainRemoveHead(index2, head)
				end
				table.remove(chain2, 1)
			end

			if (buildLog) then
				buildLog.chainJoin(index1, index2)
			end
			chains[index1] = concatArray(chain1, chain2)
			table.remove(chains, index2)
		end

		local F = first_match.index
		local S = second_match.index

		if (buildLog) then
			buildLog.chainConnect(F, S)
		end

		local reverseF = #chains[F] < #chains[S] -- reverse the shorter chain, if needed
		if (first_match.matches_head) then
			if (second_match.matches_head) then
				if (reverseF) then
					-- <<<< F <<<< --- >>>> S >>>>
					reverseChain(F)
					-- >>>> F >>>> --- >>>> S >>>>
					appendChain(F, S)
				else
					-- <<<< F <<<< --- >>>> S >>>>
					reverseChain(S);
					-- <<<< F <<<< --- <<<< S <<<<   logically same as:
					-- >>>> S >>>> --- >>>> F >>>>
					appendChain(S, F);
				end
			else
				-- <<<< F <<<< --- <<<< S <<<<   logically same as:
				-- >>>> S >>>> --- >>>> F >>>>
				appendChain(S, F);
			end
		else
			if (second_match.matches_head) then
				-- >>>> F >>>> --- >>>> S >>>>
				appendChain(F, S)
			else
				if (reverseF) then
					-- >>>> F >>>> --- <<<< S <<<<
					reverseChain(F)
					-- <<<< F <<<< --- <<<< S <<<<   logically same as:
					-- >>>> S >>>> --- >>>> F >>>>
					appendChain(S, F)
				else
					-- >>>> F >>>> --- <<<< S <<<<
					reverseChain(S)
					-- >>>> F >>>> --- >>>> S >>>>
					appendChain(F, S)
				end
			end
		end
	end

	return regions
end

return SegmentChainer