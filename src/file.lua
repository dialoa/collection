local system = pandoc.system
local path = pandoc.path

-- ## File module
local file = {}

---Whether a file exists
---@param filepath string
---@return boolean
function file.exists(filepath)
    local f = io.open(filepath, 'r')
    if f ~= nil then
      io.close(f)
      return true
    else 
      return false
    end  
end


---read file as string (default) or binary.
---@param filepath string file path
---@param mode? 'b'|'t' 'b' for binary or 't' for text (default text)
---@return boolean success
---@return string? contents file contents if success
function file.read(filepath, mode)
    local mode = mode == 'b' and 'rb' or 'r'
    local contents
    local f = io.open(filepath, mode)
    if f then 
        contents = f:read('a')
        f:close()
        return true, contents
    else
        return false
    end
end

---Write string to file in text or binary mode.
---@param contents string file contents
---@param filepath string file path
---@param mode? 'b'|'t' 'b' for binary or 't' for text (default text)
---@return boolean success
function file.write(contents, filepath, mode)
    local mode = mode == 'b' and 'wb' or 'w'
    local f = io.open(filepath, mode)
      if f then 
        f:write(contents)
        f:close()
        return true
    else
      return false
    end
end

return file