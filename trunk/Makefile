# makefile for fuse library for Lua

# change these to reflect your Lua installation
LUAINC= /usr/include/lua5.1
LUALIB= $(LUA)/lib
LUABIN= $(LUA)/bin

MYNAME= fuse

# no need to change anything below here except if your gcc/glibc is not
# standard
CFLAGS= $(INCS) $(DEFS) $(WARN) -O2 $G -D_FILE_OFFSET_BITS=64 -D_REENTRANT -DFUSE_USE_VERSION=25 -DHAVE_SETXATTR
#CFLAGS= $(INCS) $(DEFS) $(WARN) -O2 $G -D_FILE_OFFSET_BITS=64 -D_REENTRANT -DFUSE_USE_VERSION=25 
WARN= #-ansi -pedantic -Wall
INCS= -I$(LUAINC) -I$(MD5INC)
LIBS= -lfuse -llua5.1

MYLIB= $(MYNAME)
T= $(MYLIB).so
OBJS= $(MYLIB).o
CC=gcc

all:	test

test:	$T

o:	$(MYLIB).o

so:	$T

$T:	$(OBJS) 
	$(CC) -o $@ -shared $(OBJS) $(LIBS)
	strip $@

clean:
	rm -f $(OBJS) $T a.out 

