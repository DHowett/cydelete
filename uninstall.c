int main(int argc, char **argv) {
	setuid(0);
	setgid(0);
	execve("/usr/libexec/quikdel/uninstall_.sh", argv, 0);
	return 0;
}
