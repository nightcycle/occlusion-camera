--!strict
-- Huge thanks to @MrChickenRocket for a lot of the initial math here: https://gist.github.com/MrChickenRocket/09050693faee256888313c04d93cbb08
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
export type Surface = {
	Normal: Vector3,
	Position: Vector3,
	Corners: {
		[number]: Vector3,
	}
}
export type Frustum = {
	__index: Frustum,
	Camera: Camera,
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
	_GetIfPointIsCloseEnough: (self: Frustum, point: Vector3) -> boolean,
	GetIfPointRendered: (self: Frustum, point: Vector3) -> boolean,
	GetIfRayRendered: (self: Frustum, ray: Ray, cornersAlreadyChecked: boolean?) -> boolean,
	GetIfSphereRendered: (self: Frustum, origin: Vector3, radius: number) -> boolean,
	GetIfBlockRendered: (self: Frustum, cf: CFrame, size: Vector3) -> boolean,
	GetIfPlaneRendered: (self: Frustum, origin: Vector3, normal: Vector3) -> boolean,
	GetNearPlaneRenderCells: (self: Frustum, cellCount: number) -> {[number]: Vector2},
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
function newPlane(
	p0: Vector3,
	p1: Vector3, 
	p2: Vector3
): Plane
	local normal = (p1 - p0):Cross(p2 - p1).Unit

	local plane = {
		Normal = normal,
		Dot = -normal:Dot(p0),
	}

	table.freeze(plane)

	return plane
end

function getIfInFrontOfCamera(camCF: CFrame, pos: Vector3)
	return ((pos - camCF.Position).Unit):Dot(camCF.LookVector) > 0
end

-- https://www.geeksforgeeks.org/program-for-point-of-intersection-of-two-lines/
function getLineIntersection(aOri: Vector2, aDest: Vector2, bOri: Vector2, bDest: Vector2): Vector2?
	local a1 = aDest.Y - aOri.Y
	local b1 = aOri.X - aDest.X
	local c1 = a1 * aOri.X + b1 * aOri.Y

	local a2 = bDest.Y - bOri.Y
	local b2 = bOri.X - bDest.X
	local c2 = a1 * bOri.X + b1 * bOri.Y

	local determinant = a1*b2 - a2*b1
	if determinant == 0 then
		return nil
	else
		local x = (b2*c1 - b1*c2)/determinant
		local y = (a1*c2 - a2*c1)/determinant
		return Vector2.new(x,y)
	end
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

function getRenderedCubeSurfaces(camCF: CFrame, cf: CFrame, size: Vector3): {[number]: Surface}
	local renderedSurfaces: {[number]: Surface} = {}

	do
		local normal = cf.RightVector
		local yVec = cf.UpVector * size.Y
		local xVec = -cf.LookVector * size.Z

		if normal:Dot(camCF.LookVector) > 0 then
			normal *= -1
		end

		local position = cf.Position + normal * size.X / 2

		local surface: Surface = {
			Normal = normal,
			Position = position,
			Corners = {
				position + (yVec/2) + (xVec/2),
				position - (yVec/2) + (xVec/2),
				position + (yVec/2) - (xVec/2),
				position - (yVec/2) - (xVec/2),
			}
		}

		table.insert(renderedSurfaces, surface)
	end

	do
		local normal = cf.UpVector
		local yVec = -cf.LookVector * size.Z
		local xVec = cf.RightVector * size.X

		if normal:Dot(camCF.LookVector) > 0 then
			normal *= -1
		end
		
		local position = cf.Position + normal * size.Y / 2

		local surface: Surface = {
			Normal = normal,
			Position = position,
			Corners = {
				position + (yVec/2) + (xVec/2),
				position - (yVec/2) + (xVec/2),
				position + (yVec/2) - (xVec/2),
				position - (yVec/2) - (xVec/2),
			}
		}

		table.insert(renderedSurfaces, surface)
	end

	do
		local normal = cf.LookVector
		local yVec = cf.UpVector * size.Y
		local xVec = cf.RightVector * size.X

		if normal:Dot(camCF.LookVector) > 0 then
			normal *= -1
		end
		
		local position = cf.Position + normal * size.Z / 2

		local surface: Surface = {
			Normal = normal,
			Position = position,
			Corners = {
				position + (yVec/2) + (xVec/2),
				position - (yVec/2) + (xVec/2),
				position + (yVec/2) - (xVec/2),
				position - (yVec/2) - (xVec/2),
			}
		}

		table.insert(renderedSurfaces, surface)
	end

	return renderedSurfaces
end

-- Class
local Frustum = {} :: Frustum
Frustum.__index = Frustum


function Frustum:_GetIfPointIsCloseEnough(point: Vector3): boolean
	local ray = self.Camera:ViewportPointToRay(point.X, point.Y)
	local angle = GeometryUtil.getAngleBetweenTwoNormals(ray.Direction.Unit, self.CFrame.LookVector)
	local maxDist = self.FarPlaneDistance/math.cos(angle) --near plane is already covered by ViewportPointToRay
	return maxDist >= (point - self.CFrame.Position).Magnitude
end

function Frustum:GetIfPointRendered(point: Vector3): boolean
	local _vPos: Vector3, isVisible: boolean = self.Camera:WorldToViewportPoint(point)
	return isVisible and self:_GetIfPointIsCloseEnough(point)
end


function Frustum:GetIfRayRendered(ray: Ray, cornersAlreadyChecked: boolean?): boolean

	local originScreenPos: Vector3, originIsVisible: boolean = self.Camera:WorldToViewportPoint(ray.Origin)
	if cornersAlreadyChecked ~= true then
		if originIsVisible and self:_GetIfPointIsCloseEnough(originScreenPos) then return true end
	end

	local destWorldPos: Vector3 = ray.Origin + ray.Direction

	local destScreenPos: Vector3, destIsVisible: boolean = self.Camera:WorldToViewportPoint(destWorldPos)
	if cornersAlreadyChecked ~= true then
		if destIsVisible and self:_GetIfPointIsCloseEnough(destScreenPos) then return true end
	end

	if not getIfInFrontOfCamera(self.CFrame, ray.Origin) and not getIfInFrontOfCamera(self.CFrame, destWorldPos) then
		return false
	end

	
	destScreenPos *= Vector3.new(1,1,0)
	originScreenPos *= Vector3.new(1,1,0)

	local dSP2: Vector2 = Vector2.new(destScreenPos.X, destScreenPos.Y)
	local oSP2: Vector2 = Vector2.new(originScreenPos.X, originScreenPos.Y)

	for i, vec in ipairs({
		{Vector2.new(0,0), Vector2.new(0,self.Camera.ViewportSize.Y)},
		{Vector2.new(0,0), Vector2.new(self.Camera.ViewportSize.X,0)},
		{Vector2.new(self.Camera.ViewportSize.X,0), Vector2.new(0,self.Camera.ViewportSize.Y)},
		{Vector2.new(0,self.Camera.ViewportSize.Y), Vector2.new(self.Camera.ViewportSize.X,0)},
	}) do
		local borderOrigin: Vector2 = vec[1]
		local borderDirection: Vector2 = vec[2]
		
		local intersection = getLineIntersection(oSP2, dSP2, borderOrigin, borderOrigin+borderDirection)
		if intersection then
			return true
		end
	end
	return false
end

function Frustum:GetIfSphereRendered(origin: Vector3, radius: number): boolean
	
	for _, plane in pairs(self.Planes) do
		local distance = origin:Dot(plane.Normal) + plane.Dot + radius
		if distance <= 0 then
			return false
		end
	end

	return true
end

function Frustum:GetIfPlaneRendered(origin: Vector3, normal: Vector3): boolean
	if self.CFrame.LookVector:Dot(normal) > 0 then
		return false

	else
		local _pos, distance = GeometryUtil.getPlaneIntersection(
			self.CFrame.Position,
			self.CFrame.LookVector,
			origin, 
			normal
		)
		
		return (math.abs(self.NearPlaneZ) <= distance and math.abs(self.FarPlaneDistance) >= distance)
	end
end

function Frustum:GetIfBlockRendered(cf: CFrame, size: Vector3): boolean	
	local maxDim = math.max(size.X, size.Y, size.Z)
	local radius = Vector3.new(maxDim, maxDim, maxDim).Magnitude / 2

	if self:GetIfSphereRendered(cf.Position, radius) then

		local lVec = self.CFrame.LookVector

		for i, vectors in ipairs({
			{cf.RightVector * size.X, -cf.LookVector * size.Z, cf.UpVector * size.Y},
			{cf.UpVector * size.Y, cf.RightVector * size.X, -cf.LookVector * size.Z},
			{-cf.LookVector * size.Z, cf.RightVector * size.X, cf.UpVector * size.Y}
		}) do
			local zVec = vectors[1]
			local xVec = vectors[2]
			local yVec = vectors[3]
	
			if zVec:Dot(lVec) > 0 then
				zVec *= -1
			end
	
			local position = cf.Position + zVec / 2

			local c1 = position + (xVec/2) + (yVec/2)


			local c1ScreenPos: Vector3, isC1Visible: boolean = self.Camera:WorldToViewportPoint(c1)
			-- makePoint(c1, `C1: {isC1Visible}`)

			if isC1Visible and self:_GetIfPointIsCloseEnough(c1ScreenPos) then return true end

			local c2 = position - (xVec/2) + (yVec/2)

			
			local c2ScreenPos: Vector3, isC2Visible: boolean = self.Camera:WorldToViewportPoint(c2)
			-- makePoint(c2, `C2: {isC2Visible}`)

			if isC2Visible and self:_GetIfPointIsCloseEnough(c2ScreenPos) then return true end

			if self:GetIfRayRendered(Ray.new(c1, c2-c1), true) then return true end

			local c3 = position + (xVec/2) - (yVec/2)
			
			local c3ScreenPos: Vector3, isC3Visible: boolean = self.Camera:WorldToViewportPoint(c3)
			-- makePoint(c3, `C3: {isC3Visible}, {c3ScreenPos}`)

			if isC3Visible and self:_GetIfPointIsCloseEnough(c3ScreenPos) then return true end

			if self:GetIfRayRendered(Ray.new(c1, c3-c1), true) then return true end

			local c4 = position - (xVec/2) - (yVec/2)
			local c4ScreenPos: Vector3, isC4Visible: boolean = self.Camera:WorldToViewportPoint(c4)
			-- makePoint(c4, `C4: {isC4Visible}`)
			if isC4Visible and self:_GetIfPointIsCloseEnough(c4ScreenPos) then return true end

			if self:GetIfRayRendered(Ray.new(c4, c2-c4), true) then return true end
			if self:GetIfRayRendered(Ray.new(c4, c3-c4), true) then return true end

			if getIfInFrontOfCamera(self.CFrame, c1) or getIfInFrontOfCamera(self.CFrame, c2) 
			or getIfInFrontOfCamera(self.CFrame, c3) or getIfInFrontOfCamera(self.CFrame, c4) then

				local centerPlanePosition, centerDist = GeometryUtil.getPlaneIntersection(
					self.CFrame.Position, 
					self.CFrame.LookVector,
					position,
					zVec
				)

				if centerPlanePosition and centerDist > -self.NearPlaneZ then
					local centerScreenPos: Vector3, isCenterVisible: boolean = self.Camera:WorldToViewportPoint(centerPlanePosition)
					if isCenterVisible and self:_GetIfPointIsCloseEnough(centerScreenPos) then return true end
				end
			end
		end
	end

	return false
end


function Frustum:GetNearPlaneRenderCells(cellCount: number): {[number]: Vector2}

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
	
	for i, offset in ipairs(self:GetNearPlaneRenderCells(sampleCount)) do

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
	
	self.Camera = camera
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