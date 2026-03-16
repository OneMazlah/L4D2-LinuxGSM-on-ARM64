#include <cstdarg>
#include <cstdio>
#include <cstring>
#include <unistd.h>

struct CPUInformation {
	int m_Size;
	bool m_bRDTSC : 1;
	bool m_bCMOV : 1;
	bool m_bFCMOV : 1;
	bool m_bSSE : 1;
	bool m_bSSE2 : 1;
	bool m_b3DNow : 1;
	bool m_bMMX : 1;
	bool m_bHT : 1;
	unsigned char m_nLogicalProcessors;
	unsigned char m_nPhysicalProcessors;
	long long m_Speed;
	char *m_szProcessorID;
};

class Color {
public:
	unsigned char _color[4];
};

namespace {

CPUInformation g_cpu_info = {
	sizeof(CPUInformation),
	true,
	true,
	true,
	true,
	true,
	false,
	true,
	false,
	1,
	1,
	0,
	const_cast<char *>("box86-compat")
};

static void init_cpu_info() {
	long logical = sysconf(_SC_NPROCESSORS_ONLN);
	if (logical > 0 && logical < 256) {
		g_cpu_info.m_nLogicalProcessors = static_cast<unsigned char>(logical);
		g_cpu_info.m_nPhysicalProcessors = static_cast<unsigned char>(logical);
	}
}

static void vprint_prefixed(FILE *stream, const char *prefix, const char *fmt, va_list args) {
	if (prefix && prefix[0] != '\0') {
		fputs(prefix, stream);
	}
	vfprintf(stream, fmt, args);
	fflush(stream);
}

}  // namespace

extern "C" __attribute__((visibility("default"))) const CPUInformation &GetCPUInformation() {
	static bool initialized = false;
	if (!initialized) {
		init_cpu_info();
		initialized = true;
	}
	return g_cpu_info;
}

extern "C" __attribute__((visibility("default"))) void Warning(const char *msg, ...) {
	va_list args;
	va_start(args, msg);
	vprint_prefixed(stderr, "[tier0compat] ", msg, args);
	va_end(args);
}

extern "C" __attribute__((visibility("default"))) void Error(const char *msg, ...) {
	va_list args;
	va_start(args, msg);
	vprint_prefixed(stderr, "[tier0compat] ", msg, args);
	va_end(args);
}

extern "C" __attribute__((visibility("default"))) void _AssertValidReadPtr(void *ptr, int count) {
	(void)ptr;
	(void)count;
}

extern "C" __attribute__((visibility("default"))) void _AssertValidWritePtr(void *ptr, int count) {
	(void)ptr;
	(void)count;
}

extern "C" __attribute__((visibility("default"))) void AssertValidStringPtr(const char *ptr, int maxchar) {
	(void)ptr;
	(void)maxchar;
}

__attribute__((visibility("default"))) void ConMsg(const char *msg, ...) {
	va_list args;
	va_start(args, msg);
	vprint_prefixed(stdout, "", msg, args);
	va_end(args);
}

__attribute__((visibility("default"))) void ConColorMsg(const Color &clr, const char *msg, ...) {
	(void)clr;
	va_list args;
	va_start(args, msg);
	vprint_prefixed(stdout, "", msg, args);
	va_end(args);
}
