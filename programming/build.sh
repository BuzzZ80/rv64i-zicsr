riscv64-elf-gcc -O3 -mbranch-cost=1 -misa-spec="2.2" -march="rv64i" -mabi=lp64 -nostdlib -S main.c tools.c
riscv64-elf-gcc -O3 -mbranch-cost=1 -misa-spec="2.2" -march="rv64i" -mabi=lp64 -nostdlib -c main.c tools.c
riscv64-elf-as -misa-spec="2.2" -march="rv64i" -mabi=lp64 -o start.o start.s
riscv64-elf-ld -Map map.map -T simple.ld start.o main.o tools.o
riscv64-elf-objcopy -O binary a.out rom
