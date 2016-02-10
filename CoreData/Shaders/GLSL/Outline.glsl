#include "Uniforms.glsl"
#include "Samplers.glsl"
#include "Transform.glsl"
#include "ScreenPos.glsl"
#include "Fog.glsl"

varying vec2 vTexCoord;
varying vec4 vWorldPos;
//varying vec2 vOriginalSPos;
//varying vec2 vSiluetSPos;

#ifdef VERTEXCOLOR
    varying vec4 vColor;
#endif

#ifdef COMPILEVS

uniform float cSiluetWidth; // ширина силуета модели 

vec2 TransformViewToProjection (vec2 v) // из пространства камеры в пространство проекции 
{
    return vec2(v.x * cProj[0][0], v.y * cProj[ 1][1]);
}

void VS()
{
#line 19
    mat4 modelMatrix = iModelMatrix;
    vec3 worldPos = GetWorldPos(modelMatrix);
    
    vec3 vNormal = iNormal * mat3(modelMatrix);
    //vec3 vNormal = GetWorldNormal(modelMatrix);
    
    vec3 vmNorm = (vNormal * mat3(cView)).xyz;
    //vec3 vmNorm = (vec4(vNormal.xyz, 0.0) * cView).xyz;
    
    gl_Position = GetClipPos(worldPos);
    vec4 originalProj = gl_Position;
    vec2 offset = TransformViewToProjection(vmNorm.xy);
    
    
    offset = offset * sqrt(gl_Position.z) * cSiluetWidth;   // контур примерно равномерный
    //offset = offset * gl_Position.z * cSiluetWidth;       // контур растет если модель мелкая или находиться далеко
    //offset = offset * cSiluetWidth;                       // в этом случае размер контура зависит от рассояния до модели
        
    gl_Position.xy += offset.xy;
    
    //calc screen pos to discard inner area of outline effect in PS
    //vOriginalSPos = GetScreenPosPreDiv(originalProj);
    //vSiluetSPos = GetScreenPosPreDiv(gl_Position); 
    
    
    vTexCoord = GetTexCoord(iTexCoord);
    vWorldPos = vec4(worldPos, GetDepth(gl_Position));

    #ifdef VERTEXCOLOR
        vColor = iColor;
    #endif
}

#endif

#ifdef COMPILEPS

uniform vec4 cSiluetColor; // туду: чтобы не юзать сmatdiff от материала

void PS()
{
    //float distance = length(vOriginalSPos - vSiluetSPos);
    //if (all( lessThan(vOriginalSPos, vSiluetSPos)) ) discard; 
    //if (distance < 0.0014) discard; 
    
    // Get material diffuse albedo
    #ifdef DIFFMAP
        vec4 diffColor = cSiluetColor * texture2D(sDiffMap, vTexCoord);
        #ifdef ALPHAMASK
            if (diffColor.a < 0.5)
                discard;
        #endif
    #else
        vec4 diffColor = cSiluetColor;
    #endif

    #ifdef VERTEXCOLOR
        diffColor *= vColor;
    #endif

    // Get fog factor
    #ifdef HEIGHTFOG
        float fogFactor = GetHeightFogFactor(vWorldPos.w, vWorldPos.y);
    #else
        float fogFactor = GetFogFactor(vWorldPos.w);
    #endif

    #if defined(PREPASS)
        // Fill light pre-pass G-Buffer
        gl_FragData[0] = vec4(0.5, 0.5, 0.5, 1.0);
        gl_FragData[1] = vec4(EncodeDepth(vWorldPos.w), 0.0);
    #elif defined(DEFERRED)
        gl_FragData[0] = vec4(GetFog(diffColor.rgb, fogFactor), diffColor.a);
        gl_FragData[1] = vec4(0.0, 0.0, 0.0, 0.0);
        gl_FragData[2] = vec4(0.5, 0.5, 0.5, 1.0);
        gl_FragData[3] = vec4(EncodeDepth(vWorldPos.w), 0.0);
    #else
        gl_FragColor = vec4(GetFog(diffColor.rgb, fogFactor), diffColor.a);
    #endif
}

#endif
