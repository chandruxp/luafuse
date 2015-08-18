This is a simple binding for lua to the linux FUSE file system. FUSE is in mainline linux 2.6.11+, for detail see http://fuse.sourceforge.net

## Build ##

download the source and make. You may need to change the Makefile for file locations of lua related thing.

It also needs the related FUSE files include files and libraries.

## Install ##

copy the resulting "fuse.so" to the proper lua C library(e.g. /usr/lib/lua/5.1) or depends on your own installation setup.

## Use ##

require 'fuse'

fuse.main(fs\_table, {fuse options})

fs\_table is a table implementing the various functions that would be called by FUSE. See the assoicated memfs.lua for detail. It is a function complete FS storing everything in memory.

## Performance ##

My not so scientific benchmark(dd if=/dev/zero) shows about a 50% deficiency comparing with a plain C implementation. File system performance comes more from the how(proper caching, buffering) than what language. FUSE is intended for unconventional file system where the raw read/write speed of the interface is order of magnitude faster the backend storage(such as gmailfs, sshfs). In this regard, Lua has the advantage of allowing quick testing out of new features which can be unmanageable in C.

The memfs.lua is written in one day. It is slow though because of the immutable string used in Lua as data buffer.

