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
local RENDER_ENABLED = true

-- Variables
-- References
-- Private Functions
					
function drawRect(screen: LayerCollector, rect: Rect, color: Color3, trans: number, zIndex: number): Frame?
	if not RENDER_ENABLED then return end
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = trans
	frame.ZIndex = zIndex
	frame.Name = `ori=({rect.Min}),size=({rect.Width},{rect.Height})`
	frame.BackgroundColor3 =  color
	frame.BorderSizePixel = 1
	frame.Position = UDim2.fromOffset(rect.Min.X+frame.BorderSizePixel, rect.Min.Y+frame.BorderSizePixel)
	frame.Size = UDim2.fromOffset(rect.Width-frame.BorderSizePixel*2, rect.Height-frame.BorderSizePixel*2)
	frame.Parent = screen
	return frame
end

function drawLine(screen: LayerCollector, a: Vector2, b: Vector2, color: Color3, trans: number, zIndex: number): Frame?
	if not RENDER_ENABLED then return end

	local mid = a:Lerp(b, 0.5)
	local offset = b - a
	do
		local frame = Instance.new("Frame")
		frame.Name = `Line`
		frame.BackgroundTransparency = trans
		frame.ZIndex = zIndex
		frame.BackgroundColor3 = color
		frame.Position = UDim2.fromOffset(mid.X, mid.Y)
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Rotation = math.deg(math.atan2(offset.Y, offset.X)) + 90
		frame.Size = UDim2.fromOffset(5, offset.Magnitude)
		frame.Parent = screen
		return frame
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
	local duration = 0
	local count = 0
	for i, inst in ipairs(parts) do
		local start = tick()
		local isInFrustum: boolean = frustum:GetIfOverlapFrustum(inst)
		local finish = tick()
		if RENDER_ENABLED then
			inst.Color = if not isInFrustum then Color3.new(0,0.5,1) else Color3.fromHSV(0,0.75,1)
		end
		duration += finish - start
		count += 1
	end

	local avg = duration/count
	frustum.Camera:SetAttribute(`_culling_net_ms`, toMilliseconds(avg))
	frustum.Camera:SetAttribute(`_culling_net_limit`, math.floor(RENDER_DURATION/avg))
end

function Util.shape(screen: LayerCollector, frustum: Frustum, parts: {[number]: BasePart})
	local duration = 0
	local count = 0
	for i, part in ipairs(parts) do
		if frustum:GetIfOverlapFrustum(part) and part.Name == "Block30" then

			local start = tick()
			local shape = frustum:GetProjectedShape(part.CFrame, part.Size)
			local finish = tick()			
			for j, v in ipairs(shape) do
				local nV = shape[j+1] or shape[1]
				if nV then
					local lineFrame = drawLine(
						screen,
						v,
						nV,
						Color3.new(0,0,0),
						(frustum.CFrame.Position - part.Position).Magnitude / frustum.FarPlaneDistance,
						100
					)
					if lineFrame then
						lineFrame.Name = `{part.Name}_L{j}_{v}`
					end
				end
			end
			duration += finish - start
			count += 1
		end
	end

	do
		local avg = duration/count
		frustum.Camera:SetAttribute(`_shape_avg_ms`, toMilliseconds(avg))
		frustum.Camera:SetAttribute(`_shape_limit`, math.floor(RENDER_DURATION/avg))

	end
end

function Util.outerBounds(screen: LayerCollector, frustum: Frustum, parts: {[number]: BasePart})
	local duration = 0
	local count = 0
	for i, part in ipairs(parts) do
		if frustum:GetIfOverlapFrustum(part) and part.Name == "Block30" then
			local shape = frustum:GetProjectedShape(part.CFrame, part.Size)

			local start = tick()
			local rect = frustum:GetOuterBlockBounds(shape)
			local finish = tick()				
			
			local frame = drawRect(
				screen,
				rect,
				Color3.new(0.5,1,1),
				(frustum.CFrame.Position - part.Position).Magnitude / frustum.FarPlaneDistance,
				10+20*(1-(frustum.CFrame.Position - part.Position).Magnitude / frustum.FarPlaneDistance)
			)

			if frame then
				local objValue = Instance.new("ObjectValue")
				objValue.Value = part
				objValue.Parent = frame
			end
			duration += finish - start
			count += 1
		end
	end

	do

		local avg = duration/count
		frustum.Camera:SetAttribute(`_outerbounds_avg_ms`, toMilliseconds(avg))
		frustum.Camera:SetAttribute(`_outerbounds_limit`, math.floor(RENDER_DURATION/avg))
	end
