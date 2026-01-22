.extern stack
.extern main

.global _start
_start:
  la sp, stack
  j main

