using UnityEngine;
using UnityEditor;
using System.Collections;

// 从该摄像机渲染到一个静态立方体贴图
public class RenderCubemapWizard : ScriptableWizard {
	
	public Transform renderFromPosition;
	public Cubemap cubemap;
	
	void OnWizardUpdate () {
		helpString = "Select transform to render from and cubemap to render into";
		isValid = (renderFromPosition != null) && (cubemap != null);
	}
	
	void OnWizardCreate () {
		// create temporary camera for rendering
        // 创建一个临时摄像机
		GameObject go = new GameObject( "CubemapCamera");
		go.AddComponent<Camera>();
		// place it on the object
        // 在renderFromPosition位置处创建一个摄像机
		go.transform.position = renderFromPosition.position;
		// render into cubemap		
        // 从当前观察到的图像渲染到用户指定的立方体纹理cubemap中
		go.GetComponent<Camera>().RenderToCubemap(cubemap);
		
		// destroy temporary camera
        // 销毁临时摄像机
		DestroyImmediate( go );
	}
	
	[MenuItem("GameObject/Render into Cubemap")]
	static void RenderCubemap () {
		ScriptableWizard.DisplayWizard<RenderCubemapWizard>(
			"Render cubemap", "Render!");
	}
}