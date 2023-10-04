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
local NO_DEBUG_RENDER = Config.Debug.NoDebugRender
local DEBUG_OCCLUSION = Config.Debug.Occlusion
local DEBUG_CULLING = Config.Debug.Culling
local IN_FRUSTUM_TAG = Config.Tag.InFrustum
local OBSCURED_TAG = Config.Tag.Obscured
local INITIAL_OBSCURED_TAG = Config.Tag.InitialObscured
local VISIBLE_TAG = Config.Tag.Visible
local LAST_SEEN_ATTR_KEY = Config.Attribute.LastSeen
local PROCESS_LIMIT = 10
local RENDER_DURATION = 0.5/60
-- Variables
-- References
-- Private Functions

-- Class
-- Types
type Signal = Signal.Signal
type Maid = Maid.Maid
type Frustum = Frustum.Frustum
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
	frustum: (camera: Camera, maxRenderDistance: number) -> Frustum,
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

	if DEBUG_CULLING or DEBUG_OCCLUSION then
					
		local function toMilliseconds(v: number): number
			return math.round(1000*10000*v)/10000
		end

		if DEBUG_CULLING then
			local debugInstances: {[number]: Instance} = workspace:WaitForChild("Map"):GetChildren()
			self._Maid:GiveTask(function()
				for i, inst in ipairs(debugInstances) do
					if inst:IsA("BasePart") then
						inst.Color = Color3.fromHSV(1,0,0.75)
					end
				end
			end)
			self._Maid:GiveTask(RunService.PreRender:Connect(function(deltaTime: number)
				local frustum = Frustum.new(self.Instance, self.MaxRenderDistance)

				if not NO_DEBUG_RENDER then
					self._Maid._frustumDraw = frustum:Draw()
				end

				local measurements: {[string]: {[number]: number}} = {}
				for i, inst in ipairs(debugInstances) do
					if inst:IsA("BasePart") then
						measurements[inst.Name] = measurements[inst.Name] or {}
						local start = tick()
						local isInFrustum: boolean = frustum:GetIfPartRendered(inst)
						local finish = tick()
						table.insert(measurements[inst.Name], finish - start)
						if not NO_DEBUG_RENDER then
							inst.Color = if not isInFrustum then Color3.new(0,0.5,1) else Color3.fromHSV(0,0.75,1)
						end
					end
				end
				
				local netSum = 0
				local netCount = 0
				for k, vList in pairs(measurements) do
					local sum = 0
					local count = #vList
					for i, v in ipairs(vList) do
						sum += v
					end
					netSum += sum
					netCount += count
					local duration = sum/count
					self.Instance:SetAttribute(`_{k}_ms`, toMilliseconds(duration))
					self.Instance:SetAttribute(`_{k}_limit`, math.floor(RENDER_DURATION/duration))

				end

				local netDuration = netSum/netCount
				self.Instance:SetAttribute(`net_ms`, toMilliseconds(netDuration))
				self.Instance:SetAttribute(`net_limit`, math.floor(RENDER_DURATION/netDuration))

			end))
		else
			local parts: {[number]: BasePart} = workspace:WaitForChild("SmallerMap"):GetChildren() :: any
			for i, part in ipairs(parts) do
				assert(part:IsA("BasePart"), `inst {part:GetFullName()} isn't a basePart`)
			end

			self._Maid:GiveTask(RunService.PreRender:Connect(function(deltaTime: number)

				local frustum = Frustum.new(self.Instance, self.MaxRenderDistance)
		
				local measurements: {[string]: {[number]: number}} = {}

				local rectRegistry: {[BasePart]: Rect} = {}
				for i, part in ipairs(parts) do
					measurements[part.Name] = measurements[part.Name] or {}

					local start = tick()
					local rect = frustum:GetOuterBlockBounds(part.CFrame, part.Size)
					local finish = tick()
					table.insert(measurements[part.Name], finish - start)
					rectRegistry[part] = rect
				end
	
				do
					local netSum = 0
					local netCount = 0
					for k, vList in pairs(measurements) do
						local sum = 0
						local count = #vList
						for i, v in ipairs(vList) do
							sum += v
						end
						netSum += sum
						netCount += count
						local duration = sum/count
						self.Instance:SetAttribute(`_outbounds_{k}_ms`, toMilliseconds(duration))
						self.Instance:SetAttribute(`_outbounds_{k}_limit`, math.floor(RENDER_DURATION/duration))

					end

					local netDuration = netSum/netCount
					self.Instance:SetAttribute(`outbounds_net_ms`, toMilliseconds(netDuration))
					self.Instance:SetAttribute(`outbounds_net_limit`, math.floor(RENDER_DURATION/netDuration))
				end

				table.sort(parts, function(a: BasePart, b: BasePart): boolean
					local aR = rectRegistry[a]
					local bR = rectRegistry[b]
					return (aR.Min - aR.Max).Magnitude > (bR.Min - bR.Max).Magnitude
				end)
	
				if DEBUG_OCCLUSION and not NO_DEBUG_RENDER then
	
					local screen = Instance.new("ScreenGui")
	
					for k, rect in pairs(rectRegistry) do
						local frame = Instance.new("Frame")
						frame.BorderSizePixel = 2
						frame.BackgroundTransparency = 0.7
						frame.Position = UDim2.fromOffset(
							rect.Min.X + rect.Width/2, 
							rect.Min.Y + rect.Height/2
						)
						frame.AnchorPoint = Vector2.new(0.5,0.5)
						frame.Size = UDim2.fromOffset(rect.Width, rect.Height)
						frame.Parent = screen
					end
	
					screen.Parent = game:GetService("CoreGui")
	
					self._Maid._screen = screen
				end
			end))
		end
	else
		self._Maid:GiveTask(RunService.PreRender:Connect(function(deltaTime: number)
			if prevCF ~= self.Instance:GetRenderCFrame() or self.OnlyUpdateOnCameraMove == false then
				prevCF = self.Instance:GetRenderCFrame()
				local t = tick()
				local frustum = Frustum.new(self.Instance, self.MaxRenderDistance)

				local parts: {[number]: BasePart} = {}

				if not NO_DEBUG_RENDER then
					self._Maid._frustumDraw = frustum:Draw()
				end

				local rectRegistry: {[BasePart]: Rect} = {}
				for i, part in ipairs(parts) do
					local rect = frustum:GetOuterBlockBounds(part.CFrame, part.Size)
					rectRegistry[part] = rect
				end

				table.sort(parts, function(a: BasePart, b: BasePart): boolean
					local aR = rectRegistry[a]
					local bR = rectRegistry[b]
					return (aR.Min - aR.Max).Magnitude > (bR.Min - bR.Max).Magnitude
				end)
		
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
			end
		end))	
	end

	

	return self
end

function OcclusionCamera.frustum(camera: Camera, maxRenderDistance: number): Frustum
	return Frustum.new(camera, maxRenderDistance)
end


return OcclusionCamera