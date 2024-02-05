--!strict
-- Services
local RunService = game:GetService("RunService")
-- Packages
local Maid = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Maid"))
local Draw = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Draw"))

-- Modules
local Frustum = require(script.Parent:WaitForChild("Frustum"))

-- Types
-- Constants
-- Variables
-- References
local PerspectiveBlock = workspace:WaitForChild("PerspectiveBlock") :: Part

-- Class
return function(frame: Frame)
	local maid = Maid.new()
	local drawMaid = maid:GiveTask(Maid.new())
	task.spawn(function()

		local imageLabel = maid:GiveTask(Instance.new("ImageLabel"))
		imageLabel.Size = UDim2.fromScale(1,1)
		imageLabel.BackgroundTransparency = 1
		imageLabel.Parent = frame

		local editableImage = maid:GiveTask(Instance.new("EditableImage"))
		editableImage.Parent = imageLabel

		local prevFrustum: Frustum.Frustum?

		local PerspectiveUtil = require(script.Parent:WaitForChild("PerspectiveUtil"))
		maid:GiveTask(RunService.RenderStepped:Connect(function()
			local frustum = Frustum.fromCamera(workspace.CurrentCamera, 10000)
			if prevFrustum == frustum then return end
			prevFrustum = frustum
			local points = PerspectiveUtil.getWorldPerimeter(
				PerspectiveBlock.CFrame,
				PerspectiveBlock.Size,
				frustum.CFrame
			)


			drawMaid:DoCleaning()
			for i, v in ipairs(points) do
				local nv = points[i+1] or points[1]
				drawMaid:GiveTask(Draw.vector(
					v,
					nv-v,
					Color3.new(0,1,1),
					nil,
					5
				))

				drawMaid:GiveTask(Draw.point(v, Color3.new(1,0,0), nil, 10))
			end

			editableImage.Size = imageLabel.AbsoluteSize
			editableImage:WritePixels(
				Vector2.zero,
				editableImage.Size,
				table.create(editableImage.Size.X*editableImage.Size.Y*4, 0)
			)
			local screenPoints = PerspectiveUtil.getScreenPerimeter(
				PerspectiveBlock.CFrame,
				PerspectiveBlock.Size,
				workspace.CurrentCamera
			)
			for i, v in ipairs(screenPoints) do
				local nv = screenPoints[i+1] or screenPoints[1]
				nv = Vector3.new(
					math.clamp(nv.X, 0, editableImage.Size.X-1),
					math.clamp(nv.Y, 0, editableImage.Size.Y-1),
					nv.Z
				)
				v = Vector3.new(
					math.clamp(v.X, 0, editableImage.Size.X-1),
					math.clamp(v.Y, 0, editableImage.Size.Y-1),
					v.Z
				)
				editableImage:DrawLine(
					Vector2.new(v.X, v.Y),
					Vector2.new(nv.X, nv.Y),
					Color3.new(1,1,0),
					0
				)
			end
			for i, v in ipairs(screenPoints) do
				-- print(v, "->", editableImage.Size)
				v = Vector3.new(
					math.clamp(v.X, 0, editableImage.Size.X),
					math.clamp(v.Y, 0, editableImage.Size.Y),
					v.Z
				)
				editableImage:DrawCircle(
					Vector2.new(v.X, v.Y),
					20,
					Color3.new(1,0,1),
					0
				)
			end
		end))
	end)
	return function()
		maid:Destroy()
	end
end