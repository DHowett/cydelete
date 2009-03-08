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

all: QuikDel.dylib uninstall

uninstall:
		/opt/iphone-sdk/bin/arm-apple-darwin9-gcc -o uninstall uninstall.c
		CODESIGN_ALLOCATE=/opt/iphone-sdk/bin/arm-apple-darwin9-codesign_allocate ldid -S $@

$(Target):	$(Objects)
		$(Compiler) $(LDFLAGS) -o $@ $^
		CODESIGN_ALLOCATE=/opt/iphone-sdk/bin/arm-apple-darwin9-codesign_allocate ldid -S $@

install:
		scp $(Target) $(IP):/var/root
#		scp uninstall $(IP):
#		ssh $(IP) ldid -S uninstall
#		ssh $(IP) mv uninstall /usr/libexec/quikdel
#		ssh $(IP) chmod 6755 /usr/libexec/quikdel/uninstall
		ssh $(IP) chmod 755 $(Target) 
		ssh $(IP) ldid -S $(Target)
		ssh $(IP) mv $(Target) /Library/MobileSubstrate/DynamicLibraries
		ssh $(IP) killall SpringBoard


%.o:	%.mm
		$(Compiler) -c $(CFLAGS) $< -o $@

clean:
		rm -f *.o $(Target) uninstall

package: $(Target) uninstall
	rm -rf _
	mkdir -p _/Library/MobileSubstrate/DynamicLibraries
	mkdir -p _/usr/libexec/quikdel
	cp $(Target) _/Library/MobileSubstrate/DynamicLibraries
	cp scripts/* _/usr/libexec/quikdel
	cp uninstall _/usr/libexec/quikdel
	chmod 6755 _/usr/libexec/quikdel/uninstall
	svn export ./DEBIAN _/DEBIAN
	dpkg-deb -b _ quikdel-beta.deb

