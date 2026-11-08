#include <assert.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include "graphics_bridge.h"

static void regions(void) {
    WBCopyRegion r;
    assert(wb_copy_region(4, 4, 4, 4, -1, -2, &r));
    assert(r.src_x == 1 && r.src_y == 2 && r.dst_x == 0 && r.width == 3 && r.height == 2);
    assert(wb_copy_region(4, 4, 4, 4, 2, 1, &r));
    assert(r.dst_x == 2 && r.dst_y == 1 && r.width == 2 && r.height == 3);
    assert(wb_copy_region(4, 4, 4, 4, INT_MIN, INT_MAX, &r) && r.width == 0);
    assert(!wb_copy_region(0, 4, 4, 4, 0, 0, &r));
}

static GLuint texture(int width, int height, const unsigned char *pixels) {
    GLuint id;
    glGenTextures(1, &id);
    glBindTexture(GL_TEXTURE_2D, id);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    assert(glGetError() == GL_NO_ERROR);
    return id;
}

static void read_texture(GLuint id, unsigned char *pixels) {
    GLuint fb;
    glGenFramebuffers(1, &fb);
    glBindFramebuffer(GL_FRAMEBUFFER, fb);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, id, 0);
    assert(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE);
    glReadPixels(0, 0, 4, 4, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
    assert(glGetError() == GL_NO_ERROR);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glDeleteFramebuffers(1, &fb);
}

static void pixels(WBGraphicsBridge *bridge, int mode, int x, int y) {
    unsigned char source[64], empty[64] = {0}, actual[64], expected[64] = {0};
    for (int i = 0; i < 16; i++) {
        source[i * 4] = (unsigned char)(17 * i);
        source[i * 4 + 1] = (unsigned char)(255 - 13 * i);
        source[i * 4 + 2] = (unsigned char)(7 * i);
        source[i * 4 + 3] = 255;
    }
    GLuint src = texture(4, 4, source), dst = texture(4, 4, empty);
    WBCopyRegion r;
    assert(wb_copy_region(4, 4, 4, 4, x, y, &r));
    for (int row = 0; row < r.height; row++)
        for (int col = 0; col < r.width; col++)
            memcpy(expected + ((row + r.dst_y) * 4 + col + r.dst_x) * 4,
                   source + ((row + r.src_y) * 4 + col + r.src_x) * 4, 4);
    GLuint sentinel[2], buffers[2];
    glGenFramebuffers(2, sentinel);
    glBindFramebuffer(GL_READ_FRAMEBUFFER, sentinel[0]);
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, sentinel[1]);
    glEnable(GL_SCISSOR_TEST); glScissor(0, 0, 1, 1);
    glGenBuffers(2, buffers);
    glBindBuffer(GL_PIXEL_PACK_BUFFER, buffers[0]); glBufferData(GL_PIXEL_PACK_BUFFER, 8, NULL, GL_STATIC_DRAW);
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, buffers[1]); glBufferData(GL_PIXEL_UNPACK_BUFFER, 8, NULL, GL_STATIC_DRAW);
    glPixelStorei(GL_PACK_ROW_LENGTH, 7); glPixelStorei(GL_UNPACK_ROW_LENGTH, 7);
    glPixelStorei(GL_PACK_SKIP_ROWS, 1); glPixelStorei(GL_UNPACK_SKIP_PIXELS, 1);
    int path = wb_graphics_copy(bridge, src, dst, &r, mode);
    assert(path > 0);
    if (mode == WB_FORCE_READBACK) assert(path == WB_COPY_READBACK);
    if (mode == WB_FORCE_BLIT) assert(path == WB_COPY_BLIT);
    GLint value;
    glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING, &value); assert((GLuint)value == sentinel[0]);
    glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, &value); assert((GLuint)value == sentinel[1]);
    glGetIntegerv(GL_PIXEL_PACK_BUFFER_BINDING, &value); assert((GLuint)value == buffers[0]);
    glGetIntegerv(GL_PIXEL_UNPACK_BUFFER_BINDING, &value); assert((GLuint)value == buffers[1]);
    glGetIntegerv(GL_PACK_ROW_LENGTH, &value); assert(value == 7);
    glGetIntegerv(GL_UNPACK_SKIP_PIXELS, &value); assert(value == 1);
    assert(glIsEnabled(GL_SCISSOR_TEST));
    glDisable(GL_SCISSOR_TEST);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glBindBuffer(GL_PIXEL_PACK_BUFFER, 0); glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
    glPixelStorei(GL_PACK_ROW_LENGTH, 0); glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
    glPixelStorei(GL_PACK_SKIP_ROWS, 0); glPixelStorei(GL_UNPACK_SKIP_PIXELS, 0);
    glDeleteFramebuffers(2, sentinel); glDeleteBuffers(2, buffers);
    read_texture(dst, actual);
    assert(!memcmp(actual, expected, sizeof(actual)));
    glDeleteTextures(1, &src); glDeleteTextures(1, &dst);
}

