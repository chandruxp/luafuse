#!/usr/bin/env lua
--[[
    Memory FS in FUSE using the lua binding
    Copyright 2007 (C) gary ng <linux@garyng.com>

    This program can be distributed under the terms of the GNU LGPL.
]]

local fuse = require 'fuse'

local tjoin = table.concat
local tadd = table.insert
local floor = math.floor
local format = string.format
local now = os.time
local difftime = os.difftime

local S_WID = 1 --world
local S_GID = 2^3 --group
local S_UID = 2^6 --owner
local S_SID = 2^9 --sticky bits etc.
local S_IFIFO = 1*2^12
local S_IFCHR = 2*2^12
local S_IFDIR = 4*2^12
local S_IFBLK = 6*2^12
local S_IFREG = 2^15
local S_IFLNK = S_IFREG + S_IFCHR
local ENOENT = -2
local mem_block_size = 4096 --this seems to be the optimal size for speed and memory
local blank_block=("0"):rep(mem_block_size)
local open_mode={'rb','wb','rb+'}


function string:splitpath() 
    local dir,file = self:match("(.-)([^:/\\]*)$") 
    return dir:match("(.-)[/\\]?$"), file
end

local function is_dir(mode)
    local o = ((mode - mode % S_IFDIR)/S_IFDIR) % 2
    return o ~= 0
end

local function clear_buffer(dirent,from,to)
    if type(dirent.content) == "table" then
        for i=from,to do dirent.content[i] = nil end
    end
    collectgarbage("collect")
end

local function mk_mode(owner, group, world, sticky)
    sticky = sticky or 0
    return owner * S_UID + group * S_GID + world + sticky * S_SID
end

local function dir_walk(root, path)
    if path == "/" then 
        local uid,gid,pid = fuse.context()
        root.meta.uid = uid
        root.meta.gid = gid
        return root 
    end
    local dirent = root
    local parent
    for c in path:gmatch("[^/]*") do
        if #c > 0 then
            parent = dirent
            local content = parent.content
            dirent = content[c]
        end
        if not dirent then return nil, parent end
    end
    return dirent,parent
end

local root=
{
 meta = {
        mode= mk_mode(7,5,5) + S_IFDIR, 
        ino = 0, 
        dev = 0, 
        nlink = 2, uid = uid, gid = gid, size = 0, atime = 0, mtime = 0, ctime = 0}
        ,
 content = {}
}

