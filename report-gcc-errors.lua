-- Support script for Fedora C99 port.  Grab logged errors from
-- /usr/lib/gcc/errors and report them (with some post-processing).

-- List of functions which are permitted to be undeclared (because
-- we do not implement them at all).
local good = {
  "IoctlSocket",
  "MIN",
  "MessageBox",
  "NSLookupAndBindSymbol",
  "QueryPerformanceCounter",
  "QueryPerformanceFrequency",
  "SSLv2_client_method",
  "_NSGetEnviron",
  "__builtin_available",
  "_alloca",
  "_controlfp",
  "_controlfp_s",
  "_dup",
  "_fdopen",
  "_fileno",
  "_fpclass",
  "_isatty",
  "_logb",
  "_rtc",
  "_scprintf",
  "_snprintf",
  "_strdup",
  "_wstat64",
  "acl",
  "acl_get_perm_np",
  "arc4random_push",
  "atomic_add_32",
  "chflags",
  "directio",
  "fpclass",
  "fpsetmask",
  "fseeko64",
  "gethrtime",
  "getmntinfo",
  "htonll",
  "htonlll",
  "inconvlist",
  "ioctlsocket",
  "issetugid",
  "krb5_principal_get_realm",
  "lchflags",
  "libiconv_open",
  "mbschr",
  "mbsrchr",
  "msem_init",
  "msem_lock",
  "msem_unlock",
  "pathfind",
  "pledge",
  "posix_close",
  "recallocarray",
  "res_ndestroy",
  "sendfilev",
  "setproctitle",
  "srand_deterministic",
  "statacl",
  "strlcat",
  "strlcpy",
  "strtonum",
  "swapctl",
  "sysctl",
  "sysctlbyname",
}

local rpm_package_name = os.getenv("RPM_PACKAGE_NAME")
local function register_package_exception(pkg, exceptions)
  if pkg == rpm_package_name then
    table.move(exceptions, 1, #exceptions, #good + 1, good)
  end
end

-- The Linux backend does not use these LFS variants.
register_package_exception("zabbix", {"statfs64", "statvfs64"})

-- This is used for _LARGEFILE64_SOURCE probing.  The implicit declaration
-- does not alter the test result.  Common with TCL-related packages.
register_package_exception("expect", {"stat64"})
register_package_exception("itcl", {"stat64"})
register_package_exception("itk", {"stat64"})
register_package_exception("memchan", {"stat64"})
register_package_exception("environment-modules", {"stat64"})
register_package_exception("tcl", {"stat64"})
register_package_exception("tcl-mysqltcl", {"stat64"})
register_package_exception("tcl-pgtcl", {"stat64"})
register_package_exception("tcl-tcludp", {"stat64"})
register_package_exception("tcl-tclvfs", {"stat64"})
register_package_exception("tcl-tclxml", {"stat64"})
register_package_exception("tcl-thread", {"stat64"})
register_package_exception("tcl-tkpng", {"stat64"})
register_package_exception("tcl-tktreectrl", {"stat64"})
register_package_exception("tcl-togl", {"stat64"})
register_package_exception("tcl-trf", {"stat64"})
register_package_exception("tcl-zlib", {"stat64"})
register_package_exception("tclx", {"stat64"})
register_package_exception("tdom", {"stat64"})
register_package_exception("tix", {"stat64"})
register_package_exception("tkdnd", {"stat64"})
register_package_exception("tkimg", {"stat64"})
register_package_exception("tktray", {"stat64"})

-- Translate to associative array.
good = (function(list)
  local dict = {}
  for i=1, #list do
    dict[list[i]] = true
  end
  return dict
end)(good)

-- Compute full pathnames and order by modification time.
local logdir = "/usr/lib/gcc/errors"
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
