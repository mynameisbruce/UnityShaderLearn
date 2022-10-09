using UnityEngine;
using System.Collections;

public class MotionBlur : PostEffectsBase {

	public Shader motionBlurShader;
	private Material motionBlurMaterial = null;

	public Material material {  
		get {
			// 调用父类的获取材质函数
			motionBlurMaterial = CheckShaderAndCreateMaterial(motionBlurShader, motionBlurMaterial);
			return motionBlurMaterial;
		}  
	}

	// 定义运动模糊在混合图像时使用的模糊参数
	// blurAmount
	[Range(0.0f, 0.9f)]
	public float blurAmount = 0.5f;
	
	// 保存之前图像叠加的结果
	private RenderTexture accumulationTexture;

	// 脚本不运行时，立即销毁accumulationTexture
	// 理由是希望在下一次开始运动模糊时重新叠加图像
	void OnDisable() {
		DestroyImmediate(accumulationTexture);
	}

	void OnRenderImage (RenderTexture src, RenderTexture dest) {
		if (material != null) {
			// Create the accumulation texture
			//创建 accumulation 纹理
			if (accumulationTexture == null || accumulationTexture.width != src.width || accumulationTexture.height != src.height) {
				DestroyImmediate(accumulationTexture);
				accumulationTexture = new RenderTexture(src.width, src.height, 0);
				accumulationTexture.hideFlags = HideFlags.HideAndDontSave;	// 设置此渲染纹理不会显示在Hierarchy中，也不会保存在场景中
				Graphics.Blit(src, accumulationTexture);
			}

			// We are accumulating motion over frames without clear/discard
			// by design, so silence any performance warnings from Unity
			// 表明我们需要进行一个渲染纹理的操作，来不让Unity发出警告误以为是忘记清空了, Unity官方建议: 这是一项代价高昂的操作，应该予以避免。
			accumulationTexture.MarkRestoreExpected();

			material.SetFloat("_BlurAmount", 1.0f - blurAmount);

			Graphics.Blit (src, accumulationTexture, material);
			Graphics.Blit (accumulationTexture, dest);
		} else {
			Graphics.Blit(src, dest);
		}
	}
}
