--!strict
-- Services
-- Packages
-- Modules
local Frustum = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("package"):WaitForChild("Frustum"))
-- Types
type Frustum = Frustum.Frustum
type BenchmarkProfiler = {
	Begin: (label: string) -> (),
	End: () -> (),
}
type TestFunction<V> = (profiler: BenchmarkProfiler, parameter: V) -> ()
type TestModule<V> = {
	ParameterGenerator: () -> V,
	Functions: {
		[string]: TestFunction<V>
	}
}
type Parameter = {
	Frustum: Frustum,
	Rectangles: {[number]: {[number]: Vector3}},
	Triangles: {[number]: {[number]: Vector3}},
	Parts: {[number]: BasePart}
}
-- Constants
local START = Vector3.new(-1000, 0, -1000)
local FINISH = Vector3.new(1000, 250, 1000)
local MID = START:Lerp(FINISH,  0.5)
local SAMPLES_PER_TEST = 1000
-- Variables
-- References
local CullingMap = game.Workspace:WaitForChild("CullingMap") :: Folder
-- local FrustumTest = workspace:WaitForChild("FrustumTest") :: Part
-- local CustomFrustum = Frustum.new(
-- 	FrustumTest.CFrame,
-- 	FrustumTest:GetAttribute("FieldOfView") or 50,
-- 	FrustumTest:GetAttribute("ViewportSize") or Vector2.new(800, 600),
-- 	FrustumTest:GetAttribute("NearPlaneZ") or -20,
-- 	FrustumTest:GetAttribute("MaxRenderDistance") or 2000
-- )
-- Private Functions
function getRandomFrustumCF(): CFrame
	local x = math.random(START.X, FINISH.X)
	local y = math.random(START.Y, FINISH.Y)
	local z = math.random(START.Z, FINISH.Z)
	local origin = Vector3.new(x,y,z)
	return CFrame.new(origin, MID)
end

-- Class
function new(generator: () -> Parameter): TestModule<Parameter>
	return {
		ParameterGenerator = generator,
		Functions = {
			["Block"] = function(profiler: BenchmarkProfiler, parameter: Parameter)
				local frustum = parameter.Frustum
				for i, v in ipairs(parameter.Parts) do
					assert(v:IsA("BasePart"))
					frustum:GetIfBlockRendered(v.CFrame, v.Size)
				end
			end,
			["Plane"] = function(profiler: BenchmarkProfiler, parameter: Parameter)
				local frustum = parameter.Frustum
				for i, v in ipairs(parameter.Parts) do
					assert(v:IsA("BasePart"))
					frustum:GetIfPlaneRendered(v.CFrame.Position, v.CFrame.LookVector)
				end
			end,
			["Point"] = function(profiler: BenchmarkProfiler, parameter: Parameter)
				local frustum = parameter.Frustum
				for i, v in ipairs(parameter.Parts) do
					assert(v:IsA("BasePart"))
					frustum:GetIfPointRendered(v.CFrame.Position)
				end
			end,
			["Sphere"] = function(profiler: BenchmarkProfiler, parameter: Parameter)
				local frustum = parameter.Frustum
				for i, v in ipairs(parameter.Parts) do
					assert(v:IsA("BasePart"))
					frustum:GetIfSphereRendered(v.Position, v.Size.Magnitude/2)
				end
			end,
			["Rectangle"] = function(profiler: BenchmarkProfiler, parameter: Parameter)
				local frustum = parameter.Frustum
				for i, v in ipairs(parameter.Rectangles) do
					frustum:GetIfRectangleRendered(v[1], v[2], v[3], v[4])
				end
			end,
			["Triangle"] = function(profiler: BenchmarkProfiler, parameter: Parameter)
				local frustum = parameter.Frustum
				for i, v in ipairs(parameter.Triangles) do
					frustum:GetIfTriangleRendered(v[1], v[2], v[3])
				end
			end,
		},
	} :: TestModule<Parameter>
end

return new(function()
	local frustum = Frustum.new(
		getRandomFrustumCF(),
		50,
		Vector2.new(800, 600),
		-0.1,
		10000
	)

	local parts: {[number]: BasePart} = table.create(SAMPLES_PER_TEST)
	local rectangles: {[number]: {[number]: Vector3}} = table.create(SAMPLES_PER_TEST)
	local triangles: {[number]: {[number]: Vector3}} = table.create(SAMPLES_PER_TEST)
	local allParts = CullingMap:GetChildren()
	local random = Random.new()
	for i=1, SAMPLES_PER_TEST do
		local part = allParts[math.random(1, #allParts)]
		assert(part:IsA("BasePart"))
		parts[i] = part
		triangles[i] = {
			part.Position + random:NextUnitVector() * random:NextNumber() * part.Size.Magnitude*0.5,
			part.Position + random:NextUnitVector() * random:NextNumber() * part.Size.Magnitude*0.5,
			part.Position + random:NextUnitVector() * random:NextNumber() * part.Size.Magnitude*0.5,
		}
		local cf = part.CFrame * CFrame.Angles(
			math.rad(random:NextNumber()*360),
			math.rad(random:NextNumber()*360),
			math.rad(random:NextNumber()*360)
		)
		rectangles[i] = {
			cf.Position + cf.RightVector * 0.5 * part.Size.X + cf.UpVector * part.Size.Y * 0.5,
			cf.Position - cf.RightVector * 0.5 * part.Size.X + cf.UpVector * part.Size.Y * 0.5,
			cf.Position + cf.RightVector * 0.5 * part.Size.X - cf.UpVector * part.Size.Y * 0.5,
			cf.Position - cf.RightVector * 0.5 * part.Size.X - cf.UpVector * part.Size.Y * 0.5,
		}
	end
	return {
		Frustum = frustum,
		Parts = parts,
		Rectangles = rectangles,
		Triangles = triangles,
	}
end)
