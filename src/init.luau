--!strict
local _Package = script
local _Packages = _Package.Parent
-- Services
local RunService = game:GetService("RunService")

-- Packages
local Maid = require(_Packages:WaitForChild("Maid"))
local Signal = require(_Packages:WaitForChild("Signal"))
local TableUtil = require(_Packages:WaitForChild("TableUtil"))

-- Modules
local Frustum = require(_Package:WaitForChild("Frustum"))

-- Types
-- Constants
local DEBUG_RENDER = false
local DEBUG_DRAW = _Package:GetFullName() == "ReplicatedStorage.Packages.package"
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
	_Frequency: number,
	_FrustumRegistry: {[BasePart]: number},
	_RenderRegistry: {[BasePart]: number},
	_ObscuredRegistry: {[BasePart]: number},
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
	return self._RenderRegistry[part] ~= nil
end

function OcclusionCamera:GetIfPartIsObscured(part: BasePart): boolean
	return self._ObscuredRegistry[part] ~= nil
end

function OcclusionCamera:GetIfPartIsInFrustum(part: BasePart): boolean
	return self._FrustumRegistry[part] ~= nil
end

function OcclusionCamera:GetVisibleParts(): {[number]: BasePart}
	return TableUtil.keys(self._RenderRegistry)
end

function OcclusionCamera:GetPartsInFrustum(): {[number]: BasePart}
	return TableUtil.keys(self._FrustumRegistry)
end

function OcclusionCamera:GetObscuredParts(): {[number]: BasePart}
	return TableUtil.keys(self._ObscuredRegistry)
end

function OcclusionCamera.new(camera: Camera): OcclusionCamera

	local self: OcclusionCamera = setmetatable({}, OcclusionCamera) :: any
	self._IsAlive = true
	self._Maid = Maid.new()
	self.MaxRenderDistance = 512
	self.Instance = camera
	self.OnlyUpdateOnCameraMove = true
	self.SampleCount = 512
	self.WorldRoot = workspace
	self.NoOccludeTag = "OcclusionCameraNoOcclude"

	self.OnViewPart = self._Maid:GiveTask(Signal.new())
	self.OnObscurePart = self._Maid:GiveTask(Signal.new())
	self.OnPartExitFrustum = self._Maid:GiveTask(Signal.new())
	self.OnPartEnterFrustum = self._Maid:GiveTask(Signal.new())

	self.ObscureDelay = 1
	self._FrustumRegistry = {}
	self._RenderRegistry = {}
	self._ObscuredRegistry = {}

	self.RaycastParams = RaycastParams.new()
	self.RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	self.RaycastParams.FilterDescendantsInstances = {}
	self.RaycastParams.IgnoreWater = false
	self.RaycastParams.RespectCanCollide = true

	local prevCF: CFrame?
	local steps = 0
	local duration = 0

	self._Maid:GiveTask(RunService.PreRender:Connect(function(deltaTime: number)
		if prevCF ~= self.Instance:GetRenderCFrame() or self.OnlyUpdateOnCameraMove == false then

			prevCF = self.Instance:GetRenderCFrame()
			local start = tick()
	
			local frustum = Frustum.new(self.Instance, self.MaxRenderDistance)
			local frustumRegistry = table.clone(self._FrustumRegistry)
	
			local renderedParts: {[number]: BasePart} = {}
			local obscuredParts: {[number]: BasePart} = {}
	
			do
				local renderRegistry: {[BasePart]: true} = {}
				local obscureRegistry: {[BasePart]: true} = {}
	
				for kV2, occlusionResults in pairs(frustum:Occludecast(
					self.SampleCount, 
					self.RaycastParams, 
					self.WorldRoot, 
					self.NoOccludeTag
				)) do
					for i, occlusionResult in ipairs(occlusionResults) do
						local part = occlusionResult.Result.Instance
						assert(part:IsA("BasePart"), `occlusion result wasn't basePart, it was a {part.ClassName}`)
						if occlusionResult.IsVisible then
							renderRegistry[part] = true
							if self._RenderRegistry[part] then
								self._RenderRegistry[part] = tick()
							end
						else
							obscureRegistry[part] = true
							if self._ObscuredRegistry[part] then
								self._ObscuredRegistry[part] = tick()
							end
						end
						if self._FrustumRegistry[part] then
							self._FrustumRegistry[part] = tick()
						end
					end
				end
	
				renderedParts = TableUtil.keys(renderRegistry)
				obscuredParts = TableUtil.keys(obscureRegistry)
			end
	
			local frustumParts = TableUtil.deduplicate(TableUtil.append(renderedParts, obscuredParts))
	
			-- get parts in frustum
			local enterParts: {[number]: BasePart} = {}
			for i, part in ipairs(frustumParts) do
				self._FrustumRegistry[part] = tick()
				if frustumRegistry[part] then
					frustumRegistry[part] = nil --remove from copy to find parts that no longer exist
				else
					table.insert(enterParts, part)
				end
			end
	
			local t = tick()
			local exitParts: {[number]: BasePart} = {}
			for part, lastSeen in pairs(frustumRegistry) do
				if t - lastSeen > self.ObscureDelay then
					self._FrustumRegistry[part] = nil
					self._ObscuredRegistry[part] = nil
					self._RenderRegistry[part] = nil
					table.insert(exitParts, part)
				end
			end
			for i, part in ipairs(enterParts) do
				self.OnPartEnterFrustum:Fire(part)
			end
			for i, part in ipairs(exitParts) do
				self.OnPartExitFrustum:Fire(part)
			end
	
			-- update obscured and rendered parts
			local renderRegistry = table.clone(self._RenderRegistry)
	
			local newObscuredParts: {[number]: BasePart} = {}
	
			for part, lastSeen in pairs(self._RenderRegistry) do
				if t - lastSeen > self.ObscureDelay then
					self._ObscuredRegistry[part] = tick()
					self._RenderRegistry[part] = nil
					table.insert(newObscuredParts, part)
				end
			end
	
	
			local newRenderedParts: {[number]: BasePart} = {}
			for i, part in ipairs(renderedParts) do
				self._RenderRegistry[part] = tick()
				if renderRegistry[part] then
					renderRegistry[part] = nil --remove from copy of registry to allow for finding of those that no longer are detected
				else
					table.insert(newRenderedParts, part)
				end
			end
	
			local obscureRegistry = table.clone(self._ObscuredRegistry)
	
			for i, part in ipairs(obscuredParts) do
				if self._RenderRegistry[part] == nil then --if a separate triangle of the part was rendered remove it from consideration
					self._ObscuredRegistry[part] = tick()
					if obscureRegistry[part] then
						obscureRegistry[part] = nil --remove from copy of registry to allow for finding of those that no longer are detected
					else
						table.insert(newObscuredParts, part)
					end
				end
			end
	
	
			for i, part in ipairs(newRenderedParts) do
				self.OnViewPart:Fire(part)
			end
			for i, part in ipairs(newObscuredParts) do
				self.OnObscurePart:Fire(part)
			end
	
			local finish = tick()
			duration += finish - start
			steps += 1
	
			if DEBUG_RENDER then
				self._Maid._frustumRender = frustum:Render(self.SampleCount)
			end
			if DEBUG_DRAW then
				self._Maid._frustumDraw = frustum:Draw()
			end		
	
			if steps%60 == 0 then
				self._Frequency = 1/(duration/steps)
				steps = 0
				duration = 0
			end
		end
	end))
	-- end)
	

	return self
end


return OcclusionCamera