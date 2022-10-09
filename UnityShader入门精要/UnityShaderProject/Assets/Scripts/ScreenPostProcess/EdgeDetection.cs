using UnityEngine;
using System.Collections;

public class EdgeDetection : PostEffectsBase {

	public Shader edgeDetectShader;
	private Material edgeDetectMaterial = null;
	public Material material {  
		get {
			// 调用父类的创建材质函数
			edgeDetectMaterial = CheckShaderAndCreateMaterial(edgeDetectShader, edgeDetectMaterial);
			return edgeDetectMaterial;
		}  
	}

	[Range(0.0f, 1.0f)]
	public float edgesOnly = 0.0f;  // 边缘线强度

	public Color edgeColor = Color.black;	// 描边颜色 默认黑色
	
	public Color backgroundColor = Color.white; // 背景颜色 默认白色

	void OnRenderImage (RenderTexture src, RenderTexture dest) {
		if (material != null) {
			// 向材质设置参数
			material.SetFloat("_EdgeOnly", edgesOnly);
			material.SetColor("_EdgeColor", edgeColor);
			material.SetColor("_BackgroundColor", backgroundColor);

			Graphics.Blit(src, dest, material);	// 把图像传给材质
		} else {
			Graphics.Blit(src, dest);	// 直接把原图像显示到屏幕上
		}
	}
}
