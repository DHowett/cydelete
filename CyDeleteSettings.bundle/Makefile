CC=/opt/iphone-sdk/bin/arm-apple-darwin9-g++

LDFLAGS=-lobjc -framework Foundation -framework UIKit -framework CoreFoundation -multiply_defined suppress \
	-Wall -Werror -lobjc -ObjC++ -fobjc-exceptions -bundle -fobjc-call-cxx-cdtors \
	-F/opt/iphone-sdk/sys/System/Library/PrivateFrameworks -framework Preferences

all: CyDeleteSettings

CyDeleteSettings: CyDeleteSettings.o
	$(CC) $(LDFLAGS) -o $@ $^
	CODESIGN_ALLOCATE=/opt/iphone-sdk/bin/arm-apple-darwin9-codesign_allocate ldid -S $@

%.o: %.mm
	$(CC) -c $(CFLAGS) $< -o $@

clean:
	rm -f *.o CyDeleteSettings
