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
  "alignof",
  "arc4random_push",
  "atomic_add_32",
  "chflags",
  "closesocket",
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
  "pthread_set_name_np", -- Variant spelling of pthread_setname_np.
  "recallocarray",
  "res_ndestroy",
  "sendfilev",
  "setproctitle",
  "srand_deterministic",
  "statacl",
  "static_assert",
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

-- makedev is detected correctly, but the declaring <sys/sysmacros.h>
-- header is not probed first.
register_package_exception("pwsafe", {"makedev"})
register_package_exception("tcpreplay", {"makedev"})

-- These curses functions are not actually implemented.
register_package_exception("perl-Curses", {"flusok", "getcap", "touchoverlap"})

-- Linux sendfile is correctly detected.  The error comes from a
-- FreeBSD-specific configure check.
register_package_exception("pure-ftpd", {"sendfile"})

-- The Fedora tor build does not use the system nacl package, so an
-- error occurs during configure probing.
register_package_exception("tor", {"crypto_scalarmult_curve25519"})

-- These are not actually implemented (the ENGINE_load_* functions are
-- not part of OpenSSL 3).  They are relevant to ruby for now.
register_package_exception("ruby", {
			      "ENGINE_load_4758cca",
			      "ENGINE_load_aep",
			      "ENGINE_load_atalla",
			      "ENGINE_load_capi",
			      "ENGINE_load_chil",
			      "ENGINE_load_cswift",
			      "ENGINE_load_gmp",
			      "ENGINE_load_gost",
			      "ENGINE_load_nuron",
			      "ENGINE_load_padlock",
			      "ENGINE_load_sureware",
			      "ENGINE_load_ubsec",
			      "freehostent",
			      "getipnodebyname",
			      "getpeerucred",
			      "t_open",
})

-- The autoconf-style logic probes incomplete header sets first, but
-- it eventually selects <sys/sysctl.h> and <unistd.h> as the headers
-- to include for these functions.
register_package_exception("pcb-rnd", {"ioctl", "gethostname"})

-- These functions are probed during the configure phase of the build.
-- _GNU_SOURCE is automatically activated as needed.  The resulting
-- config.h is the same.
register_package_exception("mandoc", {
			      "getprogname",
			      "strcasestr",
			      "strptime",
			      "vasprintf",
			      "wcwidth",
})

-- The configure script uses wcwidth to probe for _GNU_SOURCE support.
-- Note that an upstream patch (773f15d53348d417fe50d52cfe49f042df4a32ad)
-- is still need to fix the build, but even with this patch, the probing
-- tickles an implicit function declaration error.
register_package_exception("nmh", {"wcwidth"})

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
