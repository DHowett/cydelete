Compiler=/opt/iphone-sdk/bin/arm-apple-darwin9-g++
IP=root@ipod

LDFLAGS=	-lobjc \
		-framework Foundation \
		-framework UIKit \
		-framework CoreFoundation \
		-multiply_defined suppress \
		-dynamiclib \
		-init _CyDeleteInitialize \
		-Wall \
		-Werror \
		-lsubstrate \
		-lobjc \
		-ObjC++ \
		-fobjc-exceptions \
		-fobjc-call-cxx-cdtors

CFLAGS= -dynamiclib

Objects= Hook.o

Target=CyDelete.dylib

all: CyDelete.dylib setuid

setuid:
		/opt/iphone-sdk/bin/arm-apple-darwin9-gcc -o setuid setuid.c
		CODESIGN_ALLOCATE=/opt/iphone-sdk/bin/arm-apple-darwin9-codesign_allocate ldid -S $@

$(Target):	$(Objects)
		$(Compiler) $(LDFLAGS) -o $@ $^
		CODESIGN_ALLOCATE=/opt/iphone-sdk/bin/arm-apple-darwin9-codesign_allocate ldid -S $@

install: $(Target) setuid
		scp cydelete-beta.deb $(IP):
		ssh $(IP) dpkg -i cydelete-beta.deb
		ssh $(IP) killall -HUP SpringBoard

%.o:	%.mm
		$(Compiler) -c $(CFLAGS) $< -o $@

clean:
		rm -f *.o $(Target) setuid

package: $(Target) setuid
	rm -rf _
	mkdir -p _/Library/MobileSubstrate/DynamicLibraries
	mkdir -p _/usr/libexec/cydelete
	cp $(Target) _/Library/MobileSubstrate/DynamicLibraries
	cp CyDelete.plist _/Library/MobileSubstrate/DynamicLibraries
	cp scripts/* _/usr/libexec/cydelete
	cp setuid _/usr/libexec/cydelete
	svn export ./DEBIAN _/DEBIAN
	chown 0.80 _ -R
	chmod 6755 _/usr/libexec/cydelete/setuid
	dpkg-deb -b _ cydelete_$(shell grep Version DEBIAN/control | cut -d' ' -f2).deb

