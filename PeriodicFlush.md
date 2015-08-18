# Buffering writes for performance gain #

One of the key performance bottleneck of any file system is how to properly buffer writes(typical in the range of 1K-4K) so instead of actually flush on every write call(to whatever backend with high latency and expensive to run, e.g. gmailfs), they better be buffered in chunk.

This however create the risk of data loss. For other language with muitl-thread support(like python), a seperate thread can be started which can wait for a period then flush. Lua however doesn't have this. There are multi-thread modules but here is a solution without any of them, using the standard alarm() linux call.


# How to do it in a safe way with fuse.alarm #

The binding comes with a function fuse.alarm(seconds) allowing an alarm signal be set. The alarm call would call yourfs.pulse(<yourfs object>) after 

&lt;seconds&gt;

. So just implement the flush or other things there. It is not periodic even though it is named "pulse". call alarm again if more is needed.

It is written inside the binding instead of a seperate modules(there is one lalarm) because I need to make sure no active FUSE call is running, thus using the same "BIG VM lock" in the binding. That means it is safe to assume the VM is in proper state when pulse() is called, i.e. not in between a read/write call for example.

