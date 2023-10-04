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
		NoDebugRender = true,
		Culling = false,
		Occlusion = false,
		UseExactCulling = false, --slower
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