Returns a list of modules that contain undocumented functions.

## Parameters

- entry_functions - a list of tuples containing module information and their respective function ASTs.
- file - the file name where the functions are being analyzed.

## Description
 Iterates over the entry functions and prints warnings for undocumented functions.