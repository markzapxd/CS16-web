package main

/*
#include <stddef.h>
#include <sys/socket.h>

// Native engine d3bc7fa uses the registered July 2025 callbacks, while
// the Go network implementation exports the newer lib_net_* entrypoints.
// Keep the exact native ABI here and adapt only the differing parameters.
extern int lib_net_recvfrom(int, void *, size_t, int, void *, socklen_t *);
extern int lib_net_sendto_batch(int, char **, int *, int, int, struct sockaddr_storage *, int);
typedef int (*recvfrom_func_t)(int, void *, int, int, struct sockaddr *, socklen_t *);
typedef int (*sendto_func_t)(int, char **, size_t *, int, int, const struct sockaddr_storage *, int);
extern void RegisterRecvFromCallback(recvfrom_func_t);
extern void RegisterSendToCallback(sendto_func_t);

static int portable_recvfrom(int fd, void *buf, int len, int flags, struct sockaddr *addr, socklen_t *addrlen) {
    if (len < 0 || !buf) return -1;
    return lib_net_recvfrom(fd, buf, (size_t)len, flags, addr, addrlen);
}
static int portable_sendto(int fd, char **packets, size_t *sizes, int count, int sequence, const struct sockaddr_storage *to, int tolen) {
    // The final server is linux/386: size_t and int share width. Copy values
    // explicitly rather than aliasing distinct C types or forwarding the native
    // sequence number as POSIX flags.
    if (!packets || !sizes || !to || count <= 0 || count > 1024) return -1;
    int lengths[1024];
    for (int i = 0; i < count; ++i) {
        if (sizes[i] > 0x7fffffffU) return -1;
        lengths[i] = (int)sizes[i];
    }
    return lib_net_sendto_batch(fd, packets, lengths, count, 0, (struct sockaddr_storage *)to, tolen);
}
static void portable_register_callbacks(void) {
    RegisterRecvFromCallback(portable_recvfrom);
    RegisterSendToCallback(portable_sendto);
}
*/
import "C"

func registerNativeCallbacks() {
	C.portable_register_callbacks()
}
