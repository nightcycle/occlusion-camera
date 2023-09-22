--!strict
local _Package = script
local _Packages = _Package.Parent
-- Services
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

-- Packages
local Maid = require(_Packages:WaitForChild("Maid"))
local Signal = require(_Packages:WaitForChild("Signal"))
local Draw = require(_Packages:WaitForChild("Draw"))


-- Modules
local Config = require(_Package:WaitForChild("Config"))
local Frustum = require(_Package:WaitForChild("Frustum"))

-- Types
-- Constants
local DEBUG_DRAW = false --_Package:GetFullName() == "ReplicatedStorage.Packages.package"
local IN_FRUSTUM_TAG = Config.Tag.InFrustum
local OBSCURED_TAG = Config.Tag.Obscured
local INITIAL_OBSCURED_TAG = Config.Tag.InitialObscured
local VISIBLE_TAG = Config.Tag.Visible
local LAST_SEEN_ATTR_KEY = Config.Attribute.LastSeen
local PROCESS_LIMIT = 3
-- Variables
-- References
-- Private Functions
-- Class
-- Types
type Signal = Signal.Signal
type Maid = Maid.Maid
export type OcclusionCamera = {
	__index: OcclusionCamera,
	_Maid: Maid,
	_IsAlive: boolean,
	Instance: Camera,
	MaxRenderDistance: number,
	OnlyUpdateOnCameraMove: boolean,
	SampleCount: number,
	WorldRoot: WorldRoot,
	RaycastParams: RaycastParams,
	ObscureDelay: number,
	OnViewPart: Signal,
	OnObscurePart: Signal,
	OnPartExitFrustum: Signal,
	OnPartEnterFrustum: Signal,
	NoOccludeTag: string,
	GetVisibleParts: (self: OcclusionCamera) -> {[number]: BasePart},
	GetObscuredParts: (self: OcclusionCamera) -> {[number]: BasePart},
	GetPartsInFrustum: (self: OcclusionCamera) -> {[number]: BasePart},
	GetIfPartIsVisible: (self: OcclusionCamera, part: BasePart) -> boolean,
	GetIfPartIsObscured: (self: OcclusionCamera, part: BasePart) -> boolean,
	GetIfPartIsInFrustum: (self: OcclusionCamera, part: BasePart) -> boolean,
	Destroy: (self: OcclusionCamera) -> (),
	new: (camera: Camera) -> OcclusionCamera,
}

-- Class
local OcclusionCamera = {} :: OcclusionCamera
OcclusionCamera.__index = OcclusionCamera

function OcclusionCamera:Destroy()
	if not self._IsAlive then return end
	self._IsAlive = false
	self._Maid:Destroy()
	local t: any = self
	for k, v in pairs(t) do
		t[k] = nil
	end
	setmetatable(t, nil)
end

function OcclusionCamera:GetIfPartIsVisible(part: BasePart): boolean
	return CollectionService:HasTag(part, VISIBLE_TAG)
end

function OcclusionCamera:GetIfPartIsObscured(part: BasePart): boolean
	return CollectionService:HasTag(part, OBSCURED_TAG)
end

function OcclusionCamera:GetIfPartIsInFrustum(part: BasePart): boolean
	return CollectionService:HasTag(part, IN_FRUSTUM_TAG)
end

function OcclusionCamera:GetVisibleParts(): {[number]: BasePart}
	return CollectionService:GetTagged(VISIBLE_TAG) :: {[number]: any}
end

function OcclusionCamera:GetPartsInFrustum(): {[number]: BasePart}
	return CollectionService:GetTagged(IN_FRUSTUM_TAG) :: {[number]: any}
end

function OcclusionCamera:GetObscuredParts(): {[number]: BasePart}
	return CollectionService:GetTagged(OBSCURED_TAG) :: {[number]: any}
end

