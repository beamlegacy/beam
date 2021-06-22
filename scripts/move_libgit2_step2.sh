#!/bin/sh

if [ -f libgit2.a ]
then
	mkdir Extern/libgit2/build/
	mv libgit2.a Extern/libgit2/build/
fi