static void incompatible_image_format(WBGraphicsBridge *bridge) {
    unsigned char rgba[4] = {255, 0, 0, 255};
    GLuint ids[2], fb;
    glGenTextures(2, ids);
    glBindTexture(GL_TEXTURE_2D, ids[0]);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, 1, 1, 0, GL_RGBA, GL_UNSIGNED_BYTE, rgba);
    glBindTexture(GL_TEXTURE_2D, ids[1]);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB565, 1, 1, 0, GL_RGB, GL_UNSIGNED_SHORT_5_6_5, NULL);
    WBCopyRegion r = {0, 0, 0, 0, 1, 1};
    int path = wb_graphics_copy(bridge, ids[0], ids[1], &r, WB_COPY_AUTO);
    assert(path == WB_COPY_BLIT || path == WB_COPY_READBACK);
    glGenFramebuffers(1, &fb);
    glBindFramebuffer(GL_FRAMEBUFFER, fb);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, ids[1], 0);
    unsigned char actual[4] = {0};
    glReadPixels(0, 0, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, actual);
    assert(glGetError() == GL_NO_ERROR && actual[0] == 255 && actual[1] == 0 && actual[2] == 0);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glDeleteFramebuffers(1, &fb); glDeleteTextures(2, ids);
}

int main(void) {
    regions();
    PFNEGLGETPLATFORMDISPLAYEXTPROC get_display = (PFNEGLGETPLATFORMDISPLAYEXTPROC)eglGetProcAddress("eglGetPlatformDisplayEXT");
    EGLDisplay display = get_display ? get_display(EGL_PLATFORM_SURFACELESS_MESA, EGL_DEFAULT_DISPLAY, NULL) : eglGetDisplay(EGL_DEFAULT_DISPLAY);
    assert(display != EGL_NO_DISPLAY && eglInitialize(display, NULL, NULL));
    assert(eglBindAPI(EGL_OPENGL_ES_API));
    const EGLint config_attributes[] = {EGL_SURFACE_TYPE, EGL_PBUFFER_BIT, EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT, EGL_NONE};
    EGLConfig config; EGLint count;
    assert(eglChooseConfig(display, config_attributes, &config, 1, &count) && count > 0);
    const EGLint context_attributes[] = {EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE};
    const EGLint surface_attributes[] = {EGL_WIDTH, 4, EGL_HEIGHT, 4, EGL_NONE};
    EGLContext context = eglCreateContext(display, config, EGL_NO_CONTEXT, context_attributes);
    EGLSurface surface = eglCreatePbufferSurface(display, config, surface_attributes);
    assert(context != EGL_NO_CONTEXT && surface != EGL_NO_SURFACE && eglMakeCurrent(display, surface, surface, context));
    printf("Host renderer: %s\n", glGetString(GL_RENDERER));
    WBGraphicsBridge *bridge = wb_graphics_create();
    assert(bridge && (wb_graphics_validate(bridge) & 6) == 6);
    for (int mode = WB_COPY_AUTO; mode <= WB_FORCE_READBACK; mode++) {
        pixels(bridge, mode, 0, 0);
        pixels(bridge, mode, -1, -2);
        pixels(bridge, mode, 2, 1);
    }
    incompatible_image_format(bridge);
    pixels(bridge, WB_COPY_AUTO, 0, 0);
    EGLContext second = eglCreateContext(display, config, context, context_attributes);
    assert(second != EGL_NO_CONTEXT && eglMakeCurrent(display, surface, surface, second));
    WBGraphicsBridge *other = wb_graphics_create();
    assert(other && (wb_graphics_validate(other) & 6) == 6);
    pixels(other, WB_COPY_AUTO, 0, 0);
    wb_graphics_destroy(other, true);
    assert(eglMakeCurrent(display, surface, surface, context));
    pixels(bridge, WB_COPY_AUTO, 0, 0);
    wb_graphics_destroy(bridge, true);
    eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    eglDestroyContext(display, second); eglDestroyContext(display, context);
    eglDestroySurface(display, surface); eglTerminate(display);
    puts("Native graphics bridge: pixels, clipping, state restoration, format fallback and shared contexts passed.");
    return 0;
}
