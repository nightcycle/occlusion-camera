--!strict
-- Huge thanks to @MrChickenRocket for a lot of the initial math here: https://gist.github.com/MrChickenRocket/09050693faee256888313c04d93cbb08
local _Package = script.Parent
local _Packages = _Package.Parent

-- Services
local CollectionService = game:GetService("CollectionService")

-- Packages
local Draw = require(_Packages:WaitForChild("Draw"))

-- Modules
local Config = require(_Package:WaitForChild("Config"))

-- Types
export type Plane = {
	Normal: Vector3,
	Origin: Vector3,
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
	HalfHorizontalFieldOfView: number,
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
	Rays: {[number]: Ray},
	Planes: {[string]: Plane},
	GetViewportPosition: (self: Frustum, point: Vector3) -> (Vector3, boolean),
	_GetIfPointIsCloseEnough: (self: Frustum, point: Vector3) -> boolean,
	GetIfPointRendered: (self: Frustum, point: Vector3) -> boolean,
	GetIfRectangleRendered: (self: Frustum, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> boolean,
	GetIfTriangleRendered: (self: Frustum, a: Vector3, b: Vector3, c: Vector3) -> boolean,
	GetIfRayRendered: (self: Frustum, ray: Ray) -> boolean,
	GetIfSphereRendered: (self: Frustum, origin: Vector3, radius: number) -> boolean,
	GetIfBlockRendered: (self: Frustum, cf: CFrame, size: Vector3) -> boolean,
	GetIfPlaneRendered: (self: Frustum, origin: Vector3, normal: Vector3) -> boolean,
	GetIfPartRendered: (self: Frustum, part: BasePart) -> boolean,
	GetOuterBlockBounds: (self: Frustum, cf: CFrame, size: Vector3) -> Rect,
	Draw: (self: Frustum) -> Folder,
	new: (camera: Camera, farPlaneZ: number) -> Frustum,
}
-- Constants
local IN_FRUSTUM_TAG = Config.Tag.InFrustum
local VISIBLE_TAG = Config.Tag.Visible
local INITIAL_OBSCURED_TAG = Config.Tag.InitialObscured
local OBSCURED_TAG = Config.Tag.Obscured
local LAST_SEEN_ATTR_KEY = Config.Attribute.LastSeen
local USE_CUSTOM_VIEWPORT_MATH = true
local RENDER_PARTS_AS_SPHERE = true

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
		Origin = p0,
		Dot = -normal:Dot(p0),
	}

	table.freeze(plane)

	return plane
end

 -- https://stackoverflow.com/questions/5666222/3d-line-plane-intersection
function getPlaneIntersection(planeOrigin: Vector3, planeNormal: Vector3, rayOrigin: Vector3, rayDirection: Vector3): Vector3?
	local dot = planeNormal:Dot(rayDirection)
	if math.abs(dot) > 1e-6 then
		-- The factor of the point between rayOrigin -> rayLimit (0 - 1)
		local w = rayOrigin - planeOrigin
		-- if 'fac' is between (0 - 1) the point intersects with the segment.
		-- Otherwise:
		-- < 0.0: behind rayOrigin.
		-- > 1.0: infront of rayLimit.
		local fac = -(planeNormal:Dot(w)) / dot
		if fac >= 0 and fac <= 1 then
			rayDirection = rayDirection * fac
			return rayOrigin + rayDirection
		end
	end
	return nil
end

function getRectangleIntersection(rayOrigin: Vector3, rayDirection: Vector3, a: Vector3, b: Vector3, c: Vector3, d: Vector3): Vector3?
	local planeNormal = ((b - a).Unit):Cross((c - a).Unit)
	if planeNormal:Dot(rayDirection.Unit) > 0 then
		planeNormal *= -1
	end

	local intersction = getPlaneIntersection(
		a,
		planeNormal,
		rayOrigin,
		rayDirection
	)
	if intersction then
		local ab = (b - a):Dot(intersction - a)
		local ba = (a - b):Dot(intersction - b)
		local bc = (c - b):Dot(intersction - b)
		local cb = (b - c):Dot(intersction - c)
		local cd = (d - c):Dot(intersction - c)
		local dc = (c - d):Dot(intersction - d)
		local da = (a - d):Dot(intersction - d)
		local ad = (d - a):Dot(intersction - a)
	
		if ab >= 0 and ba >= 0 and bc >= 0 and cb >= 0 and cd >= 0 and dc >= 0 and da >= 0 and ad >= 0 then
			return intersction
		end
	end
	return nil
