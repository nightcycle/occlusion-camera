--!strict
-- pre-maps all the relevant geometry data for different cube perspectives, hopefully saves time in processing
local _Package = script.Parent
local _Packages = _Package.Parent

-- Services
-- Packages

-- Modules
-- local ShapeUtil = require(_Package:WaitForChild("ShapeUtil"))

-- Types
type CornerId = "XYZ" | "xYZ" | "XYz" | "xYz" | "XyZ" | "xyZ" | "Xyz" | "xyz"
type EdgeId = "YZ" | "Yz" | "yZ" |  "yz" | "XZ" | "xZ" | "Xz" | "xz" | "XY" | "xY" | "Xy" | "xy"
type FaceId = "X" | "x" | "Y" | "y" | "Z" | "z"
type PerspectiveId = CornerId | EdgeId | FaceId

-- Constants
-- local INNER_BOX_DATA: {[PerspectiveId]: {
-- 	MinX: CornerId | EdgeId,
-- 	MaxX: CornerId | EdgeId,
-- 	MinY: CornerId | EdgeId,
-- 	MaxY: CornerId | EdgeId,
-- }} = {
-- 	XYZ = {
-- 		MinX = "Yz",
-- 		MinY = "Yx",
-- 		MaxX = "yx",
-- 		MaxY = "yz",
-- 	},
-- 	XYZ = {
-- 		MinX = "Yz",
-- 		MinY = "Yx",
-- 		MaxX = "yx",
-- 		MaxY = "yz",
-- 	},
-- }

local TRIANGLE_DATA: {[PerspectiveId]: {[number]: {[number]: CornerId}}} = {
	X = {
		{"Xyz", "XYz", "XYZ"},
		{"Xyz", "XyZ", "XYZ"},
	},
	x = {
		{"xyz", "xYz", "xYZ"},
		{"xyz", "xyZ", "xYZ"},
	},
	Z = {
		{"xyZ", "xYZ", "XYZ"},
		{"xyZ", "XyZ", "XYZ"},
	},
	z = {
		{"xyz", "xYz", "XYz"},
		{"xyz", "Xyz", "XYz"},
	},
	Y = {
		{"xYz", "xYZ", "XYZ"},
		{"xYz", "XYz", "XYZ"},
	},
	y = {
		{"xyz", "xyZ", "XyZ"},
		{"xyz", "Xyz", "XyZ"},
	},
	Xy = {
		{"Xyz", "xyz", "xyZ"},
		{"Xyz", "XYz", "XYZ"},
		{"XyZ", "xyZ", "XYZ"},
		{"Xyz", "xyZ", "XYZ"},
	},
	XY = {
		{"XYz", "xYz", "xYZ"},
		{"XYz", "Xyz", "XyZ"},
		{"XYZ", "xYZ", "XyZ"},
		{"XYz", "xYZ", "XyZ"},
	},
	xy = {
		{"xyz", "Xyz", "XyZ"},
		{"xyz", "xYz", "xYZ"},
		{"xyZ", "XyZ", "xYZ"},
		{"xyz", "XyZ", "xYZ"},
	},
	xY = {
		{"xYz", "XYz", "XYZ"},
		{"xYz", "xyz", "xyZ"},
		{"xYZ", "XYZ", "xyZ"},
		{"xYz", "XYZ", "xyZ"},
	},
	Xz = {
		{"Xyz", "xyz", "xYz"},
		{"Xyz", "XyZ", "XYZ"},
		{"XYz", "xYz", "XYZ"},
		{"Xyz", "xYz", "XYZ"},
	},
	XZ = {
		{"XyZ", "xyZ", "xYZ"},
		{"XyZ", "Xyz", "XYz"},
		{"XYZ", "xYZ", "XYz"},
		{"XyZ", "xYZ", "XYz"},
	},
	xz = {
		{"xyz", "Xyz", "XYz"},
		{"xyz", "xyZ", "xYZ"},
		{"xYz", "XYz", "xYZ"},
		{"xyz", "XYz", "xYZ"},
	},
	xZ = {
		{"xyZ", "XyZ", "XYZ"},
		{"xyZ", "xyz", "xYz"},
		{"xYZ", "XYZ", "xYz"},
		{"xyZ", "XYZ", "xYz"},
	},
	Yz = {
		{"xYz", "xyz", "Xyz"},
		{"xYz", "xYZ", "XYZ"},
		{"XYz", "Xyz", "XYZ"},
		{"xYz", "Xyz", "XYZ"},
	},
	yz = {
		{"xyz", "xYz", "XYz"},
		{"xyz", "xyZ", "XyZ"},
		{"Xyz", "XYz", "XyZ"},
		{"xyz", "XYz", "XyZ"},
	},
	YZ = {
		{"xYZ", "xyZ", "XyZ"},
		{"xYZ", "xYz", "XYz"},
		{"XYZ", "XyZ", "XYz"},
		{"xYZ", "XyZ", "XYz"},
	},
	yZ = {
		{"xyZ", "xYZ", "XYZ"},
		{"xyZ", "xyz", "Xyz"},
		{"XyZ", "XYZ", "Xyz"},
		{"xyZ", "XYZ", "Xyz"},
	},
	XYZ = {
		{"xYZ", "XyZ", "XYz"},
		{"xYZ", "xyZ", "XyZ"},
		{"XyZ", "Xyz", "XYz"},
		{"XYz", "xYz", "xYZ"},
	},
	xYZ = {
		{"XYZ", "xyZ", "xYz"},
		{"XYZ", "XyZ", "xyZ"},
		{"xyZ", "xyz", "xYz"},
		{"xYz", "XYz", "XYZ"},
	},
	XyZ = {
		{"xyZ", "XYZ", "Xyz"},
		{"xyZ", "xYZ", "XYZ"},
		{"XYZ", "XYz", "Xyz"},
		{"Xyz", "xyz", "xyZ"},
	},
	xyZ = {
		{"XyZ", "xYZ", "xyz"},
		{"XyZ", "XYZ", "xYZ"},
		{"xYZ", "xYz", "xyz"},
		{"xyz", "Xyz", "XyZ"},
	},
	XYz = {
		{"xYz", "Xyz", "XYZ"},
		{"xYz", "xyz", "Xyz"},
		{"Xyz", "XyZ", "XYZ"},
		{"XYZ", "xYZ", "xYz"},
	},
	xYz = {
		{"XYz", "xyz", "xYZ"},
		{"XYz", "Xyz", "xyz"},
		{"xyz", "xyZ", "xYZ"},
		{"xYZ", "XYZ", "XYz"},
	},
	Xyz = {
		{"xyz", "XYz", "XyZ"},
		{"xyz", "xYz", "XYz"},
		{"XYz", "XYZ", "XyZ"},
		{"XyZ", "xyZ", "xyz"},
	},
	xyz = {
		{"Xyz", "xYz", "xyZ"},
		{"Xyz", "XYz", "xYz"},
		{"xYz", "xYZ", "xyZ"},
		{"xyZ", "XyZ", "Xyz"},
	},
}

