--!strict
-- Huge thanks to @MrChickenRocket for the math here: https://gist.github.com/MrChickenRocket/09050693faee256888313c04d93cbb08
local _Package = script.Parent
local _Packages = _Package.Parent
-- Services
local Players = game:GetService("Players")
-- Packages
local GeometryUtil = require(_Packages:WaitForChild("GeometryUtil"))

-- Modules
local Draw = require(_Packages:WaitForChild("Draw"))
local TableUtil = require(_Packages:WaitForChild("TableUtil"))

-- Types
export type Plane = {
	Normal: Vector3,
	Dot: number,
}
export type Frustum = {
	__index: Frustum,
	CFrame: CFrame,
	MaxRenderDistance: number,
	ViewportSize: Vector2,
	AspectRatio: number,
	NearPlaneZ: number,
	HalfFieldOfView: number,
	HalfFarPlaneHeight: number,
	HalfFarPlaneWidth: number,
	HalfNearPlaneHeight: number,
	HalfNearPlaneWidth: number,
	FarTopLeft: Vector3,
	FarTopRight: Vector3,
	FarBottomRight: Vector3,
	FarBottomLeft: Vector3,
	NearTopLeft: Vector3,
	NearTopRight: Vector3,
	NearBottomLeft: Vector3,
	NearBottomRight: Vector3,
	Planes: {
		Near: Plane,
		Far: Plane,
		Top: Plane,
		Bottom: Plane,
		Left: Plane,
		Right: Plane,
	},
	Obscurecast: (self: Frustum, sampleCount: number?, raycastParams: RaycastParams?, worldRoot: WorldRoot?) -> {[Vector2]: {[number]: RaycastResult}},
	Rendercast: (self: Frustum, sampleCount: number?, raycastParams: RaycastParams?, worldRoot: WorldRoot?) -> {[Vector2]: RaycastResult},
	GetRenderedParts: (self: Frustum, sampleCount: number?, raycastParams: RaycastParams?, worldRoot: WorldRoot?) -> {[number]: BasePart},
	GetObscuredParts: (self: Frustum, sampleCount: number?, raycastParams: RaycastParams?, worldRoot: WorldRoot?) -> {[number]: BasePart},
	GetIfSphereRendered: (self: Frustum, origin: Vector3, radius: number) -> boolean,
	Draw: (self: Frustum) -> Folder,
	Render: (self: Frustum, sampleCount: number?) -> Part,
	new: (camera: Camera, farPlaneZ: number) -> Frustum,
}
-- Constants
local DEFAULT_SAMPLE_COUNT = 512

-- Variables
-- References
local Terrain = workspace:WaitForChild("Terrain") :: Terrain

-- Private Functions
local function getStudOffsets(maxPixelCount: number, nearStudWidth: number, cellPixelWidth: number): {[number]: number}
	local count = math.floor(maxPixelCount / cellPixelWidth)
	local halfStartStudOffset = (-nearStudWidth * 0.5)
	local coordinates: {[number]: number} = {}
	for i=0, count do
		local pxStart = maxPixelCount * i/count
		local pxFinish =  maxPixelCount * (i+1)/count
		local pxWidth = pxFinish - pxStart
		local pxCenter = pxStart + pxWidth * 0.5
		table.insert(coordinates, halfStartStudOffset + (pxCenter/maxPixelCount) * nearStudWidth)
	end
	return coordinates
end
function newPlane(p0: Vector3, p1: Vector3, p2: Vector3): Plane
	local normal = (p1 - p0):Cross(p2 - p1).Unit

	local plane = {
		Normal = normal,
		Dot = -normal:Dot(p0),
	}

	table.freeze(plane)

	return plane
end

-- Class
local Frustum = {} :: Frustum
Frustum.__index = Frustum

function Frustum:GetIfSphereRendered(origin: Vector3, radius: number): boolean
	
	for _, plane in pairs(self.Planes) do
		local distance = origin:Dot(plane.normal) + plane.d + radius
		if distance <= 0 then
			return false
		end
	end

	return true
end

