using UnityEngine;
using System.Collections;

public class GaussianBlur : PostEffectsBase {

	public Shader gaussianBlurShader;
	private Material gaussianBlurMaterial = null;

	public Material material {  
		get {
			// 调用父类的创建材质函数
			gaussianBlurMaterial = CheckShaderAndCreateMaterial(gaussianBlurShader, gaussianBlurMaterial);
			return gaussianBlurMaterial;
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
	
	/// 1st edition: just apply blur	// 第一个版本，只实现模糊
//	void OnRenderImage(RenderTexture src, RenderTexture dest) {
//		if (material != null) {
//			int rtW = src.width;
//			int rtH = src.height;
//			RenderTexture buffer = RenderTexture.GetTemporary(rtW, rtH, 0); // 分配一块与屏幕图像大小相同的缓存，作为两个Pass的中间缓存
//
//			// Render the vertical pass	// 使用第一个Pass(使用竖直方向的一维高斯核进行滤波)
//			Graphics.Blit(src, buffer, material, 0);
//			// Render the horizontal pass	// 使用第二个Pass(使用水平方向的一维高斯核进行滤波)
//			Graphics.Blit(buffer, dest, material, 1);
//
//			RenderTexture.ReleaseTemporary(buffer);	// 释放上面创建的缓存
//		} else {
//			Graphics.Blit(src, dest);
//		}
//	} 

	/// 2nd edition: scale the render texture	// 第二个版本，利用缩放对图像进行降采样，从而减少处理的像素个数提高性能
//	void OnRenderImage (RenderTexture src, RenderTexture dest) {
//		if (material != null) {
//			int rtW = src.width/downSample;
//			int rtH = src.height/downSample;
//			RenderTexture buffer = RenderTexture.GetTemporary(rtW, rtH, 0); // 分配一块与屏幕图像大小相同的缓冲区，作为两个pass的中间缓存
//			buffer.filterMode = FilterMode.Bilinear;	// 将临时渲染纹理的滤波模式设置为双线性(双线性过滤以pixel对应的纹理坐标为中心，采该纹理坐标周围4个texel的像素，再取平均值作为采样值)
//
//			// Render the vertical pass	// 使用第一个Pass(使用竖直方向的一维高斯核进行滤波)
//			Graphics.Blit(src, buffer, material, 0);
//			// Render the horizontal pass	// 使用第二个Pass(使用水平方向的一维高斯核进行滤波)
//			Graphics.Blit(buffer, dest, material, 1);
//
//			RenderTexture.ReleaseTemporary(buffer);	// 释放上面创建的缓存
//		} else {
//			Graphics.Blit(src, dest);
//		}
//	}

	/// 3rd edition: use iterations for larger blur 	// 在方案二的基础上，增加了高斯模糊的迭代次数以得到更好的效果
	void OnRenderImage (RenderTexture src, RenderTexture dest) {
		if (material != null) {
			int rtW = src.width/downSample;
			int rtH = src.height/downSample;

			RenderTexture buffer0 = RenderTexture.GetTemporary(rtW, rtH, 0);
			buffer0.filterMode = FilterMode.Bilinear;

			Graphics.Blit(src, buffer0);

			// 传入设定的iterations值来迭代模糊
			for (int i = 0; i < iterations; i++) {
				material.SetFloat("_BlurSize", 1.0f + i * blurSpread);

				RenderTexture buffer1 = RenderTexture.GetTemporary(rtW, rtH, 0);

				// Render the vertical pass
				Graphics.Blit(buffer0, buffer1, material, 0);

				RenderTexture.ReleaseTemporary(buffer0);
				buffer0 = buffer1;
				buffer1 = RenderTexture.GetTemporary(rtW, rtH, 0);

				// Render the horizontal pass
				Graphics.Blit(buffer0, buffer1, material, 1);

				RenderTexture.ReleaseTemporary(buffer0);
				buffer0 = buffer1;
			}

			Graphics.Blit(buffer0, dest);
			RenderTexture.ReleaseTemporary(buffer0);
		} else {
			Graphics.Blit(src, dest);
		}
	}
}
