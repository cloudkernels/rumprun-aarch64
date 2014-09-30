THEBIN= rk.bin

# answer "yes" if you have built "userspace" (i.e. you've run buildme.sh)
RUMPRUN_PRESENT?= yes

# Has to be an i386 target compiler.  Don't care about much else.
# Easiest way for me to get an i386 target compiler was to let
# NetBSD's build.sh create it for me.  YMMV.
#TOOLDIR=/home/pooka/src/nbsrc/obj.i386/tooldir.Linux-3.13.0-32-generic-x86_64/bin
#AS= ${TOOLDIR}/i486-netbsdelf-as
#CC= ${TOOLDIR}/i486--netbsdelf-gcc
#STRIP= ${TOOLDIR}/i486--netbsdelf-strip

CFLAGS+=	-std=gnu99 -g -Wall -Werror
CPPFLAGS=	-Iinclude -I${RUMPKERNDIR}/include -nostdinc
STRIP?=		strip

MACHINE:= $(shell ${CC} -dumpmachine | sed 's/i.86/i386/;s/-.*//;')

# Check if we're building for a 32bit target.
# XXX: this is here only to help Travis CI.  The resulting binary will
# not run if you do not build it with a real toolchain
supported= false
ifeq (${MACHINE},i386)
supported:= true
endif
ifeq (${MACHINE},x86_64)
  supported:= true
  MACHINE:=i386
  CFLAGS=-m32
  LDFLAGS=-m32
endif
ifneq (${supported},true)
$(error only supported target is 32bit x86)
endif

# Naturally this has to be an installation compiled for $MACHINE
RUMPKERNDIR?=	/home/pooka/src/buildrump.sh/rump

all: ${THEBIN}

OBJS=		intr.o kernel.o undefs.o memalloc.o sched.o subr.o
OBJS+=		rumpuser.o rumpfiber.o rumppci.o

include arch/${MACHINE}/Makefile.inc

LIBS_VIO=	-lrumpdev_pci_virtio
LIBS_VIO_NET=	-lrumpdev_virtio_if_vioif
LIBS_VIO_LD=	-lrumpdev_disk -lrumpdev_virtio_ld
LIBS_PCI_NET=	-lrumpdev_pci_if_wm -lrumpdev_miiphy
LIBS_PCI=	-lrumpdev_pci
LIBS_NETINET=	-lrumpnet_config -lrumpnet_netinet -lrumpnet_net
LIBS_NETBPF=	-lrumpdev_bpf
LIBS_NETUNIX=	-lrumpnet_local

ALLLIBS=	${LIBS_VIO_NET}					\
		${LIBS_VIO_LD}					\
		${LIBS_VIO}					\
		${LIBS_PCI_NET}					\
		${LIBS_PCI}					\
		${LIBS_NETINET}					\
		${LIBS_NETBPF}					\
		-lrumpdev -lrumpvfs -lrumpnet -lrump

ifeq (${RUMPRUN_PRESENT},yes)
  OBJS+=	libc_errno.o libc_emul.o libc_malloc.o
  OBJS+=	app.o
  CPPFLAGS+=	-DBMK_APP
  LIBS_USER=	-lcrypto -lc
  CFLAGS+=	-Wmissing-prototypes
else
  COMPILER_RT=	librt/divdi3.o librt/udivmoddi4.o librt/udivsi3.o
  COMPILER_RT+=	librt/udivdi3.o librt/moddi3.o librt/umoddi3.o
endif

${THEBIN}: ${THEBIN}.gdb
	${STRIP} -g -o $@ $<

${THEBIN}.gdb: ${OBJS} ${COMPILER_RT} ${LDSCRIPT} Makefile
	${CC} -ffreestanding -nostdlib -o $@ -T ${LDSCRIPT} ${LDFLAGS} ${OBJS} -L${RUMPKERNDIR}/lib -Wl,--whole-archive ${ALLLIBS} -Wl,--no-whole-archive ${LIBS_USER} ${COMPILER_RT}

clean:
	rm -f ${OBJS} ${COMPILER_RT} ${THEBIN} ${THEBIN}.gdb