local PERIMETER_DATA: {[PerspectiveId]: {[number]: CornerId}} = {
	X = {"Xyz", "XYz", "XYZ", "XyZ"},
	x = {"xyz", "xYz", "xYZ", "xyZ"},
	Y = {"xYz", "XYz", "XYZ", "xYZ"},
	y = {"xyz", "Xyz", "XyZ", "xyZ"},
	Z = {"xyZ", "XyZ", "XYZ", "xYZ"},
	z = {"xyz", "Xyz", "XYz", "xYz"},

	Xy = {"Xyz", "xyz", "xyZ", "XyZ", "XYZ", "XYz"},
	XY = {"XYz", "xYz", "xYZ", "XYZ", "XyZ", "Xyz"},
	xY = {"xYz", "XYz", "XYZ", "xYZ", "xyZ", "xyz"},
	xy = {"xyz", "Xyz", "XyZ", "xyZ", "xYZ", "xYz"},

	Xz = {"Xyz", "xyz", "xYz", "XYz", "XYZ", "XyZ"},
	XZ = {"XyZ", "xyZ", "xYZ", "XYZ", "XYz", "Xyz"},
	xZ = {"xyZ", "XyZ", "XYZ", "xYZ", "xYz", "xyz"},
	xz = {"xyz", "Xyz", "XYz", "xYz", "xYZ", "xyZ"},

	Yz = {"xYz", "xyz", "Xyz", "XYz", "XYZ", "xYZ"},
	YZ = {"xYZ", "xyZ", "XyZ", "XYZ", "XYz", "xYz"},
	yZ = {"xyZ", "xYZ", "XYZ", "XyZ", "Xyz", "xyz"},
	yz = {"xyz", "xYz", "XYz", "Xyz", "XyZ", "xyZ"},

	XYZ = {"xYZ", "xyZ", "XyZ", "Xyz", "XYz", "xYz"},
	XYz = {"xYz", "xyz", "Xyz", "XyZ", "XYZ", "xYZ"},
	XyZ = {"xyZ", "xYZ", "XYZ", "XYz", "Xyz", "xyz"},
	Xyz = {"xyz", "xYz", "XYz", "XYZ", "XyZ", "xyZ"},

	xYZ = {"XYZ", "XyZ", "xyZ", "xyz", "xYz", "XYz"},
	xYz = {"XYz", "Xyz", "xyz", "xyZ", "xYZ", "XYZ"},
	xyZ = {"XyZ", "XYZ", "xYZ", "xYz", "xyz", "Xyz"},
	xyz = {"Xyz", "XYz", "xYz", "xYZ", "xyZ", "XyZ"},
}

