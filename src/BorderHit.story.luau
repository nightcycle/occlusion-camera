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

-- Class
return function(frame: Frame)
	local maid = Maid.new()
	task.spawn(function()

		local imageLabel = maid:GiveTask(Instance.new("ImageLabel"))
		imageLabel.Size = UDim2.fromScale(1,1)
		imageLabel.BackgroundTransparency = 1
		imageLabel.Parent = frame

		local editableImage = maid:GiveTask(Instance.new("EditableImage"))
		editableImage.Parent = imageLabel

		local function drawLine(v: Vector3, nv: Vector3, col: Color3)
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
				col,
				0
			)
			editableImage:DrawCircle(
				Vector2.new(v.X, v.Y),
				5,
				col,
				0
			)
			editableImage:DrawCircle(
				Vector2.new(nv.X, nv.Y),
				5,
				col,
				0
			)
		end

		local function getBorderHit(
			originX: number, originY: number,
			normalX: number, normalY: number, 
			screenSizeX: number, screenSizeY: number
		): Vector3

			local stepsToX: number
			if normalX < 0 then
				stepsToX = -originX/normalX
			elseif normalX > 0 then
				stepsToX = (screenSizeX-originX)/normalX
			else
				stepsToX = math.huge
			end

			local stepsToY: number
			if normalY < 0 then
				stepsToY = -originY/normalY
			elseif normalY > 0 then
				stepsToY = (screenSizeY-originY)/normalY
			else
				stepsToY = math.huge
			end

			local steps = math.min(stepsToX, stepsToY)
			if steps == math.huge then
				return Vector3.new(originX, originY)
			else
				return Vector3.new(
					originX + normalX * steps,
					originY + normalY * steps
				)
			end

		end

		local rotation = 0

		maid:GiveTask(RunService.RenderStepped:Connect(function(deltaTime: number)
			editableImage.Size = imageLabel.AbsoluteSize
			editableImage:WritePixels(
				Vector2.zero,
				editableImage.Size,
				table.create(editableImage.Size.X*editableImage.Size.Y*4, 0)
			)
			rotation += math.rad(deltaTime * 90)
			local normal = Vector2.new(
				math.cos(rotation),
				math.sin(rotation)
			).Unit
			local origin = workspace.CurrentCamera.ViewportSize * 0.5
			local hit = getBorderHit(
				origin.X, origin.Y,
				normal.X, normal.Y,
				workspace.CurrentCamera.ViewportSize.X,
				workspace.CurrentCamera.ViewportSize.Y
			)
			drawLine(
				Vector3.new(origin.X, origin.Y),
				Vector3.new(hit.X, hit.Y),
				Color3.new(1,0,0)
			)
		end))
	end)
	return function()
		maid:Destroy()
	end
end