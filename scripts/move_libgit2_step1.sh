#!/bin/sh

if [ -f Extern/libgit2/build/libgit2.a ]
then
	mv Extern/libgit2/build/libgit2.a ./
	rm -r Extern/libgit2/build/
fi
