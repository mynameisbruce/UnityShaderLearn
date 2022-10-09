using UnityEngine;
using System.Collections;

public class Bloom : PostEffectsBase {

	public Shader bloomShader;
	private Material bloomMaterial = null;
	public Material material {  
		get {
			bloomMaterial = CheckShaderAndCreateMaterial(bloomShader, bloomMaterial);
			return bloomMaterial;
		}  
	}

	// Blur iterations - larger number means more blur.
	// 模糊的迭代次数，越大越模糊
	[Range(0, 4)]
	public int iterations = 3;
	
	// Blur spread for each iteration - larger value means more blur
	// 每次迭代的模糊范围，越大越模糊
	[Range(0.2f, 3.0f)]
	public float blurSpread = 0.6f;

	// 缩放系数
	// downSample越大，需要处理的像素数越少，能提高模糊程度。过大会导致图像像素化
	[Range(1, 8)]
	public int downSample = 2;

	[Range(0.0f, 4.0f)]
	public float luminanceThreshold = 0.6f;

	void OnRenderImage (RenderTexture src, RenderTexture dest) {
		if (material != null) {
			material.SetFloat("_LuminanceThreshold", luminanceThreshold);

			int rtW = src.width/downSample;
			int rtH = src.height/downSample;
			
			RenderTexture buffer0 = RenderTexture.GetTemporary(rtW, rtH, 0);
			buffer0.filterMode = FilterMode.Bilinear;	// 将临时渲染纹理的滤波模式设置为双线性(双线性过滤以pixel对应的纹理坐标为中心，采该纹理坐标周围4个texel的像素，再取平均值作为采样值)
			
			Graphics.Blit(src, buffer0, material, 0);
			
			// 传入设定的iterations值来迭代模糊
			for (int i = 0; i < iterations; i++) {
				material.SetFloat("_BlurSize", 1.0f + i * blurSpread);
				
				RenderTexture buffer1 = RenderTexture.GetTemporary(rtW, rtH, 0);
				
				// Render the vertical pass
				Graphics.Blit(buffer0, buffer1, material, 1);
				
				RenderTexture.ReleaseTemporary(buffer0);
				buffer0 = buffer1;
				buffer1 = RenderTexture.GetTemporary(rtW, rtH, 0);
				
				// Render the horizontal pass
				Graphics.Blit(buffer0, buffer1, material, 2);
				
				RenderTexture.ReleaseTemporary(buffer0);
				buffer0 = buffer1;
			}

			material.SetTexture ("_Bloom", buffer0);  
			Graphics.Blit (src, dest, material, 3);  

			RenderTexture.ReleaseTemporary(buffer0);
		} else {
			Graphics.Blit(src, dest);
		}
	}
}
