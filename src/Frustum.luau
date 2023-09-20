--!strict
-- Huge thanks to @MrChickenRocket for the math here: https://gist.github.com/MrChickenRocket/09050693faee256888313c04d93cbb08
local _Package = script.Parent
local _Packages = _Package.Parent

-- Services
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

-- Packages
local GeometryUtil = require(_Packages:WaitForChild("GeometryUtil"))
local Draw = require(_Packages:WaitForChild("Draw"))
local TableUtil = require(_Packages:WaitForChild("TableUtil"))

-- Modules

-- Types
export type Plane = {
	Normal: Vector3,
	Dot: number,
}
export type OcclusionResult = {
	Result: RaycastResult,
	IsVisible: boolean
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
	Occludecast: (self: Frustum, sampleCount: number, raycastParams: RaycastParams?, worldRoot: WorldRoot?, noOccludeTag: string?) -> {[Vector2]: {[number]: OcclusionResult}},
	GetIfSphereRendered: (self: Frustum, origin: Vector3, radius: number) -> boolean,
	Draw: (self: Frustum) -> Folder,
	Render: (self: Frustum, sampleCount: number?) -> Part,
	new: (camera: Camera, farPlaneZ: number) -> Frustum,
}
-- Constants
local DEFAULT_SAMPLE_COUNT = 512
local USE_SHAPE_CASTS = false
local DRAW_CASTS = false
local MAX_SHAPE_CAST_LENGTH = 255


-- Variables
-- References
local Terrain = workspace:WaitForChild("Terrain") :: Terrain

-- Private Functions
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


