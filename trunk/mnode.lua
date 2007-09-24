module('mnode', package.seeall)

local nodes = {}
local blocks = setmetatable({},{__mode="v"})

function get(key)
    return nodes[key]
end

function set(key, v)
    nodes[key] = v
end

function get_block(key)
    return blocks[key]
end

function flush_node(node, path, final)
    return true
end

function flush_data(block, node, path, final)
    return true
end

local block_mt = {
    __index = function(o,k) 
        return rawget(o,'_data')[k]
    end,
    __newindex = function(o, k, v)
        local x = rawget(o,'_data')
        x[k] = v
    end,
    __call = function(o,t,i)
        return next(rawget(o, '_data'), i) 
    end
    }

local node_mt = {
    __index = function(o,k) 
        return rawget(o,'_data')[k]
    end,
    __newindex = function(o, k, v)
        local x = rawget(o,'_data')
        x[k] = v
    end,
    __call = function(o,t,i)
        return next(rawget(o, '_data'), i) 
    end
    }

function block(t)
    local key = function() end
    local n =  setmetatable({_key= key, _data=t or {}}, block_mt)
    blocks[key] = n
    return n
end

function node(t)
    local key = function() end
    local n =  setmetatable({_key= key, _data=t or {}}, node_mt)
    nodes[key] = n
    return n
end
