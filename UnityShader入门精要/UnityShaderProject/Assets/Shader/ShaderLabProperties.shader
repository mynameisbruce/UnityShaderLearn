Shader "MyShaders/ShaderLabProperties" {
    Properties {
        // 数字和滑动条
        _Int ("Int", Int) = 1
        _Float ("Float", Float) = 1.0
        _Range ("Range", Range(0.0, 5.0)) = 1.0

        // 颜色和向量
        _Color ("Color", Color) = (1,1,1,1)
        _Vector ("Vector", Vector) = (1,2,3,4)

        // 贴图
        _2D ("2D", 2D) = "white" {}
        _Cube ("Cube", Cube) = "white" {}
        _3D ("3D", 3D) = "black" {}
    }

    // SubShader中定义了一系列Pass以及可选的状态和标签
    SubShader {

        // 每个Pass定义了一次完整的渲染流程，但如果Pass的数目过多，往往会造成渲染性能的下降。
        Pass {

            // 由于使用的是CG语言，所以代码块以CGPROGRAM开头，ENDCG结尾
            CGPROGRAM
            
            /*定义顶点着色器的函数名称和片元着色器的函数名称，该步是必要的，起什么名字无所谓，命名规则同C类语言命名规则
            1.区分大小写
            2.不以数字开头
            3.不能和系统关键字冲突*/
            #pragma vertex vert
            #pragma fragment frag

            // 单单在Properties语块中定义变量是没用的，必须在CGPROGRAM块中再次声明，Unity才会把变量材质面板的值填充过来
            fixed4 _Color;

            // 定义顶点着色器, 处理和模型顶点有关的内容
            // 一个顶点着色器至少要完成一件事，那就是把模型的顶点转换到裁剪空间
            // 顶点着色器是为每个传入的顶点执行一次函数
            float4 vert (float4 v : POSITION) : SV_POSITION {
                return UnityObjectToClipPos(v); //把模型转换到裁剪空间
            }

            // 片元着色器为每个传入的片元执行一次函数
            // 计算模型表面每个像素值的颜色
            float4 frag () : SV_Target {
                return float4(0.5, 0.5, 1.0, 0.0);
            }

            ENDCG
        }
    }
}