end

function getTriangleIntersection(rayOrigin: Vector3, rayDirection: Vector3, a: Vector3, b: Vector3, c: Vector3): Vector3?
	local planeNormal = ((b - a).Unit):Cross((c - a).Unit)
	if planeNormal:Dot(rayDirection.Unit) > 0 then
		planeNormal *= -1
	end

	local intersction = getPlaneIntersection(
		a,
		planeNormal,
		rayOrigin,
		rayDirection
	)


	if intersction then
		local function getTriangleArea(ab: number, bc: number, ca: number)
			local s = (ab+bc+ca)/2
			return (s*(s-ab)*(s-bc)*(s-ca))^0.5
		end
	
		local ab = (a-b).Magnitude
		local bc = (b-c).Magnitude
		local ca = (c-a).Magnitude

		local pa = (intersction-a).Magnitude
		local pb = (intersction-b).Magnitude
		local pc = (intersction-c).Magnitude

		local pab = getTriangleArea(ab, pa, pb)
		local pbc = getTriangleArea(bc, pc, pb)
		local pca = getTriangleArea(ca, pc, pa)
		local full = getTriangleArea(ab, bc, ca)
		if math.abs(full - (pab+pbc+pca)) < full * 0.001 then
			return intersction
		end
	end
	return nil
end
-- Class
local Frustum = {} :: Frustum
Frustum.__index = Frustum

function Frustum:GetViewportPosition(point: Vector3): (Vector3, boolean)
	if USE_CUSTOM_VIEWPORT_MATH then
		local offset = self.CFrame:PointToObjectSpace(point)
		local xAngle = math.atan2(offset.X, offset.Z)
		local yAngle = math.atan2(offset.Y, offset.Z)
	
		local xOffset = (math.tan(xAngle) * self.NearPlaneZ)
		local yOffset = (math.tan(yAngle) * self.NearPlaneZ)
	
		local xAlpha = 0.5 * (xOffset / self.HalfNearPlaneWidth) + 0.5
		local yAlpha = 1 - (0.5 * (yOffset / self.HalfNearPlaneHeight) + 0.5)
	
		local screenPosition = self.ViewportSize * Vector2.new(xAlpha, yAlpha)
		screenPosition = Vector2.new(math.round(screenPosition.X), math.round(screenPosition.Y))
		local isVisible = math.sign(offset.Z) == -1 and (screenPosition.X >= 0 and screenPosition.X <= self.ViewportSize.X) and (screenPosition.Y >= 0 and screenPosition.Y <= self.ViewportSize.Y)
	
		return Vector3.new(screenPosition.X, screenPosition.Y, math.sign(offset.Z)), isVisible
	else
		return self.Camera:WorldToViewportPoint(point)
	end
end


function Frustum:_GetIfPointIsCloseEnough(point: Vector3): boolean
	local offset = self.CFrame:PointToObjectSpace(point)
	return offset.Z <= self.FarPlaneDistance
end

function Frustum:GetIfPointRendered(point: Vector3): boolean
	return self:GetIfSphereRendered(point, 0)
end

function Frustum:GetIfRayRendered(ray: Ray): boolean
	if not self:GetIfSphereRendered(ray.Origin + ray.Direction/2, ray.Direction.Magnitude/2) then return false end

	if self:GetIfPointRendered(ray.Origin) then
		return true
	end

	if self:GetIfPointRendered(ray.Origin + ray.Direction) then
		return true
	end

	for _, plane in pairs(self.Planes) do
		local intersection = getPlaneIntersection(
			plane.Origin,
			plane.Normal,
			ray.Origin, 
			ray.Direction
		)

		if intersection then
			local _screenPos, isVisible = self:GetViewportPosition(intersection)
			if isVisible then
				return true
			end
		end
	end

	return false
