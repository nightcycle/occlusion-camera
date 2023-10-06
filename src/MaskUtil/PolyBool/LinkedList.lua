--!strict
-- (c) Copyright 2016, Sean Connelly (@voidqk), http:--syntheti.cc
-- MIT License
-- Project Home: https:--github.com/voidqk/polybooljs
-- Converted to Lua by EgoMoose

--
-- simple linked list implementation that allows you to traverse down nodes and save positions
--

-- Services
-- Packages
-- Modules
local Types = require(script.Parent:WaitForChild("Types"))
-- Types
type Node = Types.Node
type RootNode = Types.RootNode
type NodeContent = Types.NodeContent
export type CheckMethod = (node: Node) -> boolean
export type Transition = {
	before: Node?,
	after: Node?,
	insert:  (node: Node) -> Node
}
export type LinkedList = {
	root: RootNode,
	exists: (node: Node?) -> boolean,
	isEmpty: () -> boolean,
	getHead: () -> Node?,
	insertBefore: (node: Node, check: CheckMethod) -> (),
	findTransition: (checkMethod: CheckMethod) -> Transition,
}
-- Constants
-- Variables
-- References
-- Private Functions
-- Class

local LinkedList = {
	create = function(): LinkedList
		local list: LinkedList = {} :: any;
		list.root = { 
			root = true,
			next = nil,
			remove = function()

			end,
		}
		function list.exists(node: Node?): boolean
			if (node == nil or node == list.root) then
				return false
			end
			return true
		end

		function list.isEmpty(): boolean
			return list.root.next == nil
		end
		function list.getHead(): Node?
			return list.root.next
		end
		function list.insertBefore(node: Node, check: CheckMethod): ()
			local last: Node = list.root :: any
			local here = list.root.next
			while (here ~= nil) do
				assert(here)
				if (check(here)) then
					node.prev = here.prev
					node.next = here
					if here.prev then
						here.prev.next = node
					end
					here.prev = node
					return
				end
				last = here
				here = here.next
			end
			last.next = node
			node.prev = last
			node.next = nil
		end
		function list.findTransition(check: CheckMethod): Transition
			local root = list.root :: Node
			local prev = root
			local here: Node? = list.root.next
			while (here ~= nil) do
				if (check(here)) then
					break
				end
				prev = here
				here = here.next
			end
			return {
				before = if prev == root then nil else prev,
				after = here,
				insert = function(node: Node): Node
					node.prev = prev
					node.next = here
					prev.next = node
					if (here ~= nil) then
						here.prev = node
					end
					return node
				end
			}
		end
		return list
	end,
	node = function(data: NodeContent): Node
		local out: Node = data :: any
		out.prev = nil
		out.next = nil
		out.remove = function()
			if out.prev then
				out.prev.next = out.next
			end
			if (out.next) then
				out.next.prev = out.prev
			end
			out.prev = nil
			out.next = nil
		end
		return out
	end
}

return LinkedList