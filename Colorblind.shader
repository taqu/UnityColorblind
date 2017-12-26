/**
references:
 http://biecoll.ub.uni-bielefeld.de/volltexte/2007/52/pdf/ICVS2007-6.pdf
 http://www.daltonize.org/search/label/Daltonize
 http://web.archive.org/web/20090318054431/http://www.nofunc.com/Color_Blindness_Library
 http://ixora.io/projects/colorblindness/color-blindness-simulation-research/
*/
Shader "Hidden/Colorblind"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		// No culling or depth
		Cull Off ZWrite Off ZTest Always

        CGINCLUDE
        #include "UnityCG.cginc"

        float3 rgb2xyz(float3 rgb)
        {
            float x = dot(rgb, float3(0.430574, 0.341550, 0.178325));
            float y = dot(rgb, float3(0.222015, 0.706655, 0.071330));
            float z = dot(rgb, float3(0.020183, 0.129553, 0.939180));
            return float3(x,y,z);
        }

        float3 xyz2rgb(float3 xyz)
        {
            float r = dot(xyz, float3(3.063218, -1.393325, -0.475802));
            float g = dot(xyz, float3(-0.969243, 1.875966, 0.041555));
            float b = dot(xyz, float3(0.067871, -0.228834, 1.069251));
            return float3(r,g,b);
        }

        struct appdata
        {
            float4 vertex : POSITION;
            float2 uv : TEXCOORD0;
        };

        struct v2f
        {
            float2 uv : TEXCOORD0;
            float4 vertex : SV_POSITION;
        };

        v2f vert(appdata v)
        {
            v2f o;
            o.vertex = UnityObjectToClipPos(v.vertex);
            o.uv = v.uv;
            return o;
        }

        sampler2D _MainTex;

//#define USE_HCIRN
#ifdef USE_HCIRN
        
        /*

        The Color Blind Simulation function is
        copyright (c) 2000-2001 by Matthew Wickline and the
        Human-Computer Interaction Resource Network ( http://hcirn.com/ ).

        It is used with the permission of Matthew Wickline and HCIRN,
        and is freely available for non-commercial use. For commercial use, please
        contact the Human-Computer Interaction Resource Network ( http://hcirn.com/ ).

        */
        static const float4 protanopia = float4(0.735, 0.265, 1.273463, -0.073894);
        static const float4 deuteranopia = float4(1.14, -0.14, 0.968437, 0.003331);
        static const float4 tritanopia = float4(0.171, -0.003, 0.062921, 0.292119);

        float3 blind(float3 rgb, const float4 coeff)
        {
            const float gamma = 2.2;
            const float invGamma = 1.0/gamma;
            const float3 wxyz = float3(0.312713, 0.329016, 0.358271);

            float3 crgb = pow(rgb, gamma);
            float3 cxyz = saturate(rgb2xyz(crgb));
            float sum = cxyz.x + cxyz.y + cxyz.z;
            float2 cuv = (1.0e-5<sum)? cxyz.xy/sum : float2(0,0);
            float2 nxz = wxyz.xz * cxyz.y/wxyz.y;
            float clm = (cuv.x < coeff.x)? ((coeff.y-cuv.y)/(coeff.x-cuv.x)) : ((cuv.y-coeff.y)/(cuv.x-coeff.x));

            float clyi = cuv.y - cuv.x*clm;
            float du = (coeff.w - clyi) / (clm - coeff.z);
            float dv = (clm * du) + clyi;

            float3 sxyz = float3(du*cxyz.y/dv, cxyz.y, (1-(du+dv))*cxyz.y/dv);
            float3 srgb = xyz2rgb(sxyz);
            float dx = nxz.x-sxyz.x;
            float dz = nxz.y-sxyz.z;
            float3 drgb = xyz2rgb(float3(dx, 0, dz));

            float3 trgb; //=step(1.0e-6, srgb);
            trgb.r = srgb.r<0? 0 : 1;
            trgb.g = srgb.g<0? 0 : 1;
            trgb.b = srgb.b<0? 0 : 1;
            trgb = (trgb-srgb)/drgb;

            float3 adj;
            adj.r = (0!=drgb.r)? trgb.r : 0;
            adj.g = (0!=drgb.g)? trgb.g : 0;
            adj.b = (0!=drgb.b)? trgb.b : 0;
            adj.r = (adj.r<0 || 1<adj.r)? 0 : adj.r;
            adj.g = (adj.g<0 || 1<adj.g)? 0 : adj.g;
            adj.b = (adj.b<0 || 1<adj.b)? 0 : adj.b;

            float adjust = max(max(adj.r, adj.g), adj.b);
            srgb = srgb + adjust*drgb;
            return pow(srgb, invGamma);
        }

        float3 anomylize(float3 rgb0, float3 rgb1)
        {
            const float v = 1.75;
            const float d = v*1 + 1;
            return (rgb1*v + rgb0)/d;
        }

        float3 monochrome(float3 rgb)
        {
            float gray = dot(rgb, float3(0.299, 0.587, 0.114));
            return float3(gray, gray, gray);
        }

        float4 frag_base(v2f i, float4 coeff)
        {
            float4 c = tex2D(_MainTex, i.uv);
            c.rgb = blind(c.rgb, coeff);
            return c;
        }

        float4 frag_anomylize(v2f i, float4 coeff)
        {
            float4 c = tex2D(_MainTex, i.uv);
            float3 rgb = blind(c.rgb, coeff);
            c.rgb = anomylize(c.rgb, rgb);
            return c;
        }
