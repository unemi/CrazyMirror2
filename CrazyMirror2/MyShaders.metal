//
//  MyShaders.metal
//  CrazyMirror2
//
//  Created by Tatsuo Unemi on 2023/05/06.
//

#include <metal_stdlib>
#include "VecTypes.h"
using namespace metal;

int4 windowRange(uint index, uint3 sz) {
	int2 a = {int(index % sz.x), int(index / sz.x)};
	return int4(max(0, a.x - int(sz.z)), min(int(sz.x), a.x + int(sz.z) + 1),
		max(0, a.y - int(sz.z)), min(int(sz.y), a.y + int(sz.z) + 1));
}
kernel void blurFunction(device const uchar4 *src, device float4 *result,
	constant uint3 *size,	// width, height and window
	uint index [[thread_position_in_grid]]) {
	int4 b = windowRange(index, *size);
	float4 p = 0.;
	for (int i = b.z; i < b.w; i ++) for (int j = b.x; j < b.y; j ++)
		p += float4(src[i * size->x + j].yzwx);
	result[index] = p / ((b.y - b.x) * (b.w - b.z) * 255.);
}
kernel void diffuseFunction(device const float4 *src, device float4 *result,
	constant uint3 *size,	// width, height and window
	uint index [[thread_position_in_grid]]) {
	int4 b = windowRange(index, *size);
	float4 p = 0.;
	for (int i = b.z; i < b.w; i ++) for (int j = b.x; j < b.y; j ++)
		p += src[i * size->x + j];
	result[index] = p / ((b.y - b.x) * (b.w - b.z));
}
kernel void copyImgFunction(constant uint *flag,
	device const uchar4 *frmARGB, device const float4 *blurImg,
	device float4 *avrgImg, device float4 *difsImg,
	uint index [[thread_position_in_grid]]) {
	float4 src = (*flag & ArgBlurMask)?
		blurImg[index] : float4(frmARGB[index].yzwx) / 255.;
	if (*flag & ArgAvrgMask) avrgImg[index] = src;
	if (*flag & ArgDifsMask) difsImg[index] = src;
}

struct RasterizerData {
	float4 position [[position]];
	float2 pt;
};
vertex RasterizerData vertexShader(uint vertexID [[vertex_id]],
	constant float2 *vertices) {
    RasterizerData out = {{0.,0.,0.,1.}};
    out.pt = (1. - (out.position.xy = vertices[vertexID])) / 2.;
    return out;
}
uint pixelIndex(uint bpr, float2 coord, float2 size) {
	uint2 pt = uint2(coord * size);
	return bpr / 4 * pt.y + pt.x;
}
float4 vSmooth(constant uint *intInfo, constant uchar4 *frms, uint2 pt, float dep) {
	float d = clamp(FRM_NFRAMES * dep, 0., (float)FRM_NFRAMES-1);
	uint2 srcF = ((FRM_IDX + MAX_ST_FRAMES - uint2(floor(d),ceil(d)))
		% MAX_ST_FRAMES) * FRM_PPF + FRM_BPR / 4 * pt.y + pt.x;
	float frc = fract(d);
	return (float4(frms[srcF.x].yzwx) * (1. - frc) + float4(frms[srcF.y].yzwx) * frc) / 255.;
}
float4 convol(device float4 *avrgImg, uint idx, float4 src) {
	return avrgImg[idx] += (src - avrgImg[idx]) * .02;
}
float frameDiff(device float4 *avrgImg, device float4 *blurImg, uint idx, float offset, float mag) {
	return saturate((distance(convol(avrgImg, idx, blurImg[idx]), blurImg[idx]) - offset) * mag);
}
fragment float4 hnalalaa(RasterizerData in [[stage_in]],
	constant uint *intInfo, constant float3 *floatInfo, constant uchar4 *frms) {
	float2 p = in.pt * 2. - 1.;
	return vSmooth(intInfo, frms, uint2(in.pt * floatInfo->xy),
		(length(p)/M_SQRT2_F * cos(floatInfo->z*M_PI_F*2. - atan2(p.y,p.x)) + 1.) / 2.);
}
fragment float4 howawaan(RasterizerData in [[stage_in]],
	constant uint *intInfo, constant float3 *floatInfo, constant uchar4 *frms,
	device float4 *avrgImg) {
	uint pidx = pixelIndex(FRM_BPR, in.pt, floatInfo->xy);
	return convol(avrgImg, pidx, float4(frms[FRM_IDX * FRM_PPF + pidx].yzwx) / 255.);
}
fragment float4 zjvdgycboo(RasterizerData in [[stage_in]],
	constant uint *intInfo, constant float3 *floatInfo, constant uchar4 *frms,
	device float4 *avrgImg, device float4 *blurImg) {
	uint pidx = pixelIndex(FRM_BPR, in.pt, floatInfo->xy);
	return float4(abs(float3(frms[FRM_IDX * FRM_PPF + pidx].yzw) / 255.
		- convol(avrgImg, pidx, blurImg[pidx]).rgb), 1.);
}
fragment float4 hnolelee(RasterizerData in [[stage_in]],
	constant uint *intInfo, constant float3 *floatInfo, constant uchar4 *frms,
	device float4 *avrgImg, device float4 *blurImg) {
	uint pidx = pixelIndex(FRM_BPR, in.pt, floatInfo->xy);
	return vSmooth(intInfo, frms, uint2(in.pt * floatInfo->xy),
		frameDiff(avrgImg, blurImg, pidx, .05, 2.));
}
fragment float4 shavazzz(RasterizerData in [[stage_in]],
	constant uint *intInfo, constant float3 *floatInfo, constant uchar4 *frms,
	device ulong *lrand) {
	uint pidx = pixelIndex(FRM_BPR, in.pt, floatInfo->xy);
	lrand[pidx] = (lrand[pidx] * 224737) % 224729;
	return float4(frms[clamp(int(lrand[pidx] * FRM_NFRAMES / 224729), 0, (int)FRM_NFRAMES - 1)
		* FRM_PPF + pidx].yzwx) / 255.;
}
fragment float4 hahehohu(RasterizerData in [[stage_in]],
	constant uint *intInfo, constant float3 *floatInfo, constant uchar4 *frms,
	device float4 *avrgImg, device float4 *blurImg, device float4 *difsImg) {
	uint pidx = pixelIndex(FRM_BPR, in.pt, floatInfo->xy);
	float4 px = float4(frms[FRM_IDX * FRM_PPF + pidx].yzwx) / 255.;
	return difsImg[pidx] +=
		(px - difsImg[pidx]) * frameDiff(avrgImg, blurImg, pidx, .1, 5.);
}