local CORNER_OFFSET: {[CornerId]: Vector3} = {
	XYZ = 0.5*(Vector3.fromAxis(Enum.Axis.X) + Vector3.fromAxis(Enum.Axis.Y) + Vector3.fromAxis(Enum.Axis.Z)),
	XYz = 0.5*(Vector3.fromAxis(Enum.Axis.X) + Vector3.fromAxis(Enum.Axis.Y) - Vector3.fromAxis(Enum.Axis.Z)),
	XyZ = 0.5*(Vector3.fromAxis(Enum.Axis.X) - Vector3.fromAxis(Enum.Axis.Y) + Vector3.fromAxis(Enum.Axis.Z)),
	Xyz = 0.5*(Vector3.fromAxis(Enum.Axis.X) - Vector3.fromAxis(Enum.Axis.Y) - Vector3.fromAxis(Enum.Axis.Z)),

	xYZ = 0.5*(-Vector3.fromAxis(Enum.Axis.X) + Vector3.fromAxis(Enum.Axis.Y) + Vector3.fromAxis(Enum.Axis.Z)),
	xYz = 0.5*(-Vector3.fromAxis(Enum.Axis.X) + Vector3.fromAxis(Enum.Axis.Y) - Vector3.fromAxis(Enum.Axis.Z)),
	xyZ = 0.5*(-Vector3.fromAxis(Enum.Axis.X) - Vector3.fromAxis(Enum.Axis.Y) + Vector3.fromAxis(Enum.Axis.Z)),
	xyz = 0.5*(-Vector3.fromAxis(Enum.Axis.X) - Vector3.fromAxis(Enum.Axis.Y) - Vector3.fromAxis(Enum.Axis.Z)),
}

-- Variables
-- References
-- Private Functions
function getCenterId(cf: CFrame, size: Vector3, cameraCF: CFrame): PerspectiveId
	local offset = cf:PointToObjectSpace(cameraCF.Position)
	local x: string, y: string, z: string
	if offset.X < 0 then
		x = "x"
	elseif offset.X >= 0 then
		x = "X"
	end
	if offset.Y < 0 then
		y = "y"
	elseif offset.Y >= 0 then
		y = "Y"
	end
	if offset.Z < 0 then
		z = "z"
	elseif offset.Z >= 0 then
		z = "Z"
	end
	if math.abs(offset.X) <= size.X * 0.5 then
		x = ""
	end
	if math.abs(offset.Y) <= size.Y * 0.5 then
		y = ""
	end
	if math.abs(offset.Z) <= size.Z * 0.5 then
		z = ""
	end
	return `{x}{y}{z}` :: PerspectiveId
end


function getWorldPosition(cf: CFrame, size: Vector3, cornerId: CornerId): Vector3
	local offset = CORNER_OFFSET[cornerId] * size
	return cf:PointToWorldSpace(offset)
end

-- Class
local Util = {}