end

function Util.innerBounds(screen: LayerCollector, frustum: Frustum, parts: {[number]: BasePart})
	local count = 0
	local duration = 0
	
	for i, part in pairs(parts) do
		if frustum:GetIfOverlapFrustum(part) and part.Name == "Block30" then
			local shape = frustum:GetProjectedShape(part.CFrame, part.Size)

			local start = tick()
			local rect = frustum:GetInnerBlockBounds(shape)
			local finish = tick()				

			local frame = drawRect(
				screen,
				rect,
				Color3.new(1,1,0.5),
				(frustum.CFrame.Position - part.Position).Magnitude / frustum.FarPlaneDistance,
				50+20*(1-(frustum.CFrame.Position - part.Position).Magnitude / frustum.FarPlaneDistance)
			)

			if frame then
				local objValue = Instance.new("ObjectValue")
				objValue.Value = part
				objValue.Parent = frame
			end


			count += 1
			duration += (finish - start)
		end
	end

	do

		local avg = duration/count
		frustum.Camera:SetAttribute(`_innerbounds_avg_ms`, toMilliseconds(avg))
		frustum.Camera:SetAttribute(`_innerbounds_limit`, math.floor(RENDER_DURATION/avg))
	end
end

function Util.maskRegister(screen: LayerCollector, frustum: Frustum, parts: {[number]: BasePart})
	local duration = 0
	local count = 0
	local mask = Mask.new() :: Mask<BasePart>

	for i, part in ipairs(parts) do
		if frustum:GetIfOverlapFrustum(part) then
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

			duration += finish - start
			count += 1
		end
	end

	do

		local avg = duration/count
		frustum.Camera:SetAttribute(`_maskreg_avg_ms`, toMilliseconds(avg))
		frustum.Camera:SetAttribute(`_maskreg_limit`, math.floor(RENDER_DURATION/avg))
	end
end

function Util.maskSearch(screen: LayerCollector, frustum: Frustum, parts: {[number]: BasePart})
	local duration = 0
	local count = 0
	local mask = Mask.new() :: Mask<BasePart>

	for i, part in ipairs(parts) do
		if frustum:GetIfOverlapFrustum(part) then
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

			local color = if not isOccluded then Color3.new(0, 1, 1) else Color3.new(1,0,0)
			drawRect(
				screen,
				maskData.InnerRect,
				color,
				if not isOccluded then 0.8 else 0,
				frustum.FarPlaneDistance - distance
			)

			duration += finish - start
			count += 1
		end
	end

	do
		local avg = duration/count
		frustum.Camera:SetAttribute(`_masksearch_avg_ms`, toMilliseconds(avg))
		frustum.Camera:SetAttribute(`_masksearch_limit`, math.floor(RENDER_DURATION/avg))
	end
end

function Util.total(screen: LayerCollector, frustum: Frustum, parts: {[number]: BasePart})
	local duration = 0
	local count = 0
	local mask = Mask.new() :: Mask<BasePart>

	for i, part in ipairs(parts) do
		if frustum:GetIfOverlapFrustum(part) then

			local start = tick()

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
			local finish = tick()
			duration += finish - start
			count += 1
		end
	end

	for i, part in ipairs(parts) do
		if frustum:GetIfOverlapFrustum(part) then
			local start = tick()
			mask:GetIfOccluded(part)
			local finish = tick()

			local maskData = mask._Items[part]
			assert(maskData)

			duration += finish - start
		end
	end

	do	
		local avg = duration/count
		frustum.Camera:SetAttribute(`_total_avg_ms`, toMilliseconds(avg))
		frustum.Camera:SetAttribute(`_total_limit`, math.floor(RENDER_DURATION/avg))
	end
end

return Util