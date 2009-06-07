#import <substrate.h>

#define HOOK(class, name, type, args...) \
	static type (*_ ## class ## $ ## name)(class *self, SEL sel, ## args); \
	static type $ ## class ## $ ## name(class *self, SEL sel, ## args)

#define CALL_ORIG(class, name, args...) \
	_ ## class ## $ ## name(self, sel, ## args)

#define GET_CLASS(class) \
	Class $ ## class = objc_getClass(#class)

#define HOOK_MESSAGE(class, sel) \
	_ ## class ## $ ## sel = MSHookMessage($ ## class, @selector(sel), &$ ## class ## $ ## sel) 

#define HOOK_MESSAGE_ARGS(class, sel) \
	_ ## class ## $ ## sel ## $ = MSHookMessage($ ## class, @selector(sel:), &$ ## class ## $ ## sel ## $) 
