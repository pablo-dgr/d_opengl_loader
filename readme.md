# D Opengl loader

A standalone program that parses the Opengl API XML and outputs type definitions and proc loading calls for the desired feature levels and extensions in D code.

**Disclaimer: this is just some hobby code, it has shortcuts and probably some bugs. Use at your own risk!**

**Disclaimer: the basic typedefs are hardcoded because parsing them from the XML is just too annoying to deal with. But this shouldn't pose a real problem since the Opengl API doesn't really change anymore.**

## Parameters

The generated output can be controlled by the parameters block at the start of the main function.

## Intergration into your code

The output is written to a single `output.d` file and contains the following major blocks of code:

- basic typedefs
- function typedefs
- function pointer declarations
- a loader function that loads and checks all included procs

The loader function expects a proc loader as argument.

Just copy-paste the code into your project, provide a proc loader and you're good to go!