#else
        static const float4 RGBToLMS_L = float4(0.31399022, 0.63951294, 0.04649755, 0);
        static const float4 RGBToLMS_M = float4(0.15537241, 0.75789446, 0.08670142, 0);
        static const float4 RGBToLMS_S = float4(0.01775239, 0.10944209, 0.87256922, 0);

        static const float4 LMSToRGB_R = float4(5.47221206, -4.6419601, 0.16963708, 0);
        static const float4 LMSToRGB_G = float4(-1.1252419, 2.29317094, -0.1678952, 0);
        static const float4 LMSToRGB_B = float4(0.02980165, -0.19318073, 1.16364789, 0);

        float3 rgb2lms(float3 rgb)
        {
            float l = dot(rgb, RGBToLMS_L.xyz);
            float m = dot(rgb, RGBToLMS_M.xyz);
            float s = dot(rgb, RGBToLMS_S.xyz);
            return float3(l,m,s);
        }

        float3 lms2rgb(float3 lms)
        {
            float r = dot(lms, LMSToRGB_R.xyz);
            float g = dot(lms, LMSToRGB_G.xyz);
            float b = dot(lms, LMSToRGB_B.xyz);
            return float3(r,g,b);
        }

        static const float4 Deuteranopia_L = float4(1, 0, 0, 0);
        static const float4 Deuteranopia_M = float4(0.9513092, 0, 0.04866992, 0);
        static const float4 Deuteranopia_S = float4(0, 0, 1, 0);

        static const float4 Protanopia_L = float4(0, 1.05118294, -0.05116099, 0);
        static const float4 Protanopia_M = float4(0, 1, 0, 0);
        static const float4 Protanopia_S = float4(0, 0, 1, 0);

        static const float4 Tritanopia_L = float4(1, 0, 0, 0);
        static const float4 Tritanopia_M = float4(0, 1, 0, 0);
        static const float4 Tritanopia_S = float4(-0.86744736, 1.86727089, 0, 0);
        
        //no red
        static const float4 Protanopia_R = float4(0.56667, 0.43333, 0, 0);
        static const float4 Protanopia_G = float4(0.55833, 0.44167, 0, 0);
        static const float4 Protanopia_B = float4(0, 0.24167, 0.75833, 0);

        //low red
        static const float4 Protanomaly_R = float4(0.81667, 0.18333, 0, 0);
        static const float4 Protanomaly_G = float4(0.33333, 0.66667, 0, 0);
        static const float4 Protanomaly_B = float4(0, 0.125, 0.875, 0);

        //no green
        static const float4 Deuteranopia_R = float4(0.625, 0.375, 0, 0);
        static const float4 Deuteranopia_G = float4(0.70, 0.30, 0, 0);
        static const float4 Deuteranopia_B = float4(0, 0.30, 0.70, 0);

        //low green
        static const float4 Deuteranomaly_R = float4(0.80, 0.20, 0, 0);
        static const float4 Deuteranomaly_G = float4(0.25833, 0.74167, 0, 0);
        static const float4 Deuteranomaly_B = float4(0, 0.14167, 0.85833, 0);

        //no blue
        static const float4 Tritanopia_R = float4(0.95, 0.05, 0, 0);
        static const float4 Tritanopia_G = float4(0, 0.43333, 0.56667, 0);
        static const float4 Tritanopia_B = float4(0, 0.475, 0.525, 0);

        //low blue
        static const float4 Tritanomaly_R = float4(0.96667, 0.03333, 0, 0);
        static const float4 Tritanomaly_G = float4(0, 0.73333, 0.26667, 0);
        static const float4 Tritanomaly_B = float4(0, 0.18333, 0.81667, 0);

        //typical monochromacy
        static const float4 Achromatopsia_R = float4(0.299, 0.587, 0.114, 0);
        static const float4 Achromatopsia_G = float4(0.299, 0.587, 0.114, 0);
        static const float4 Achromatopsia_B = float4(0.299, 0.587, 0.114, 0);

        //atypical monochromacy
        static const float4 Achromatomaly_R = float4(0.618, 0.32, 0.062, 0);
        static const float4 Achromatomaly_G = float4(0.163, 0.775, 0.062, 0);
        static const float4 Achromatomaly_B = float4(0.163, 0.320, 0.516, 0);

        float4 frag_lms(v2f i, float4 l, float4 m, float4 s)
        {
            float4 c = tex2D(_MainTex, i.uv);
            float3 lms = rgb2lms(c.rgb);
            float3 lms_prime;
            lms_prime.r = dot(lms, l.xyz);
            lms_prime.g = dot(lms, m.xyz);
            lms_prime.b = dot(lms, s.xyz);
            c.rgb = lms2rgb(lms_prime);
            return c;
        }

        float4 frag_rgb(v2f i, float4 r, float4 g, float4 b)
        {
            float4 c = tex2D(_MainTex, i.uv);
            float3 c_prime;
            c_prime.r = dot(c.rgb, r.xyz);
            c_prime.g = dot(c.rgb, g.xyz);
            c_prime.b = dot(c.rgb, b.xyz);
            c.rgb = c_prime;
            return c;
        }
