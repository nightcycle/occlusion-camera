--!strict
-- pre-maps all the relevant geometry data for different cube perspectives, hopefully saves time in processing
local _Package = script.Parent
local _Packages = _Package.Parent

-- Services
local Debris = game:GetService("Debris")
local TouchInputService = game:GetService("TouchInputService")

-- Packages
local TableUtil = require(_Packages:WaitForChild("TableUtil"))
local Draw = require(_Packages:WaitForChild("Draw"))
local MeshUtil = require(_Packages:WaitForChild("MeshUtil"))

-- Modules
-- Types
type CornerId = "XYZ" | "xYZ" | "XYz" | "xYz" | "XyZ" | "xyZ" | "Xyz" | "xyz"
type EdgeId = "YZ" | "Yz" | "yZ" |  "yz" | "XZ" | "xZ" | "Xz" | "xz" | "XY" | "xY" | "Xy" | "xy"
type FaceId = "X" | "x" | "Y" | "y" | "Z" | "z"
-- Constants
local CORNER_TO_NORMAL_ID: {[string]: Enum.NormalId} = {
	X = Enum.NormalId.Right,
	x = Enum.NormalId.Left,
	y = Enum.NormalId.Bottom,
	Y = Enum.NormalId.Top,
	z = Enum.NormalId.Front,
	Z = Enum.NormalId.Back,
}


local SURFACE_CORNERS: {[Enum.NormalId]: {[number]: CornerId}} = {
	[Enum.NormalId.Right] = {
		"XYZ", 
		"XYz", 
		"XyZ",
		"Xyz"
	},
	[Enum.NormalId.Left] = {
		"xYZ", 
		"xYz", 
		"xyZ",
		"xyz"
	},
	[Enum.NormalId.Top] = {
		"XYZ", 
		"xYZ", 
		"XYz",
		"xYz"
	},
	[Enum.NormalId.Bottom] = {
		"XyZ", 
		"xyZ", 
		"Xyz",
		"xyz"
	},
	[Enum.NormalId.Back] = {
		"XYZ", 
		"xYZ", 
		"XyZ",
		"xyZ"
	},
	[Enum.NormalId.Front] = {
		"XYz", 
		"xYz", 
		"Xyz",
		"xyz"
	},
}

local FACE_TRIANGLE_DATA: {[FaceId]: {[number]: {[number]: CornerId}}} = {
	X = {
		{"Xyz", "XYz", "XYZ"},
		{"Xyz", "XyZ", "XYZ"},
	},
	x = {
		{"xyz", "xYz", "xYZ"},
		{"xyz", "xyZ", "xYZ"},
	},
	Z = {
		{"xyZ", "xYZ", "XYZ"},
		{"xyZ", "XyZ", "XYZ"},
	},
	z = {
		{"xyz", "xYz", "XYz"},
		{"xyz", "Xyz", "XYz"},
	},
	Y = {
		{"xYz", "xYZ", "XYZ"},
		{"xYz", "XYz", "XYZ"},
	},
	y = {
		{"xyz", "xyZ", "XyZ"},
		{"xyz", "Xyz", "XyZ"},
	},
}

local FACE_PERIMETER_DATA: {[FaceId]: {[number]: CornerId}} = {
	X = {"Xyz", "XYz", "XYZ", "XyZ"},
	x = {"xyz", "xYz", "xYZ", "xyZ"},
	Y = {"xYz", "XYz", "XYZ", "xYZ"},
	y = {"xyz", "Xyz", "XyZ", "xyZ"},
	Z = {"xyZ", "XyZ", "XYZ", "xYZ"},
	z = {"xyz", "Xyz", "XYz", "xYz"},
}