function OcclusionCamera.new(camera: Camera): OcclusionCamera

	local self: OcclusionCamera = setmetatable({}, OcclusionCamera) :: any
	self._IsAlive = true
	self._Maid = Maid.new()
	self.MaxRenderDistance = 512
	self.Instance = camera
	self.OnlyUpdateOnCameraMove = true
	self.SampleCount = 256
	self.WorldRoot = workspace
	self.NoOccludeTag = "OcclusionCameraNoOcclude"

	self.OnViewPart = self._Maid:GiveTask(Signal.new())
	self.OnObscurePart = self._Maid:GiveTask(Signal.new())
	self.OnPartExitFrustum = self._Maid:GiveTask(Signal.new())
	self.OnPartEnterFrustum = self._Maid:GiveTask(Signal.new())

	self.ObscureDelay = 1

	self.RaycastParams = RaycastParams.new()
	self.RaycastParams.FilterType = Enum.RaycastFilterType.Include
	self.RaycastParams.FilterDescendantsInstances = {}
	self.RaycastParams.IgnoreWater = false
	self.RaycastParams.RespectCanCollide = false

	local prevCF: CFrame?

	local function onVisibleTag(inst: Instance)
		assert(inst:IsA("BasePart"))
		self.OnViewPart:Fire(inst)
	end

	self._Maid:GiveTask(CollectionService:GetInstanceAddedSignal(VISIBLE_TAG):Connect(onVisibleTag))
	for i, inst in ipairs(CollectionService:GetTagged(VISIBLE_TAG)) do
		onVisibleTag(inst)
	end

	local function onInitialObscureTag(inst: Instance)
		assert(inst:IsA("BasePart"))
		if self.ObscureDelay > 0 then
			task.wait(self.ObscureDelay)

			if CollectionService:HasTag(inst, INITIAL_OBSCURED_TAG) and self._IsAlive then
				if not CollectionService:HasTag(inst, OBSCURED_TAG) then
					CollectionService:AddTag(inst, OBSCURED_TAG)
				end
			end
		else
			if not CollectionService:HasTag(inst, OBSCURED_TAG) then
				CollectionService:AddTag(inst, OBSCURED_TAG)
			end
		end
	end

	self._Maid:GiveTask(CollectionService:GetInstanceAddedSignal(INITIAL_OBSCURED_TAG):Connect(onInitialObscureTag))
	for i, inst in ipairs(CollectionService:GetTagged(INITIAL_OBSCURED_TAG)) do
		onInitialObscureTag(inst)
	end


	local function onObscureTag(inst: Instance)
		assert(inst:IsA("BasePart"))
		self.OnObscurePart:Fire(inst)
	end
	self._Maid:GiveTask(CollectionService:GetInstanceAddedSignal(OBSCURED_TAG):Connect(onObscureTag))
	for i, inst in ipairs(CollectionService:GetTagged(OBSCURED_TAG)) do
		onObscureTag(inst)
	end

	local function onFrustumTag(inst: Instance)
		assert(inst:IsA("BasePart"))
		self.OnPartEnterFrustum:Fire(inst)
	end

	self._Maid:GiveTask(CollectionService:GetInstanceAddedSignal(IN_FRUSTUM_TAG):Connect(onFrustumTag))
	for i, inst in ipairs(CollectionService:GetTagged(IN_FRUSTUM_TAG)) do
		onFrustumTag(inst)
	end

	local function onRemoveFrustumTag(inst: Instance)
		if not inst:IsDescendantOf(game) then return end
		inst:SetAttribute(LAST_SEEN_ATTR_KEY, nil)
		if CollectionService:HasTag(inst, OBSCURED_TAG) then
			CollectionService:RemoveTag(inst, OBSCURED_TAG)
		end
		if CollectionService:HasTag(inst, INITIAL_OBSCURED_TAG) then
			CollectionService:RemoveTag(inst, INITIAL_OBSCURED_TAG)
		end
		if CollectionService:HasTag(inst, VISIBLE_TAG) then
			CollectionService:RemoveTag(inst, VISIBLE_TAG)
		end
		self.OnPartExitFrustum:Fire(inst)
	end
	self._Maid:GiveTask(CollectionService:GetInstanceRemovedSignal(IN_FRUSTUM_TAG):Connect(onRemoveFrustumTag))

	local total = {}
	local steps = 0

	self._Maid:GiveTask(RunService.PreRender:Connect(function(deltaTime: number)
		if prevCF ~= self.Instance:GetRenderCFrame() or self.OnlyUpdateOnCameraMove == false then
			prevCF = self.Instance:GetRenderCFrame()
			steps += 1
			task.delay(1, function()
				steps -= 1
			end)
			-- local a = tick()

			local frustum = Frustum.new(self.Instance, self.MaxRenderDistance)

			-- local a2 = tick()
			-- self.Instance:SetAttribute("Construction", math.round(1000*(a2-a)/(1/60)))

			if DEBUG_DRAW then
				self._Maid._frustumDraw = frustum:Draw()
			end

			-- local a3 = tick()
			-- self.Instance:SetAttribute("Draw", math.round(1000*(a3-a2)/(1/60)))

			local speedTest: {[string]: number} = {}
			local census: {[string]: number} = {}
			for i, inst in ipairs(self.RaycastParams.FilterDescendantsInstances) do
				if inst:IsA("BasePart") then
					local isInFrustum: boolean
					speedTest[inst.Name] = speedTest[inst.Name] or 0
					census[inst.Name] = census[inst.Name] or 0
					local start = tick()
					if inst.Name == "Block" then
						isInFrustum = frustum:GetIfBlockRendered(inst.CFrame, inst.Size)
					elseif inst.Name == "Ray" then
						isInFrustum = frustum:GetIfRayRendered(
							Ray.new(
								(inst.CFrame * CFrame.new(-inst.Size.X/2,0,0)).Position,
								inst.CFrame.RightVector * inst.Size.X
							)
						)
					elseif inst.Name == "Sphere" then
						isInFrustum = frustum:GetIfSphereRendered(
							inst.Position,
							math.min(inst.Size.X, inst.Size.Y, inst.Size.Z)/2
						)
					elseif inst.Name == "Point" then
						isInFrustum = frustum:GetIfPointRendered(
							inst.Position
						)
					elseif inst.Name == "Plane" then
						isInFrustum = frustum:GetIfPlaneRendered(
							inst.Position,
							inst.CFrame.UpVector
						)
					elseif inst.Name == "SquareSurface" then
						local xVec = inst.CFrame.RightVector * inst.Size.X
						local yVec = inst.CFrame.LookVector * inst.Size.Z

						local position = inst.CFrame.Position
			
						local c1 = position + (xVec/2) + (yVec/2)
						local c2 = position - (xVec/2) + (yVec/2)	
						local c3 = position + (xVec/2) - (yVec/2)
						local c4 = position - (xVec/2) - (yVec/2)

						isInFrustum = frustum:GetIfRectangleRendered(
							c1, c2, c3, c4
						)
					elseif inst.Name == "TriangleSurface" then
						local position = inst.CFrame.Position
						local xVec = inst.CFrame.LookVector * inst.Size.Z
						local yVec = inst.CFrame.UpVector * inst.Size.Y

						local c1 = position - (xVec/2) - (yVec/2)
						local c2 = position - (xVec/2) + (yVec/2)	
						local c3 = position + (xVec/2) - (yVec/2)

						isInFrustum = frustum:GetIfTriangleRendered(
							c1, c2, c3
						)
					end
					speedTest[inst.Name] += 100*(tick() - start)
					census[inst.Name] += 1
					if isInFrustum == nil then
						inst.Color = Color3.new(1,0,0)
					else
						inst.Color = if isInFrustum then Color3.new(1,0.5,0) else Color3.new(0,0.5,1)
					end
					local decal = inst:FindFirstChildOfClass("Decal")
					if decal then
						decal.Color3 = inst.Color
					end
				end
			end

			-- local b = tick()
			-- self.Instance:SetAttribute("Cast", math.round(1000*(b-a3)/(1/60)))
			for k, v in pairs(speedTest) do
				local value = (1/120)/(v / census[k])
				total[k] = total[k] or 0
				total[k] += value
				if total[k] then
					self.Instance:SetAttribute(k, math.round(total[k]/steps))
				end
				task.delay(1, function()
					total[k] -= value
				end)
			end

			-- local tagged = CollectionService:GetTagged(IN_FRUSTUM_TAG)
			-- table.sort(tagged, function(a: Instance, b: Instance)
			-- 	local aTick = a:GetAttribute(LAST_SEEN_ATTR_KEY)
			-- 	local bTick = b:GetAttribute(LAST_SEEN_ATTR_KEY)
			-- 	if bTick and aTick then
			-- 		return aTick < bTick
			-- 	elseif bTick then
			-- 		return false
			-- 	elseif aTick then
			-- 		return true
			-- 	else
			-- 		return false
			-- 	end
			-- end)

			-- local c = tick()
			-- self.Instance:SetAttribute("Sort", math.round(1000*(c-b)/(1/60)))


			-- local t = tick()
			-- for i, inst in ipairs(tagged) do
			-- 	if i > PROCESS_LIMIT then
			-- 		break
			-- 	end
			-- 	local lastSeen = inst:GetAttribute(LAST_SEEN_ATTR_KEY)
			-- 	if lastSeen then
			-- 		if t-lastSeen > self.ObscureDelay then
			-- 			if CollectionService:HasTag(inst, IN_FRUSTUM_TAG) then
			-- 				CollectionService:RemoveTag(inst, IN_FRUSTUM_TAG)
			-- 			end
			-- 		end
			-- 	else
			-- 		if CollectionService:HasTag(inst, IN_FRUSTUM_TAG) then
			-- 			CollectionService:RemoveTag(inst, IN_FRUSTUM_TAG)
			-- 		end
			-- 	end
			-- end
			-- local d = tick()
			-- self.Instance:SetAttribute("Filter", math.round(1000*(d-c)/(1/60)))
		end
	end))



	return self
end


return OcclusionCamera