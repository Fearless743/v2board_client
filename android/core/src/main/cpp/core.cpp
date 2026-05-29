#include <jni.h>
#include <dlfcn.h>
#include "jni_helper.h"

// Function pointers loaded via dlsym from libclash.so
typedef void (*startTUN_fn)(int fd, void *cb);
typedef void (*stopTun_fn)(void);
typedef void (*registerCallbacks_fn)(void *protect, void *resolve, void *release);

static startTUN_fn p_startTUN = nullptr;
static stopTun_fn p_stopTun = nullptr;
static registerCallbacks_fn p_registerCallbacks = nullptr;
static void *libclash_handle = nullptr;

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clashx_core_Core_startTun(JNIEnv *env, jobject, const jint fd, jobject cb) {
    if (p_startTUN) {
        const auto interface = new_global(cb);
        p_startTUN(fd, interface);
    }
}

extern "C"
JNIEXPORT void JNICALL
Java_com_follow_clashx_core_Core_stopTun(JNIEnv *) {
    if (p_stopTun) {
        p_stopTun();
    }
}

static jmethodID m_tun_interface_protect;
static jmethodID m_tun_interface_resolve_process;

static void release_jni_object_impl(void *obj) {
    ATTACH_JNI();
    del_global(static_cast<jobject>(obj));
}

static void call_tun_interface_protect_impl(void *tun_interface, const int fd) {
    ATTACH_JNI();
    env->CallVoidMethod(static_cast<jobject>(tun_interface),
                        m_tun_interface_protect,
                        fd);
}

static const char *
call_tun_interface_resolve_process_impl(void *tun_interface, int protocol,
                                        const char *source,
                                        const char *target,
                                        const int uid) {
    ATTACH_JNI();
    const auto packageName = reinterpret_cast<jstring>(env->CallObjectMethod(
        static_cast<jobject>(tun_interface),
        m_tun_interface_resolve_process,
        protocol,
        new_string(source),
        new_string(target),
        uid));
    return get_string(packageName);
}

extern "C"
JNIEXPORT jboolean JNICALL
Java_com_follow_clashx_core_Core_loadLibClash(JNIEnv *env, jclass, jstring path) {
    // If already loaded, close previous handle
    if (libclash_handle) {
        dlclose(libclash_handle);
        libclash_handle = nullptr;
    }

    if (path == nullptr) {
        libclash_handle = dlopen("libclash.so", RTLD_NOW | RTLD_GLOBAL);
    } else {
        const char *pathStr = env->GetStringUTFChars(path, nullptr);
        libclash_handle = dlopen(pathStr, RTLD_NOW | RTLD_GLOBAL);
        env->ReleaseStringUTFChars(path, pathStr);
    }

    if (!libclash_handle) {
        return JNI_FALSE;
    }

    p_startTUN = reinterpret_cast<startTUN_fn>(dlsym(libclash_handle, "startTUN"));
    p_stopTun = reinterpret_cast<stopTun_fn>(dlsym(libclash_handle, "stopTun"));
    p_registerCallbacks = reinterpret_cast<registerCallbacks_fn>(
        dlsym(libclash_handle, "registerCallbacks"));

    if (!p_startTUN || !p_stopTun || !p_registerCallbacks) {
        return JNI_FALSE;
    }

    return JNI_TRUE;
}

extern "C"
JNIEXPORT jint JNICALL
JNI_OnLoad(JavaVM *vm, void *) {
    JNIEnv *env = nullptr;
    if (vm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6) != JNI_OK) {
        return JNI_ERR;
    }

    initialize_jni(vm, env);

    const auto c_tun_interface = find_class("com/follow/clashx/core/TunInterface");

    m_tun_interface_protect = find_method(c_tun_interface, "protect", "(I)V");
    m_tun_interface_resolve_process = find_method(c_tun_interface, "resolverProcess",
                                                  "(ILjava/lang/String;Ljava/lang/String;I)Ljava/lang/String;");

    if (p_registerCallbacks) {
        p_registerCallbacks(&call_tun_interface_protect_impl,
                            &call_tun_interface_resolve_process_impl,
                            &release_jni_object_impl);
    }
    return JNI_VERSION_1_6;
}
