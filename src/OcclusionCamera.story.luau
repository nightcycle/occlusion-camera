--!strict
local _Package = script.Parent
local _Packages = _Package.Parent
-- Services
local RunService = game:GetService("RunService")
-- Packages
local Maid = require(_Packages:WaitForChild("Maid"))
-- Modules
-- Types
-- Constants
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

		local part = maid:GiveTask(Instance.new("Part"))
		part.Name = "CameraHolder"
		part.CFrame = CFrame.new(0,20,0)
		part.Size = Vector3.new(2, 1, 0.05)
		part.Anchored = true
		part.Parent = workspace

		local camera = maid:GiveTask(Instance.new("Camera"))
		camera:SetAttribute("ViewportSize", Vector2.new(1280, 800))
		camera:SetAttribute("NearPlaneZ", -5)
		camera.FieldOfView = 55
		camera.Parent = part

		local oCam = maid:GiveTask(OcclusionCamera.new(camera))
		oCam.OnlyUpdateOnCameraMove = false
		oCam.RaycastParams.FilterDescendantsInstances = Map:GetChildren()
		oCam.RaycastParams.FilterType = Enum.RaycastFilterType.Include

		maid:GiveTask(RunService.RenderStepped:Connect(function()
			camera.CFrame = part.CFrame
			part:SetAttribute("Frequency", oCam._Frequency)
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
		for k, v in pairs(highlights) do
			highlights[k] = nil
			v:Destroy()
		end
	end
end