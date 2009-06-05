CC=/opt/iphone-sdk/bin/arm-apple-darwin9-g++

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

include DebMakefile

setuid:
	/opt/iphone-sdk/bin/arm-apple-darwin9-gcc -o setuid setuid.c
	/opt/iphone-sdk/bin/arm-apple-darwin9-strip -x setuid
	CODESIGN_ALLOCATE=/opt/iphone-sdk/bin/arm-apple-darwin9-codesign_allocate ldid -S $@

$(TARGET): $(OFILES)
	$(CC) $(LDFLAGS) -o $@ $^
	/opt/iphone-sdk/bin/arm-apple-darwin9-strip -x $@
	CODESIGN_ALLOCATE=/opt/iphone-sdk/bin/arm-apple-darwin9-codesign_allocate ldid -S $@

%.o: %.mm
	$(CC) -c $(CFLAGS) $< -o $@

clean:
	rm -f *.o $(TARGET) setuid
	@(cd CyDeleteSettings.bundle; $(MAKE) $(MFLAGS) clean)

package-local:
	cp $(TARGET) _/Library/MobileSubstrate/DynamicLibraries
	cp CyDeleteSettings.bundle/CyDeleteSettings _/System/Library/PreferenceBundles/CyDeleteSettings.bundle/
	cp setuid _/usr/libexec/cydelete
	rm _$(BUNDLEDIR)/$(BUNDLENAME)/convert.sh
	sed -i "s/VERSION/$(VERSION)/g" _/System/Library/PreferenceBundles/CyDeleteSettings.bundle/Info.plist
	sed -i "s/VERSION/$(VERSION)/g" _/Library/MobileSubstrate/DynamicLibraries/CyDelete.bundle/Info.plist
	chown 0.80 _ -R
	chmod 6755 _/usr/libexec/cydelete/setuid

