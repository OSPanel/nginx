#!/bin/bash
cp -rf /mingw64/bin/libGeoIP-1.dll ./Release/libGeoIP-1.dll
cp -rf /mingw64/bin/libmaxminddb.dll ./Release/libmaxminddb.dll
cp -rf /mingw64/bin/libgd.dll ./Release/libgd.dll
cp -rf /mingw64/bin/libopenjp2-7.dll ./Release/libopenjp2-7.dll
cp -rf /mingw64/bin/libopenjph-0.21.dll ./Release/libopenjph-0.21.dll
cp -rf /mingw64/bin/libopenh264-7.dll ./Release/libopenh264-7.dll
cp -rf /mingw64/bin/libsharpyuv-0.dll ./Release/libsharpyuv-0.dll
cp -rf /mingw64/bin/libfreetype-6.dll ./Release/libfreetype-6.dll
cp -rf /mingw64/bin/libfontconfig-1.dll ./Release/libfontconfig-1.dll
cp -rf /mingw64/bin/libheif.dll ./Release/libheif.dll
cp -rf /mingw64/bin/libavif-16.dll ./Release/libavif-16.dll
cp -rf /mingw64/bin/libkvazaar-7.dll ./Release/libkvazaar-7.dll
cp -rf /mingw64/bin/libiconv-2.dll ./Release/libiconv-2.dll
cp -rf /mingw64/bin/libcryptopp.dll ./Release/libcryptopp.dll
cp -rf /mingw64/bin/libjpeg-8.dll ./Release/libjpeg-8.dll
cp -rf /mingw64/bin/libimagequant.dll ./Release/libimagequant.dll
cp -rf /mingw64/bin/libwebp-7.dll ./Release/libwebp-7.dll
cp -rf /mingw64/bin/libpng16-16.dll ./Release/libpng16-16.dll
cp -rf /mingw64/bin/libXpm-noX4.dll ./Release/libXpm-noX4.dll
cp -rf /mingw64/bin/libaom.dll ./Release/libaom.dll
cp -rf /mingw64/bin/zlib1.dll ./Release/zlib1.dll
cp -rf /mingw64/bin/libtiff-6.dll ./Release/libtiff-6.dll
cp -rf /mingw64/bin/libdav1d-7.dll ./Release/libdav1d-7.dll
cp -rf /mingw64/bin/librav1e.dll ./Release/librav1e.dll
cp -rf /mingw64/bin/libyuv.dll ./Release/libyuv.dll
cp -rf /mingw64/bin/libgcc_s_seh-1.dll ./Release/libgcc_s_seh-1.dll
cp -rf /mingw64/bin/libSvtAv1Enc-3.dll ./Release/libSvtAv1Enc-3.dll
cp -rf /mingw64/bin/libintl-8.dll ./Release/libintl-8.dll
cp -rf /mingw64/bin/libexpat-1.dll ./Release/libexpat-1.dll
cp -rf /mingw64/bin/libbz2-1.dll ./Release/libbz2-1.dll
cp -rf /mingw64/bin/libharfbuzz-0.dll ./Release/libharfbuzz-0.dll
cp -rf /mingw64/bin/libbrotlienc.dll ./Release/libbrotlienc.dll
cp -rf /mingw64/bin/libde265-0.dll ./Release/libde265-0.dll
cp -rf /mingw64/bin/libstdc++-6.dll ./Release/libstdc++-6.dll
cp -rf /mingw64/bin/libbrotlidec.dll ./Release/libbrotlidec.dll
cp -rf /mingw64/bin/libx265-215.dll ./Release/libx265-215.dll
cp -rf /mingw64/bin/libjbig-0.dll ./Release/libjbig-0.dll
cp -rf /mingw64/bin/libdeflate.dll ./Release/libdeflate.dll
cp -rf /mingw64/bin/libLerc.dll ./Release/libLerc.dll
cp -rf /mingw64/bin/liblzma-5.dll ./Release/liblzma-5.dll
cp -rf /mingw64/bin/libzstd.dll ./Release/libzstd.dll
cp -rf /mingw64/bin/libbrotlicommon.dll ./Release/libbrotlicommon.dll
cp -rf /mingw64/bin/libwinpthread-1.dll ./Release/libwinpthread-1.dll
cp -rf /mingw64/bin/libgraphite2.dll ./Release/libgraphite2.dll
cp -rf /mingw64/bin/libglib-2.0-0.dll ./Release/libglib-2.0-0.dll
cp -rf /mingw64/bin/libpcre2-8-0.dll ./Release/libpcre2-8-0.dll

cp -rf nginx/conf ./Release
cp -rf nginx/docs/html ./Release
cp -rf nginx/contrib ./Release
mkdir -p ./Release/temp
mkdir -p ./Release/logs
cd ./Release
7z a -mx9 nginx-bin.7z nginx-*.exe *.dll contrib docs conf html temp logs