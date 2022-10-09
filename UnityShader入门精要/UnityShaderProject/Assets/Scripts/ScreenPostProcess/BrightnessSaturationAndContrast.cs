using UnityEngine;
using System.Collections;

public class BrightnessSaturationAndContrast : PostEffectsBase {

	public Shader briSatConShader;
	private Material briSatConMaterial;
	public Material material {  
		get {
			// 调用父类的创建材质函数
			briSatConMaterial = CheckShaderAndCreateMaterial(briSatConShader, briSatConMaterial);
			return briSatConMaterial;
		}  
	}

	// 调整亮度、饱和度和对比度的参数并设定合适的变化区间
	[Range(0.0f, 3.0f)]
	public float brightness = 1.0f;

	[Range(0.0f, 3.0f)]
	public float saturation = 1.0f;

	[Range(0.0f, 3.0f)]
	public float contrast = 1.0f;

	void OnRenderImage(RenderTexture src, RenderTexture dest) {
		if (material != null) {
			// 向材质设置参数
			material.SetFloat("_Brightness", brightness);
			material.SetFloat("_Saturation", saturation);
			material.SetFloat("_Contrast", contrast);

			Graphics.Blit(src, dest, material);	// 把图像传给材质
		} else {
			Graphics.Blit(src, dest);	// 直接把原图像显示到屏幕上
		}
	}
}
