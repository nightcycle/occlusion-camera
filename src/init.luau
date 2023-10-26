--!strict
local _Package = script
local _Packages = _Package.Parent
-- Services
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local ShapeUtil = require(ReplicatedStorage.Packages.package.ShapeUtil)
local Maid = require(_Packages:WaitForChild("Maid"))
local Signal = require(_Packages:WaitForChild("Signal"))
local Draw = require(_Packages:WaitForChild("Draw"))
local TableUtil = require(_Packages:WaitForChild("TableUtil"))

-- Modules
local RTree = require(_Package:WaitForChild("RTree"))
local Config = require(_Package:WaitForChild("Config"))
local Frustum = require(_Package:WaitForChild("Frustum"))
local Mask = require(_Package:WaitForChild("Mask"))

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

-- https://github.com/EgoMoose/Articles/blob/master/2d%20triangles/2d%20triangles.md

-- Class
-- Types
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
			self._Maid:GiveTask(function()
				for i, inst in ipairs(parts) do
					if inst:IsA("BasePart") then
						inst.Color = Color3.fromHSV(1,0,0.75)
					end
				end
			end)
			self._Maid:GiveTask(RunService.RenderStepped:Connect(function(deltaTime: number)
				local screen = self._Maid:GiveTask(Instance.new("ScreenGui"))
				screen.Parent = game:GetService("CoreGui")

				local frustum = Frustum.new(self.Instance, self.MaxRenderDistance)
		
				local partOuterRectRegistry: {[BasePart]: Rect} = {}
				local partInnerRectRegistry: {[BasePart]: Rect} = {}
				local partShapeRegistry: {[BasePart]: {[number]: Vector2}} = {}
				local partOuterAreaRegistry: {[BasePart]: number} = {}
				local partInnerAreaRegistry: {[BasePart]: number} = {}
				local partDistanceRegistry: {[BasePart]: number} = {}
				local visiblePartList: {[number]: BasePart} = {}

				local mask = Mask.new() :: Mask<BasePart>

				do
					local shapeMeasurements: {[string]: {[number]: number}} = {}

					for i, part in ipairs(parts) do
						if frustum:GetIfPartRendered(part) then
							shapeMeasurements[part.Name] = shapeMeasurements[part.Name] or {}
	
							local start = tick()
							local shape = frustum:GetProjectedShape(part.CFrame, part.Size)
							local finish = tick()				
							partShapeRegistry[part] = shape
							partDistanceRegistry[part] = (part.CFrame.Position - self.Instance.CFrame.Position).Magnitude
							table.insert(shapeMeasurements[part.Name], finish - start)
						end
					end
		
					do
						local netSum = 0
						local netCount = 0
						for k, vList in pairs(shapeMeasurements) do
							local sum = 0
							local count = #vList
							for i, v in ipairs(vList) do
								sum += v
							end
							netSum += sum
							netCount += count
							local duration = sum/count
							self.Instance:SetAttribute(`_shape_{k}_ms`, toMilliseconds(duration))
							self.Instance:SetAttribute(`_shape_{k}_limit`, math.floor(RENDER_DURATION/duration))
						end
	
						local netDuration = netSum/netCount
						self.Instance:SetAttribute(`shape_net_ms`, toMilliseconds(netDuration))
						self.Instance:SetAttribute(`shape_net_limit`, math.floor(RENDER_DURATION/netDuration))
					end
				end


				do
					local outerRectMeasurements: {[string]: {[number]: number}} = {}

					for part, shape in pairs(partShapeRegistry) do
						outerRectMeasurements[part.Name] = outerRectMeasurements[part.Name] or {}

						local start = tick()
						local outerRect = ShapeUtil.getOuterBounds(shape)
						local finish = tick()				

						partOuterAreaRegistry[part] = outerRect.Width * outerRect.Height
						partOuterRectRegistry[part] = outerRect

						table.insert(outerRectMeasurements[part.Name], finish - start)
					end
		
					do
						local netSum = 0
						local netCount = 0
						for k, vList in pairs(outerRectMeasurements) do
							local sum = 0
							local count = #vList
							for i, v in ipairs(vList) do
								sum += v
							end
							netSum += sum
							netCount += count
							local duration = sum/count
							self.Instance:SetAttribute(`_out_{k}_ms`, toMilliseconds(duration))
							self.Instance:SetAttribute(`_out_{k}_limit`, math.floor(RENDER_DURATION/duration))
						end
	
						local netDuration = netSum/netCount
						self.Instance:SetAttribute(`out_net_ms`, toMilliseconds(netDuration))
						self.Instance:SetAttribute(`out_net_limit`, math.floor(RENDER_DURATION/netDuration))
					end
				end

				do
					local innerMeasurements: {[string]: {[number]: number}} = {}

					for part, shape in pairs(partShapeRegistry) do
						innerMeasurements[part.Name] = innerMeasurements[part.Name] or {}

						local start = tick()
						local innerRect = ShapeUtil.getInnerBounds(shape)
						local finish = tick()				

						do
							for rect, fillType in pairs(ShapeUtil.getInnerBoundSubdivisions(shape)) do
								local frame = Instance.new("Frame")
								frame.BackgroundTransparency = 0.5
								frame.ZIndex = 1
								frame.BorderSizePixel = 1
								frame.BackgroundColor3 = if fillType == "Inner" then Color3.new(0,1,0) elseif fillType == "Line" then Color3.new(1,1,0) else  Color3.new(1,0,0)
								frame.Position = UDim2.fromOffset(rect.Min.X+frame.BorderSizePixel, rect.Min.Y+frame.BorderSizePixel)
								frame.Size = UDim2.fromOffset(rect.Width-frame.BorderSizePixel*2, rect.Height-frame.BorderSizePixel*2)
								frame.Parent = screen
							end
						end


						partInnerAreaRegistry[part] = innerRect.Width * innerRect.Height
						partInnerRectRegistry[part] = innerRect

						table.insert(visiblePartList, part)

						table.insert(innerMeasurements[part.Name], finish - start)
					end
		
					do
						local netSum = 0
						local netCount = 0
						for k, vList in pairs(innerMeasurements) do
							local sum = 0
							local count = #vList
							for i, v in ipairs(vList) do
								sum += v
							end
							netSum += sum
							netCount += count
							local duration = sum/count
							self.Instance:SetAttribute(`_in_{k}_ms`, toMilliseconds(duration))
							self.Instance:SetAttribute(`_in_{k}_limit`, math.floor(RENDER_DURATION/duration))
						end
	
						local netDuration = netSum/netCount
						self.Instance:SetAttribute(`in_net_ms`, toMilliseconds(netDuration))
						self.Instance:SetAttribute(`in_net_limit`, math.floor(RENDER_DURATION/netDuration))
					end
				end

				table.sort(visiblePartList, function(a: BasePart, b: BasePart): boolean
					return partOuterAreaRegistry[a] > partOuterAreaRegistry[b]
				end)

				do
					local maskMeasurements: {[string]: {[number]: number}} = {}

					for part, rect in pairs(partOuterRectRegistry) do
						maskMeasurements[part.Name] = maskMeasurements[part.Name] or {}

						local start = tick()

						mask:Register(
							part,
							rect,
							partShapeRegistry[part],
							self.MaxRenderDistance - partDistanceRegistry[part],
							true
						)
						local finish = tick()

						table.insert(maskMeasurements[part.Name], finish - start)
					end
		
					do
						local netSum = 0
						local netCount = 0
						for k, vList in pairs(maskMeasurements) do
							local sum = 0
							local count = #vList
							for i, v in ipairs(vList) do
								sum += v
							end
							netSum += sum
							netCount += count
							local duration = sum/count
							self.Instance:SetAttribute(`_mask_{k}_ms`, toMilliseconds(duration))
							self.Instance:SetAttribute(`_mask_{k}_limit`, math.floor(RENDER_DURATION/duration))
						end
	
						local netDuration = netSum/netCount
						self.Instance:SetAttribute(`mask_net_ms`, toMilliseconds(netDuration))
						self.Instance:SetAttribute(`mask_net_limit`, math.floor(RENDER_DURATION/netDuration))
					end

				end

				do
					local searchMeasurements: {[string]: {[number]: number}} = {}
				
					for part, rect in pairs(partOuterRectRegistry) do
						searchMeasurements[part.Name] = searchMeasurements[part.Name] or {}

						local start = tick()
						local isOccluded = mask:GetIfOccluded(part)

						local finish = tick()

						for i, v in ipairs(partShapeRegistry[part]) do
							do
								local frame = Instance.new("Frame")
								frame.BackgroundTransparency = 0
								frame.ZIndex = 10 + self.MaxRenderDistance - (part.Position - self.Instance.CFrame.Position).Magnitude
								frame.BackgroundColor3 =  Color3.new(1,1,0)
								frame.Position = UDim2.fromOffset(v.X, v.Y)
								frame.AnchorPoint = Vector2.new(0.5, 0.5)
								frame.Size = UDim2.fromOffset(5, 5)
								frame.Parent = screen
							end

							do
								local nV = partShapeRegistry[part][i+1] or partShapeRegistry[part][1]
								local mid = v:Lerp(nV, 0.5)
								local offset = (nV - v)
								local frame = Instance.new("Frame")
								frame.BackgroundTransparency = 0
								frame.ZIndex = 20 + self.MaxRenderDistance - (part.Position - self.Instance.CFrame.Position).Magnitude
								frame.BackgroundColor3 =  Color3.new(1,1,0)
								frame.Position = UDim2.fromOffset(mid.X, mid.Y)
								frame.AnchorPoint = Vector2.new(0.5, 0.5)
								frame.Rotation = math.deg(math.atan2(offset.Y, offset.X)) + 90
								frame.Size = UDim2.fromOffset(5, offset.Magnitude)
								frame.Parent = screen
							end
						end

						-- do
						-- 	local frame = Instance.new("Frame")
						-- 	frame.BackgroundTransparency = if not isOccluded then 0.8 else 0.2
						-- 	frame.ZIndex = self.MaxRenderDistance - (part.Position - self.Instance.CFrame.Position).Magnitude
						-- 	frame.BackgroundColor3 =  if not isOccluded then Color3.new(0, 1, 1) else Color3.new(1,0,0)
						-- 	frame.Position = UDim2.fromOffset(rect.Min.X, rect.Min.Y)
						-- 	frame.Size = UDim2.fromOffset(rect.Width, rect.Height)
						-- 	frame.Parent = screen
						-- end

						table.insert(searchMeasurements[part.Name], finish - start)
					end
		
					do
						local netSum = 0
						local netCount = 0
						for k, vList in pairs(searchMeasurements) do
							local sum = 0
							local count = #vList
							for i, v in ipairs(vList) do
								sum += v
							end
							netSum += sum
							netCount += count
							local duration = sum/count
							self.Instance:SetAttribute(`_search_{k}_ms`, toMilliseconds(duration))
							self.Instance:SetAttribute(`_search_{k}_limit`, math.floor(RENDER_DURATION/duration))
						end
	
						local netDuration = netSum/netCount
						self.Instance:SetAttribute(`search_net_ms`, toMilliseconds(netDuration))
						self.Instance:SetAttribute(`search_net_limit`, math.floor(RENDER_DURATION/netDuration))
					end

				end

				-- do
				-- 	local function debugTree(dir: Directory<BasePart>, depth: number)
				-- 		if depth > 0 then
				-- 			local frame = Instance.new("Frame")
				-- 			frame.BackgroundTransparency = 0.8
				-- 			frame.ZIndex = depth + 5
				-- 			frame.BackgroundColor3 = Color3.fromHSV(
				-- 				if depth == 1 then 0 else 0.5,
				-- 				1, --1/depth,
				-- 				1
				-- 			)
				-- 			frame.BorderSizePixel = 3
				-- 			frame.Position = UDim2.fromOffset(dir.Region.Min.X, dir.Region.Min.Y)
				-- 			frame.Size = UDim2.fromOffset(dir.Region.Width, dir.Region.Height)
	
				-- 			frame.Parent = screen
				-- 		end
				-- 		for k, v in pairs(dir.SubDirectories) do
				-- 			debugTree(v, depth+1)
				-- 		end
				-- 	end
				-- 	debugTree(rTree._Master, 0)
				-- end

				-- do
				-- 	local measurements: {[string]: {[number]: number}} = {}

				-- 	for part, rect in pairs(partOuterRectRegistry) do
				-- 		measurements[part.Name] = measurements[part.Name] or {}

				-- 		do
				-- 			local start = tick()

				-- 			local hits = rTree:SearchUniqueOnly(rect)

				-- 			local isObscured = true
				-- 			do
				-- 				for i, hit in ipairs(hits) do
				-- 					if hit == part then
				-- 						isObscured = false
				-- 						break
				-- 					end
				-- 				end
				-- 			end
			
				-- 			print(`h: {#hits} = {isObscured}`)
				-- 			local finish = tick()
				-- 			-- local shape = partShapeRegistry[part]
				-- 			local color = if isObscured then Color3.new(0,0,1) else Color3.new(1,1,1)
				-- 			if DEBUG_OCCLUSION and not NO_DEBUG_RENDER then
				-- 				do
				-- 					local frame = Instance.new("Frame")
				-- 					frame.BackgroundTransparency = 0.7
				-- 					frame.ZIndex = 10^6 - (rect.Width * rect.Height)
				-- 					frame.BackgroundColor3 =  color
				-- 					frame.Position = UDim2.fromOffset(rect.Min.X, rect.Min.Y)
				-- 					frame.Size = UDim2.fromOffset(rect.Width, rect.Height)
				-- 					frame.Parent = screen
				-- 				end
				-- 				-- for i, hit in ipairs(hits) do
				-- 				-- 	do
				-- 				-- 		local frame = Instance.new("Frame")
				-- 				-- 		frame.BackgroundTransparency = i
				-- 				-- 		frame.ZIndex = 10
				-- 				-- 		frame.BackgroundColor3 =  if hit ~= part then color else Color3.new(0.5,0.5,0.5)
				-- 				-- 		frame.Position = UDim2.fromOffset(rect.Min.X, rect.Min.Y)
				-- 				-- 		frame.Size = UDim2.fromOffset(rect.Width, rect.Height)
				-- 				-- 		frame.Parent = screen
				-- 				-- 	end
				-- 				-- 	if hit ~= part then
				-- 				-- 	end
				-- 				-- end

				-- 				-- local function debugLine(a: Vector2, b: Vector2)
				-- 				-- 	local pos = a:Lerp(b, 0.5)
				-- 				-- 	local offset = (b-a)
				-- 				-- 	local frame = Instance.new("Frame")
				-- 				-- 	frame.BackgroundTransparency = 00.5
				-- 				-- 	frame.ZIndex = 10
				-- 				-- 	frame.BorderSizePixel = 0
				-- 				-- 	frame.AnchorPoint = Vector2.new(0.5,0.5)
				-- 				-- 	frame.Position = UDim2.fromOffset(pos.X, pos.Y)
				-- 				-- 	frame.BackgroundColor3 = color --Color3.new(1,1,1)
				-- 				-- 	frame.Size = UDim2.fromOffset(5, offset.Magnitude)
				-- 				-- 	frame.Rotation = math.deg(math.atan2(offset.X, -offset.Y))
				-- 				-- 	frame.Parent = screen
				-- 				-- end

				-- 				-- for j, v in ipairs(shape) do
				-- 				-- 	local pV = shape[j-1] or shape[#shape]
				-- 				-- 	assert(pV)
				-- 				-- 	debugLine(pV, v)
				-- 				-- end
				-- 			end

				-- 			part.Color = color

				-- 			table.insert(measurements[part.Name], finish - start)
				-- 		end

				-- 		-- break
				-- 	end
		
				-- 	do
				-- 		local netSum = 0
				-- 		local netCount = 0
				-- 		for k, vList in pairs(measurements) do
				-- 			local sum = 0
				-- 			local count = #vList
				-- 			for i, v in ipairs(vList) do
				-- 				sum += v
				-- 			end
				-- 			netSum += sum
				-- 			netCount += count
				-- 			local duration = sum/count
				-- 			self.Instance:SetAttribute(`_search_{k}_ms`, toMilliseconds(duration))
				-- 			self.Instance:SetAttribute(`_search_{k}_limit`, math.floor(RENDER_DURATION/duration))
				-- 		end
	
				-- 		local netDuration = netSum/netCount
				-- 		self.Instance:SetAttribute(`search_net_ms`, toMilliseconds(netDuration))
				-- 		self.Instance:SetAttribute(`search_net_limit`, math.floor(RENDER_DURATION/netDuration))
				-- 	end
				-- end
				
				self._Maid._screen = screen
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