#endif
        ENDCG

		Pass //0 Normal
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
            fixed4 frag(v2f i) : SV_Target
            {
                return tex2D(_MainTex, i.uv);
            }
			ENDCG
		}

        Pass //1 Protanomaly
        {
            CGPROGRAM
#pragma vertex vert
#pragma fragment frag
            fixed4 frag(v2f i) : SV_Target
            {
#ifdef USE_HCIRN
                return frag_anomylize(i, protanopia);
#else
                return frag_rgb(i, Protanomaly_R, Protanomaly_G, Protanomaly_B);
#endif
            }
            ENDCG
        }

        Pass //2 Deuteranomaly
        {
            CGPROGRAM
#pragma vertex vert
#pragma fragment frag
            fixed4 frag(v2f i) : SV_Target
            {
#ifdef USE_HCIRN
                return frag_anomylize(i, deuteranopia);
#else
                return frag_rgb(i, Deuteranomaly_R, Deuteranomaly_G, Deuteranomaly_B);
#endif
            }
            ENDCG
        }

        Pass //3 Tritanomaly
        {
            CGPROGRAM
#pragma vertex vert
#pragma fragment frag
            fixed4 frag(v2f i) : SV_Target
            {
#ifdef USE_HCIRN
                return frag_anomylize(i, tritanopia);
#else
                return frag_rgb(i, Tritanomaly_R, Tritanomaly_G, Tritanomaly_B);
#endif
            }
            ENDCG
        }

        Pass //4 Protanopia
        {
            CGPROGRAM
#pragma vertex vert
#pragma fragment frag
            fixed4 frag(v2f i) : SV_Target
            {
#ifdef USE_HCIRN
                return frag_base(i, protanopia);
#else
                //return frag_rgb(i, Protanopia_R, Protanopia_G, Protanopia_B);
                return frag_lms(i, Protanopia_L, Protanopia_M, Protanopia_S);
#endif
            }
            ENDCG
        }

        Pass //5 Deuteranopia
        {
            CGPROGRAM
#pragma vertex vert
#pragma fragment frag
            fixed4 frag(v2f i) : SV_Target
            {
#ifdef USE_HCIRN
                return frag_base(i, deuteranopia);
#else
                //return frag_rgb(i, Deuteranopia_R, Deuteranopia_G, Deuteranopia_B);
                return frag_lms(i, Deuteranopia_L, Deuteranopia_M, Deuteranopia_S);
#endif
            }
            ENDCG
        }

        Pass //6 Tritanopia
        {
            CGPROGRAM
#pragma vertex vert
#pragma fragment frag
            fixed4 frag(v2f i) : SV_Target
            {
#ifdef USE_HCIRN
                return frag_base(i, tritanopia);
#else
                //return frag_rgb(i, Tritanopia_R, Tritanopia_G, Tritanopia_B);
                return frag_lms(i, Tritanopia_L, Tritanopia_M, Tritanopia_S);
#endif
            }
            ENDCG
        }

        Pass //7 Achromatopsia
        {
            CGPROGRAM
#pragma vertex vert
#pragma fragment frag
            fixed4 frag(v2f i) : SV_Target
            {
#ifdef USE_HCIRN
                float4 c = tex2D(_MainTex, i.uv);
                c.rgb = monochrome(c.rgb);
                return c;
#else
                return frag_rgb(i, Achromatopsia_R, Achromatopsia_G, Achromatopsia_B);
#endif
            }
            ENDCG
        }

        Pass //8 Achromatomaly
        {
            CGPROGRAM
#pragma vertex vert
#pragma fragment frag
            fixed4 frag(v2f i) : SV_Target
            {
#ifdef USE_HCIRN
                float4 c = tex2D(_MainTex, i.uv);
                float3 rgb = monochrome(c.rgb);
                c.rgb = anomylize(c.rgb, rgb);
                return c;
#else
                return frag_rgb(i, Achromatomaly_R, Achromatomaly_G, Achromatomaly_B);
#endif
            }
            ENDCG
        }

	}//SubShader
}//Shader
