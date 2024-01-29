--!strict
local _Package = script
local _Packages = _Package.Parent
-- Services
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

-- Packages
local Maid = require(_Packages:WaitForChild("Maid"))
local Signal = require(_Packages:WaitForChild("Signal"))
-- local Draw = require(_Packages:WaitForChild("Draw"))
-- local TableUtil = require(_Packages:WaitForChild("TableUtil"))
local Queue = require(_Packages:WaitForChild("Queue"))

-- Modules
local Config = require(_Package:WaitForChild("Config"))
local Frustum = require(_Package:WaitForChild("Frustum"))

-- Types
-- Constants
local IN_FRUSTUM_TAG = Config.Tag.InFrustum
local RENDER_TAG = Config.Tag.Render
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
export type OcclusionCamera = {
	__index: OcclusionCamera,
	_Maid: Maid,
	_IsAlive: boolean,
	Instance: Camera,
	MaxRenderDistance: number,
	OnlyUpdateOnCameraMove: boolean,
	SampleCount: number,
	WorldRoot: WorldRoot,
	ObscureDelay: number,

	OnRenderStart: Signal,
	OnRenderStop: Signal,
	OnExitFrustum: Signal,
	OnEnterFrustum: Signal,

	NoOccludeTag: string,
	Frustum: typeof(Frustum),

	GetAllVisible: (self: OcclusionCamera) -> { [number]: BasePart },
	GetAllInFrustum: (self: OcclusionCamera) -> { [number]: BasePart },
	GetIfVisible: (self: OcclusionCamera, part: BasePart) -> boolean,
	GetIfInFrustum: (self: OcclusionCamera, part: BasePart) -> boolean,

	Destroy: (self: OcclusionCamera) -> (),
	new: (camera: Camera) -> OcclusionCamera,
}

-- Class
local OcclusionCamera = {} :: OcclusionCamera
OcclusionCamera.__index = OcclusionCamera

function OcclusionCamera:Destroy()
	if not self._IsAlive then
		return
	end
	self._IsAlive = false
	self._Maid:Destroy()
	local t: any = self
	for k, v in pairs(t) do
		t[k] = nil
	end
	setmetatable(t, nil)
end

function OcclusionCamera:GetIfVisible(part: BasePart): boolean
	return CollectionService:HasTag(part, RENDER_TAG)
end

function OcclusionCamera:GetIfInFrustum(part: BasePart): boolean
	return CollectionService:HasTag(part, IN_FRUSTUM_TAG)
end

function OcclusionCamera:GetAllVisible(): { [number]: BasePart }
	return CollectionService:GetTagged(RENDER_TAG) :: { [number]: any }
end

function OcclusionCamera:GetAllInFrustum(): { [number]: BasePart }
	return CollectionService:GetTagged(IN_FRUSTUM_TAG) :: { [number]: any }
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

	self.OnRenderStart = self._Maid:GiveTask(Signal.new())
	self.OnRenderStop = self._Maid:GiveTask(Signal.new())
	self.OnExitFrustum = self._Maid:GiveTask(Signal.new())
	self.OnEnterFrustum = self._Maid:GiveTask(Signal.new())

	self.ObscureDelay = 1

	local function onRenderStart(inst: Instance)
		assert(inst:IsA("BasePart"))
		self.OnRenderStart:Fire(inst)
	end

	local function onRenderStop(inst: Instance)
		assert(inst:IsA("BasePart"))
		self.OnRenderStop:Fire(inst)
	end

	self._Maid:GiveTask(CollectionService:GetInstanceAddedSignal(RENDER_TAG):Connect(onRenderStart))
	self._Maid:GiveTask(CollectionService:GetInstanceRemovedSignal(RENDER_TAG):Connect(onRenderStop))

	for i, inst in ipairs(CollectionService:GetTagged(RENDER_TAG)) do
		onRenderStart(inst)
	end

	local function onEnterFrustum(inst: Instance)
		assert(inst:IsA("BasePart"))
		self.OnEnterFrustum:Fire(inst)
	end
	local function onRemoveFrustum(inst: Instance)
		if not inst:IsDescendantOf(game) then
			return
		end
		inst:SetAttribute(LAST_SEEN_ATTR_KEY, nil)

		if CollectionService:HasTag(inst, RENDER_TAG) then
			CollectionService:RemoveTag(inst, RENDER_TAG)
		end

		self.OnExitFrustum:Fire(inst)
	end
	self._Maid:GiveTask(CollectionService:GetInstanceAddedSignal(IN_FRUSTUM_TAG):Connect(onEnterFrustum))
	self._Maid:GiveTask(CollectionService:GetInstanceRemovedSignal(IN_FRUSTUM_TAG):Connect(onRemoveFrustum))

	for i, inst in ipairs(CollectionService:GetTagged(IN_FRUSTUM_TAG)) do
		onEnterFrustum(inst)
	end

	self._Maid:GiveTask(RunService.PreRender:Connect(function(deltaTime: number)
		local _frustum = Frustum.fromCamera(self.Instance, self.MaxRenderDistance)
	end))

	return self
end

return OcclusionCamera
