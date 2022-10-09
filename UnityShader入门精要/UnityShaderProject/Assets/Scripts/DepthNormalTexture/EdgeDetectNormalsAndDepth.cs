using UnityEngine;
using System.Collections;

public class EdgeDetectNormalsAndDepth : PostEffectsBase {

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
	public float edgesOnly = 0.0f;	// 边缘线强度

	public Color edgeColor = Color.black;	// 描边颜色 默认黑色

	public Color backgroundColor = Color.white;	// 背景颜色 默认白色

	public float sampleDistance = 1.0f;		// 控制对深度+法线纹理采样时使用的采样距离，sampleDistance越大，描边越宽

	public float sensitivityDepth = 1.0f;	// 会影响邻域的深度值相差多少时，会被认为存在一条边界

	public float sensitivityNormals = 1.0f;	// 会影响邻域的法线值相差多少时，会被认为存在一条边界
	
	void OnEnable() {
		// 获取深度法线纹理
		GetComponent<Camera>().depthTextureMode |= DepthTextureMode.DepthNormals;
	}

	// 不对透明物体进行描边
	[ImageEffectOpaque]
	void OnRenderImage (RenderTexture src, RenderTexture dest) {
		if (material != null) {
			// 向材质设置参数
			material.SetFloat("_EdgeOnly", edgesOnly);
			material.SetColor("_EdgeColor", edgeColor);
			material.SetColor("_BackgroundColor", backgroundColor);
			material.SetFloat("_SampleDistance", sampleDistance);
			material.SetVector("_Sensitivity", new Vector4(sensitivityNormals, sensitivityDepth, 0.0f, 0.0f));

			Graphics.Blit(src, dest, material);
		} else {
			Graphics.Blit(src, dest);
		}
	}
}
