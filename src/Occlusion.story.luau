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
local MAX_RENDER_DISTANCE = 2048
local PERFORMANCE_TEST = false
local USE_REAL_CAMERA = true
local FIELD_OF_VIEW = if USE_REAL_CAMERA then workspace.CurrentCamera.FieldOfView else 55

-- Variables
-- References
-- Class
return function(frame: Frame)
	local maid = Maid.new()
			
	Config.Debug.NoDebugRender = PERFORMANCE_TEST
	Config.Debug.Occlusion = true
	
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
		for k, v in pairs(part:GetAttributes()) do
			part:SetAttribute(k, nil)
		end

		local camera: Camera
		if USE_REAL_CAMERA then
			camera = workspace.CurrentCamera
			for k, v in pairs(camera:GetAttributes()) do
				camera:SetAttribute(k, nil)
			end
		else
			camera = maid:GiveTask(Instance.new("Camera"))
			camera:SetAttribute("NearPlaneZ", -50)
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
		oCam.MaxRenderDistance = MAX_RENDER_DISTANCE

		maid:GiveTask(RunService.RenderStepped:Connect(function()
			if camera ~= workspace.CurrentCamera then
				camera.CFrame = part.CFrame
			end
		end))
	end)
	return function()
		maid:Destroy()
	end
end