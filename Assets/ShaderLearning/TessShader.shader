Shader "Unlit/TessShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        
        _TessellationUniform("TessellationUniform",Range(1,64)) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM

            #pragma hull hullProgram
            #pragma domain ds
            
            #pragma vertex tessvert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
            #include "Tessellation.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            //domain shader space transform
            //not vertex shader
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.tangent = v.tangent;
                o.normal = v.normal;
                return o;
            }

            #ifdef UNITY_CAN_COMPILE_TESSELLATION
                //顶点着色器结构的定义
                struct TessVertex{
                    float4 vertex : INTERNALTESSPOS;
                    float3 normal : NORMAL;
                    float4 tangent : TANGENT;
                    float2 uv : TEXCOORD0;
                };

                struct OutputPatchConstant { 
                    //不同的图元，该结构会有所不同
                    //该部分用于Hull Shader里面
                    //定义了patch的属性
                    //Tessellation Factor和Inner Tessellation Factor
                    float edge[3] : SV_TESSFACTOR;
                    float inside  : SV_INSIDETESSFACTOR;
                };

                TessVertex tessvert(appdata v)
                {
                    TessVertex o;
                    o.vertex  = v.vertex;
                    o.normal  = v.normal;
                    o.tangent = v.tangent;
                    o.uv      = v.uv;
                    return o;
                }

                float _TessellationUniform;
                OutputPatchConstant hsconst (InputPatch<TessVertex,3> patch){
                    //定义曲面细分的参数
                    OutputPatchConstant o;
                    o.edge[0] = _TessellationUniform;
                    o.edge[1] = _TessellationUniform;
                    o.edge[2] = _TessellationUniform;
                    o.inside  = _TessellationUniform;
                    return o;
                }

                [UNITY_domain("tri")]//确定图元，quad,triangle等
                [UNITY_partitioning("fractional_odd")]//拆分edge的规则，equal_spacing,fractional_odd,fractional_even
                [UNITY_outputtopology("triangle_cw")] //组装设置
                [UNITY_patchconstantfunc("hsconst")]//一个patch一共有三个点，但是这三个点都共用这个函数
                [UNITY_outputcontrolpoints(3)]      //不同的图元会对应不同的控制点
            
                TessVertex hullProgram (InputPatch<TessVertex,3> patch,uint id : SV_OutputControlPointID){
                    //hullProgram进行patch信息的传输
                    //传输control points patch information
                    //具体细分过程，根据UNITY_patchconstantfunc提供的参数，自动进行细分操作
                    return patch[id];
                }

                [UNITY_domain("tri")]
                v2f ds(OutputPatchConstant tessFactors,
                    const OutputPatch<TessVertex,3>patch,
                    float3 bary :SV_DOMAINLOCATION)
                {
                    appdata v;
                    v.vertex = patch[0].vertex*bary.x + patch[1].vertex*bary.y + patch[2].vertex*bary.z;
			        v.tangent = patch[0].tangent*bary.x + patch[1].tangent*bary.y + patch[2].tangent*bary.z;
			        v.normal = patch[0].normal*bary.x + patch[1].normal*bary.y + patch[2].normal*bary.z;
			        v.uv = patch[0].uv*bary.x + patch[1].uv*bary.y + patch[2].uv*bary.z;
                    
                    v2f o = vert(v);
                    return o;
                }
            #endif
            
            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