local EDGE_TRIANGLE_DATA: {[EdgeId]: {[number]: {[number]: CornerId}}} = {
	Xy = {
		{"Xyz", "xyz", "xyZ"},
		{"Xyz", "XYz", "XYZ"},
		{"XyZ", "xyZ", "XYZ"},
		{"Xyz", "xyZ", "XYZ"},
	},
	XY = {
		{"XYz", "xYz", "xYZ"},
		{"XYz", "Xyz", "XyZ"},
		{"XYZ", "xYZ", "XyZ"},
		{"XYz", "xYZ", "XyZ"},
	},
	xy = {
		{"xyz", "Xyz", "XyZ"},
		{"xyz", "xYz", "xYZ"},
		{"xyZ", "XyZ", "xYZ"},
		{"xyz", "XyZ", "xYZ"},
	},
	xY = {
		{"xYz", "XYz", "XYZ"},
		{"xYz", "xyz", "xyZ"},
		{"xYZ", "XYZ", "xyZ"},
		{"xYz", "XYZ", "xyZ"},
	},
	Xz = {
		{"Xyz", "xyz", "xYz"},
		{"Xyz", "XyZ", "XYZ"},
		{"XYz", "xYz", "XYZ"},
		{"Xyz", "xYz", "XYZ"},
	},
	XZ = {
		{"XyZ", "xyZ", "xYZ"},
		{"XyZ", "XyZ", "XYz"},
		{"XYZ", "xYZ", "XYz"},
		{"XyZ", "xYZ", "XYz"},
	},
	xz = {
		{"xyz", "Xyz", "XYz"},
		{"xyz", "xyZ", "xYZ"},
		{"xYz", "XYz", "xYZ"},
		{"xyz", "XYz", "xYZ"},
	},
	xZ = {
		{"xyZ", "XyZ", "XYZ"},
		{"xyZ", "xyz", "xYz"},
		{"xYZ", "XYZ", "xYz"},
		{"xyZ", "XYZ", "xYz"},
	},
	Yz = {
		{"xYz", "xyz", "Xyz"},
		{"xYz", "xYZ", "XYZ"},
		{"XYz", "Xyz", "XYZ"},
		{"xYz", "Xyz", "XYZ"},
	},
	yz = {
		{"xyz", "xYz", "XYz"},
		{"xyz", "xyZ", "XyZ"},
		{"Xyz", "XYz", "XyZ"},
		{"xyz", "XYz", "XyZ"},
	},
	YZ = {
		{"xYZ", "xyZ", "XyZ"},
		{"xYZ", "xYz", "XYz"},
		{"XYZ", "XyZ", "XYz"},
		{"xYZ", "XyZ", "XYz"},
	},
	yZ = {
		{"xyZ", "xYZ", "XYZ"},
		{"xyZ", "xyz", "Xyz"},
		{"XyZ", "XYZ", "Xyz"},
		{"xyZ", "XYZ", "Xyz"},
	},
}


local EDGE_PERIMETER_DATA: {[EdgeId]: {[number]: CornerId}} = {
	Xy = {"Xyz", "xyz", "xyZ", "XyZ", "XYZ", "XYz"},
	XY = {"XYz", "xYz", "xYZ", "XYZ", "XyZ", "Xyz"},
	xY = {"xYz", "XYz", "XYZ", "xYZ", "xyZ", "xyz"},
	xy = {"xyz", "Xyz", "XyZ", "xyZ", "xYZ", "xYz"},

	Xz = {"Xyz", "xyz", "xYz", "XYz", "XYZ", "XyZ"},
	XZ = {"XyZ", "xyZ", "xYZ", "XYZ", "XYz", "Xyz"},
	xZ = {"xyZ", "XyZ", "XYZ", "xYZ", "xYz", "xyz"},
	xz = {"xyz", "Xyz", "XYz", "xYz", "xYZ", "xyZ"},

	Yz = {"xYz", "xyz", "Xyz", "XYz", "XYZ", "xYZ"},
	YZ = {"xYZ", "xyZ", "XyZ", "XYZ", "XYz", "xYz"},
	yZ = {"xyZ", "xYZ", "XYZ", "XyZ", "Xyz", "xyz"},
	yz = {"xyz", "xYz", "XYz", "Xyz", "XyZ", "xyZ"},

}


type CornerInfo = {
	Offset: Vector3,
	EdgeTriangles: {
		[number]: {
			Opp: CornerId,
			Edge1: CornerId,
			Edge2: CornerId
		}
	},
	CenterTriangle: {
		A: CornerId,
		B: CornerId,
		C: CornerId
	},
	Perimeter: {
		A: CornerId,
		B: CornerId,
		C: CornerId,
		D: CornerId,
		E: CornerId,
		F: CornerId,
	},
}

local CORNER_INFO: {[CornerId]: CornerInfo} = {}

