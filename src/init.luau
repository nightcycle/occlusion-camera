--!strict
local _Package = script
local _Packages = _Package.Parent
-- Services
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- Packages
local ShapeUtil = require(ReplicatedStorage.Packages.package.ShapeUtil)
local Maid = require(_Packages:WaitForChild("Maid"))
local Signal = require(_Packages:WaitForChild("Signal"))
local Draw = require(_Packages:WaitForChild("Draw"))
local TableUtil = require(_Packages:WaitForChild("TableUtil"))
local Queue = require(_Packages:WaitForChild("Queue"))

-- Modules
local RTree = require(_Package:WaitForChild("RTree"))
local Config = require(_Package:WaitForChild("Config"))
local Frustum = require(_Package:WaitForChild("Frustum"))
local Mask = require(_Package:WaitForChild("Mask"))
local DebugUtil = require(_Package:WaitForChild("DebugUtil"))

-- Types
-- Constants
local DEBUG_CULLING = Config.Debug.Culling
local DEBUG_SHAPE = Config.Debug.Shape
local DEBUG_INNER_BOUNDS = Config.Debug.InnerBounds
local DEBUG_OUTER_BOUNDS = Config.Debug.OuterBounds
local DEBUG_REGISTER_MASK = Config.Debug.RegisterMask
local DEBUG_SEARCH_MASK = Config.Debug.SearchMask
local IS_DEBUG = DEBUG_CULLING or DEBUG_SHAPE or DEBUG_INNER_BOUNDS or DEBUG_OUTER_BOUNDS or DEBUG_SEARCH_MASK or DEBUG_REGISTER_MASK

local IN_FRUSTUM_TAG = Config.Tag.InFrustum
local VISIBLE_TAG = Config.Tag.Visible
local LAST_SEEN_ATTR_KEY = Config.Attribute.LastSeen

-- Variables
-- References
-- Private Functions

-- https://github.com/EgoMoose/Articles/blob/master/2d%20triangles/2d%20triangles.md

-- Class
-- Types
type Queue<T> = Queue.Queue<T>
type Signal = Signal.Signal
type Maid = Maid.Maid
type Frustum = Frustum.Frustum
type RTree<T> = RTree.RTree<T>
type Mask<T> = Mask.Mask<T>
type Directory<T> = RTree.Directory<T>
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
	Parts: {[number]: BasePart},

	GetVisibleParts: (self: OcclusionCamera) -> {[number]: BasePart},
	-- GetObscuredParts: (self: OcclusionCamera) -> {[number]: BasePart},
	GetPartsInFrustum: (self: OcclusionCamera) -> {[number]: BasePart},
	GetIfPartIsVisible: (self: OcclusionCamera, part: BasePart) -> boolean,
	-- GetIfPartIsObscured: (self: OcclusionCamera, part: BasePart) -> boolean,
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

-- function OcclusionCamera:GetIfPartIsObscured(part: BasePart): boolean
-- 	return CollectionService:HasTag(part, OBSCURED_TAG)
-- end

function OcclusionCamera:GetIfPartIsInFrustum(part: BasePart): boolean
	return CollectionService:HasTag(part, IN_FRUSTUM_TAG)
end

function OcclusionCamera:GetVisibleParts(): {[number]: BasePart}
	return CollectionService:GetTagged(VISIBLE_TAG) :: {[number]: any}
end

function OcclusionCamera:GetPartsInFrustum(): {[number]: BasePart}
	return CollectionService:GetTagged(IN_FRUSTUM_TAG) :: {[number]: any}
end