function Util.getWorldTriangles(cf: CFrame, size: Vector3, cameraCF: CFrame): {[number]: {A: Vector3, B: Vector3, C: Vector3}}
	local triangles: {[number]: {A: Vector3, B: Vector3, C: Vector3}} = {}

	local centerId: PerspectiveId = getCenterId(cf, size, cameraCF)
	if centerId:len() == 0 then return {} end

	local function addTriangle(aId: CornerId, bId: CornerId, cId: CornerId)
		local a = getWorldPosition(cf, size, aId)
		local b = getWorldPosition(cf, size, bId)
		local c = getWorldPosition(cf, size, cId)

		table.insert(triangles, {
			A = a,
			B = b,
			C = c,
		})
	end

	local triangleData = TRIANGLE_DATA[centerId]

	for j, triangle in ipairs(triangleData) do
		addTriangle(
			triangle[1] :: CornerId,
			triangle[2] :: CornerId,
			triangle[3] :: CornerId
		)

	end

	assert(#triangles ~= 0)

	return triangles
end

-- local debugEnabled = false
function Util.toViewportPoint(point: Vector3, cf: CFrame, fov: number, vSize: Vector2, nearPlaneZ: number): (Vector3, boolean, boolean)

	-- print(`point: {point}`)
	-- print(`cf: {cf.Position}`)
	-- print(`wOffset: {point-cf.Position}`)

	-- if debugEnabled then print(`vSize: {vSize}`) end

	-- if debugEnabled then print(`nearPlaneZ: {nearPlaneZ}`) end

	local aspectRatio = vSize.X / vSize.Y
	-- if debugEnabled then print(`aspectRatio: {aspectRatio}`) end

	local halfFieldOfView = math.rad(fov) * 0.5
	-- if debugEnabled then print(`halfFieldOfView: {fov*0.5}`) end

	local offset: Vector3 = cf:PointToObjectSpace(point)
	-- if debugEnabled then print(`offset: {offset}`) end


	local halfNearPlaneHeight = 2 * math.tan(halfFieldOfView) * -nearPlaneZ / 2
	-- if debugEnabled then print(`halfNearPlaneHeight: {halfNearPlaneHeight}`) end

	local halfNearPlaneWidth = halfNearPlaneHeight * aspectRatio
	-- if debugEnabled then print(`halfNearPlaneWidth: {halfNearPlaneWidth}`) end


	local xAngle = math.atan2(offset.X, offset.Z)
	local yAngle = math.atan2(offset.Y, offset.Z)

	-- if debugEnabled then print(`xAngle: {math.deg(xAngle)}`) end
	-- if debugEnabled then print(`yAngle: {math.deg(yAngle)}`) end

	-- if offset.Z > 0 then
	-- 	if xAngle < 0 then
	-- 		xAngle += math.rad(180)
	-- 	else
	-- 		xAngle -= math.rad(180)
	-- 	end
	-- 	if yAngle < 0 then
	-- 		yAngle += math.rad(180)
	-- 	else
	-- 		yAngle -= math.rad(180)
	-- 	end
	-- end


	local xTan = math.tan(xAngle)
	local yTan = math.tan(yAngle)



	-- if debugEnabled then print(`xTan: {xTan}`) end
	-- if debugEnabled then print(`yTan: {yTan}`) end

	local xOffset = (xTan * nearPlaneZ)
	local yOffset = (yTan * nearPlaneZ)
	-- if debugEnabled then print(`xOffset: {xOffset}`) end
	-- if debugEnabled then print(`yOffset: {yOffset}`) end


	local xAlpha = 0.5 * (xOffset / halfNearPlaneWidth) + 0.5
	local yAlpha = 1 - (0.5 * (yOffset / halfNearPlaneHeight) + 0.5)
	-- if debugEnabled then print(`xAlpha: {xAlpha}`) end
	-- if debugEnabled then print(`yAlpha: {yAlpha}`) end



	local screenPosition = vSize * Vector2.new(xAlpha, yAlpha)
	-- if debugEnabled then print(`sP1: {screenPosition}`) end

	screenPosition = Vector2.new(math.round(screenPosition.X), math.round(screenPosition.Y))
	-- if debugEnabled then print(`sP2: {screenPosition}`) end

	local isVisible = math.sign(offset.Z) == -1 and (screenPosition.X >= 0 and screenPosition.X <= vSize.X) and (screenPosition.Y >= 0 and screenPosition.Y <= vSize.Y)
	-- if debugEnabled then print(`isVisible: {isVisible}`) end

	local out = Vector3.new(screenPosition.X, screenPosition.Y, math.sign(offset.Z))
	-- if debugEnabled then print(`sPF: {out}`) end

	local isInverted = offset.Z > 0

	return out, isVisible, isInverted
end

function Util.getWorldPerimeter(cf: CFrame, size: Vector3, cameraCF: CFrame): {[number]: Vector3}

	local centerId: PerspectiveId = getCenterId(cf, size, cameraCF)


	if centerId:len() == 0 then return {} end

	local perimeterData = PERIMETER_DATA[centerId]
	assert(perimeterData, `bad perimeter: {centerId}`)

	local perimeter: {[number]: Vector3} = {}

	for j, cornerId in ipairs(perimeterData) do
		local point = getWorldPosition(cf, size, cornerId :: CornerId)
		table.insert(perimeter, point)
	end

	assert(#perimeter ~= 0)

	return perimeter
end
return Util