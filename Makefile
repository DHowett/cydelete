CC=/opt/iphone-sdk/bin/arm-apple-darwin9-g++
IP=root@ipod

BUNDLEDIR=/Library/MobileSubstrate/DynamicLibraries
BUNDLENAME=CyDelete.bundle
VERSION=$(shell grep Version layout/DEBIAN/control | cut -d' ' -f2)

LDFLAGS=-lobjc -framework Foundation -framework UIKit -framework CoreFoundation \
	-multiply_defined suppress -dynamiclib -init _CyDeleteInitialize -Wall \
	-Werror -lsubstrate -lobjc -ObjC++ -fobjc-exceptions -fobjc-call-cxx-cdtors #-ggdb

CFLAGS=-dynamiclib -DBUNDLE="@\"$(BUNDLEDIR)/$(BUNDLENAME)\"" -DVERSION="$(VERSION)"#-ggdb

OFILES=Hook.o

TARGET=CyDelete.dylib

all: $(TARGET) setuid
	@(cd CyDeleteSettings.bundle; $(MAKE) $(MFLAGS) all)

setuid:
	/opt/iphone-sdk/bin/arm-apple-darwin9-gcc -o setuid setuid.c
	CODESIGN_ALLOCATE=/opt/iphone-sdk/bin/arm-apple-darwin9-codesign_allocate ldid -S $@

$(TARGET): $(OFILES)
	$(CC) $(LDFLAGS) -o $@ $^
	CODESIGN_ALLOCATE=/opt/iphone-sdk/bin/arm-apple-darwin9-codesign_allocate ldid -S $@

install: $(TARGET) setuid
	scp cydelete_$(VERSION).deb $(IP):
	ssh $(IP) dpkg -i cydelete_$(VERSION).deb
	ssh $(IP) killall -HUP SpringBoard

%.o: %.mm
	$(CC) -c $(CFLAGS) $< -o $@

clean:
	rm -f *.o $(TARGET) setuid
	@(cd CyDeleteSettings.bundle; $(MAKE) $(MFLAGS) clean)

package: $(TARGET) setuid
	rm -rf _
	svn export layout _
	cp $(TARGET) _/Library/MobileSubstrate/DynamicLibraries
	cp CyDeleteSettings.bundle/CyDeleteSettings _/System/Library/PreferenceBundles/CyDeleteSettings.bundle/
	cp setuid _/usr/libexec/cydelete
	rm _$(BUNDLEDIR)/$(BUNDLENAME)/convert.sh
	chown 0.80 _ -R
	chmod 6755 _/usr/libexec/cydelete/setuid
	dpkg-deb -b _ cydelete_$(VERSION).deb

