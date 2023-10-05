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
local GeometryUtil = require(_Packages:WaitForChild("GeometryUtil"))

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

			local screen = self._Maid:GiveTask(Instance.new("ScreenGui"))

			local canvasSize: Vector2 = self.Instance:GetAttribute("ViewportSize") or self.Instance.ViewportSize
			local imageLabel = Instance.new("ImageLabel")
			imageLabel.Size = UDim2.fromOffset(canvasSize.X, canvasSize.Y)
			imageLabel.BackgroundTransparency = 1
			imageLabel.Parent = screen
			local canvas = Instance.new("DynamicImage")
			canvas.Size = canvasSize
			canvas.Parent = imageLabel

			local emptyPixels = {}
			for x=1, canvasSize.X do
				for y=1, canvasSize.Y do
					table.insert(emptyPixels, 0) --r 
					table.insert(emptyPixels, 0) --g
					table.insert(emptyPixels, 0) --b
					table.insert(emptyPixels, 0) --t
				end
			end

			local function drawRect(rect: Rect, color: Color3, transparency: number)
				local xMin = math.floor(math.clamp(rect.Min.X, 0, canvas.Size.X))
				local xMax = math.ceil(math.clamp(rect.Max.X, 0, canvas.Size.X))
				local yMin = math.floor(math.clamp(rect.Min.Y, 0, canvas.Size.Y))
				local yMax = math.ceil(math.clamp(rect.Max.Y, 0, canvas.Size.Y))
				rect = Rect.new(Vector2.new(xMin, yMin), Vector2.new(xMax, yMax))
				if rect.Height >= 1 and rect.Width >= 1 then
					canvas:DrawRectangle(
						rect.Min,
						Vector2.new(rect.Width, rect.Height),
						color,
						transparency
					)
				end
			end

			local function drawPoint(p: Vector2, color: Color3, transparency: number)
				local x = math.floor(math.clamp(p.X, 0, canvas.Size.X))
				local y = math.ceil(math.clamp(p.Y, 0, canvas.Size.Y))
				canvas:DrawCircle(
					Vector2.new(x, y),
					3,
					color,
					transparency
				)
			end

			local function drawTriangle(
				a: Vector2, 
				b: Vector2, 
				c: Vector2, 
				color: Color3, 
				transparency: number
			)
				a = Vector2.new(
					math.round(a.X),
					math.round(a.Y)
				)
				b = Vector2.new(
					math.round(b.X),
					math.round(b.Y)
				)
				c = Vector2.new(
					math.round(c.X),
					math.round(c.Y)
				)
				local origin: Vector2, dest: Vector2, mid: Vector2
				
				local height: number
				do
					local xMax = math.max(a.X, b.X, c.X)
					local xMin = math.min(a.X, b.X, c.X)
					local yMax = math.round(math.max(a.Y, b.Y, c.Y))
					local yMin = math.round(math.min(a.Y, b.Y, c.Y))
					local rect = Rect.new(Vector2.new(xMin, yMin), Vector2.new(xMax, yMax))
					height = rect.Height
					if yMin == math.round(a.Y) then
						origin = a
					elseif yMin == math.round(b.Y) then
						origin = b
					elseif yMin == math.round(c.Y) then
						origin = c
					end
					if yMax == a.Y then
						dest = a
						if origin == b then
							mid = c
						else
							mid = b
						end
					elseif yMax == b.Y then
						dest = b
						if origin == a then
							mid = c
						else
							mid = a
						end
					elseif yMax == c.Y then
						dest = c
						if origin == b then
							mid = a
						else
							mid = b
						end
					end
				
					if not origin then
						print(`a: {a}, b: {b}, c: {c}`)
						warn(`yMax: {yMax}, yMin: {yMin}`)
					end
				end		
				-- drawPoint(
				-- 	origin,
				-- 	Color3.new(0,1,0),
				-- 	0
				-- )
				local oN = (mid - origin).Unit
				local oD = (dest - origin).Unit
				local dN = (mid - dest).Unit
				local dO = (dest - origin).Unit

				local oMDist = (mid - origin).Magnitude

				for y=1, height do

					if (oN * y / oN.Y).Magnitude <= oMDist then
						local d1 = oN * y / oN.Y

						local d2 = oD * y / oD.Y

						local x1 = d1.X
						local x2 = d2.X
	
						local dist = math.abs(x2 - x1)
						if dist >= 1 then
							
							local rect: Rect = Rect.new(
								origin+Vector2.new(x1,y-1),
								origin+Vector2.new(x2,y)
							)
	
							drawRect(rect, color, transparency)					
						end
					else
						y = height - y + 1
						local d1 = dN * y / dN.Y

						local d2 = dO * y / dO.Y

						local x1 = d1.X
						local x2 = d2.X
	
						local dist = math.abs(x2 - x1)
						if dist >= 1 then
							
							local rect: Rect = Rect.new(
								dest-Vector2.new(x1,y-1),
								dest-Vector2.new(x2,y)
							)
	
							drawRect(rect, color, transparency)					
						end
					end					
				end
			end

			screen.Parent = game:GetService("CoreGui")


			self._Maid:GiveTask(RunService.RenderStepped:Connect(function(deltaTime: number)

				local frustum = Frustum.new(self.Instance, self.MaxRenderDistance)
		
				local measurements: {[string]: {[number]: number}} = {}

				local rectRegistry: {[BasePart]: Rect} = {}
				for i, part in ipairs(parts) do
					if frustum:GetIfPartRendered(part) then
						measurements[part.Name] = measurements[part.Name] or {}

						local start = tick()
						local rect = frustum:GetOuterBlockBounds(part.CFrame, part.Size)
						local finish = tick()
						table.insert(measurements[part.Name], finish - start)
						rectRegistry[part] = rect


					end
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
					if aR and bR then
						return (aR.Min - aR.Max).Magnitude > (bR.Min - bR.Max).Magnitude
					elseif aR then
						return true
					else
						return false
					end
				end)
	


				if DEBUG_OCCLUSION and not NO_DEBUG_RENDER then
					canvas:WritePixels(
						Vector2.zero,
						canvasSize,
						emptyPixels
					)
					for part, rect in pairs(rectRegistry) do
						if frustum:GetIfPartRendered(part) then
							local dist = (self.Instance.CFrame.Position - part.Position).Magnitude

							-- drawRect(
							-- 	rect,
							-- 	Color3.new(1,0,0),
							-- 	0.7 + 0.3 * dist / self.MaxRenderDistance
							-- )

							local triangles = frustum:GetBlockShadow(part.CFrame, part.Size)

							local function constrain(v: Vector2): Vector2
								return Vector2.new(
									math.clamp(v.X, rect.Min.X, rect.Max.X),
									math.clamp(v.Y, rect.Min.Y, rect.Max.Y)
								)
							end

							for i, tri in ipairs(triangles) do
								local a, b, c = tri.A, tri.B, tri.C
								a = constrain(a)
								b = constrain(b)
								c = constrain(c)
								-- drawPoint(
								-- 	a,
								-- 	Color3.new(1,0,0),
								-- 	0
								-- )
								-- drawPoint(
								-- 	b,
								-- 	Color3.new(0,1,0),
								-- 	0
								-- )
								-- drawPoint(
								-- 	c,
								-- 	Color3.new(0,0,1),
								-- 	0
								-- )
								drawTriangle(
									a,
									b,
									c,
									Color3.new(0,0,1),
									0--0.7 + 0.3 * dist / self.MaxRenderDistance
								)
								-- break
							end
						end
			
					end

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