-- function OcclusionCamera:GetObscuredParts(): {[number]: BasePart}
-- 	return CollectionService:GetTagged(OBSCURED_TAG) :: {[number]: any}
-- end

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
	self.Parts = {}

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

	-- local function onInitialObscureTag(inst: Instance)
	-- 	assert(inst:IsA("BasePart"))
	-- 	if self.ObscureDelay > 0 then
	-- 		task.wait(self.ObscureDelay)

	-- 		if CollectionService:HasTag(inst, INITIAL_OBSCURED_TAG) and self._IsAlive then
	-- 			if not CollectionService:HasTag(inst, OBSCURED_TAG) then
	-- 				CollectionService:AddTag(inst, OBSCURED_TAG)
	-- 			end
	-- 		end
	-- 	else
	-- 		if not CollectionService:HasTag(inst, OBSCURED_TAG) then
	-- 			CollectionService:AddTag(inst, OBSCURED_TAG)
	-- 		end
	-- 	end
	-- end

	-- self._Maid:GiveTask(CollectionService:GetInstanceAddedSignal(INITIAL_OBSCURED_TAG):Connect(onInitialObscureTag))
	-- for i, inst in ipairs(CollectionService:GetTagged(INITIAL_OBSCURED_TAG)) do
	-- 	onInitialObscureTag(inst)
	-- end

	-- local function onObscureTag(inst: Instance)
	-- 	assert(inst:IsA("BasePart"))
	-- 	self.OnObscurePart:Fire(inst)
	-- end
	-- self._Maid:GiveTask(CollectionService:GetInstanceAddedSignal(OBSCURED_TAG):Connect(onObscureTag))
	-- for i, inst in ipairs(CollectionService:GetTagged(OBSCURED_TAG)) do
	-- 	onObscureTag(inst)
	-- end

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
		-- if CollectionService:HasTag(inst, OBSCURED_TAG) then
		-- 	CollectionService:RemoveTag(inst, OBSCURED_TAG)
		-- end
		-- if CollectionService:HasTag(inst, INITIAL_OBSCURED_TAG) then
		-- 	CollectionService:RemoveTag(inst, INITIAL_OBSCURED_TAG)
		-- end
		if CollectionService:HasTag(inst, VISIBLE_TAG) then
			CollectionService:RemoveTag(inst, VISIBLE_TAG)
		end
		self.OnPartExitFrustum:Fire(inst)
	end
	self._Maid:GiveTask(CollectionService:GetInstanceRemovedSignal(IN_FRUSTUM_TAG):Connect(onRemoveFrustumTag))

	if IS_DEBUG then
		
		local debugMaid = self._Maid:GiveTask(Maid.new())

		local function onDebugUpdate()
			debugMaid:DoCleaning()
			local frustum = Frustum.new(self.Instance, self.MaxRenderDistance)

			local screen: LayerCollector
			if self.Instance == workspace.CurrentCamera then
				screen = debugMaid:GiveTask(Instance.new("ScreenGui"))
				screen.Parent = game:GetService("CoreGui")
			else
				local part = debugMaid:GiveTask(Instance.new("Part"))
				part.Anchored = true
				part.Transparency = 1
				part.Color = Color3.new(1,1,1)
				part.Transparency = 0.7
				part.Size = Vector3.new(
					frustum.HalfNearPlaneWidth*2,
					frustum.HalfNearPlaneHeight*2,
					0.01
				)
				part.CFrame = frustum.CFrame * CFrame.new(0,0,frustum.NearPlaneZ)
				
				local surfaceGui = debugMaid:GiveTask(Instance.new("SurfaceGui"))
				surfaceGui.Face = Enum.NormalId.Back
				surfaceGui.Parent = part

				part.Parent = workspace

				screen = surfaceGui

			end

			if DEBUG_CULLING then
				DebugUtil.culling(frustum, self.Parts)	
			end

			if DEBUG_SHAPE then
				DebugUtil.shape(screen, frustum, self.Parts)
			end

			if DEBUG_INNER_BOUNDS then
				DebugUtil.innerBounds(screen, frustum, self.Parts)
			end

			if DEBUG_OUTER_BOUNDS then
				DebugUtil.outerBounds(screen, frustum, self.Parts)
			end

			if DEBUG_REGISTER_MASK then
				DebugUtil.maskRegister(screen, frustum, self.Parts)
			end

			if DEBUG_SEARCH_MASK then
				DebugUtil.maskSearch(screen, frustum, self.Parts)
			end
		end

		local isPlaying = false
		self._Maid:GiveTask(RunService.RenderStepped:Connect(function(deltaTime: number)
			if isPlaying then
				onDebugUpdate()
			end
		end))
		self._Maid:GiveTask(UserInputService.InputBegan:Connect(function(inputObject: InputObject)
			if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
				isPlaying = false
				onDebugUpdate()
			elseif inputObject.UserInputType == Enum.UserInputType.MouseButton2 then
				isPlaying = true
			end
		end))
		self._Maid:GiveTask(UserInputService.InputEnded:Connect(function(inputObject: InputObject)
			if inputObject.UserInputType == Enum.UserInputType.MouseButton2 then
				isPlaying = false
			end
		end))
		task.spawn(onDebugUpdate)
	else

		self._Maid:GiveTask(RunService.PreRender:Connect(function(deltaTime: number)
			if prevCF ~= self.Instance:GetRenderCFrame() or self.OnlyUpdateOnCameraMove == false then
				prevCF = self.Instance:GetRenderCFrame()
				local t = tick()
				local frustum = Frustum.new(self.Instance, self.MaxRenderDistance)
				local mask = Mask.new() :: Mask<BasePart>
		
				local parts: {[number]: BasePart} = {}
				for i, inst in ipairs(self.Parts) do
					if frustum:GetIfOverlapFrustum(inst) then
						inst:AddTag(IN_FRUSTUM_TAG)
						-- inst:SetAttribute(LAST_SEEN_ATTR_KEY, tick())
						table.insert(parts, inst)	
					else
						inst:RemoveTag(IN_FRUSTUM_TAG)
					end
				end

				local outerRectRegistry: {[BasePart]: Rect} = {}
				local innerRectRegistry: {[BasePart]: Rect} = {}

				for i, part in ipairs(self.Parts) do
					local shape = frustum:GetProjectedShape(part.CFrame, part.Size)
					local outerRect = frustum:GetOuterBlockBounds(shape)
					local innerRect = frustum:GetOuterBlockBounds(shape)
					local distance = (part.CFrame.Position - self.Instance.CFrame.Position).Magnitude
					
					mask:Register(
						part,
						innerRect,
						outerRect,
						shape,
						self.MaxRenderDistance - distance,
						not part:HasTag(self.NoOccludeTag)
					)

					outerRectRegistry[part] = outerRect
					innerRectRegistry[part] = innerRect
				end

				for i, part in ipairs(parts) do
					if mask:GetIfOccluded(part) then
						-- if not part:HasTag(OBSCURED_TAG) then
						-- 	part:AddTag(OBSCURED_TAG)
						-- end
						if part:HasTag(VISIBLE_TAG) then
							part:RemoveTag(VISIBLE_TAG)
						end
					else
						if not part:HasTag(VISIBLE_TAG) then
							part:AddTag(VISIBLE_TAG)
						end
						-- if part:HasTag(OBSCURED_TAG) then
						-- 	part:AddTag(OBSCURED_TAG)
						-- end
					end
				end

				-- local unloadQueue: Queue<BasePart> = Queue.new()
				-- unloadQueue.IsSorted = true

				-- for i, inst in ipairs(CollectionService:GetTagged(IN_FRUSTUM_TAG)) do
				-- 	assert(inst:IsA("BasePart"))
				-- 	unloadQueue:Add(inst, -(inst:GetAttribute(LAST_SEEN_ATTR_KEY) or 0))
				-- end
				
				-- unloadQueue:Step(deltaTime * 0.2, function(inst: BasePart)
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
				-- end)
			end
		end))	
	end

	return self
end

function OcclusionCamera.frustum(camera: Camera, maxRenderDistance: number): Frustum
	return Frustum.new(camera, maxRenderDistance)
end


return OcclusionCamera