local memfs={

pulse=function()
    print "periodic pulse"
end,

getattr=function(self, path)
    local dirent = dir_walk(root, path)
    if not dirent then return ENOENT end
    local x = dirent.meta
    return 0, x.mode, x.ino, x.dev, x.nlink, x.uid, x.gid, x.size, x.atime, x.mtime, x.ctime    
end,

opendir = function(self, path)
    local dirent = dir_walk(root, path)
    if not dirent then return ENOENT end
    return 0, dirent
end,

readdir = function(self, path, offset, dirent)
    local out={'.','..'}
    for k,v in pairs(dirent.content) do 
        out[#out+1] = k

        --out[#out+1]={d_name=k, ino = v.meta.ino, d_type = v.meta.mode, offset = 0}
    end
    return 0, out
    --return 0, {{d_name="abc", ino = 1, d_type = S_IFREG + 7*S_UID, offset = 0}}
end,

releasedir = function(self, path, dirent)
    return 0
end,

mknod = function(self, path, mode, rdev)
    local dir, base = path:splitpath()
    local dirent,parent = dir_walk(root, path)
    local uid,gid,pid = fuse.context()
    local x = {
        mode = mode,
        ino = 0, 
        dev = rdev, 
        nlink = 1, uid = uid, gid = gid, size = 0, atime = now(), mtime = now(), ctime = now()}
    local o = { meta=x, content={}}
    if not dirent then
        local content = parent.content
        content[base]=o
        parent.meta.nlink = parent.meta.nlink + 1
        return 0,o
    end
end,

read=function(self, path, size, offset, obj)
    local block = floor(offset/mem_block_size)
    local o = offset%mem_block_size
    local data={}
    
    if o == 0 and size % mem_block_size == 0 then
        for i=block, block + floor(size/mem_block_size) - 1 do
            data[#data+1]=obj.content[i] or blank_block
        end
    else
        while size > 0 do
            local x = obj.content[block] or blank_block
            local b_size = mem_block_size - o 
            if b_size > size then b_size = size end
            data[#data+1]=x:sub(o+1, b_size)
            o = 0
            size = size - b_size
            block = block + 1
        end
    end

    return 0, tjoin(data,"")
end,

write=function(self, path, buf, offset, obj)
    local size = #buf
    local o = offset % mem_block_size
    local block = floor(offset / mem_block_size)
    if o == 0 and size % mem_block_size == 0 then
        local start = 0
        for i=block, block + floor(size/mem_block_size) - 1 do
            obj.content[i] = buf:sub(start + 1, start + mem_block_size)
            start = start + mem_block_size
        end
    else
        local start = 0
        while size > 0 do
            local x = obj.content[block] or blank_block
            local b_size = mem_block_size - o 
            if b_size > size then b_size = size end
            obj.content[block] = tjoin({x:sub(1, o), buf:sub(start+1, start + b_size), x:sub(o + 1 + b_size)},"")
            o = 0
            size = size - b_size
            block = block + 1
        end
    end
    local eof = offset + #buf
    if eof > obj.meta.size then obj.meta.size = eof end

    return #buf
end,

open=function(self, path, mode)
    local m = mode % 4
    local dirent = dir_walk(root, path)
    if not dirent then return ENOENT end
    return 0, dirent
end,

release=function(self, path, obj)
    if obj.bs then obj.bs:close() end
    return 0
end,

fgetattr=function(self, path, obj, ...)
    local x = obj.meta
    return 0, x.mode, x.ino, x.dev, x.nlink, x.uid, x.gid, x.size, x.atime, x.mtime, x.ctime    
end,

rmdir = function(self, path)
    local dir, base = path:splitpath()
    local dirent,parent = dir_walk(root, path)
    parent.content[base] = nil
    parent.meta.nlink = parent.meta.nlink - 1
    return 0
end,

mkdir = function(self, path, mode, ...)
    local dir, base = path:splitpath()
    local dirent,parent = dir_walk(root, path)
    local uid,gid,pid = fuse.context()
    local x = {
        --mode= S_IFDIR + 6*S_UID, 
        mode = mode+S_IFDIR,
        ino = 0, 
        dev = 0, 
        nlink = 2, uid = uid, gid = gid, size = 0, atime = now(), mtime = now(), ctime = now()}
    local o = { meta=x, content={} }
    if not dirent then
        local content = parent.content
        content[base]=o
        parent.meta.nlink = parent.meta.nlink + 1
    end
    return 0
end,

create = function(self, path, mode, flag, ...)
    local dir, base = path:splitpath()
    local dirent,parent = dir_walk(root, path)
    local uid,gid,pid = fuse.context()
    local x = {
        mode = mode,
        ino = 0, 
        dev = 0, 
        nlink = 1, uid = uid, gid = gid, size = 0, atime = now(), mtime = now(), ctime = now()}
    local o = { meta=x, content={}}
    if not dirent then
        local content = parent.content
        content[base]=o
        parent.meta.nlink = parent.meta.nlink + 1
        return 0,o
    end
end,

flush=function(self, path, obj)
    return 0
end,

readlink=function(self, path)
    local dirent,parent = dir_walk(root, path)
    if dirent then
        return 0, dirent.content
    end
    return ENOENT
end,

symlink=function(self, from, to)
    local dir, base = to:splitpath()
    local dirent,parent = dir_walk(root, to)
    local uid,gid,pid = fuse.context()
    local x = {
        mode= S_IFLNK+mk_mode(7,7,7),
        ino = 0, 
        dev = 0, 
        nlink = 1, uid = uid, gid = gid, size = 0, atime = 0, mtime = 0, ctime = 0}
    local o = { meta=x, content=from }
    if not dirent then
        local content = parent.content
        content[base]=o
        parent.meta.nlink = parent.meta.nlink + 1
        return 0
    end
end,

rename = function(self, from, to)
    local dir, o_base = from:splitpath()
    local dir, base = to:splitpath()
    local dirent,fp = dir_walk(root, from)
    local n_dirent,tp = dir_walk(root, to)
    if dirent and not n_dirent then
        tp.content[base]=dirent
        tp.meta.nlink = tp.meta.nlink + 1
        fp.content[o_base]=nil
        fp.meta.nlink = fp.meta.nlink - 1
        return 0
    end
end,

link=function(self, from, to, ...)
    local dir, base = to:splitpath()
    local dirent,fp = dir_walk(root, from)
    local n_dirent,tp = dir_walk(root, to)
    if dirent and not n_dirent then
        tp.content[base]=dirent
        tp.meta.nlink = tp.meta.nlink + 1
        dirent.meta.nlink = dirent.meta.nlink + 1
        return 0
    end
end,

unlink=function(self, path, ...)
    local dir, base = path:splitpath()
    local dirent,parent = dir_walk(root, path)
    local meta = dirent.meta
    local content = parent.content
    parent.content[base] = nil
    parent.meta.nlink = parent.meta.nlink - 1
    meta.nlink = meta.nlink - 1 - (is_dir(meta.mode) and 1 or 0)
    if meta.nlink == 0 then
        clear_buffer(dirent, 0, floor(dirent.meta.size/mem_block_size))
        dirent.content = nil
        dirent.meta = nil
    end
    return 0
end,

chown=function(self, path, uid, gid)
    local dirent,parent = dir_walk(root, path)
    if dirent then
        dirent.meta.uid = uid
        dirent.meta.gid = gid
    end
    return 0
end,
chmod=function(self, path, mode)
    local dirent,parent = dir_walk(root, path)
    if dirent then
        dirent.meta.mode = mode
    end
    return 0
end,
utime=function(self, path, atime, mtime)
    local dirent,parent = dir_walk(root, path)
    if dirent then
        dirent.meta.atime = atime
        dirent.meta.mtime = mtime
    end
    return 0
end,
ftruncate = function(self, path, size, obj)
    local old_size = obj.meta.size
    obj.meta.size = size
    clear_buffer(dirent, floor(size/mem_block_size), floor(old_size/mem_block_size))
    return 0
end,
truncate=function(self, path, size)
    local dirent,parent = dir_walk(root, path)
    if dirent then 
        local old_size = dirent.meta.size
        dirent.meta.size = size
        clear_buffer(dirent, floor(size/mem_block_size), floor(old_size/mem_block_size))
    end
    return 0
end,
access=function(...)
    return 0
end,
fsync = function(self, path, isdatasync, obj)
    return 0
end,
fsyncdir = function(self, path, isdatasync, obj)
    return 0
end,
listxattr = function(self, path, size)
    return 0, "attr1\0attr2\0attr3\0\0"
end,
removexattr = function(self, path, name)
    return 0
end,
setxattr = function(self, path, name, val)
    return 0
end,
getxattr = function(self, path, name)
    return 0, "attr"
end,

statfs = function(self,path)
    local dirent,parent = dir_walk(root, path)
    local o = {bs=1024,blocks=4096,bfree=1024,bavail=3072,bfiles=1024,bffree=1024}
    return 0, o.bs, o.blocks, o.bfree, o.bavail, o.bfiles, o.bffree
end
}

fuse_opt = { 'memfs', 'mnt', '-f', '-s', '-oallow_other'}

if select('#', ...) < 2 then
    print(string.format("Usage: %s <fsname> <mount point>", arg[0]))
    os.exit(1)
end

fuse.main(memfs, {...})