for _, x in ipairs({"X", "x"}) do

	local xNormalId = CORNER_TO_NORMAL_ID[x]
	assert(xNormalId)
	local xVec = Vector3.fromNormalId(xNormalId)

	for _, y in ipairs({"Y", "y"}) do

		local yNormalId = CORNER_TO_NORMAL_ID[y]
		assert(yNormalId)
		local yVec = Vector3.fromNormalId(yNormalId)

		for _, z in ipairs({"Z", "z"}) do

			local zNormalId = CORNER_TO_NORMAL_ID[z]
			assert(zNormalId)
			local zVec = Vector3.fromNormalId(zNormalId)

			local id = `{x}{y}{z}` :: CornerId
			
			CORNER_INFO[id :: CornerId] = {
				Offset = (xVec + yVec + zVec)/2,
				EdgeTriangles = {},
				CenterTriangle = {},
				Perimeter = {},
			} :: any

			local finalTriangle: {[CornerId]: true} = {}

			for nId, cornerList in pairs(SURFACE_CORNERS) do
				if table.find(cornerList, id) then
					local edges: {[number]: CornerId} = {}
					local opp: CornerId
					for j, corner in ipairs(cornerList) do
						local cX = corner:sub(1,1)
						local cY = corner:sub(2,2)
						local cZ = corner:sub(3,3)
						local similarityCount = 0
						if cX == x then
							similarityCount += 1
						end
						if cY == y then
							similarityCount += 1
						end
						if cZ == z then
							similarityCount += 1
						end
						if similarityCount ~= 3 then
							if similarityCount == 1 then --opposite
								opp = corner :: CornerId
							else
								table.insert(edges, corner)
							end
						end
					end
					local edge1 = edges[1]
					local edge2 = edges[2]
					assert(edge1 and edge2, `bad edges`)
					table.insert(CORNER_INFO[id :: CornerId].EdgeTriangles,{
						Opp = opp :: CornerId,
						Edge1 = edge1 :: CornerId,
						Edge2 = edge2 :: CornerId,
					})
					finalTriangle[edge1 :: CornerId] = true
					finalTriangle[edge2 :: CornerId] = true
				end
			end
			do
				local vertices = TableUtil.keys(finalTriangle)

				local a,b,c = vertices[1], vertices[2], vertices[3]
				assert(a and b and c)

				CORNER_INFO[id :: CornerId].CenterTriangle = {
					A = a :: CornerId,
					B = b :: CornerId,
					C = c :: CornerId,
				}

				local function getConnectingCorner(c1: CornerId, c2: CornerId): CornerId
					for k, v in pairs(CORNER_INFO[id :: CornerId].EdgeTriangles) do
						if v.Edge1 == c1 and v.Edge2 == c2 then
							return v.Opp
						elseif v.Edge1 == c2 and v.Edge2 == c1 then
							return v.Opp
						end
					end
					error(`invalid pairing: {c1}, {c2}`)
				end

				CORNER_INFO[id :: CornerId].Perimeter = {
					A = a :: CornerId,
					B = getConnectingCorner(a :: CornerId, b :: CornerId),
					C = b :: CornerId,
					D = getConnectingCorner(b :: CornerId, c :: CornerId),
					E = c :: CornerId,
					F = getConnectingCorner(c :: CornerId, a :: CornerId)
				}

			end
		end
	end
end


type EdgeInfo = {
	Position: Vector3,
	Axis: Vector3,
	EdgeTriangles: {
		[number]: {
			Opp: CornerId,
			Edge1: CornerId,
			Edge2: CornerId
		}
	},
	CenterTriangle: {
		A: CornerId,
		B: CornerId,
		C: CornerId
	},
	Perimeter: {
		A: CornerId,
		B: CornerId,
		C: CornerId,
		D: CornerId,
		E: CornerId,
		F: CornerId,
	},
}

-- Variables
-- References
-- Private Functions
function getCenterId(cf: CFrame, size: Vector3, cameraPosition: Vector3): string
	local offset = cf:PointToObjectSpace(cameraPosition)
	local x: string, y: string, z: string
	if offset.X < 0 then
		x = "x"
	elseif offset.X >= 0 then
		x = "X"
	end
	if offset.Y < 0 then
		y = "y"
	elseif offset.Y >= 0 then
		y = "Y"
	end
	if offset.Z < 0 then
		z = "z"
	elseif offset.Z >= 0 then
		z = "Z"
	end
	if math.abs(offset.X) <= size.X * 0.5 then
		x = ""
	end
	if math.abs(offset.Y) <= size.Y * 0.5 then
		y = ""
	end
	if math.abs(offset.Z) <= size.Z * 0.5 then
		z = ""
	end
	return `{x}{y}{z}`
end

function getWorldPosition(cf: CFrame, size: Vector3, cornerId: CornerId): Vector3
	local cornerInfo = CORNER_INFO[cornerId]
	local offset = cornerInfo.Offset * size
	return cf:PointToWorldSpace(offset)
end

-- Class
local Util = {}

