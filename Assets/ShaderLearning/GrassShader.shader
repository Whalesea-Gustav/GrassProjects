Shader "Custom/Grass"
{
    Properties
    {
        [Header(shading)]
        _TopColor ("Top Color", Color) = (1,1,1,1)
        _BottomColor ("Bottom Color", Color) = (1,1,1,1)
        _BladeWidth ("Blade Width",float) = 0.05
        _BladeWidthRandom ("Blade Width Random",float) = 0.02
        _BladeHeight ("Blade Height",float) = 0.5
        _BladeHeightRandom ("Blade Height Random",float) = 0.3
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            //定义几何着色器
            #pragma geometry geo
            #pragma fragment frag
            #pragma target 4.6

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "Autolight.cginc"

            float4 _TopColor;
            float4 _BottomColor;
            
            // 生成随机数
            float rand(float3 co)
            {
                return frac(sin(dot(co.xyz,float3(12.9898,78.233,53.539))) * 43758.5453);
            }

            float3x3 AngleAxis3x3(float angle, float3 axis)//旋转矩阵
            {
                float c,s;

                sincos(angle,s,c);

                float t = 1 - c;
                float x = axis.x;
                float y = axis.y;
                float z = axis.z;

                return float3x3(
                t * x * x + c, t * x * y - s * z, t * x * z + s * y,
                t * x * y + s * z, t * y * y + c, t * y * z - s * x,
                t * x * z - s * y, t * y * z + s * x, t * z * z + c
                );
            }

            float _BladeHeight;
            float _BladeHeightRandom;
            float _BladeWidth;
            float _BladeWidthRandom;

            struct vertexInput
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct vertexOutput
            {
                float3 normal : NORMAL;
                float4 vertex : SV_POSITION;
                float4 tangent : TANGENT;
            };


            vertexOutput vert (vertexInput v)
            {
                vertexOutput o;
                o.vertex = v.vertex;
                o.normal = v.normal;
                o.tangent = v.tangent;
                return o;
            }

            struct geometryOutput
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            geometryOutput CreateGeoOutput(float3 pos,float2 uv)// 用于空间转换的函数
            {
                geometryOutput o;
                o.pos = UnityObjectToClipPos(pos);
                o.uv = uv;
                return o;
            }

            [maxvertexcount(3)]//定义最大输出点，此处输出三角形所以是3
            //输出使用了TriangleStream，每个顶点都用到了结构体geometryOutput
            void geo(triangle vertexOutput IN[3] : SV_POSITION, inout TriangleStream<geometryOutput> triStream)
            {
                //抛弃顶点本身位置信息的影响，所以采用切线空间，类比法线
                float3 pos = IN[0].vertex;
                float3 vNormal = IN[0].normal;
                float4 vTangent = IN[0].tangent;
                float3 vBitangent = cross(vNormal,vTangent) * vTangent.w;

                float height = (rand(pos.zyx) * 2 - 1) * _BladeHeightRandom + _BladeHeight;
                float width = (rand(pos.xzy) * 2 - 1) * _BladeWidthRandom + _BladeWidth;

                //构建矩阵
                float3x3 facingRotationMatrix = AngleAxis3x3(rand(pos) * UNITY_TWO_PI,float3(0,0,1));
                float3x3 tangentToLocal = float3x3(
                vTangent.x,vBitangent.x,vNormal.x,
                vTangent.y,vBitangent.y,vNormal.y,
                vTangent.z,vBitangent.z,vNormal.z
                );
                float3x3 transformationMat = mul(tangentToLocal,facingRotationMatrix);

                //输出图元用到了TriangleStream，相当于一个用来装配三角形的工具
                //定义了三角形的宽度和高度
                geometryOutput o;
                triStream.Append(CreateGeoOutput(pos + mul(transformationMat,float3(width,0,0)),float2(0,0)));
                triStream.Append(CreateGeoOutput(pos + mul(transformationMat,float3(-width,0,0)),float2(1,0)));
                triStream.Append(CreateGeoOutput(pos + mul(transformationMat,float3(0,0,height)),float2(0.5,1)));
            }

            fixed4 frag (geometryOutput i,fixed facing : VFACE) : SV_Target
            {
                return lerp(_BottomColor,_TopColor,i.uv.y);
            }
            ENDCG
        }
    }
}

