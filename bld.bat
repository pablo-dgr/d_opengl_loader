@echo off

set proj=d_opengl_loader
set bdir=%cd%\build
set sdir=%cd%\source

cls

if not exist %bdir% (mkdir %bdir%)

pushd %sdir%

dmd main.d -m64 -g -gf -debug -of=%bdir%\%proj%.exe

popd
