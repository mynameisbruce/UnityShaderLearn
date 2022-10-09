using UnityEngine;
using System.Collections;

public class MotionBlurWithDepthTexture : PostEffectsBase {

	// 声明该效果需要的Shader，并据此创建相应的材质
	public Shader motionBlurShader;
	private Material motionBlurMaterial = null;

	public Material material {  
		get {
			// 调用父类的创建材质函数
			motionBlurMaterial = CheckShaderAndCreateMaterial(motionBlurShader, motionBlurMaterial);
			return motionBlurMaterial;
		}  
	}

	// 定义一个Camera类型变量，以获取该脚本所在的摄像机组件
	private Camera myCamera;
	public Camera camera {
		get {
			if (myCamera == null) {
				myCamera = GetComponent<Camera>();
			}
			return myCamera;
		}
	}

	// 定义运动模糊时模糊图像使用的大小
	[Range(0.0f, 1.0f)]
	public float blurSize = 0.5f;

	// 定义一个变量保存上一帧的视角*投影矩阵
	private Matrix4x4 previousViewProjectionMatrix;
	
	void OnEnable() {
		// 获取深度纹理
		camera.depthTextureMode |= DepthTextureMode.Depth;

		previousViewProjectionMatrix = camera.projectionMatrix * camera.worldToCameraMatrix;
	}
	
	void OnRenderImage (RenderTexture src, RenderTexture dest) {
		if (material != null) {
			material.SetFloat("_BlurSize", blurSize);
			
			// 将前一帧的视角*投影矩阵与和当前帧的视角*投影逆矩阵传入Shader
			material.SetMatrix("_PreviousViewProjectionMatrix", previousViewProjectionMatrix);
			Matrix4x4 currentViewProjectionMatrix = camera.projectionMatrix * camera.worldToCameraMatrix;
			Matrix4x4 currentViewProjectionInverseMatrix = currentViewProjectionMatrix.inverse;
			material.SetMatrix("_CurrentViewProjectionInverseMatrix", currentViewProjectionInverseMatrix);

			// 保存当前帧的视角*投影矩阵
			previousViewProjectionMatrix = currentViewProjectionMatrix;

			Graphics.Blit (src, dest, material);
		} else {
			Graphics.Blit(src, dest);
		}
	}
}