function Util.getWorldTriangles(cf: CFrame, size: Vector3, cameraPosition: Vector3): {[number]: {A: Vector3, B: Vector3, C: Vector3}}
	local triangles: {[number]: {A: Vector3, B: Vector3, C: Vector3}} = {}

	local centerId: string = getCenterId(cf, size, cameraPosition)

	local function addTriangle(aId: CornerId, bId: CornerId, cId: CornerId)
		local a = getWorldPosition(cf, size, aId)
		local b = getWorldPosition(cf, size, bId)
		local c = getWorldPosition(cf, size, cId)
		-- Debris:AddItem(Draw.vector(a, b-a, Color3.new(1,0,0), nil, 0.5))
		-- Debris:AddItem(Draw.vector(b, c-b, Color3.new(0,1,0), nil, 0.5))
		-- Debris:AddItem(Draw.vector(c, a-c, Color3.new(0,0,1), nil, 0.5))

		local center = (a:Lerp(b, 0.5):Lerp(c, 0.33))
		local seed = center.X * 2 + center.Y * 5 + center.Z * 15
		local rng = Random.new(seed)
		local color = Color3.fromHSV(rng:NextNumber() , 1, 1)
		local w1, w2 = MeshUtil.renderTriangle(a,b,c, 0.05)
		w1.Color = color
		w2.Color = color
		w1.CastShadow = false
		w2.CastShadow = false
		w1.Archivable = false
		w2.Archivable = false
		w1.Parent = workspace
		w2.Parent = workspace
		Debris:AddItem(w1, 1/60)
		Debris:AddItem(w2, 1/60)
		table.insert(triangles, {
			A = a,
			B = b,
			C = c,
		})
	end

	local cornerInfo = CORNER_INFO[centerId :: CornerId]
	if cornerInfo then
		for i, edgeTriangle in ipairs(cornerInfo.EdgeTriangles) do
			addTriangle(edgeTriangle.Edge1, edgeTriangle.Opp, edgeTriangle.Edge2)
			-- break
		end
	
		addTriangle(cornerInfo.CenterTriangle.A, cornerInfo.CenterTriangle.B, cornerInfo.CenterTriangle.C)
	
	else
		local edgeInfo = EDGE_TRIANGLE_DATA[centerId :: EdgeId]
		if edgeInfo then
			for j, triangle in ipairs(edgeInfo) do
				addTriangle(
					triangle[1] :: CornerId, 
					triangle[2] :: CornerId, 
					triangle[3] :: CornerId
				)
	
			end
		else
			local faceInfo = FACE_TRIANGLE_DATA[centerId :: FaceId]
			for j, triangle in ipairs(faceInfo) do
				addTriangle(
					triangle[1] :: CornerId, 
					triangle[2] :: CornerId, 
					triangle[3] :: CornerId
				)
	
			end

		end

	end

	return triangles
end
function Util.getWorldPerimeter(cf: CFrame, size: Vector3, cameraPosition: Vector3): {[number]: Vector3}

	local centerId: string = getCenterId(cf, size, cameraPosition)

	local cornerInfo = CORNER_INFO[centerId :: CornerId]
	if cornerInfo then
		local perimeter = {
			getWorldPosition(cf, size, cornerInfo.Perimeter.A),
			getWorldPosition(cf, size, cornerInfo.Perimeter.B),
			getWorldPosition(cf, size, cornerInfo.Perimeter.C),
			getWorldPosition(cf, size, cornerInfo.Perimeter.D),
			getWorldPosition(cf, size, cornerInfo.Perimeter.E),
			getWorldPosition(cf, size, cornerInfo.Perimeter.F),
		} :: any
	
		return perimeter
	else
		local edgeInfo = EDGE_PERIMETER_DATA[centerId :: EdgeId]
		if edgeInfo then
			local perimeter = {
				getWorldPosition(cf, size, edgeInfo[1]),
				getWorldPosition(cf, size, edgeInfo[2]),
				getWorldPosition(cf, size, edgeInfo[3]),
				getWorldPosition(cf, size, edgeInfo[4]),
				getWorldPosition(cf, size, edgeInfo[5]),
				getWorldPosition(cf, size, edgeInfo[6]),
			}
	
			return perimeter
		else
			local faceInfo = FACE_PERIMETER_DATA[centerId :: FaceId]
			local perimeter = {
				getWorldPosition(cf, size, faceInfo[1]),
				getWorldPosition(cf, size, faceInfo[2]),
				getWorldPosition(cf, size, faceInfo[3]),
				getWorldPosition(cf, size, faceInfo[4])
			}

			return perimeter
		end

	end
end
return Util