--!strict
-- Huge thanks to @MrChickenRocket for a lot of the initial math here: https://gist.github.com/MrChickenRocket/09050693faee256888313c04d93cbb08
local _Package = script.Parent
local _Packages = _Package.Parent

-- Services

-- Packages
local Draw = require(_Packages:WaitForChild("Draw"))

-- Modules
local Config = require(_Package:WaitForChild("Config"))
local PerspectiveUtil = require(_Package:WaitForChild("PerspectiveUtil"))
local ShapeUtil = require(_Package:WaitForChild("ShapeUtil"))

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
export type Triangle = {
	A: Vector2,
	B: Vector2,
	C: Vector2
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
	GetBlockShadow: (self: Frustum, cf: CFrame, size: Vector3) -> {[number]: Triangle},
	GetProjectedShape: (self: Frustum, cf: CFrame, size: Vector3) -> {[number]: Vector2},
	GetViewportPosition: (self: Frustum, point: Vector3) -> (Vector3, boolean, boolean),
	_GetIfPointIsCloseEnough: (self: Frustum, point: Vector3) -> boolean,
	GetIfPointRendered: (self: Frustum, point: Vector3) -> boolean,
	GetIfRectangleRendered: (self: Frustum, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> boolean,
	GetIfTriangleRendered: (self: Frustum, a: Vector3, b: Vector3, c: Vector3) -> boolean,
	GetIfRayRendered: (self: Frustum, ray: Ray) -> boolean,
	GetIfSphereRendered: (self: Frustum, origin: Vector3, radius: number) -> boolean,
	GetIfBlockRendered: (self: Frustum, cf: CFrame, size: Vector3) -> boolean,
	GetIfPlaneRendered: (self: Frustum, origin: Vector3, normal: Vector3) -> boolean,
	GetIfOverlapFrustum: (self: Frustum, part: BasePart) -> boolean,
	GetOuterBlockBounds: (self: Frustum, perimeter: {[number]: Vector2}) -> Rect,
	GetInnerBlockBounds: (self: Frustum, perimeter: {[number]: Vector2}) -> Rect,
	Draw: (self: Frustum) -> Folder,
	new: (camera: Camera, farPlaneZ: number) -> Frustum,
}
-- Constants
local USE_EXACT_CULLING = Config.Debug.UseExactCulling
-- local USE_CUSTOM_VIEWPORT_MATH = true

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

function Frustum:GetViewportPosition(point: Vector3): (Vector3, boolean, boolean)
	-- if USE_CUSTOM_VIEWPORT_MATH then
	return PerspectiveUtil.toViewportPoint(
		point,
		self.CFrame,
		self.Camera.FieldOfView,
		self.ViewportSize,
		self.NearPlaneZ
	)
	-- else
	-- 	return self.Camera:WorldToViewportPoint(point)
	-- end
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

function Frustum:GetBlockShadow(cf: CFrame, size: Vector3): {[number]: Triangle}
	local worldTriangles = PerspectiveUtil.getWorldTriangles(cf, size, self.CFrame)
	local triangles: {[number]: Triangle} = {}
	
	for i, tri in ipairs(worldTriangles) do
		local a, _ = self:GetViewportPosition(tri.A)
		local b, _ = self:GetViewportPosition(tri.B)
		local c, _ = self:GetViewportPosition(tri.C)
		triangles[i] = {
			A = Vector2.new(
				math.round(a.X),
				math.round(a.Y)
			),
			B = Vector2.new(
				math.round(b.X),
				math.round(b.Y)
			),
			C = Vector2.new(
				math.round(c.X),
				math.round(c.Y)
			),
		}
	end

	return triangles
end

function Frustum:GetProjectedShape(cf: CFrame, size: Vector3): {[number]: Vector2}

	local points: {[number]: Vector2} = {}
	local visibility: {[number]: boolean} = {}
	local inversion: {[number]: boolean} = {}
	local offsets: {[number]: Vector3} = {}

	local perimeter = PerspectiveUtil.getWorldPerimeter(cf, size, self.CFrame)
	local areAnyInverted = false
	local maxDist = self.ViewportSize.Magnitude

	for i, v in ipairs(perimeter) do

		local offset = cf:PointToObjectSpace(v)
		local surfacePoint, isVisible, isInverted = self:GetViewportPosition(v)
		if isInverted then
			areAnyInverted = true
		end
		
		-- if surfacePoint.Magnitude > 0 then
		-- 	surfacePoint = surfacePoint.Unit * math.min(surfacePoint.Magnitude, maxDist)
		-- end

		local point = Vector2.new(
			math.round(surfacePoint.X),
			math.round(surfacePoint.Y)
		)
		points[i] = point
		visibility[i] = isVisible
		inversion[i] = isInverted
		offsets[i] = offset
	end


	if areAnyInverted then

		local finalPoints: {[number]: Vector2} = {}

		local planeOrigin = (self.CFrame * CFrame.new(0,0,self.NearPlaneZ)).Position

		for i, v in ipairs(perimeter) do
			-- print(`\ni={i}, inversion[i]={inversion[i]}`)
			if inversion[i] == true then
				local pI = if i-1 < 1 then #points else i-1
				-- print(`pi={pI}`)
				local nI = if i+1 > #points then 1 else i+1
				-- print(`nI={nI}`)

				local function addPoint(origin: Vector3, direction: Vector3, index: number)
					-- direction = direction.Unit
					local intersection = getPlaneIntersection(
						planeOrigin,
						-self.CFrame.LookVector,
						origin,
						direction
					)
					-- print(`intersection={intersection}`)
					if not intersection then
						intersection = origin + direction
						-- print(`maxxed={intersection}`)
					end
					assert(intersection)

					local surfacePoint, _isVisible, _isInverted = self:GetViewportPosition(intersection - direction.Unit*0.0015)
					local sP2 = Vector2.new(
						(surfacePoint.X),
						(surfacePoint.Y)
					)
					sP2 = ((sP2 - points[index]).Unit * maxDist * 3) + points[index]
					-- print(`surfacePoint={surfacePoint}, isVisible={_isVisible}, isInverted={_isInverted}`)

					finalPoints[i] = Vector2.new(
						math.round(sP2.X),
						math.round(sP2.Y)
					)
				end

				-- print(`inversion[pI]={inversion[pI]}`)
				-- print(`inversion[nI]={inversion[nI]}`)
				if inversion[pI] == false then

					local pV = perimeter[pI]
					local direction = v - pV
					-- print(`pV={pV}`)
					-- print(`direction={direction}`)
					addPoint(pV, direction, pI)
				elseif inversion[nI] == false then
					local nV = perimeter[nI]
					local direction = v - nV
					-- print(`nV={nV}`)
					-- print(`direction={direction}`)
					addPoint(nV, direction, nI)
				else
					-- print(`edit failed, adding original point`)

					finalPoints[i] = points[i]
				end
			else
				-- print(`no edit needed, adding original point`)

				finalPoints[i] = points[i]
			end
		end
		-- print(finalPoints)
		return finalPoints
	end


	return points
end

function Frustum:GetOuterBlockBounds(perimeter: {[number]: Vector2}): Rect
	return ShapeUtil.getOuterBounds(perimeter)
end

function Frustum:GetInnerBlockBounds(perimeter: {[number]: Vector2}): Rect
	return ShapeUtil.getInnerBounds(perimeter, self.ViewportSize)
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

function Frustum:GetIfOverlapFrustum(part: BasePart)
	if not USE_EXACT_CULLING then
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