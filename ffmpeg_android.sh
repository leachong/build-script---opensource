# ffmpegX.X.X/build_ffmpeg_with_librtmp_for_android.sh
#!/bin/bash

#NDK=/opt/android-ndk-r9d
NDK=/Users/leendx/Documents/libs_src_code/android-ndk-r10e
SYSROOT=$NDK/platforms/android-16/arch-arm/
#TOOLCHAIN=$NDK/toolchains/arm-linux-androideabi-4.6/prebuilt/linux-x86_64
#TOOLCHAIN_LIBGCC_DIR=$TOOLCHAIN/lib/gcc/arm-linux-androideabi/4.6
TOOLCHAIN=$NDK/toolchains/arm-linux-androideabi-4.8/prebuilt/darwin-x86_64
TOOLCHAIN_LIBGCC_DIR=$TOOLCHAIN/lib/gcc/arm-linux-androideabi/4.8

#LIBAAC_DIR=/home/zcp/faac/android/arm/
LIBAAC_DIR=/Users/leendx/Downloads/faac/android/arm/
# Note: Change above variables to match your system
function build_one
{
./configure \
    --prefix=$PREFIX \
    --disable-shared \
    --enable-static \
    --disable-symver \
    --disable-doc \
    --disable-ffplay \
    --disable-ffmpeg \
    --disable-ffprobe \
    --disable-ffserver \
    --disable-avdevice \
    --disable-avfilter \
    --disable-encoders \
    --disable-muxers \
    --disable-filters \
    --disable-devices \
    --disable-zlib \
    --disable-bzlib \
    --disable-debug \
    --disable-postproc \
    --enable-small \
    --disable-everything \
    --enable-protocol=file \
    --disable-network \
    --enable-parser=aac \
    --enable-parser=h264 \
    --enable-parser=mpeg4video\
    --enable-parser=hevc\
    --enable-decoder=hevc \
	--enable-encoder=mpeg4 \
	--enable-encoder=libfaac \
	--enable-decoder=h264 \
	--enable-libfaac \
	--enable-muxer=mp4 \
	--enable-swscale \
	--enable-asm \
	--enable-version3 \
	--enable-armv5te \
	--enable-gpl \
	--enable-nonfree \
    --cross-prefix=$TOOLCHAIN/bin/arm-linux-androideabi- \
    --target-os=linux \
    --arch=arm \
    --enable-cross-compile \
    --sysroot=$SYSROOT \
    --extra-cflags="-Os -fpic $ADDI_CFLAGS" \
    --extra-ldflags="$ADDI_LDFLAGS" \
	$ADDITIONAL_CONFIGURE_FLAG
make -j8
make install
}
CPU=arm
PREFIX=$(pwd)/android/$CPU 
ADDI_CFLAGS="-marm "
ADDI_CFLAGS+=" -I${LIBAAC_DIR}/include "
ADDI_LDFLAGS+="-L${LIBAAC_DIR}/lib -lfaac "  
build_one

$TOOLCHAIN/bin/arm-linux-androideabi-ld -rpath-link=$SYSROOT/usr/lib -L$SYSROOT/usr/lib  -soname $PREFIX/libffmpeg.so -shared -nostdlib  -Bsymbolic --whole-archive --no-undefined -o $PREFIX/libffmpeg.so libavcodec/libavcodec.a libavformat/libavformat.a libavutil/libavutil.a libswscale/libswscale.a $LIBAAC_DIR/lib/libfaac.a -lc -lm -lz -ldl -llog   --dynamic-linker=/system/bin/linker $TOOLCHAIN_LIBGCC_DIR/libgcc.a

$TOOLCHAIN/bin/arm-linux-androideabi-strip --strip-unneeded $PREFIX/libffmpeg.so 

