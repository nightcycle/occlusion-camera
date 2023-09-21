--!strict
-- Huge thanks to @MrChickenRocket for the math here: https://gist.github.com/MrChickenRocket/09050693faee256888313c04d93cbb08
local _Package = script.Parent
local _Packages = _Package.Parent

-- Services
local CollectionService = game:GetService("CollectionService")

-- Packages
local GeometryUtil = require(_Packages:WaitForChild("GeometryUtil"))
local Draw = require(_Packages:WaitForChild("Draw"))

-- Modules
local Config = require(_Package:WaitForChild("Config"))

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
	FarPlaneDistance: number,
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
	TagCast: (self: Frustum, sampleCount: number, raycastParams: RaycastParams?, worldRoot: WorldRoot?, noOccludeTag: string?) -> (),
	GetIfSphereRendered: (self: Frustum, origin: Vector3, radius: number) -> boolean,
	_GetNearPlaneRenderCells: (self: Frustum, cellCount: number) -> {[number]: Vector2},
	Draw: (self: Frustum) -> Folder,
	new: (camera: Camera, farPlaneZ: number) -> Frustum,
}
-- Constants
local IN_FRUSTUM_TAG = Config.Tag.InFrustum
local VISIBLE_TAG = Config.Tag.Visible
local INITIAL_OBSCURED_TAG = Config.Tag.InitialObscured
local OBSCURED_TAG = Config.Tag.Obscured
local LAST_SEEN_ATTR_KEY = Config.Attribute.LastSeen

-- Variables
-- References

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

function getCellVector(camCF: CFrame, nearPlaneDistance: number, nearPlanePosition: Vector2)
	local tiltAngle = math.atan2(nearPlanePosition.Y, math.abs(nearPlaneDistance))
	local panAngle = math.atan2(nearPlanePosition.X, math.abs(nearPlaneDistance))

	return (camCF * CFrame.Angles(0, panAngle, 0) * CFrame.Angles(tiltAngle, 0, 0)).LookVector.Unit
end

function getCellRenderDistance(camCF: CFrame, lookVector: Vector3, farPlaneDistance: number): number
	local angle = GeometryUtil.getAngleBetweenTwoNormals(lookVector, camCF.LookVector)
	return farPlaneDistance/math.cos(angle)
end

function recursiveCellCast(
	camCF: CFrame, 
	lookVector: Vector3, 
	nearPlaneDistance: number, 
	cellRenderDistance: number,
	raycastParams: RaycastParams, 
	worldRoot: WorldRoot,
	noOccludeTag: string?
): {[number]: OcclusionResult}
	local lastRaycastResult: RaycastResult?
	local origin = camCF.Position + lookVector * math.abs(nearPlaneDistance)
	local isVisible = true

	local distance = cellRenderDistance
	local count = 0
	local out: {[number]: OcclusionResult} = {}
	repeat
		count += 1
		lastRaycastResult = nil
		local direction = distance * lookVector
		local result = worldRoot:Raycast(origin, direction, raycastParams)
		if result then
			
			-- print("A")
			table.insert(out, {
				IsVisible = isVisible,
				Result = result,
			})

			if isVisible then
				if noOccludeTag then
					if not CollectionService:HasTag(result.Instance, noOccludeTag) then
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
	until lastRaycastResult == nil or distance <= 0 or count >= 100

	if count >= 100 then
		error(`inf recursion possible`)
	end

	return out
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

function Frustum:_GetNearPlaneRenderCells(cellCount: number): {[number]: Vector2}

	local area = self.ViewportSize.X * self.ViewportSize.Y
	local cellPixelWidth = (area ^ 0.5) / (cellCount ^ 0.5)

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

	local samples: {[number]: Vector2} = {}
	for iX, xOffset in ipairs(xStudOffsets) do
		for iY, yOffset in ipairs(yStudOffsets) do
			table.insert(samples, Vector2.new(xOffset, yOffset))
		end
	end

	return samples
end


