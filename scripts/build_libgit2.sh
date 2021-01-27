#!/bin/sh

FILE=Extern/libgit2/build/libgit2.a
if [ -f "${FILE}" ]; then
  echo "libgit2 already built"
else
  make build_libgit2
fi
