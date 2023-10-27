--!strict
local _Package = script.Parent
local _Packages = _Package.Parent
-- Services
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
-- Packages
local Maid = require(_Packages:WaitForChild("Maid"))
-- Modules
local Config = require(_Package:WaitForChild("Config"))
-- Types
-- Constants
local IN_FRUSTUM_TAG = Config.Tag.InFrustum
local OBSCURED_TAG = Config.Tag.Obscured
local INITIAL_OBSCURED_TAG = Config.Tag.InitialObscured
local VISIBLE_TAG = Config.Tag.Visible
local LAST_SEEN_ATTR_KEY = Config.Attribute.LastSeen
local FIELD_OF_VIEW = 55
local MAX_RENDER_DISTANCE = 2048
local USE_REAL_CAMERA = true
local PERFORMANCE_TEST = false

-- Variables
-- References
local Map = workspace:WaitForChild("MediumMap")
-- Class
return function(frame: Frame)
	local maid = Maid.new()
			
	Config.Debug.NoDebugRender = true -- PERFORMANCE_TEST

	local isDead = false
	task.spawn(function()
		task.wait(1)
		if isDead then return end
		local OcclusionCamera = require(_Package)


		local part = workspace:FindFirstChild("CameraHolder")
		if not part then
			part = Instance.new("Part")
			assert(part and part:IsA("BasePart"))
			part.Name = "CameraHolder"
			part.CFrame = CFrame.new(-189.282, 109, 117.047) * CFrame.fromOrientation(0, math.rad(150), 0)
			part.Size = Vector3.new(2, 1, 0.05)
			part.Anchored = true
			part.Parent = workspace
			
		end
		assert(part and part:IsA("BasePart"))
		for k, v in pairs(part:GetAttributes()) do
			part:SetAttribute(k, nil)
		end

		local camera: Camera
		if USE_REAL_CAMERA then
			camera = workspace.CurrentCamera
		else
			camera = maid:GiveTask(Instance.new("Camera"))
			camera:SetAttribute("NearPlaneZ", -5)
			camera:SetAttribute("ViewportSize", Vector2.new(1280, 800))
			camera.FieldOfView = FIELD_OF_VIEW
			camera.Parent = part
			
			maid:GiveTask(camera.AttributeChanged:Connect(function(key: string)
				part:SetAttribute(key, camera:GetAttribute(key))
			end))

			for k, v in pairs(camera:GetAttributes()) do
				part:SetAttribute(k, v)
			end
		end		

		local oCam = maid:GiveTask(OcclusionCamera.new(camera))
		oCam.OnlyUpdateOnCameraMove = false
		oCam.MaxRenderDistance = MAX_RENDER_DISTANCE

		maid:GiveTask(RunService.RenderStepped:Connect(function()
			if camera ~= workspace.CurrentCamera then
				camera.CFrame = part.CFrame
			end
		end))

		-- maid:GiveTask(oCam.OnPartEnterFrustum:Connect(function(part: BasePart)
		-- 	part.Color = Color3.new(1,1,0)
		-- end))

		-- maid:GiveTask(oCam.OnObscurePart:Connect(function(part: BasePart)
		-- 	part.Color = Color3.new(1,0,0)
		-- end))
		-- maid:GiveTask(oCam.OnViewPart:Connect(function(part: BasePart)
		-- 	part.Color = Color3.new(0,0,1)
		
		-- end))
		-- maid:GiveTask(oCam.OnPartExitFrustum:Connect(function(part: BasePart)
		-- 	part.Color = Color3.new(0,0,0)
		-- end))

		local parts: {[number]: BasePart} = Map:GetChildren() :: any

		maid:GiveTask(RunService.RenderStepped:Connect(function()
			for i, part in ipairs(parts) do
				if oCam:GetIfPartIsInFrustum(part) then
					if not oCam:GetIfPartIsVisible(part) then
						part.Color = Color3.new(1,0,0)
					else
						part.Color = Color3.new(0,0,1)
					end
				else
					part.Color = Color3.new(0,0,0)
				end
			end
		end))

		oCam.Parts = parts

	end)
	return function()
		isDead = true
		maid:Destroy()
		for i, inst in ipairs(CollectionService:GetTagged(IN_FRUSTUM_TAG)) do
			CollectionService:RemoveTag(inst, OBSCURED_TAG)
			CollectionService:RemoveTag(inst, INITIAL_OBSCURED_TAG)
			CollectionService:RemoveTag(inst, VISIBLE_TAG)
			inst:SetAttribute(LAST_SEEN_ATTR_KEY, nil)
		end
		for i, inst in ipairs(Map:GetChildren()) do
			if inst:IsA("BasePart") then
				inst.Color = Color3.fromHSV(0,0,0.8)
				local decal = inst:FindFirstChildOfClass("Decal")
				if decal then
					decal.Color3 = inst.Color
				end
			end
		end
	end
end