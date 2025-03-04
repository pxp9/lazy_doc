## Parameters

- patterns - a list of regular expressions used to filter file paths.
- @global_path - a global variable representing the directory path to search for files.

## Description
Extracts data from files in the specified paths by reading the file contents, parsing them into an abstract syntax tree (AST), and extracting module and function information.

## Returns
A list of maps, each containing details about the file, including its content, AST, extracted functions, documented functions, undocumented functions, modules, and any comments found.