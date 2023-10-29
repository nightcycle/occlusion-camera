--!strict
local _Package = script.Parent
local _Packages = _Package.Parent
-- Services
-- Packages
local Maid = require(_Packages:WaitForChild("Maid"))
-- Modules
local Frustum = require(_Package:WaitForChild("Frustum"))
local Mask = require(_Package:WaitForChild("Mask"))

-- Types
type Maid = Maid.Maid
type Frustum = Frustum.Frustum
type Mask<V> = Mask.Mask<V>
-- Constants
local RENDER_DURATION = 0.5/60

-- Variables
-- References
-- Private Functions
					
function drawRect(screen: LayerCollector, rect: Rect, color: Color3, trans: number, zIndex: number)
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = trans
	frame.ZIndex = zIndex
	frame.BackgroundColor3 =  color
	frame.BorderSizePixel = 1
	frame.Position = UDim2.fromOffset(rect.Min.X+frame.BorderSizePixel, rect.Min.Y+frame.BorderSizePixel)
	frame.Size = UDim2.fromOffset(rect.Width-frame.BorderSizePixel*2, rect.Height-frame.BorderSizePixel*2)
	frame.Parent = screen
end

function drawLine(screen: LayerCollector, a: Vector2, b: Vector2, color: Color3, trans: number, zIndex: number)
	local mid = a:Lerp(b, 0.5)
	local offset = b - a
	do
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = trans
		frame.ZIndex = zIndex
		frame.BackgroundColor3 = color
		frame.Position = UDim2.fromOffset(mid.X, mid.Y)
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Rotation = math.deg(math.atan2(offset.Y, offset.X)) + 90
		frame.Size = UDim2.fromOffset(5, offset.Magnitude)
		frame.Parent = screen
	end

	-- local reps = math.clamp(math.floor(offset.Magnitude / 25), 1, 50)
	-- for i=0, reps do
	-- 	local h,_s,_v = color:ToHSV()
	-- 	local pos = a + i * offset / reps
	-- 	local frame = Instance.new("Frame")
	-- 	frame.BackgroundTransparency = trans * 0.5
	-- 	frame.ZIndex = zIndex + 1
	-- 	frame.BackgroundColor3 = Color3.fromHSV(h,1, 0.25 + 0.75 * (i/reps))
	-- 	frame.BorderSizePixel = 1
	-- 	frame.Position = UDim2.fromOffset(pos.X, pos.Y)
	-- 	frame.Size = UDim2.fromOffset(10, 10)
	-- 	frame.Parent = screen
	-- end
end

local function toMilliseconds(v: number): number
	return math.round(1000*10000*v)/10000
end

-- Class
local Util = {}



function Util.culling(frustum: Frustum, parts: {[number]: BasePart})
	local measurements: {[string]: {[number]: number}} = {}

	for i, inst in ipairs(parts) do
		measurements[inst.Name] = measurements[inst.Name] or {}
		local start = tick()
		local isInFrustum: boolean = frustum:GetIfOverlapFrustum(inst)
		local finish = tick()
		table.insert(measurements[inst.Name], finish - start)
		inst.Color = if not isInFrustum then Color3.new(0,0.5,1) else Color3.fromHSV(0,0.75,1)
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
	end

	local netDuration = netSum/netCount
	frustum.Camera:SetAttribute(`net_ms`, toMilliseconds(netDuration))
	frustum.Camera:SetAttribute(`net_limit`, math.floor(RENDER_DURATION/netDuration))
end

function Util.shape(screen: LayerCollector, frustum: Frustum, parts: {[number]: BasePart})
	local shapeMeasurements: {[string]: {[number]: number}} = {}

	for i, part in ipairs(parts) do
		if frustum:GetIfOverlapFrustum(part) then
			shapeMeasurements[part.Name] = shapeMeasurements[part.Name] or {}

			local start = tick()
			local shape = frustum:GetProjectedShape(part.CFrame, part.Size)
			local finish = tick()			
			for i, v in ipairs(shape) do
				local nV = shape[i+1] or shape[1]
				if nV then
					drawLine(
						screen,
						v,
						nV,
						Color3.new(1,1,0),
						0.5,
						100
					)
				end
			end
			
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
		end

		local netDuration = netSum/netCount
		frustum.Camera:SetAttribute(`shape_net_ms`, toMilliseconds(netDuration))
		frustum.Camera:SetAttribute(`shape_net_limit`, math.floor(RENDER_DURATION/netDuration))

	end
end

