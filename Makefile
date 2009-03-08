Compiler=/opt/iphone-sdk/bin/arm-apple-darwin9-g++
IP=root@ipod

LDFLAGS=	-lobjc \
		-framework Foundation \
		-framework UIKit \
		-framework CoreFoundation \
		-multiply_defined suppress \
		-dynamiclib \
		-init _QuikDelInitialize \
		-Wall \
		-Werror \
		-lsubstrate \
		-lobjc \
		-ObjC++ \
		-fobjc-exceptions \
		-fobjc-call-cxx-cdtors

CFLAGS= -dynamiclib

Objects= Hook.o

Target=QuikDel.dylib

all: QuikDel.dylib setuid

setuid:
		/opt/iphone-sdk/bin/arm-apple-darwin9-gcc -o setuid setuid.c
		CODESIGN_ALLOCATE=/opt/iphone-sdk/bin/arm-apple-darwin9-codesign_allocate ldid -S $@

$(Target):	$(Objects)
		$(Compiler) $(LDFLAGS) -o $@ $^
		CODESIGN_ALLOCATE=/opt/iphone-sdk/bin/arm-apple-darwin9-codesign_allocate ldid -S $@

install: $(Target) setuid
		scp quikdel-beta.deb $(IP):
		ssh $(IP) dpkg -i quikdel-beta.deb
		ssh $(IP) killall -HUP SpringBoard

%.o:	%.mm
		$(Compiler) -c $(CFLAGS) $< -o $@

clean:
		rm -f *.o $(Target) setuid

package: $(Target) setuid
	rm -rf _
	mkdir -p _/Library/MobileSubstrate/DynamicLibraries
	mkdir -p _/usr/libexec/quikdel
	cp $(Target) _/Library/MobileSubstrate/DynamicLibraries
	cp scripts/* _/usr/libexec/quikdel
	cp setuid _/usr/libexec/quikdel
	chmod 6755 _/usr/libexec/quikdel/setuid
	svn export ./DEBIAN _/DEBIAN
	dpkg-deb -b _ quikdel-beta.deb

