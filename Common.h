#import <substrate.h>

#define HOOK(class, name, type, args...) \
	static type (*_ ## class ## $ ## name)(class *self, SEL sel, ## args); \
	static type $ ## class ## $ ## name(class *self, SEL sel, ## args)

#define CALL_ORIG(class, name, args...) \
	_ ## class ## $ ## name(self, sel, ## args)

