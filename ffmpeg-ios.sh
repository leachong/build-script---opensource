#!/bin/sh

# directories
SOURCE="ffmpeg-2.8.5"
FAT="FFmpeg-iOS"

SCRATCH="scratch"
# must be an absolute path
THIN=`pwd`/"thin"

# absolute path to x264 library
#X264=`pwd`/fat-x264

#FDK_AAC=`pwd`/fdk-aac/fdk-aac-ios
VO_AAC=`pwd`/vo-aacenc-libs

CONFIGURE_FLAGS="--enable-cross-compile --disable-debug --disable-programs \
                 --disable-doc --enable-pic"
CONFIGURE_FLAGS="$CONFIGURE_FLAGS \
--enable-static --disable-shared --enable-version3 --enable-nonfree --enable-small --disable-debug \
--disable-programs --disable-postproc --enable-network --disable-avfilter --disable-avresample \
--enable-gpl  --enable-pthreads --disable-w32threads --disable-doc --disable-openssl --disable-hwaccels \
--disable-encoders --disable-decoders --disable-parsers --disable-devices --disable-filters --enable-protocols --enable-bsfs \
--enable-decoder=hevc \
--enable-encoder=libx264 --enable-decoder=h264 \
--enable-encoder=nellymoser --enable-decoder=nellymoser \
--enable-libspeex --enable-encoder=libspeex --enable-decoder=libspeex \
--enable-libfdk-aac --enable-encoder=libfdk_aac \
--enable-decoder=aac --enable-decoder=aac_latm \
"

ANDROID_CONFIGURE_FLAGS=" \
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
    --enable-decoder=nellymoser \
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
	"

if [ "$X264" ]
then
	CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-gpl --enable-libx264"
fi

if [ "$FDK_AAC" ]
then
	CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-libfdk-aac"
fi

if [ "$VO_AAC" ]
then
	CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-libvo-aacenc --enable-version3"
fi

# avresample
#CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-avresample"

ARCHS="armv7 armv7s arm64"

COMPILE="y"
LIPO="y"

DEPLOYMENT_TARGET="6.0"

if [ "$*" ]
then
	if [ "$*" = "lipo" ]
	then
		# skip compile
		COMPILE=
	else
		ARCHS="$*"
		if [ $# -eq 1 ]
		then
			# skip lipo
			LIPO=
		fi
	fi
fi

if [ "$COMPILE" ]
then
	if [ ! `which yasm` ]
	then
		echo 'Yasm not found'
		if [ ! `which brew` ]
		then
			echo 'Homebrew not found. Trying to install...'
                        ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" \
				|| exit 1
		fi
		echo 'Trying to install Yasm...'
		brew install yasm || exit 1
	fi
	if [ ! `which gas-preprocessor.pl` ]
	then
		echo 'gas-preprocessor.pl not found. Trying to install...'
		(curl -L https://github.com/libav/gas-preprocessor/raw/master/gas-preprocessor.pl \
			-o /usr/local/bin/gas-preprocessor.pl \
			&& chmod +x /usr/local/bin/gas-preprocessor.pl) \
			|| exit 1
	fi

	if [ ! -r $SOURCE ]
	then
		echo 'FFmpeg source not found. Trying to download...'
		curl http://www.ffmpeg.org/releases/$SOURCE.tar.bz2 | tar xj \
			|| exit 1
	fi

	CWD=`pwd`
	for ARCH in $ARCHS
	do
		echo "building $ARCH..."
		mkdir -p "$SCRATCH/$ARCH"
		cd "$SCRATCH/$ARCH"

		CFLAGS="-arch $ARCH"
		if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
		then
		    PLATFORM="iPhoneSimulator"
		    CFLAGS="$CFLAGS -mios-simulator-version-min=$DEPLOYMENT_TARGET"
		else
		    PLATFORM="iPhoneOS"
		    CFLAGS="$CFLAGS -mios-version-min=$DEPLOYMENT_TARGET -fembed-bitcode"
		    if [ "$ARCH" = "arm64" ]
		    then
		        EXPORT="GASPP_FIX_XCODE5=1"
		    fi
		fi

		XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
		CC="xcrun -sdk $XCRUN_SDK clang"
		CXXFLAGS="$CFLAGS"
		LDFLAGS="$CFLAGS"
		if [ "$X264" ]
		then
			CFLAGS="$CFLAGS -I$X264/include"
			LDFLAGS="$LDFLAGS -L$X264/lib"
		fi
		if [ "$FDK_AAC" ]
		then
			CFLAGS="$CFLAGS -I$FDK_AAC/include"
			LDFLAGS="$LDFLAGS -L$FDK_AAC/lib"
		fi
		if [ "$VO_AAC" ]
		then
			CFLAGS="$CFLAGS -I$VO_AAC/$ARCH/include"
			LDFLAGS="$LDFLAGS -L$VO_AAC/$ARCH/lib"
		fi

		TMPDIR=${TMPDIR/%\/} $CWD/$SOURCE/configure \
		    --target-os=darwin \
		    --arch=$ARCH \
		    --cc="$CC" \
		    $CONFIGURE_FLAGS \
		    --extra-cflags="$CFLAGS" \
		    --extra-ldflags="$LDFLAGS" \
		    --prefix="$THIN/$ARCH" \
		|| exit 1

		make -j3 install $EXPORT || exit 1
		cd $CWD
	done
fi

if [ "$LIPO" ]
then
	echo "building fat binaries..."
	mkdir -p $FAT/lib
	set - $ARCHS
	CWD=`pwd`
	cd $THIN/$1/lib
	for LIB in *.a
	do
		cd $CWD
		echo lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB 1>&2
		lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB || exit 1
	done

	cd $CWD
	cp -rf $THIN/$1/include $FAT
fi

echo Done
