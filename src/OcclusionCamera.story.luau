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
local USE_REAL_CAMERA = false
-- Variables
-- References
local Map = workspace:WaitForChild("Map")
-- Class
return function(frame: Frame)
	local maid = Maid.new()
			
	local highlights: {[BasePart]: SelectionBox} = {

	}
	
	task.spawn(function()
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

		local camera: Camera
		if USE_REAL_CAMERA then
			camera = workspace.CurrentCamera
		else
			camera = maid:GiveTask(Instance.new("Camera"))
			camera:SetAttribute("NearPlaneZ", -25)
			camera:SetAttribute("ViewportSize", Vector2.new(1280, 800))
			camera.FieldOfView = 55
			camera.Parent = part
		end		

		local oCam = maid:GiveTask(OcclusionCamera.new(camera))
		oCam.OnlyUpdateOnCameraMove = false
		oCam.MaxRenderDistance = 2048
		oCam.RaycastParams.FilterDescendantsInstances = Map:GetChildren()--}
		oCam.RaycastParams.FilterType = Enum.RaycastFilterType.Include

		maid:GiveTask(RunService.RenderStepped:Connect(function()
			if camera ~= workspace.CurrentCamera then
				camera.CFrame = part.CFrame
			end
		end))

		maid:GiveTask(oCam.OnPartEnterFrustum:Connect(function(part: BasePart)
			if not highlights[part] then
				local box = Instance.new("SelectionBox")
				box.Adornee = part
				box.SurfaceTransparency = 0.75
				box.SurfaceColor3 = Color3.new(1,1,1)
				box.LineThickness = 2
				box.Color3 = box.SurfaceColor3
				box.Parent = part
				highlights[part] = box
			end
		end))

		maid:GiveTask(oCam.OnObscurePart:Connect(function(part: BasePart)
			local box = highlights[part]
			if box then
				box.SurfaceColor3 = Color3.new(0,0,1)
				box.Color3 = box.SurfaceColor3
			end
		end))
		maid:GiveTask(oCam.OnViewPart:Connect(function(part: BasePart)
			local box = highlights[part]
			if box then
				box.SurfaceColor3 = Color3.new(1,0,0)
				box.Color3 = box.SurfaceColor3
			end
		end))
		maid:GiveTask(oCam.OnPartExitFrustum:Connect(function(part: BasePart)
			local box = highlights[part]
			if box then
				box:Destroy()
				highlights[part] = nil
			end
		end))


		end)
	return function()
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
		for k, v in pairs(highlights) do
			highlights[k] = nil
			v:Destroy()
		end
	end
end