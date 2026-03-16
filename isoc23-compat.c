#include <errno.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <wchar.h>

#ifdef pthread_cond_clockwait
#undef pthread_cond_clockwait
#endif

long __isoc23_strtol(const char *nptr, char **endptr, int base) {
	return strtol(nptr, endptr, base);
}

unsigned long __isoc23_strtoul(const char *nptr, char **endptr, int base) {
	return strtoul(nptr, endptr, base);
}

long long __isoc23_strtoll(const char *nptr, char **endptr, int base) {
	return strtoll(nptr, endptr, base);
}

unsigned long long __isoc23_strtoull(const char *nptr, char **endptr, int base) {
	return strtoull(nptr, endptr, base);
}

int __isoc23_sscanf(const char *s, const char *format, ...) {
	int result;
	va_list args;

	va_start(args, format);
	result = vsscanf(s, format, args);
	va_end(args);

	return result;
}

int __isoc23_fscanf(FILE *stream, const char *format, ...) {
	int result;
	va_list args;

	va_start(args, format);
	result = vfscanf(stream, format, args);
	va_end(args);

	return result;
}

int __isoc23_scanf(const char *format, ...) {
	int result;
	va_list args;

	va_start(args, format);
	result = vscanf(format, args);
	va_end(args);

	return result;
}

int __isoc23_vfscanf(FILE *stream, const char *format, va_list args) {
	return vfscanf(stream, format, args);
}

int __isoc23_vscanf(const char *format, va_list args) {
	return vscanf(format, args);
}

int __isoc23_vsscanf(const char *s, const char *format, va_list args) {
	return vsscanf(s, format, args);
}

wchar_t *__wmemset_chk(wchar_t *wcs, wchar_t wc, size_t n, size_t dstlen) {
	(void)dstlen;
	return wmemset(wcs, wc, n);
}

size_t __mbsrtowcs_chk(wchar_t *dst, const char **src, size_t len, mbstate_t *ps, size_t dstlen) {
	(void)dstlen;
	return mbsrtowcs(dst, src, len, ps);
}

size_t __mbsnrtowcs_chk(wchar_t *dst, const char **src, size_t nmc, size_t len, mbstate_t *ps, size_t dstlen) {
	(void)dstlen;
	return mbsnrtowcs(dst, src, nmc, len, ps);
}

static void timespec_normalize(struct timespec *ts) {
	while (ts->tv_nsec >= 1000000000L) {
		ts->tv_nsec -= 1000000000L;
		ts->tv_sec += 1;
	}
	while (ts->tv_nsec < 0) {
		ts->tv_nsec += 1000000000L;
		ts->tv_sec -= 1;
	}
}

int pthread_cond_clockwait(pthread_cond_t *cond, pthread_mutex_t *mutex, clockid_t clock_id, const struct timespec *abstime) {
	struct timespec realtime_deadline;
	struct timespec now_clock;
	struct timespec now_realtime;

	if (abstime == NULL) {
		return pthread_cond_wait(cond, mutex);
	}

	if (clock_id == CLOCK_REALTIME) {
		return pthread_cond_timedwait(cond, mutex, abstime);
	}

	if (clock_gettime(clock_id, &now_clock) != 0) {
		return errno;
	}

	if (clock_gettime(CLOCK_REALTIME, &now_realtime) != 0) {
		return errno;
	}

	realtime_deadline.tv_sec = now_realtime.tv_sec + (abstime->tv_sec - now_clock.tv_sec);
	realtime_deadline.tv_nsec = now_realtime.tv_nsec + (abstime->tv_nsec - now_clock.tv_nsec);
	timespec_normalize(&realtime_deadline);

	return pthread_cond_timedwait(cond, mutex, &realtime_deadline);
}
