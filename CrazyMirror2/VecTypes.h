//
//  VecTypes.h
//  CrazyMirror2
//
//  Created by Tatsuo Unemi on 2023/05/06.
//

#ifndef VecTypes_h
#define VecTypes_h

#define MAX_ST_FRAMES 60
#define FRM_IDX intInfo[0]
#define FRM_NFRAMES intInfo[1]
#define FRM_BPF intInfo[2]
#define FRM_BPR intInfo[3]
#define FRM_PPF intInfo[4]
#define EFCT_TYPE intInfo[5]
#define N_INT_INFOS 6

#define DIFS_BACK 0x100
#define EFCT_CHANGED 0x80
#define EFCT_MASK 0x7f

enum {
	ArgAvrgMask = 1,
	ArgBlurMask = (ArgAvrgMask<<1),
	ArgDifsMask = (ArgBlurMask<<1),
	ArgLRndMask = (ArgDifsMask<<1)
};

#endif /* VecTypes_h */