function Frustum:TagCast(sampleCount: number, raycastParams: RaycastParams?, worldRoot: WorldRoot?, noOccludeTag: string?)
	worldRoot = worldRoot or workspace
	assert(worldRoot)

	if not raycastParams then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.IgnoreWater = false
		params.RespectCanCollide = false
		params.FilterDescendantsInstances = {}

		raycastParams = params
	end
	assert(raycastParams)
	
	for i, offset in ipairs(self:_GetNearPlaneRenderCells(sampleCount)) do

		local lookVector = getCellVector(self.CFrame, self.NearPlaneZ, offset)
		local distance = getCellRenderDistance(self.CFrame, lookVector, self.FarPlaneDistance)

		-- local vec = Draw.vector(self.CFrame.Position, (distance*lookVector - self.CFrame.Position))
		-- if vec then
		-- 	task.spawn(function()
		-- 		task.wait()
		-- 		vec:Destroy()
		-- 	end)
		-- end

		local out = recursiveCellCast(
			self.CFrame, 
			lookVector, 
			self.NearPlaneZ, 
			distance, 
			raycastParams, 
			worldRoot, 
			noOccludeTag
		)

		for i, obscureResult in ipairs(out) do
			local result = obscureResult.Result
			local inst = result.Instance
			local isVisible = obscureResult.IsVisible

			inst:SetAttribute(LAST_SEEN_ATTR_KEY, tick())

			if not CollectionService:HasTag(inst, IN_FRUSTUM_TAG) then
				CollectionService:AddTag(inst, IN_FRUSTUM_TAG)
			end
			
			if isVisible then
				if not CollectionService:HasTag(inst, VISIBLE_TAG) then
					CollectionService:AddTag(inst, VISIBLE_TAG)
				end
				if CollectionService:HasTag(inst, OBSCURED_TAG) then
					CollectionService:RemoveTag(inst, OBSCURED_TAG)
				end
				if CollectionService:HasTag(inst, INITIAL_OBSCURED_TAG) then
					CollectionService:RemoveTag(inst, INITIAL_OBSCURED_TAG)
				end
			else
				if not CollectionService:HasTag(inst, INITIAL_OBSCURED_TAG) then
					CollectionService:AddTag(inst, INITIAL_OBSCURED_TAG)
				end
				if CollectionService:HasTag(inst, VISIBLE_TAG) then
					CollectionService:RemoveTag(inst, VISIBLE_TAG)
				end
			end

		end
	end
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
	self.FarPlaneDistance = maxRenderDistance
	self.ViewportSize = camera:GetAttribute("ViewportSize") or camera.ViewportSize
	self.AspectRatio = self.ViewportSize.X / self.ViewportSize.Y
	self.NearPlaneZ = camera:GetAttribute("NearPlaneZ") or camera.NearPlaneZ

	self.HalfFieldOfView = math.rad(camera.FieldOfView / 2)
	
	self.HalfFarPlaneHeight = 2 * math.tan(self.HalfFieldOfView) * self.FarPlaneDistance / 2
	self.HalfFarPlaneWidth = self.HalfFarPlaneHeight * self.AspectRatio
	self.HalfNearPlaneHeight = 2 * math.tan(self.HalfFieldOfView) * -self.NearPlaneZ / 2
	self.HalfNearPlaneWidth = self.HalfNearPlaneHeight * self.AspectRatio

	self.FarTopLeft = self.CFrame * Vector3.new(-self.HalfFarPlaneWidth, self.HalfFarPlaneHeight, -self.FarPlaneDistance)
	self.FarTopRight = self.CFrame * Vector3.new(self.HalfFarPlaneWidth, self.HalfFarPlaneHeight, -self.FarPlaneDistance)
	self.FarBottomRight = self.CFrame * Vector3.new(self.HalfFarPlaneWidth, -self.HalfFarPlaneHeight, -self.FarPlaneDistance)
	self.FarBottomLeft = self.CFrame * Vector3.new(-self.HalfFarPlaneWidth, -self.HalfFarPlaneHeight, -self.FarPlaneDistance)

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