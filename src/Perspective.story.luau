--!strict
-- Services
local RunService = game:GetService("RunService")
-- Packages
local Maid = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Maid"))
local Draw = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Draw"))
local TableUtil = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("TableUtil"))
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
		
		local PerspectiveUtil = require(script.Parent:WaitForChild("PerspectiveUtil"))
		
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
		local MIN_STEP = 0.001
		local function constrainPoint(v: Vector3): Vector3
			return Vector3.new(
				math.clamp(v.X, 0, editableImage.Size.X-1),
				math.clamp(v.Y, 0, editableImage.Size.Y-1),
				v.Z
			)
		end

		local function getScreenPerimeter(cf: CFrame, size: Vector3, camera: Camera): {[number]: Vector3}
			local worldPoints = PerspectiveUtil.getWorldPerimeter(cf, size, camera:GetRenderCFrame())
			local viewportSize = camera.ViewportSize
			local initialScreenPoints: {[number]: Vector3} = table.create(#worldPoints)
			local pointVisibility: {[number]: boolean} = table.create(#worldPoints)
			local finalScreenPoints: {[number]: Vector3} = table.create(#worldPoints)
		
			for i, v in ipairs(worldPoints) do
				initialScreenPoints[i], pointVisibility[i] = camera:WorldToViewportPoint(
					v
				)
			end
		
			for i, screenPoint in ipairs(initialScreenPoints) do

				local function extendLine(
					visibleWorldPoint: Vector3, 
					hiddenWorldPoint: Vector3,
					visibleScreenPoint: Vector3
				): Vector3
					if hiddenWorldPoint == visibleWorldPoint then
						return visibleScreenPoint
					end
					local worldStepPoint = (hiddenWorldPoint - visibleWorldPoint).Unit * MIN_STEP + visibleWorldPoint
					-- drawMaid:GiveTask(Draw.vector(
					-- 	hiddenWorldPoint,
					-- 	visibleWorldPoint-hiddenWorldPoint,
					-- 	Color3.new(1,0,0),
					-- 	nil,
					-- 	2
					-- ))
		
					local screenStepPoint, isScreenStepVisible = camera:WorldToViewportPoint(worldStepPoint)
					local screenLineNormalV2 = (
						Vector2.new(screenStepPoint.X, screenStepPoint.Y) 
						- Vector2.new(visibleScreenPoint.X, visibleScreenPoint.Y)
					).Unit
		
					local screenLineNormal = Vector3.new(screenLineNormalV2.X, screenLineNormalV2.Y)
					assert(isScreenStepVisible, `nIV is not visible, \nstepPoint=[{screenStepPoint.X}, {screenStepPoint.Y}] \norigin=[{visibleScreenPoint.X}, {visibleScreenPoint.Y}] \nnorm=[{screenLineNormal.X}, {screenLineNormal.Y}]`)
					drawLine(visibleScreenPoint, screenStepPoint, Color3.new(1,1,0))
		
					return getBorderHit(
						visibleScreenPoint.X, visibleScreenPoint.Y,
						screenLineNormal.X, screenLineNormal.Y,
						camera.ViewportSize.X, camera.ViewportSize.Y
					)
				end
		
				local nI = if #initialScreenPoints < i+1 then 1 else i
				local pI = if i==1 then #initialScreenPoints else i-1

				local nextScreenPoint = initialScreenPoints[nI]
				local prevScreenPoint = initialScreenPoints[pI]

				local worldPoint = worldPoints[i]
				local nextWorldPoint = worldPoints[nI]
				local prevWorldPoint = worldPoints[pI]

				local isVisible = pointVisibility[i]
				local nextIsVisible = pointVisibility[nI]
				local prevIsVisible = pointVisibility[pI]
				
				drawMaid:GiveTask(
					Draw.text(
						worldPoint,
						`{i}`
					)
				)
				if isVisible then
					if not prevIsVisible then
						table.insert(finalScreenPoints, extendLine(
							worldPoint,
							prevWorldPoint,
							screenPoint
						))
					end
					table.insert(finalScreenPoints, screenPoint)
					if not nextIsVisible then
						table.insert(finalScreenPoints, extendLine(
							worldPoint,
							nextWorldPoint,
							screenPoint
						))
					end

					
				else
					if nextIsVisible then
						table.insert(finalScreenPoints, extendLine(
							nextWorldPoint,
							worldPoint,
							nextScreenPoint
						))
					end

					if prevIsVisible then
						table.insert(finalScreenPoints, extendLine(
							prevWorldPoint,
							worldPoint,
							prevScreenPoint
						))
					end
				end


				-- if isVisible and nextIsVisible then
				-- 	table.insert(finalScreenPoints, screenPoint)
				-- else
				-- 	if nextIsVisible then
				-- 		table.insert(finalScreenPoints, extendLine(
				-- 			nextWorldPoint,
				-- 			worldPoint,
				-- 			nextScreenPoint
				-- 		))
				-- 	elseif prevIsVisible then
				-- 		table.insert(finalScreenPoints, extendLine(
				-- 			prevWorldPoint,
				-- 			worldPoint,
				-- 			prevScreenPoint
				-- 		))

				-- 	end
				-- end
	
			end
			print(#initialScreenPoints, "->",#finalScreenPoints)
			if #finalScreenPoints >= 3 then
				return finalScreenPoints
			else
				return {}
			end
		end

		local prevFrustum: Frustum.Frustum?

		maid:GiveTask(RunService.RenderStepped:Connect(function()
			local frustum = Frustum.fromCamera(workspace.CurrentCamera, 10000)
			if prevFrustum == frustum then return end
			prevFrustum = frustum
			drawMaid:DoCleaning()

			local points = PerspectiveUtil.getWorldPerimeter(
				PerspectiveBlock.CFrame,
				PerspectiveBlock.Size,
				frustum.CFrame
			)


			for i, v in ipairs(points) do
				local nv = points[i+1] or points[1]
				-- drawMaid:GiveTask(Draw.vector(
				-- 	v,
				-- 	nv-v,
				-- 	Color3.new(0,0,0),
				-- 	nil,
				-- 	5
				-- ))

				-- drawMaid:GiveTask(Draw.point(v, Color3.new(0,0,0), nil, 10))
			end

			editableImage.Size = imageLabel.AbsoluteSize
			editableImage:WritePixels(
				Vector2.zero,
				editableImage.Size,
				table.create(editableImage.Size.X*editableImage.Size.Y*4, 0)
			)
			local screenPoints = getScreenPerimeter(
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
					Color3.new(0,1,0),
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
				-- editableImage:DrawCircle(
				-- 	Vector2.new(v.X, v.Y),
				-- 	5,
				-- 	Color3.new(1,0,1),
				-- 	0
				-- )
			end
		end))
	end)
	return function()
		maid:Destroy()
	end
end