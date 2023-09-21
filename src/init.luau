--!strict
local _Package = script
local _Packages = _Package.Parent
-- Services
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

-- Packages
local Maid = require(_Packages:WaitForChild("Maid"))
local Signal = require(_Packages:WaitForChild("Signal"))
local TableUtil = require(_Packages:WaitForChild("TableUtil"))


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

	self._Maid:GiveTask(RunService.PreRender:Connect(function(deltaTime: number)
		if prevCF ~= self.Instance:GetRenderCFrame() or self.OnlyUpdateOnCameraMove == false then
			prevCF = self.Instance:GetRenderCFrame()
	
			local a = tick()

			local frustum = Frustum.new(self.Instance, self.MaxRenderDistance)

			local a2 = tick()
			self.Instance:SetAttribute("Construction", math.round(1000*(a2-a)/(1/60)))

			if DEBUG_DRAW then
				self._Maid._frustumDraw = frustum:Draw()
			end

			local a3 = tick()
			self.Instance:SetAttribute("Draw", math.round(1000*(a3-a2)/(1/60)))

			frustum:TagCast(
				self.SampleCount, 
				self.RaycastParams, 
				self.WorldRoot, 
				self.NoOccludeTag
			)
			local b = tick()
			self.Instance:SetAttribute("Cast", math.round(1000*(b-a3)/(1/60)))

			local tagged = CollectionService:GetTagged(IN_FRUSTUM_TAG)
			table.sort(tagged, function(a: Instance, b: Instance)
				local aTick = a:GetAttribute(LAST_SEEN_ATTR_KEY)
				local bTick = b:GetAttribute(LAST_SEEN_ATTR_KEY)
				if bTick and aTick then
					return aTick < bTick
				elseif bTick then
					return false
				elseif aTick then
					return true
				else
					return false
				end
			end)

			local c = tick()
			self.Instance:SetAttribute("Sort", math.round(1000*(c-b)/(1/60)))


			local t = tick()
			for i, inst in ipairs(tagged) do
				if i > PROCESS_LIMIT then
					break
				end
				local lastSeen = inst:GetAttribute(LAST_SEEN_ATTR_KEY)
				if lastSeen then
					if t-lastSeen > self.ObscureDelay then
						if CollectionService:HasTag(inst, IN_FRUSTUM_TAG) then
							CollectionService:RemoveTag(inst, IN_FRUSTUM_TAG)
						end
					end
				else
					if CollectionService:HasTag(inst, IN_FRUSTUM_TAG) then
						CollectionService:RemoveTag(inst, IN_FRUSTUM_TAG)
					end
				end
			end
			local d = tick()
			self.Instance:SetAttribute("Filter", math.round(1000*(d-c)/(1/60)))
		end
	end))

	self._Maid:GiveTask(CollectionService:GetInstanceAddedSignal(VISIBLE_TAG):Connect(function(inst: Instance)
		assert(inst:IsA("BasePart"))
		self.OnViewPart:Fire(inst)
	end))

	self._Maid:GiveTask(CollectionService:GetInstanceAddedSignal(INITIAL_OBSCURED_TAG):Connect(function(inst: Instance)
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
	end))
	self._Maid:GiveTask(CollectionService:GetInstanceAddedSignal(OBSCURED_TAG):Connect(function(inst: Instance)
		assert(inst:IsA("BasePart"))
		self.OnObscurePart:Fire(inst)
	end))

	self._Maid:GiveTask(CollectionService:GetInstanceAddedSignal(IN_FRUSTUM_TAG):Connect(function(inst: Instance)
		assert(inst:IsA("BasePart"))
		self.OnPartEnterFrustum:Fire(inst)
	end))

	self._Maid:GiveTask(CollectionService:GetInstanceRemovedSignal(IN_FRUSTUM_TAG):Connect(function(inst: Instance)
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
	end))

	return self
end


return OcclusionCamera