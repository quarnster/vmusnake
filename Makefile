.SUFFIXES: .vms .s
.s.vms:
	aslc86k $<

all: snake.vms

