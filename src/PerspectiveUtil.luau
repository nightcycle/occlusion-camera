--!strict
-- pre-maps all the relevant geometry data for different cube perspectives, hopefully saves time in processing
local _Package = script.Parent
local _Packages = _Package.Parent

-- Services
-- Packages
local Frustum = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Frustum"))

-- Modules
-- local ShapeUtil = require(_Package:WaitForChild("ShapeUtil"))

-- Types
type CornerId = "XYZ" | "xYZ" | "XYz" | "xYz" | "XyZ" | "xyZ" | "Xyz" | "xyz"
type EdgeId = "YZ" | "Yz" | "yZ" |  "yz" | "XZ" | "xZ" | "Xz" | "xz" | "XY" | "xY" | "Xy" | "xy"
type FaceId = "X" | "x" | "Y" | "y" | "Z" | "z"
type PerspectiveId = CornerId | EdgeId | FaceId
type Frustum = Frustum.Frustum

-- Constants
local MIN_STEP = 0.001
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
local function getBorderHit(
	originX: number, originY: number,
	normalX: number, normalY: number, 
	screenSizeX: number, screenSizeY: number
): Vector3

	local stepsToX: number
	if normalX < 0 then
		stepsToX = -originX/normalX
	elseif normalX > 0 then
		stepsToX = (screenSizeX-originX)/normalX
	else
		stepsToX = math.huge
	end

	local stepsToY: number
	if normalY < 0 then
		stepsToY = -originY/normalY
	elseif normalY > 0 then
		stepsToY = (screenSizeY-originY)/normalY
	else
		stepsToY = math.huge
	end

	local steps = math.min(stepsToX, stepsToY)
	if steps == math.huge then
		return Vector3.new(originX, originY)
	else
		return Vector3.new(
			originX + normalX * steps,
			originY + normalY * steps
		)
	end
end

local function extendLine(
	visibleWorldPoint: Vector3, 
	hiddenWorldPoint: Vector3,
	visibleScreenPoint: Vector3,
	camera: Camera
): Vector3
	if hiddenWorldPoint == visibleWorldPoint then
		return visibleScreenPoint
	end
	local worldStepPoint = (hiddenWorldPoint - visibleWorldPoint).Unit * MIN_STEP + visibleWorldPoint

	local screenStepPoint, isScreenStepVisible = camera:WorldToViewportPoint(worldStepPoint)
	local screenLineNormalV2 = (
		Vector2.new(screenStepPoint.X, screenStepPoint.Y) 
		- Vector2.new(visibleScreenPoint.X, visibleScreenPoint.Y)
	).Unit

	local screenLineNormal = Vector3.new(screenLineNormalV2.X, screenLineNormalV2.Y)
	assert(isScreenStepVisible, `nIV is not visible, \nstepPoint=[{screenStepPoint.X}, {screenStepPoint.Y}] \norigin=[{visibleScreenPoint.X}, {visibleScreenPoint.Y}] \nnorm=[{screenLineNormal.X}, {screenLineNormal.Y}]`)

	return getBorderHit(
		visibleScreenPoint.X, visibleScreenPoint.Y,
		screenLineNormal.X, screenLineNormal.Y,
		camera.ViewportSize.X, camera.ViewportSize.Y
	)
end

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


function Util.getScreenPerimeter(cf: CFrame, size: Vector3, camera: Camera): {[number]: Vector3}
	local worldPoints = Util.getWorldPerimeter(cf, size, camera:GetRenderCFrame())
	local initialScreenPoints: {[number]: Vector3} = table.create(#worldPoints)
	local pointVisibility: {[number]: boolean} = table.create(#worldPoints)
	local finalScreenPoints: {[number]: Vector3} = table.create(#worldPoints)

	for i, v in ipairs(worldPoints) do
		initialScreenPoints[i], pointVisibility[i] = camera:WorldToViewportPoint(
			v
		)
	end

	for i, screenPoint in ipairs(initialScreenPoints) do
		local nI = if #initialScreenPoints < i+1 then 1 else i
		local pI = if i==1 then #initialScreenPoints else i-1

		local nextScreenPoint = initialScreenPoints[nI]
		local prevScreenPoint = initialScreenPoints[pI]

		local worldPoint = worldPoints[i]
		local nextWorldPoint = worldPoints[nI]
		local prevWorldPoint = worldPoints[pI]

		local isVisible = pointVisibility[i]
		local nextIsVisible = pointVisibility[nI]
		local prevIsVisible = pointVisibility[pI]
	
		if isVisible then
			if not prevIsVisible then
				table.insert(finalScreenPoints, extendLine(
					worldPoint,
					prevWorldPoint,
					screenPoint,
					camera
				))
			end
			table.insert(finalScreenPoints, screenPoint)
			if not nextIsVisible then
				table.insert(finalScreenPoints, extendLine(
					worldPoint,
					nextWorldPoint,
					screenPoint,
					camera
				))
			end
		else
			if nextIsVisible then
				table.insert(finalScreenPoints, extendLine(
					nextWorldPoint,
					worldPoint,
					nextScreenPoint,
					camera
				))
			end

			if prevIsVisible then
				table.insert(finalScreenPoints, extendLine(
					prevWorldPoint,
					worldPoint,
					prevScreenPoint,
					camera
				))
			end
		end
	end
	if #finalScreenPoints >= 3 then
		return finalScreenPoints
	else
		return {}
	end
end

return Util