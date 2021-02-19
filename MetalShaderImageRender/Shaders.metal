//
//  Shaders.metal
//  MetalShaderImageRender
//
//  Created by shinriyo on 2021/02/19.
//  Copyright © 2021 shinriyo. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct ColorInOut
{
    float4 position [[ position ]];
    float2 texCoords;
};

vertex ColorInOut vertexShader(constant float4 *positions [[ buffer(0) ]],
                               constant float2 *texCoords [[ buffer(1) ]],
                                        uint    vid       [[ vertex_id ]])
{
    ColorInOut out;
    out.position = positions[vid];
    out.texCoords = texCoords[vid];
    return out;
}

fragment float4 fragmentShader(ColorInOut       in      [[ stage_in ]],
                               texture2d<float> texture [[ texture(0) ]])
{
    constexpr sampler colorSampler;
    float4 color = texture.sample(colorSampler, in.texCoords);
    return color;
}
