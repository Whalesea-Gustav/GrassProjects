Shader "Unlit/Tess_Diss_Shader"
{
    Properties
    {
        _MainTex("MainTex",2D) = "white"{}
        _DisplacementMap("_DisplacementMap",2D)="gray"{}
        _DisplacementStrength("DisplacementStrength",Range(0,1)) = 0
        _Smoothness("Smoothness",Range(0,5))=0.5
        _TessellationUniform("TessellationUniform",Range(1,64)) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        Pass
        {
            CGPROGRAM
            //定义2个函数 hull domain
            #pragma hull hullProgram
            #pragma domain ds
           
            #pragma vertex tessvert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            //引入曲面细分的头文件
            #include "Tessellation.cginc" 

            #pragma target 5.0
            float _TessellationUniform;
            sampler2D _MainTex;
            float4 _MainTex_ST;

            sampler2D _DisplacementMap;
            float4 _DisplacementMap_ST;
            float _DisplacementStrength;
            float _Smoothness;

            struct VertexInput
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct VertexOutput
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float4 worldPos:TEXCOORD1;
                half3 tspace0 :TEXCOORD2;
                half3 tspace1 :TEXCOORD3;
                half3 tspace2 :TEXCOORD4;
            };

            VertexOutput vert (VertexInput v)
            //这个函数应用在domain函数中，用来空间转换的函数
            {
                VertexOutput o;
                o.uv = TRANSFORM_TEX(v.uv,_MainTex);
                //Displacement
                //由于并不是在Fragnent shader中读取图片，GPU无法获取mipmap信息，因此需要使用tex2Dlod来读取图片，使用第四坐标作为mipmap的level，这里取了0
                float Displacement = tex2Dlod(_DisplacementMap,float4(o.uv.xy,0.0,0.0)).g;
                Displacement = (Displacement-0.5)*_DisplacementStrength;
                v.normal = normalize(v.normal);
                v.vertex.xyz += v.normal * Displacement;

                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);

                //计算切线空间转换矩阵
                half3 vNormal = UnityObjectToWorldNormal(v.normal);
                half3 vTangent = UnityObjectToWorldDir(v.tangent.xyz);
                //compute bitangent from cross product of normal and tangent
                half tangentSign = v.tangent.w * unity_WorldTransformParams.w;
                half3 vBitangent = cross(vNormal,vTangent)*tangentSign;
                //output the tangent space matrix
                o.tspace0 = half3(vTangent.x,vBitangent.x,vNormal.x);
                o.tspace1 = half3(vTangent.y,vBitangent.y,vNormal.y);
                o.tspace2 = half3(vTangent.z,vBitangent.z,vNormal.z);
                return o;
            }

            //有些硬件不支持曲面细分着色器，定义了该宏就能够在不支持的硬件上不会变粉，也不会报错
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

                TessVertex tessvert (VertexInput v){
                    //顶点着色器函数
                    TessVertex o;
                    o.vertex  = v.vertex;
                    o.normal  = v.normal;
                    o.tangent = v.tangent;
                    o.uv      = v.uv;
                    return o;
                }

                //float _TessellationUniform;
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
                [UNITY_outputtopology("triangle_cw")]
                [UNITY_patchconstantfunc("hsconst")]//一个patch一共有三个点，但是这三个点都共用这个函数
                [UNITY_outputcontrolpoints(3)]      //不同的图元会对应不同的控制点
              
                TessVertex hullProgram (InputPatch<TessVertex,3> patch,uint id : SV_OutputControlPointID){
                    //定义hullshaderV函数
                    return patch[id];
                }

                [UNITY_domain("tri")]//同样需要定义图元
                VertexOutput ds (OutputPatchConstant tessFactors, const OutputPatch<TessVertex,3>patch,float3 bary :SV_DOMAINLOCATION)
                //bary:重心坐标
                {
                    VertexInput v;
                    v.vertex = patch[0].vertex*bary.x + patch[1].vertex*bary.y + patch[2].vertex*bary.z;
			        v.tangent = patch[0].tangent*bary.x + patch[1].tangent*bary.y + patch[2].tangent*bary.z;
			        v.normal = patch[0].normal*bary.x + patch[1].normal*bary.y + patch[2].normal*bary.z;
			        v.uv = patch[0].uv*bary.x + patch[1].uv*bary.y + patch[2].uv*bary.z;

                    VertexOutput o = vert (v);
                    return o;
                }
            #endif

            float4 frag (VertexOutput i) : SV_Target
            {
                float3 lightDir =_WorldSpaceLightPos0.xyz;
                float3 tnormal = UnpackNormal (tex2D (_DisplacementMap, i.uv));
                half3 worldNormal;
                worldNormal.x=dot(i.tspace0,tnormal);
                worldNormal.y= dot (i.tspace1, tnormal);
                worldNormal.z=dot (i.tspace2, tnormal);
                float3 albedo=tex2D (_MainTex, i.uv). rgb;
                float3 lightColor = _LightColor0.rgb;
                float3 diffuse = albedo * lightColor * DotClamped(lightDir,worldNormal);
                float3 viewDir = normalize (_WorldSpaceCameraPos. xyz-i. worldPos. xyz);
                float3 halfVector = normalize(lightDir + viewDir);
                float3 specular = albedo * pow (DotClamped (halfVector, worldNormal), _Smoothness * 100);
                float3 result = specular + diffuse;
                return float4(result, 1.0);

                return float4(result,1.0);
            }
            ENDCG
        }
    }
    Fallback "Diffuse"
}
