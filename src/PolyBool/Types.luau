--!strict
-- Services
-- Packages
-- Modules
-- Types
export type PolygonRegion = {[number]: {[number]: number}}
export type Polygon = {
	regions: {[number]: PolygonRegion},
	inverted: boolean
}
export type Shape = {
	segments: {[number]: Segment},
	inverted: boolean
}
export type BuildLog = {
	segmentId: () -> number,
	checkIntersection: (seg1: Segment, seg2: Segment) -> boolean,
	selected: (segments: {[number]: Segment}) -> (),
	segmentNew: (Segment, boolean) -> unknown,
	segmentChop: (Segment, Point) -> unknown,
	segmentUpdate: (Segment) -> unknown,
	chainMatch: (index: number) -> unknown,
	chainClose: (index: number) -> unknown,
	chainAddHead: (index: number, pt: Point) -> unknown,
	chainAddTail: (index: number, pt: Point) -> unknown,
	chainConnect: (f: number, s: number) -> unknown,
	chainJoin: (f: number, s: number) -> unknown,
	chainReverse: (index: number) -> unknown,
	chainRemoveTail: (index: number, pt: Point) -> unknown,
	chainRemoveHead: (index: number, pt: Point) -> unknown,
	chainNew: (p1: Point, p2: Point) -> unknown,
	rewind: (Segment) -> unknown,
	status: (Segment, Segment?, Segment?) -> unknown,
	chainStart: (Segment) -> unknown,
	statusRemove: (Segment) -> unknown,
	vert: (number) -> unknown,
	done: () -> unknown,
	tempStatus: (
		Segment,
		Segment?,
		Segment?
	) -> Node,
}
export type Point = {[number]: number}
export type Selection = {[number]: number}
export type CombineData = {
	combined: {[number]: Segment},
	inverted1: boolean,
	inverted2: boolean
}
export type Fill = {
	above: boolean?,
	below: boolean?
}
export type NodeContent = {
	isStart: boolean,
	pt: Point,
	ev: Node?,
	seg: Segment,
	primary: boolean,
	other: Node?,
	status: Node?,
}
export type RootNode = {
	prev: Node?,
	next: Node?,
	root: boolean,
	remove: () -> (),
}
export type Node = RootNode & NodeContent

export type Segment = {
	id: number,
	start: Point,
	finish: Point,
	myFill: Fill,
	otherFill: Fill?
}
-- Constants
-- Variables
-- References
-- Private Functions
-- Class

return {}