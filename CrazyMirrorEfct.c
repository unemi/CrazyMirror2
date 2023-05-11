extern int Width, Height;

static float Theta = 0., Phi = 0.;
static float TT = 0;
static int Oc11 = 0, Oc12 = 0, Oc21 = 0, Oc22 = 0;
static unsigned char **sourceFrames = NULL;
static float *fBuffer = NULL, *fBuffer1, *fBuffer2, *fBuffer3;
static int Depth = 0, SFIndex = 0;
static int rowBytes;
static unsigned char *base;
static int srcRowBytes;
static vUf128 *hnalalaaxc = NULL;

NSBitmapImageRep *bitmap, *smallBitmap, *largeBitmap;

static void hnalalaa(void) {
	int ix, iy, jj, js, k;
	float st, ctsph,
		hw = Width * .5f, hh = Height * .5f;
	unsigned char *bb;
	vUf128 vx, vy, vtt, vfx, vd;
	vUi128 vk, vidx;
	Oc11 = (Oc11 + 7) % 3600;
	Oc12 = (Oc12 + 17) % 3600;
	Oc21 = (Oc21 + 13) % 3600;
	Oc22 = (Oc22 + 23) % 3600;
	Theta = (sinf(Oc11 * M_PI / 1800) * .7f + sinf(Oc12 * M_PI / 1800) * .3) * M_PI * .45;
	Phi = (cosf(Oc11 * M_PI / 1800) * .6f + cosf(Oc12 * M_PI / 1800) * .4) * M_PI * .45;
	TT = (cosf(Oc21 * M_PI / 1800) * .8f + cosf(Oc22 * M_PI / 1800) * .2) * .5;
	st = sinf(Theta); ctsph = cosf(Theta) * sinf(Phi);
	vtt.f[0] = vtt.f[1] = vtt.f[2] = vtt.f[3] = TT + 1.f;
	vd.f[0] = vd.f[1] = vd.f[2] = vd.f[3] = Depth - 1;
	vidx.i[0] = vidx.i[1] = vidx.i[2] = vidx.i[3] = SFIndex - 1 + Depth;
	for (ix = 0; ix < Width; ix ++) hnalalaaxc[ix / 4].f[ix % 4] = (ix / hw - 1.f) * st;
	for (iy = 0, js = 0; iy < Height; iy ++, base += rowBytes, js += srcRowBytes) {
		vy.f[0] = vy.f[1] = vy.f[2] = vy.f[3] = (iy / hh - 1.f) * ctsph;
		for (ix = 0, bb = base, jj = js + 1; ix < Width / 4; ix ++, bb += 16, jj += 16) {
			vx.v = vfabf((hnalalaaxc[ix].v + vy.v + vtt.v) * vConstF(.5));
			vk.v = vinteger(vfx.v = vec_floor(vx.v)) & vConstI(1);
			for (k = 0; k < 4; k ++)
				vx.f[k] = vk.i[k]? vfx.f[k] + 1.f - vx.f[k] : vx.f[k] - vfx.f[k];
			vx.v *= vd.v;
			vx.v -= (vfx.v = vec_floor(vx.v));
			vk.v = vidx.v - vinteger(vfx.v);
			for (k = 0; k < 4; k ++) vk.i[k] %= Depth;
			vsmooth(bb, vk, vx, jj);
		}
	}
}
static void howawaan(void) {
	int ix, iy, w, j, jd, js, jj, k;
	vFloat vf;
	vUi128 vdw;
	if (fBuffer == NULL) return;
	w = (SFIndex + MaxDepth - 1) % MaxDepth;
	for (iy = jj = 0; iy < Height; iy ++) {
		jd = iy * rowBytes;
		js = iy * srcRowBytes + 1;
		for (ix = 0; ix < Width; ix += 4, jd += 16, js += 16) {
			for (k = 0; k < 3; k ++, jj += 4) {
				for (j = 0; j < 4; j ++) vdw.i[j] = sourceFrames[w][js + j * 4 + k];
				vf = vfloat(vdw.v) * vConstF(.02) + vLoad(jj, fBuffer) * vConstF(.98);
				vStore(vf, jj, fBuffer);
				vdw.v = vinteger(vf);
				for (j = 0; j < 4; j ++) base[jd + j * 4 + k] = vdw.i[j];
			}
		}
	}
}
static void zjvdgycboo(void) {
	int ix, iy, w, j, jd, js, jj, k;
	vFloat vf;
	vUi128 vdw;
	if (fBuffer == NULL) return;
	memcpy(fBuffer1, fBuffer, sizeof(float) * Width * 3 * Height);
	w = (SFIndex + MaxDepth - 1) % MaxDepth;
	for (iy = jj = 0; iy < Height; iy ++) {
		jd = iy * rowBytes;
		js = iy * srcRowBytes + 1;
		for (ix = 0; ix < Width; ix += 4, jd += 16, js += 16) {
			for (k = 0; k < 3; k ++, jj += 4) {
				for (j = 0; j < 4; j ++) vdw.i[j] = sourceFrames[w][js + j * 4 + k];
				vf = vfloat(vdw.v) * vConstF(.02) + vLoad(jj, fBuffer) * vConstF(.98);
				vStore(vf, jj, fBuffer);
				vdw.v = vinteger(vfabf(vf - vLoad(jj, fBuffer1)) * vConstF(50));
				for (j = 0; j < 4; j ++) base[jd + j * 4 + k] = vdw.i[j];
			}
		}
	}
}
static inline void vblur(float *src, float *dst, int i, int j) {
	vFloat d = (vLoad(i, src) - vLoad(j, src)) * vConstF(.2499);
	vStore(vLoad(i, dst) - d, i, dst);
	vStore(vLoad(j, dst) + d, j, dst);
}
static void hnolelee(void) {
	int ix, iy, w, j, js, jj, jf, k;
	float dif;
	vFloat vf;
	vUf128 v1, v2, vdif;
	vUi128 vdw, vww;
	if (fBuffer == NULL) return;
	memcpy(fBuffer1, fBuffer, sizeof(float) * Width * 3 * Height);
	w = (SFIndex + MaxDepth - 1) % MaxDepth;
	for (iy = jj = jf = 0; iy < Height; iy ++) {
		js = iy * srcRowBytes + 1;
		for (ix = 0; ix < Width; ix += 4, jf += 4, js += 16) {
			vdif.v = vConstF(0);
			for (k = 0; k < 3; k ++, jj += 4) {
				for (j = 0; j < 4; j ++) vdw.i[j] = sourceFrames[w][js + j * 4 + k];
				vf = vfloat(vdw.v) * vConstF(.02) + vLoad(jj, fBuffer) * vConstF(.98);
				vStore(vf, jj, fBuffer);
				vdif.v += vfabf(vf - vLoad(jj, fBuffer1));
			}
			vStore(vdif.v, jf, fBuffer3);
		}
	}
	for (k = 0; k < 2; k ++) {
		memcpy(fBuffer1, fBuffer3, sizeof(float) * Width * Height);
		for (iy = 0; iy < Height; iy ++)
		for (ix = 0, j = iy * Width, dif = 0.f; ix < Width; ix += 4, j += 4) {
			v1.v = vLoad(j, fBuffer1);
			v2.v = vShiftL32(v1.v);
			v2.f[3] = (ix + 4 < Width)? fBuffer1[j + 4] : fBuffer1[j + 3];
			vdif.v = (v1.v - v2.v) * vConstF(.2499);
			v2.v = vShiftR32(vdif.v);
			v2.f[0] = dif;
			dif = vdif.f[3];
			vStore(vLoad(j, fBuffer3) - vdif.v + v2.v, j, fBuffer3);
		}
		for (iy = 1, j = Width; iy < Height; iy ++)
			for (ix = 0; ix < Width; ix += 4, j += 4)
				vblur(fBuffer1, fBuffer3, j - Width, j);
	}
	v1.f[0] = v1.f[1] = v1.f[2] = v1.f[3] = Depth - 1;
	vdw.i[0] = vdw.i[1] = vdw.i[2] = vdw.i[3] = w + Depth;
	for (iy = 0; iy < Height; iy ++) {
		j = iy * rowBytes;
		js = iy * srcRowBytes + 1;
		jf = iy * Width;
		for (ix = 0; ix < Width; ix +=4, j += 16, js += 16, jf += 4) {
			vdif.v = vec_min(vLoad(jf, fBuffer3) * vConstF(.1), vConstF(1)) * v1.v;
			vdif.v -= (vf = vec_floor(vdif.v));
			vww.v = vdw.v - vinteger(vf);
			for (k = 0; k < 4; k ++) vww.i[k] %= Depth;
			vsmooth(base + j, vww, vdif, js);
		}
	}
}
static void shavazzz(void) {
	int ix, iy, w, j, js, jj, k, ir;
	for (iy = jj = 0; iy < Height; iy ++) {
		j = iy * rowBytes;
		js = iy * srcRowBytes + 1;
		for (ix = 0; ix < Width; ix ++, j += 4, js += 4, jj += 3) {
			if (ix % 5 == 0) ir = lrand48();
			else ir >>= 6;
			w = ir % Depth;
			for (k = 0; k < 3; k ++) base[j + k] = sourceFrames[w][js + k];
		}
	}
}
static void hahehohu(void) {
	int ix, iy, w, j, jd, js, jj, jjj, k;
	vFloat vz, vf[3];
	vUf128 v1, v2, vdif;
	vUi128 vdw;
	int msize = Width * 3 * Height;
	if (fBuffer == NULL) return;
	memcpy(fBuffer1, fBuffer, sizeof(float) * msize);
	memcpy(fBuffer3, fBuffer2, sizeof(float) * msize);
	w = (SFIndex + MaxDepth - 1) % MaxDepth;
	k = Width * 3;
	for (iy = j = 0; iy < Height; iy ++, j += k)
	for (ix = 0, jj = j, jjj = j + 12; ix < k; ix += 4, jj += 4, jjj += 4) {
		v1.v = vLoad(jj, fBuffer3);
		v2.v = vShiftL32(v1.v);
		v2.f[3] = (ix + 12 < k)? fBuffer3[jjj] : fBuffer3[jj + 3];
		vdif.v = (v1.v - v2.v) * vConstF(.2499);
		vStore(vLoad(jj, fBuffer2) - vdif.v + vShiftR32(vdif.v), jj, fBuffer2);
		if (ix + 12 < k) fBuffer2[jjj] += vdif.f[3];
	}
	for (iy = 1, j = k; iy < Height; iy ++)
		for (ix = 0; ix < k; ix += 4, j += 4)
			vblur(fBuffer3, fBuffer2, j - k, j);
	for (iy = jj = 0; iy < Height; iy ++) {
		jd = iy * rowBytes;
		js = iy * srcRowBytes + 1;
		for (ix = 0; ix < Width; ix += 4, jd += 16, js += 16) {
			vdif.v = vConstF(0);
			for (k = 0, jjj = jj; k < 3; k ++, jjj += 4) {
				for (j = 0; j < 4; j ++) vdw.i[j] = sourceFrames[w][js + j * 4 + k];
				vz = (vf[k] = vfloat(vdw.v)) * vConstF(.02) + vLoad(jjj, fBuffer) * vConstF(.98);
				vStore(vz, jjj, fBuffer);
				vdif.v += vfabf(vz - vLoad(jjj, fBuffer1));
			}
			vdif.v = vdif.v * vConstF(.2) + vConstF(-.4);
			vdif.v = vec_min(vConstF(1), vec_max(vdif.v, vConstF(0)));
			for (k = 0; k < 3; k ++, jj += 4) {
				vz = vf[k] * vdif.v + vLoad(jj, fBuffer2) * (vConstF(1) - vdif.v);
				vStore(vz, jj, fBuffer2);
				vdw.v = vinteger(vz);
				for (j = 0; j < 4; j ++) base[jd + j * 4 + k] = vdw.i[j];
			}
		}
	}
}