end

function Frustum:GetOuterBlockBounds(cf: CFrame, size: Vector3): Rect
	local min = Vector2.new(math.huge, math.huge)
	local max = -Vector2.new(math.huge, math.huge)

	local function compare(v: Vector3)
		if v.X < min.X then
			min = Vector2.new(v.X, min.Y)
		end
		if v.Y < min.Y then
			min = Vector2.new(min.X, v.Y)
		end
		if v.X > max.X then
			max = Vector2.new(v.X, max.Y)
		end
		if v.Y > max.Y then
			max = Vector2.new(max.X, v.Y)
		end
	end

	local lVec = self.CFrame.LookVector
	for i, vectors in ipairs({
		{cf.RightVector * size.X, -cf.LookVector * size.Z, cf.UpVector * size.Y},
		{cf.UpVector * size.Y, cf.RightVector * size.X, -cf.LookVector * size.Z},
		{-cf.LookVector * size.Z, cf.RightVector * size.X, cf.UpVector * size.Y}
	}) do
		local xVec = vectors[2]
		local yVec = vectors[3]

		local zVec = vectors[1]
		if zVec:Dot(lVec) > 0 then
			zVec *= -1
		end
		local position = cf.Position + zVec / 2

		local c1 = position + (xVec/2) + (yVec/2)
		local s1, _ = self:GetViewportPosition(c1)
		compare(s1)
		local c2 = position - (xVec/2) + (yVec/2)
		local s2, _ = self:GetViewportPosition(c2)
		compare(s2)

		local c3 = position + (xVec/2) - (yVec/2)
		local s3, _ = self:GetViewportPosition(c3)
		compare(s3)

		local c4 = position - (xVec/2) - (yVec/2)
		local s4, _ = self:GetViewportPosition(c4)
		compare(s4)
	end

	return Rect.new(min, max)
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

function Frustum:GetIfRectangleRendered(a: Vector3, b: Vector3, c: Vector3, d: Vector3): boolean
	local pos = (a:Lerp(b, 0.5)):Lerp((c:Lerp(d, 0.5)), 0.5)
	local radius = math.max((pos-a).Magnitude, (pos-b).Magnitude, (pos-c).Magnitude, (pos-d).Magnitude)
	if not self:GetIfSphereRendered(pos, radius) then return false end
	if self:GetIfPointRendered(a) then return true end
	if self:GetIfPointRendered(b) then return true end
	if self:GetIfPointRendered(c) then return true end
	if self:GetIfPointRendered(d) then return true end

	for i, ray in ipairs(self.Rays) do
		local intersection = getRectangleIntersection(ray.Origin, ray.Direction, a, b, c, d) 
		if intersection then
			return true
		end
	end

	return false
end

function Frustum:GetIfTriangleRendered(a: Vector3, b: Vector3, c: Vector3): boolean
	local pos = (a:Lerp(b, 0.5)):Lerp(c, 1/3)
	local radius = math.max((pos-a).Magnitude, (pos-b).Magnitude, (pos-c).Magnitude)
	if not self:GetIfSphereRendered(pos, radius) then return false end

	if self:GetIfPointRendered(a) then return true end
	if self:GetIfPointRendered(b) then return true end
	if self:GetIfPointRendered(c) then return true end

	for i, ray in ipairs(self.Rays) do
		local intersection = getTriangleIntersection(ray.Origin, ray.Direction, a, b, c) 
		if intersection then
			return true
		end
	end
	return false
end

function Frustum:GetIfPlaneRendered(origin: Vector3, normal: Vector3): boolean
	for i, ray in ipairs(self.Rays) do
		local intersection = getPlaneIntersection(
			origin, 
			normal,
			ray.Origin, 
			ray.Direction
		)

		if intersection then
			return true
		end
	end

	return false
