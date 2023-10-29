--!strict
-- Services
-- Packages
-- Modules
-- Types
-- Constants
-- Variables
-- References
-- Private Functions
-- Class
return {
	Debug = {
		Culling = false,
		Shape = true,
		InnerBounds = false,
		OuterBounds = false,
		RegisterMask = false,
		SearchMask = false,
	},
	Tag = {
		InFrustum = "OcclusionCameraInFrustum",
		InitialObscured = "OcclusionCameraInitialObscured",
		Obscured = "OcclusionCameraObscured",
		Visible = "OcclusionCameraVisible",
	},
	Attribute = {
		LastSeen = "OcclusionCameraLastSeen",
	}
}