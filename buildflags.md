This document contains documentation of the individual compiler flags
and how to use them.

[TOC]

# Using RPM build flags

For packages which use autoconf to set up the build environment, use
the `%configure` macro to obtain the full complement of flags, like
this:

    %configure

This will invoke the `./configure` with arguments (such as
`--prefix=/usr`) to adjust the paths to the packaging defaults.

As a side effect, this will set the environment variables `CFLAGS`,
`CXXFLAGS`, `FFLAGS`, `FCFLAGS`, and `LDFLAGS`, so they can be used by
makefiles and other build tools.  (However, existing values for this
variables are not overwritten.)

If your package does not use autoconf, you can still set the same
environment variables using

    %set_build_flags

early in the `%build` section.  (Again, existing environment variables
are not overwritten.)

Individual build flags are also available through RPM macros:

* `%{build_cflags}` for the C compiler flags (also known as the
  `CFLAGS` variable).  Also historically available as `%{optflags}`.
  Furthermore, at the start of the `%build` section, the environment
  variable `RPM_OPT_FLAGS` is set to this value.
* `%{build_cxxflags}` for the C++ compiler flags (usually assigned to
  the `CXXFLAGS` shell variable).
* `%{build_fflags} for `FFLAGS` (the Fortran compiler flags, also
  known as the `FCFLAGS` variable).
* `%{build_ldflags}` for the link editor (ld) flags, usually known as
  `LDFLAGS`.  Note that the contents quotes linker arguments using
  `-Wl`, so this variable is intended for use with the `gcc` compiler
  driver.  At the start of the `%build` section, the environment
  variable `RPM_LD_FLAGS` is set to this value.

These RPM macros do not alter shell environment variables.

For some other build tools separate mechanisms exist:

* CMake builds use the the `%cmake` macro from the `cmake-rpm-macros`
  package.

Care must be taking not to compile the current selection of compiler
flags into any RPM package besides `redhat-rpm-config`, so that flag
changes are picked up automatically once `redhat-rpm-config` is
updated.

# Flag selection for the build type

The default flags are suitable for building applications.

For building shared objects, you must compile with `-fPIC` in
(`CFLAGS` or `CXXFLAGS`) and link with `-shared` (in `LDFLAGS`).

For other considerations involving shared objects, see:

* [Fedora Packaging Guidelines: Shared Libraries](https://fedoraproject.org/wiki/Packaging:Guidelines#Shared_Libraries)

# Customizing compiler flags

It is possible to set RPM macros to change some aspects of the
compiler flags.  Changing these flags should be used as a last
recourse if other workarunds are not available.

### Lazy binding

If your package depends on the semantics of lazy binding (e.g., it has
plugins which load additional plugins to complete their dependencies,
before which some referenced functions are undefined), you should put
`-Wl,-z,lazy` at the end of the `LDFLAGS` setting when linking objects
which have such requirements.  Under these circumstances, it is
unnecessary to disable hardened builds (and thus lose full ASLR for
executables), or link everything without `-Wl,z,now` (non-lazy
binding).

### Hardened builds

By default, the build flags enable fully hardened builds.  To change
this, include this in the RPM spec file:

    %undefine _hardened_build

This turns off certain hardening features, as described in detail
below.  The main difference is that executables will be
position-dependent (no full ASLR) and use lazy binding.

### Annotated builds/watermarking

By default, the build flags cause a special output section to be
included in ELF files which describes certain aspects of the build.
To change this for all compiler invocations, include this in the RPM
spec file:

    %undefine _annotated_build

Be warned that this turns off watermarking, making it impossible to do
full hardening coverage analysis for any binaries produced.

It is possible to disable annotations for individual compiler
invocations, using the `-fplugin-arg-annobin-disable` flag.  However,
the annobin plugin must still be loaded for this flag to be
recognized, so it has to come after the hardening flags on the command
line (it has to be added at the end of `CFLAGS`, or specified after
the `CFLAGS` variable contents).

### Strict symbol checks in the link editor (ld)

Optionally, the link editor will refuse to link shared objects which
contain undefined symbols.  Such symbols lack symbol versioning
information and can be bound to the wrong (compatibility) symbol
version at run time, and not the actual (default) symbol version which
would have been used if the symbol definition had been available at
static link time.  Furthermore, at run time, the dynamic linker will
not have complete dependency information (in the form of DT_NEEDED
entries), which can lead to errors (crashes) if IFUNC resolvers are
executed before the shared object containing them is fully relocated.

To switch on these checks, define this macro in the RPM spec file:

    %define _strict_symbol_defs_build 1

If this RPM spec option is active, link failures will occur if the
linker command line does not list all shared objects which are needed.
In this case, you need to add the missing DSOs (with linker arguments
such as `-lm`).  As a result, the link editor will also generated the
necessary DT_NEEDED entries.

In some cases (such as when a DSO is loaded as a plugin and is
expected to bind to symbols in the main executable), undefined symbols
are expected.  In this case, you can add

    %undefine _strict_symbol_defs_build

to the RPM spec file to disable these strict checks.  Alternatively,
you can pass `-z undefs` to ld (written as `-Wl,-z,undefs` on the gcc
command line).  The latter needs binutils 2.29.1-12.fc28 or later.

# Individual compiler flags

Compiler flags end up in the environment variables `CFLAGS`,
`CXXFLAGS`, `FFLAGS`, and `FCFLAGS`.

The general (architecture-independent) build flags are:

* `-O2`: Turn on various GCC optimizations.  See the [GCC manual](https://gcc.gnu.org/onlinedocs/gcc/Optimize-Options.html#index-O2).
  Optimization improves performance, the accuracy of warnings, and the
  reach of toolchain-based hardening, but it makes debugging harder.
* `-g`: Generate debugging information (DWARF).  In Fedora, this data
  is separated into `-debuginfo` RPM packages whose installation is
  optional, so debuging information does not increase the size of
  installed binaries by default.
* `-pipe`: Run compiler and assembler in parallel and do not use a
  temporary file for the assembler input.  This can improve
  compilation performance.  (This does not affect code generation.)
* `-Wall`: Turn on various GCC warnings.
  See the [GCC manual](https://gcc.gnu.org/onlinedocs/gcc/Warning-Options.html#index-Wall).
* `-Werror=format-security`: Turn on format string warnings and treat
  them as errors.
  See the [GCC manual](https://gcc.gnu.org/onlinedocs/gcc/Warning-Options.html#index-Wformat-security).
  This can occasionally result in compilation errors.  In this case,
  the best option is to rewrite the source code so that only constant
  format strings (string literals) are used.
* `-Wp,-D_FORTIFY_SOURCE=2`: Source fortification activates various
  hardening features in glibc:
    * String functions such as `memcpy` attempt to detect buffer lengths
      and terminate the process if a buffer overflow is detected.
    * `printf` format strings may only contain the `%n` format specifier
      if the format string resides in read-only memory.
    * `open` and `openat` flags are checked for consistency with the
      presence of a *mode* argument.
    * Plus other minor hardening changes.
  (These changes can occasionally break valid programs.)
* `-fexceptions`: Provide exception unwinding support for C programs.
  See the [`-fexceptions` option in the GCC
  manual](https://gcc.gnu.org/onlinedocs/gcc/Code-Gen-Options.html#index-fexceptions)
  and the [`cleanup` variable
  attribute](https://gcc.gnu.org/onlinedocs/gcc/Common-Variable-Attributes.html#index-cleanup-variable-attribute).
  This also hardens cancellation handling in C programs because
  it is not required to use an on-stack jump buffer to install
  a cancellation handler with `pthread_cleanup_push`.  It also makes
  it possible to unwind the stack (using C++ `throw` or Rust panics)
  from C callback functions if a C library supports non-local exits
  from them (e.g., via `longjmp`).
* `-Wp,-D_GLIBCXX_ASSERTIONS`: Enable lightweight assertions in the
  C++ standard library, such as bounds checking for the subscription
  operator on vectors.  (This flag is added to both `CFLAGS` and
  `CXXFLAGS`; C compilations will simply ignore it.)
* `-fstack-protector-strong`: Instrument functions to detect
  stack-based buffer overflows before jumping to the return address on
  the stack.  The *strong* variant only performs the instrumentation
  for functions whose stack frame contains addressable local
  variables.  (If the address of a variable is never taken, it is not
  possible that a buffer overflow is caused by incorrect pointer
  arithmetic involving a pointer to that variable.)
* `-grecord-gcc-switches`: Include select GCC command line switches in
  the DWARF debugging information.  This is useful for detecting the
  presence of certain build flags and general hardening coverage.

For hardened builds (which are enabled by default, see above for how
to disable them), the flag
`-specs=/usr/lib/rpm/redhat/redhat-hardened-cc1` is added to the
command line.  It adds the following flag to the command line:

*   `-fPIE`: Compile for a position-independent executable (PIE),
    enabling full address space layout randomization (ASLR).  This is
    similar to `-fPIC`, but avoids run-time indirections on certain
    architectures, resulting in improved performance and slightly
    smaller executables.  However, compared to position-dependent code
    (the default generated by GCC), there is still a measurable
    performance impact.

    If the command line also contains `-r` (producing a relocatable
    object file), `-fpic` or `-fPIC`, this flag is automatically
    dropped.  (`-fPIE` can only be used for code which is linked into
    the main program.) Code which goes into static libraries should be
    compiled with `-fPIE`, except when this code is expected to be
    linked into DSOs, when `-fPIC` must be used.

    To be effective, `-fPIE` must be used with the `-pie` linker flag
    when producing an executable, see below.

To support [binary watermarks for ELF
objects](https://fedoraproject.org/wiki/Toolchain/Watermark) using
annobin, the `-specs=/usr/lib/rpm/redhat/redhat-annobin-cc1` flag is
added by default.  This can be switched off by undefining the
`%_annotated_build` RPM macro (see above).

### Architecture-specific compiler flags

These compiler flags are enabled for all builds (hardened/annotated or
not), but their selection depends on the architecture:

*   `-fstack-clash-protection`: Turn on instrumentation to avoid
    skipping the guard page in large stack frames.  (Without this flag,
    vulnerabilities can result where the stack overlaps with the heap,
    or thread stacks spill into other regions of memory.)  This flag is
    fully ABI-compatible and has adds very little run-time overhead, but
    is only available on certain architectures (currently aarch64, i386,
    ppc64, ppc64le, s390x, x86_64).
*   `-fcf-protection`: Instrument binaries to guard against
    ROP/JOP attacks.  Used on i686 and x86_64.
*   `-m64` and `-m32`: Some GCC builds support both 32-bit and 64-bit in
    the same compilation.  For such architectures, the RPM build process
    explicitly selects the architecture variant by passing this compiler
    flag.
*   `-fasynchronous-unwind-tables`: Generate full unwind information
    covering all program points.  This is required for support of
    asynchronous cancellation and proper unwinding from signal
    handlers.  It also makes performance and debugging tools more
    useful because unwind information is available without having to
    install (and load) debugging ienformation.
    Asynchronous unwind tables are enabled for aarch64, i686, s390x,
    and x86_64.  They are not needed on armhfp, ppc64 and ppc64le due
    to architectural differences in stack management.  On these
    architectures, `-fexceptions` (see above) still enables regular
    unwind tables (or they are enabled by default even without this
    option).
*   `-funwind-tables`: A subset of the unwind information restricted
    to actual call sites.  Used on ppc64, ppc64le.  Also implied by
    `-fexceptions`.

In addition, `redhat-rpm-config` re-selects the built-in default
tuning in the `gcc` package.  These settings are:

*   **armhfp**: `-march=armv7-a -mfpu=vfpv3-d16  -mfloat-abi=hard`
    selects an Arm subarchitecture based on the ARMv7-A architecture
    with 16 64-bit floating point registers.  `-mtune=cortex-8a` selects
    tuning for the Cortex-A8 implementation (while preserving compatibility
    with other ARMv7-A implementations).  `-mabi=aapcs-linux` switches to
    the AAPCS ABI for GNU/Linux.
*   **i686**: `-march=i686` is used to select a minmum support CPU level
    of i686 (corresponding to the Pentium Pro).  `-mtune=generic` activates
    tuning for a current blend of CPUs (under the assumption that most
    users of i686 packages obtain them through an x86_64 installation
    on current hardware).
*   **ppc64le**: `-mcpu=power8 -mtune=power8` selects a minimum supported
    CPU level of POWER8 (the first CPU with ppc64le support) and tunes
    for POWER8.
*   **s390x**: `-march=zEC12 -mtune=z13` specifies a minimum supported CPU
    level of zEC12, while optimizing for a subsequent CPU generation
    (z13).
*   **x86_64**: `-mtune=generic` selects tuning which is expected to
     beneficial for a broad range of current CPUs.
*   **ppc64** and **aarch64** do not have any architecture-specific tuning.

# Individual linker flags

Linker flags end up in the environment variable `LDFLAGS`.

The linker flags listed below are injected.  Note that they are
prefixed with `-Wl` because it is expected that these flags are passed
to the compiler driver `gcc`, and not directly to the link editor
`ld`.

* `-z relro`: Activate the *read-only after relocation* feature.
  Constant data and relocations are placed on separate pages, and the
  dynamic linker is instructed to revoke write permissions after
  dynamic linking.  Full protection of relocation data requires the
  `-z now` flag (see below).
* `-z defs`: Refuse to link shared objects (DSOs) with undefined symbols
  (optional, see above).

For hardened builds, the
`-specs=/usr/lib/rpm/redhat/redhat-hardened-ld` flag is added to the
compiler driver command line.  (This can be disabled by undefining the
`%_hardened_build` macro; see above) This activates the following
linker flags:

* `-pie`: Produce a PIE binary.  This is only activated for the main
  executable, and only if it is dynamically linked.  This requires
  that all objects which are linked in the main executable have been
  compiled with `-fPIE` or `-fPIC` (or `-fpie` or `-fpic`; see above).
  By itself, `-pie` has only a slight performance impact because it
  disables some link editor optimization, however the `-fPIE` compiler
  flag has some overhead.
* `-z now`: Disable lazy binding and turn on the `BIND_NOW` dynamic
  linker feature.  Lazy binding involves an array of function pointers
  which is writable at run time (which could be overwritten as part of
  security exploits, redirecting execution).  Therefore, it is
  preferable to turn of lazy binding, although it increases startup
  time.
