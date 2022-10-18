-- Support script for Fedora C99 port.  Grab logged errors from
-- /var/log/gcc-errors and report them (with some post-processing).

-- List of functions which are permitted to be undeclared (because
-- we do not implement them at all).
local good = {
  "fpsetmask",
}

-- Translate to associative array.
good = (function(list)
  local dict = {}
  for i=1, #list do
    dict[list[i]] = true
  end
  return dict
end)(good)

-- Compute full pathnames and order by modification time.
local logdir = "/var/log/gcc-errors"
files = {}
for fname in assert(posix.files(logdir)) do
  if string.match(fname, "^gcc") then
    local fullpath = logdir .. "/" .. fname
    local mtime = assert(posix.stat(fullpath)).mtime
    files[#files + 1] = {fullpath, mtime}
  end
end
table.sort(files, function(left, right) return left[2] < right[2] end)

-- Report errors.  Filter out known-good implicit declarations.
local problem = false
for i = 1,#files do
  local p = files[i][1]
  for line in io.lines(p) do
    local match = string.match(line, "implicit function declaration: (%g+)$")
    if (not match) or not (good[match]) then
      if not problem then
          print("*** GCC errors begin ***\n")
        end
      problem = true
      print(line .. "\n")
    end
  end
end
if problem then
  print("*** GCC errors end ***\n")
end
