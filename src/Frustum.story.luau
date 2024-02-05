--!strict
-- Services
local RunService = game:GetService("RunService")

-- Packages
local Maid = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Maid"))
-- Modules
-- Types
-- Constants
-- Variables
-- References
local FrustumTest = workspace:WaitForChild("FrustumTest") :: Part
local CullingMap = workspace:WaitForChild("CullingMap") :: Folder
-- Class
return function(frame: Frame)
	local maid = Maid.new()
	local drawMaid = maid:GiveTask(Maid.new())
	task.spawn(function()
		local Frustum = require(script.Parent.Frustum)
		maid:GiveTask(RunService.RenderStepped:Connect(function()
			local frustum = Frustum.new(
				FrustumTest.CFrame,
				FrustumTest:GetAttribute("FieldOfView") or 50,
				FrustumTest:GetAttribute("ViewportSize") or Vector2.new(800, 600),
				FrustumTest:GetAttribute("NearPlaneZ") or -20,
				FrustumTest:GetAttribute("MaxRenderDistance") or 2000
			)
			drawMaid:DoCleaning()
			local render = drawMaid:GiveTask(frustum:_Draw())
			render.Parent = workspace.CurrentCamera
			for i, v in ipairs(CullingMap:GetChildren()) do
				if v:IsA("BasePart") then
					if frustum:GetIfSphereRendered(v.Position, v.Size.Magnitude/2) then
						v.Color = Color3.new(1,0,0)
					else
						v.Color = Color3.new(0,0,1)
					end
				end
			end
		end))
	end)
	return function()
		maid:Destroy()
		for i, v in ipairs(CullingMap:GetChildren()) do
			if v:IsA("BasePart") then

				v.Color = Color3.fromRGB(204, 204, 204)

			end
		end
	end
end