using UnityEngine;
using System.Collections;

[ExecuteInEditMode]		// 在编辑器状态下执行
[RequireComponent (typeof(Camera))]		// 绑定在某个摄像机上
public class PostEffectsBase : MonoBehaviour {

	// Called when start
	// 检查各种资源和条件是否满足
	protected void CheckResources() {
		bool isSupported = CheckSupport();
		
		if (isSupported == false) {
			NotSupported();
		}
	}

	// Called in CheckResources to check support on this platform
	// 检查是否支持图像效果和渲染
	protected bool CheckSupport() {
		// // supportsImageEffects和supportsRenderTextures已经过时，因为永远返回true
		// if (SystemInfo.supportsImageEffects == false || SystemInfo.supportsRenderTextures == false) {
		// 	Debug.LogWarning("This platform does not support image effects or render textures.");
		// 	return false;
		// }
		
		return true;
	}

	// Called when the platform doesn't support this effect
	// 当平台不支持后处理效果时设置enabled = false
	protected void NotSupported() {
		enabled = false;
	}
	
	// 调用CheckResources
	protected void Start() {
		CheckResources();
	}

	// Called when need to create the material used by this effect
	// 返回一个使用该shader的材质，否则返回null
	protected Material CheckShaderAndCreateMaterial(Shader shader, Material material) {
		if (shader == null) {
			return null;
		}
		
		if (shader.isSupported && material && material.shader == shader)
			return material;
		
		if (!shader.isSupported) {
			return null;
		}
		else {
			material = new Material(shader);
			material.hideFlags = HideFlags.DontSave;	// 对象不会保存到场景中，当一个新的场景创建的时候也不会被销毁
			if (material)
				return material;
			else 
				return null;
		}
	}
}