end

function Frustum:GetIfBlockRendered(cf: CFrame, size: Vector3): boolean	

	if self:GetIfSphereRendered(cf.Position, size.Magnitude/2) then

		local lVec = self.CFrame.LookVector

		for i, vectors in ipairs({
			{cf.RightVector * size.X, -cf.LookVector * size.Z, cf.UpVector * size.Y},
			{cf.UpVector * size.Y, cf.RightVector * size.X, -cf.LookVector * size.Z},
			{-cf.LookVector * size.Z, cf.RightVector * size.X, cf.UpVector * size.Y}
		}) do
			local xVec = vectors[2]
			local yVec = vectors[3]

			local function solveFace(zVec: Vector3): boolean
				local position = cf.Position + zVec / 2

				local c1 = position + (xVec/2) + (yVec/2)
				if self:GetIfPointRendered(c1) then return true end
	
				local c2 = position - (xVec/2) + (yVec/2)
				if self:GetIfPointRendered(c2) then return true end
	
				local c3 = position + (xVec/2) - (yVec/2)
				if self:GetIfPointRendered(c3) then return true end
	
				local c4 = position - (xVec/2) - (yVec/2)
				if self:GetIfPointRendered(c4) then return true end
		
				if self:GetIfRectangleRendered(c1, c2, c3, c4) then
					return true
				end
				return false
			end
			if vectors[1]:Dot(lVec) < 0 then
				if solveFace(vectors[1]) then
					return true
				end
			else
				if solveFace(-vectors[1]) then
					return true
				end
			end
		end
	end

	return false
end

function Frustum:GetIfPartRendered(part: BasePart)
	if RENDER_PARTS_AS_SPHERE then
		return self:GetIfSphereRendered(part.Position, part.Size.Magnitude/2)
	else
		if part:IsA("Part") then
			if part.Shape == Enum.PartType.Ball then
				return self:GetIfSphereRendered(part.Position, part.Size.Magnitude/2)
			else
				return self:GetIfBlockRendered(part.CFrame, part.Size)
			end
		else
			return self:GetIfBlockRendered(part.CFrame, part.Size)
		end
	end
end

function Frustum:Draw(): Folder
	local folder = Instance.new("Folder")
	local function line(origin: Vector3, direction: Vector3, color: Color3)
		local vec = Draw.vector(origin, direction, color, folder, 2)
		vec.Locked = true
		vec.Archivable = false
	end

	for i, ray in ipairs(self.Rays) do
		line(ray.Origin, ray.Direction, Color3.new(1,0,1))
	end

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
	self.HalfHorizontalFieldOfView = self.AspectRatio * self.HalfFieldOfView

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

	self.Rays = {
		Ray.new(self.FarTopLeft, self.FarTopRight - self.FarTopLeft),
		Ray.new(self.FarTopLeft, self.NearTopLeft - self.FarTopLeft),
		Ray.new(self.FarTopRight, self.NearTopRight - self.FarTopRight),
		Ray.new(self.NearTopLeft, self.NearTopRight - self.NearTopLeft),

		Ray.new(self.FarBottomLeft, self.FarBottomRight - self.FarBottomLeft),
		Ray.new(self.FarBottomLeft, self.NearBottomLeft - self.FarBottomLeft),
		Ray.new(self.FarBottomRight, self.NearBottomRight - self.FarBottomRight),
		Ray.new(self.NearBottomLeft, self.NearBottomRight - self.NearBottomLeft),

		Ray.new(self.NearBottomLeft, self.NearTopLeft - self.NearBottomLeft),
		Ray.new(self.FarBottomLeft, self.FarTopLeft - self.FarBottomLeft),
		Ray.new(self.NearBottomRight, self.NearTopRight - self.NearBottomRight),
		Ray.new(self.FarBottomRight, self.FarTopRight - self.FarBottomRight),
	}


	table.freeze(self.Planes)
	table.freeze(self.Rays)

	table.freeze(self)

	return self
end

return Frustum