function Frustum:Obscurecast(sampleCount: number?, raycastParams: RaycastParams?, worldRoot: WorldRoot?): {[Vector2]: {[number]: RaycastResult}}
	sampleCount = sampleCount or DEFAULT_SAMPLE_COUNT
	assert(sampleCount)
	local area = self.ViewportSize.X * self.ViewportSize.Y
	local cellWidth = (area ^ 0.5) / (sampleCount ^ 0.5)


	local xStudOffsets = getStudOffsets(
		self.ViewportSize.X, 
		(self.NearBottomLeft - self.NearBottomRight).Magnitude,
		cellWidth
	)
	local yStudOffsets = getStudOffsets(
		self.ViewportSize.Y, 
		(self.NearBottomLeft - self.NearTopLeft).Magnitude,
		cellWidth
	)

	worldRoot = worldRoot or workspace
	assert(worldRoot)

	if not raycastParams then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude

		local player = Players.LocalPlayer
		if player and player.Character then
			params.FilterDescendantsInstances = {player.Character}
		else
			params.FilterDescendantsInstances = {}
		end

		params.IgnoreWater = false
		params.RespectCanCollide = true

		raycastParams = params
	end
	assert(raycastParams)

	local out: {[Vector2]: {[number]: RaycastResult}} = {}

	for iX, xOffset in ipairs(xStudOffsets) do
		for iY, yOffset in ipairs(yStudOffsets) do

			local tiltAngle = math.atan2(yOffset, self.NearPlaneZ)
			local panAngle = math.atan2(xOffset, self.NearPlaneZ)

			local lookVector = (self.CFrame * CFrame.Angles(tiltAngle, panAngle, 0)).LookVector
			local angle = GeometryUtil.getAngleBetweenTwoNormals(lookVector, self.CFrame.LookVector)
			local distance = self.MaxRenderDistance / math.cos(angle)
			local lastResult: RaycastResult?
			local resultList: {[number]: RaycastResult} = {}

			local origin = self.CFrame.Position
			local count = 0
			repeat
				lastResult = nil
				local direction = distance * lookVector
				local result = worldRoot:Raycast(origin, direction, raycastParams)
				if result then
					if count > 0 then -- skip first one
						table.insert(resultList, result)
					end
					lastResult = result
					count += 1
					distance -= (origin - result.Position).Magnitude
					origin = result.Position
				end
				count += 1
			until lastResult == nil or distance <= 0
			if #resultList > 0 then
				local iV2 = Vector2.new(1 - ((iX-0.5)/#xStudOffsets), (iY-0.5)/#yStudOffsets)
				out[iV2] = resultList
			end
		end
	end

	return out
end

function Frustum:Rendercast(sampleCount: number?, raycastParams: RaycastParams?, worldRoot: WorldRoot?): {[Vector2]: RaycastResult}
	sampleCount = sampleCount or DEFAULT_SAMPLE_COUNT
	assert(sampleCount)
	local area = self.ViewportSize.X * self.ViewportSize.Y
	local cellWidth = (area ^ 0.5) / (sampleCount ^ 0.5)


	local xStudOffsets = getStudOffsets(
		self.ViewportSize.X, 
		(self.NearBottomLeft - self.NearBottomRight).Magnitude,
		cellWidth
	)
	local yStudOffsets = getStudOffsets(
		self.ViewportSize.Y, 
		(self.NearBottomLeft - self.NearTopLeft).Magnitude,
		cellWidth
	)

	worldRoot = worldRoot or workspace
	assert(worldRoot)

	if not raycastParams then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude

		local player = Players.LocalPlayer
		if player and player.Character then
			params.FilterDescendantsInstances = {player.Character}
		else
			params.FilterDescendantsInstances = {}
		end

		params.IgnoreWater = false
		params.RespectCanCollide = true

		raycastParams = params
	end
	assert(raycastParams)

	local out: {[Vector2]: RaycastResult} = {}

	local origin = self.CFrame.Position
	for iX, xOffset in ipairs(xStudOffsets) do
		for iY, yOffset in ipairs(yStudOffsets) do

			local tiltAngle = math.atan2(yOffset, self.NearPlaneZ)
			local panAngle = math.atan2(xOffset, self.NearPlaneZ)

			local lookVector = (self.CFrame * CFrame.Angles(tiltAngle, panAngle, 0)).LookVector
			local angle = GeometryUtil.getAngleBetweenTwoNormals(lookVector, self.CFrame.LookVector)
			local distance = self.MaxRenderDistance / math.cos(angle)
			local direction = distance * lookVector

			local result = worldRoot:Raycast(origin, direction, raycastParams)
			if result then
				local iV2 = Vector2.new(1 - ((iX-0.5)/#xStudOffsets), (iY-0.5)/#yStudOffsets)
				out[iV2] = result
			end
		end
	end

	return out
end

function Frustum:GetObscuredParts(sampleCount: number?, raycastParams: RaycastParams?, worldRoot: WorldRoot?): {[number]: BasePart}
	sampleCount = sampleCount or DEFAULT_SAMPLE_COUNT
	assert(sampleCount)
	local results = self:Obscurecast(sampleCount, raycastParams, worldRoot)
	local registry: {[BasePart]: true} = {}
	for kV2, resultList in pairs(results) do
		for i, result in ipairs(resultList) do
			local part = result.Instance
			if part:IsA("BasePart") then
				registry[part] = true
			end
		end
	end
	return TableUtil.keys(registry)
end

function Frustum:GetRenderedParts(sampleCount: number?, raycastParams: RaycastParams?, worldRoot: WorldRoot?): {[number]: BasePart}
	sampleCount = sampleCount or DEFAULT_SAMPLE_COUNT
	assert(sampleCount)
	local results = self:Rendercast(sampleCount, raycastParams, worldRoot)
	local registry: {[BasePart]: true} = {}
	for kV2, result in pairs(results) do
		local part = result.Instance
		if part:IsA("BasePart") then
			registry[part] = true
		end
	end
	return TableUtil.keys(registry)
end

function Frustum:Render(sampleCount: number?): Part
	sampleCount = sampleCount or DEFAULT_SAMPLE_COUNT
	assert(sampleCount)
	local dotWidth = math.min(math.min(self.ViewportSize.X, self.ViewportSize.Y)/(sampleCount^0.5))
	local renderResults = self:Rendercast(sampleCount)

	local panel = Instance.new("Part")
	panel.Name = `Rendering_{#TableUtil.keys(renderResults)}`
	panel.Anchored = true
	panel.CanCollide = false
	panel.CanTouch = false
	panel.CanQuery = false
	panel.Locked = true
	panel.Transparency = 1
	panel.Size = Vector3.new(
		(self.NearBottomLeft - self.NearBottomRight).Magnitude,
		(self.NearTopRight - self.NearBottomRight).Magnitude,
		0.01
	)
	panel.CFrame = self.CFrame * CFrame.new(0,0,self.NearPlaneZ) * CFrame.Angles(0,math.rad(180),0)

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	surfaceGui.CanvasSize = self.ViewportSize

	for kV2, result in pairs(renderResults) do
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 0.5
		frame.Name = tostring(kV2)
		frame.Size = UDim2.fromOffset(dotWidth, dotWidth)
		frame.Position = UDim2.fromScale(
			kV2.X,--0.5 - (0.5 - kV2.X), 
			kV2.Y --0.5 - (0.5 - kV2.Y)
		)
		
		local inst = result.Instance
		if inst:IsA("BasePart") then
			frame.BackgroundColor3 = inst.Color
		elseif inst:IsA("Terrain") then
			local mat = inst.Material
			local color = Terrain:GetMaterialColor(mat)
			frame.BackgroundColor3 = color
		end

		frame.Parent = surfaceGui
	end

	surfaceGui.Parent = panel
	panel.Parent = workspace.CurrentCamera

	return panel
end

function Frustum:Draw(): Folder
	local folder = Instance.new("Folder")
	local function line(p1: Vector3, p2: Vector3, color: Color3)
		local vec = Draw.vector(p1, p2-p1, color, folder, 0.1)
		vec.Locked = true
	end
	local nearColor = Color3.new(1,0,0)
	line(self.NearBottomLeft, self.NearBottomRight, nearColor)
	line(self.NearBottomLeft, self.NearTopLeft, nearColor)
	line(self.NearBottomRight, self.NearTopRight, nearColor)
	line(self.NearTopLeft, self.NearTopRight, nearColor)

	local farColor = Color3.new(0,1,0)
	line(self.FarBottomLeft, self.FarBottomRight, farColor)
	line(self.FarBottomLeft, self.FarTopLeft, farColor)
	line(self.FarBottomRight, self.FarTopRight, farColor)
	line(self.FarTopLeft, self.FarTopRight, farColor)

	local edgeColor = Color3.new(0,0,1)
	line(self.FarBottomLeft, self.NearBottomLeft, edgeColor)
	line(self.FarBottomRight, self.NearBottomRight, edgeColor)
	line(self.FarTopRight, self.NearTopRight, edgeColor)
	line(self.FarTopLeft, self.NearTopLeft, edgeColor)

	folder.Parent = workspace.CurrentCamera
	return folder
end

function Frustum.new(camera: Camera, maxRenderDistance: number): Frustum
		
	local self: Frustum = setmetatable({}, Frustum) :: any
	
	self.CFrame = camera.CFrame
	self.MaxRenderDistance = maxRenderDistance
	self.ViewportSize = camera:GetAttribute("ViewportSize") or camera.ViewportSize
	self.AspectRatio = self.ViewportSize.X / self.ViewportSize.Y
	self.NearPlaneZ = camera:GetAttribute("NearPlaneZ") or camera.NearPlaneZ

	self.HalfFieldOfView = math.rad(camera.FieldOfView / 2)
	
	self.HalfFarPlaneHeight = 2 * math.tan(self.HalfFieldOfView) * self.MaxRenderDistance / 2
	self.HalfFarPlaneWidth = self.HalfFarPlaneHeight * self.AspectRatio
	self.HalfNearPlaneHeight = 2 * math.tan(self.HalfFieldOfView) * -self.NearPlaneZ / 2
	self.HalfNearPlaneWidth = self.HalfNearPlaneHeight * self.AspectRatio

	self.FarTopLeft = self.CFrame * Vector3.new(-self.HalfFarPlaneWidth, self.HalfFarPlaneHeight, -self.MaxRenderDistance)
	self.FarTopRight = self.CFrame * Vector3.new(self.HalfFarPlaneWidth, self.HalfFarPlaneHeight, -self.MaxRenderDistance)
	self.FarBottomRight = self.CFrame * Vector3.new(self.HalfFarPlaneWidth, -self.HalfFarPlaneHeight, -self.MaxRenderDistance)
	self.FarBottomLeft = self.CFrame * Vector3.new(-self.HalfFarPlaneWidth, -self.HalfFarPlaneHeight, -self.MaxRenderDistance)

	self.NearTopLeft = self.CFrame * Vector3.new(-self.HalfNearPlaneWidth, self.HalfNearPlaneHeight, self.NearPlaneZ)
	self.NearTopRight = self.CFrame * Vector3.new(self.HalfNearPlaneWidth, self.HalfNearPlaneHeight, self.NearPlaneZ)
	self.NearBottomLeft = self.CFrame * Vector3.new(-self.HalfNearPlaneWidth, -self.HalfNearPlaneHeight, self.NearPlaneZ)
	self.NearBottomRight = self.CFrame * Vector3.new(self.HalfNearPlaneWidth, -self.HalfNearPlaneHeight, self.NearPlaneZ)

	self.Planes = {} :: any
	self.Planes.Near = newPlane(self.NearTopRight, self.NearBottomRight, self.NearTopLeft)
	self.Planes.Far = newPlane(self.FarTopRight, self.FarTopLeft, self.FarBottomRight)
	self.Planes.Top = newPlane(self.NearTopRight, self.NearTopLeft, self.FarTopRight)
	self.Planes.Bottom = newPlane(self.NearBottomRight, self.FarBottomRight, self.NearBottomLeft)
	self.Planes.Left = newPlane(self.NearTopLeft, self.NearBottomLeft, self.FarTopLeft)
	self.Planes.Right = newPlane(self.NearTopRight, self.FarTopRight, self.NearBottomRight)

	table.freeze(self.Planes)
	table.freeze(self)

	return self
end

return Frustum