Shader "MyShaders/Billboard2"{
    Properties{
        _MainTex("Main Texture",2D) = "white"{}
    }
    SubShader{
        // 这里我们使用了DisableBatching标签，一些SubShader在使用Unity的批处理功能的时候会产生问题，
        // 这个时候可以通过该标签来直接指明是否对SubShader使用批处理功能。而这些需要特殊处理的Shader通常
        // 就是指包含了模型空间的顶点动画的Shader。批处理会导致模型空间的丢失，而这正好是顶点动画所需要的
        // 所以我们在这里关闭Shader的批处理操作。
        Tags{"Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" "DisableBatching"="True"}
      
        pass{
            Tags{"LightMode"="Always"}

            Cull Off    //关闭剔除，让模型的两面都可以显示

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #include "Lighting.cginc"
            #include "UnityCG.cginc"

            sampler2D _MainTex;

            struct v2f{

                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            v2f vert(appdata_base v){

                v2f o;

                /*设（0，0，0）为模型的中心点，用于代替模型的位置，这个一定要有，
                本质上中心点的位置不变其他顶点围绕中心点发生变化
                问1：为什么不使用worldPos=mul(unity_ObjectToWorld,v.vertex).xyz？
                答1：使用worldPos代表了每个顶点的位置，每个顶点都有自己的方向，如果使用
                worldPos，那么每个顶点便会自顾自的旋转，而非整体旋转。（ps：我们是在模型
                空间计算）
                */
                float3 center = float3(0,0,0);

                // 把摄像机的位置转换到模型空间
                // 使用内置的_WorldSpaceCameraPos获得摄像机在世界空间下的位置
                float3 cameraPos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1)).xyz;
                
                // 视角方向 = 摄像机坐标减去中心坐标
                float3 viewDir = cameraPos - center;
                // 对视角方向进行归一化处理
                viewDir = normalize(viewDir);

                // 固定y轴时，向上的方向为(0,1,0)
                float3 upDir = float3(0,1,0);
                float3 rightDir = normalize(cross(upDir, viewDir));     // 通过叉乘向上方向和视线方向得到向右的方向，并归一化
                upDir = normalize(cross(viewDir, rightDir));             //新的模型视角方向

                float3 centerOffset = v.vertex.xyz - center;

                //float3 pos = centerOffset.x * rightDir + centerOffset.y * upDir + centerOffset.z * viewDir + center;
                float3x3 _RotateMatrix = transpose(float3x3(rightDir, upDir, viewDir));
                float3 pos = mul(_RotateMatrix, centerOffset) + center;

                o.pos = UnityObjectToClipPos(float4(pos,1));
                o.uv = v.texcoord;

                return o;
            }

            fixed4 frag(v2f i):SV_TARGET{

                return tex2D(_MainTex,i.uv);
            }
            
            ENDCG

        }
    }
}