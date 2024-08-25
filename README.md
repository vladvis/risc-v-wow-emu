# RISC-V Linux userspace emulator for World of Warcraft

RiscVEmulator is a World of Warcraft addon library that provides a RISC-V emulator implementing the RV32IMFD instruction set. This project allows you to run RISC-V programs within the World of Warcraft environment.

## Building and running

As we emulate the Linux and the game runs on Windows and MacOS, Windows + WSL is the best development environment for the project.

[risc-v-gnu-toolchain](https://github.com/riscv-collab/riscv-gnu-toolchain) is required to build the tests.
```sh
git clone git@github.com:riscv-collab/riscv-gnu-toolchain.git
cdriscv-gnu-toolchain
./configure --prefix=/opt/toolchains/riscv32 --with-arch=rv32g --with-abi=ilp32d
make
```

python with jinja2 and elftools is required to convert elf binaries to lua code loadable in-game.
```sh
python3 -m pip install jinja2 pyelftools
```

See the **tests/Makefile** and **tests/testsuite.lua** for guidance on how to compile and run different examples.

See `deploy.bat` to install the engine into your game as an addon on a Windows PC. Samples selected in **tests/testsuite.lua** will run as soon as the addon is loaded. 

## Key Components

- **src/risc-v-core.lua**: Core RISC-V CPU implementation.
- **src/risc-v-memory.lua**: Memory management for the emulator.
- **src/risc-v-fpu.lua**: Floating-point unit operations.
- **src/risc-v-float-conversion.lua**: Conversion functions for floating-point and double-precision numbers.
- **src/frame.lua**: Frame rendering and input handling.
- **src/risc-v-syscall.lua**: System call implementations.

## Contributing

As the project was developed to provide an execution environment for the Doom Within project, main request for contribution lies in perfomance optimisation.

## Acknowledgments

- [RISC-666](https://github.com/lcq2/risc-666) for providing a reference on instruction implementation.
- [doomgeneric](https://github.com/ozkl/doomgeneric) for making the whole thing possible.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