function Frustum:Occludecast(sampleCount: number, raycastParams: RaycastParams?, worldRoot: WorldRoot?, noOccludeTag: string?): {[Vector2]: {[number]: OcclusionResult}}

	local area = self.ViewportSize.X * self.ViewportSize.Y
	local cellPixelWidth = (area ^ 0.5) / (sampleCount ^ 0.5)

	local function getStudOffsets(maxPixelCount: number, nearStudWidth: number): {[number]: number}
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


	local xStudOffsets = getStudOffsets(
		self.ViewportSize.X, 
		(self.NearBottomLeft - self.NearBottomRight).Magnitude
	)
	local yStudOffsets = getStudOffsets(
		self.ViewportSize.Y, 
		(self.NearBottomLeft - self.NearTopLeft).Magnitude
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

	local out: {[Vector2]: {[number]: OcclusionResult}} = {}

	local function addItem(inst: Instance, duration: number)
		task.delay(duration, function()
			inst:Destroy()
		end)
	end

	local yAngle = (self.HalfFieldOfView * 2) / #yStudOffsets
	local xAngle = self.AspectRatio * yAngle

	for iX, xOffset in ipairs(xStudOffsets) do
		for iY, yOffset in ipairs(yStudOffsets) do

			local tiltAngle = math.atan2(yOffset, -self.NearPlaneZ)
			local panAngle = math.atan2(xOffset, -self.NearPlaneZ)

			local lookVector = (self.CFrame * CFrame.Angles(0, panAngle, 0) * CFrame.Angles(tiltAngle, 0, 0)).LookVector.Unit
			local angle = GeometryUtil.getAngleBetweenTwoNormals(lookVector, self.CFrame.LookVector)

			local distance = self.MaxRenderDistance / math.cos(angle)
			local originalDistance = distance
			local lastRaycastResult: RaycastResult?
			local resultList: {[number]: OcclusionResult} = {}

			local origin = self.CFrame.Position + lookVector * -self.NearPlaneZ
			local isVisible = true

			local function cast(direction: Vector3, originalDistance: number): RaycastResult?
				local visColor = if isVisible then Color3.new(1,0,0) else Color3.new(0,1,1)
				if USE_SHAPE_CASTS then
					local remainingDistance = direction.Magnitude
					local count = 0
					repeat
						local castStart = origin + direction.Unit*(MAX_SHAPE_CAST_LENGTH*count)
						local castLength = math.min(MAX_SHAPE_CAST_LENGTH, remainingDistance)

						local cf = CFrame.new(
							castStart, 
							castStart + direction.Unit
						)

						local size = Vector3.new(
							math.min(1 * math.tan(xAngle/2) * math.max((self.CFrame.Position - castStart).Magnitude, -self.NearPlaneZ), 511),
							math.min(2 * math.tan(yAngle/2) * math.max((self.CFrame.Position - castStart).Magnitude, -self.NearPlaneZ), 511),
							0.05
						)
						
						local result = worldRoot:Blockcast(
							cf, 
							size,
							direction.Unit * castLength, 
							raycastParams
						)
						if DRAW_CASTS then
							size += Vector3.new(0,0,castLength)
						end
						if result then
							castLength = math.min(castLength, (castStart - result.Position).Magnitude)
						end
						if DRAW_CASTS then
							if result then
								size = (size * Vector3.new(1,1,0)) + Vector3.new(0,0,castLength)
							end

							local part = Instance.new("Part")
							part.Color = Color3.fromHSV(
								iX/#xStudOffsets, 
								1 - ((castStart-origin).Magnitude / originalDistance), 
								0.5 + 0.5 * (iY/#yStudOffsets)
							)
							part.Transparency = 0
							part.CanCollide = false
							part.CanQuery = false
							part.CanTouch = false
							part.Anchored = true
							part.CFrame = cf
							part.Position = castStart + lookVector * size.Z/2
							part.Size = size
							part.Parent = workspace

							addItem(part, 2)
						end

						remainingDistance -= castLength

						if result then
							return result
						end
						count += 1

					until remainingDistance <= 0
				else
					local result = worldRoot:Raycast(origin, direction, raycastParams)
					if DRAW_CASTS then
						if result then
							addItem(
								Draw.vector(origin, (result.Position - origin), visColor),
								2
							)
							addItem(
								Draw.point(result.Position, visColor),
								2
							)
						else
							addItem(
								Draw.vector(origin, direction, Color3.new(0,0,0)),
								2
							)
						end
						addItem(
							Draw.labelledPoint(self.CFrame.Position + originalDistance * lookVector, `x: {math.round(math.deg(panAngle))}`),
							2
						)
					end

					return result
				end
				return nil
			end
			repeat
				lastRaycastResult = nil
				local direction = distance * lookVector
				local result = cast(direction, originalDistance)


				if result then
					local inst = result.Instance
					table.insert(resultList, {
						IsVisible = isVisible,
						Result = result,
					})
					if isVisible then
						if noOccludeTag then
							if not CollectionService:HasTag(inst, noOccludeTag) then
								isVisible = false
							end
						else
							isVisible = false
						end
					end
					distance -= (result.Position - origin).Magnitude
					origin = result.Position
				end
				lastRaycastResult = result
			until lastRaycastResult == nil or distance <= 0

			if #resultList > 0 then
				local iV2 = Vector2.new(
					1 - ((iX-0.5)/#xStudOffsets), 
					(iY-0.5)/#yStudOffsets
				)
				out[iV2] = resultList
			end
		end
	end

	return out
end

function Frustum:Render(sampleCount: number?): Part
	sampleCount = sampleCount or DEFAULT_SAMPLE_COUNT
	assert(sampleCount)
	local dotWidth = math.min(self.ViewportSize.X, self.ViewportSize.Y)/(sampleCount^0.5)
	local renderResults = self:Occludecast(sampleCount)

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

	for kV2, occludeResultList in pairs(renderResults) do
		if #occludeResultList > 0 then
			local frame = Instance.new("Frame")
			frame.BackgroundTransparency = 0.5
			frame.Name = tostring(kV2)
			frame.Size = UDim2.fromOffset(dotWidth, dotWidth)
			frame.Position = UDim2.fromScale(
				kV2.X,--0.5 - (0.5 - kV2.X), 
				kV2.Y --0.5 - (0.5 - kV2.Y)
			)
			for i, v in ipairs(occludeResultList) do
				local result = v.Result
				local inst = result.Instance
				if v.IsVisible then
					if inst:IsA("BasePart") then
						frame.BackgroundColor3 = inst.Color
					elseif inst:IsA("Terrain") then
						local mat = inst.Material
						local color = Terrain:GetMaterialColor(mat)
						frame.BackgroundColor3 = color
					end
				end
			end			

			frame.Parent = surfaceGui
		end
		
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
	
	self.CFrame = camera:GetRenderCFrame()
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