function Util.outerBounds(screen: LayerCollector, frustum: Frustum, parts: {[number]: BasePart})
	local outerRectMeasurements: {[string]: {[number]: number}} = {}

	for i, part in ipairs(parts) do
		if frustum:GetIfOverlapFrustum(part) then
			outerRectMeasurements[part.Name] = outerRectMeasurements[part.Name] or {}
			local shape = frustum:GetProjectedShape(part.CFrame, part.Size)

			local start = tick()
			frustum:GetOuterBlockBounds(shape)
			local finish = tick()				

			table.insert(outerRectMeasurements[part.Name], finish - start)
		end
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
		end

		local netDuration = netSum/netCount
		frustum.Camera:SetAttribute(`out_net_ms`, toMilliseconds(netDuration))
		frustum.Camera:SetAttribute(`out_net_limit`, math.floor(RENDER_DURATION/netDuration))
	end
end

function Util.innerBounds(screen: LayerCollector, frustum: Frustum, parts: {[number]: BasePart})
	local innerMeasurements: {[string]: {[number]: number}} = {}

	for i, part in pairs(parts) do
		if frustum:GetIfOverlapFrustum(part) then
			innerMeasurements[part.Name] = innerMeasurements[part.Name] or {}
			local shape = frustum:GetProjectedShape(part.CFrame, part.Size)

			local start = tick()
			frustum:GetInnerBlockBounds(shape)
			local finish = tick()				

			table.insert(innerMeasurements[part.Name], finish - start)
		end
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
		end

		local netDuration = netSum/netCount
		frustum.Camera:SetAttribute(`in_net_ms`, toMilliseconds(netDuration))
		frustum.Camera:SetAttribute(`in_net_limit`, math.floor(RENDER_DURATION/netDuration))
	end
end

function Util.maskRegister(screen: LayerCollector, frustum: Frustum, parts: {[number]: BasePart})
	local maskMeasurements: {[string]: {[number]: number}} = {}
	local mask = Mask.new() :: Mask<BasePart>

	for i, part in ipairs(parts) do
		if frustum:GetIfOverlapFrustum(part) then
			maskMeasurements[part.Name] = maskMeasurements[part.Name] or {}

			local shape = frustum:GetProjectedShape(part.CFrame, part.Size)
			local innerRect = frustum:GetInnerBlockBounds(shape)
			local outerRect = frustum:GetOuterBlockBounds(shape)
			local distance = (frustum.CFrame.Position - part.Position).Magnitude

			local start = tick()

			mask:Register(
				part,
				innerRect,
				outerRect,
				shape,
				frustum.FarPlaneDistance - distance,
				true
			)

			local finish = tick()

			table.insert(maskMeasurements[part.Name], finish - start)
		end
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
		end

		local netDuration = netSum/netCount
		frustum.Camera:SetAttribute(`mask_net_ms`, toMilliseconds(netDuration))
		frustum.Camera:SetAttribute(`mask_net_limit`, math.floor(RENDER_DURATION/netDuration))
	end
end

function Util.maskSearch(screen: LayerCollector, frustum: Frustum, parts: {[number]: BasePart})
	local maskMeasurements: {[string]: {[number]: number}} = {}
	local mask = Mask.new() :: Mask<BasePart>

	for i, part in ipairs(parts) do
		if frustum:GetIfOverlapFrustum(part) then
			maskMeasurements[part.Name] = maskMeasurements[part.Name] or {}

			local shape = frustum:GetProjectedShape(part.CFrame, part.Size)
			local innerRect = frustum:GetInnerBlockBounds(shape)
			local outerRect = frustum:GetOuterBlockBounds(shape)
			local distance = (frustum.CFrame.Position - part.Position).Magnitude

			mask:Register(
				part,
				innerRect,
				outerRect,
				shape,
				frustum.FarPlaneDistance - distance,
				true
			)
		end
	end

	for i, part in ipairs(parts) do
		if frustum:GetIfOverlapFrustum(part) then
			local start = tick()
			local isOccluded = mask:GetIfOccluded(part)
			local finish = tick()

			local distance = (frustum.CFrame.Position - part.Position).Magnitude

			local maskData = mask._Items[part]
			assert(maskData)

			drawRect(
				screen,
				maskData.InnerRect,
				if not isOccluded then Color3.new(0, 1, 1) else Color3.new(1,0,0),
				if not isOccluded then 0.4 else 0.1,
				frustum.FarPlaneDistance - distance
			)

			table.insert(maskMeasurements[part.Name], finish - start)
		end
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
		end

		local netDuration = netSum/netCount
		frustum.Camera:SetAttribute(`mask_net_ms`, toMilliseconds(netDuration))
		frustum.Camera:SetAttribute(`mask_net_limit`, math.floor(RENDER_DURATION/netDuration))
	end
end

return Util