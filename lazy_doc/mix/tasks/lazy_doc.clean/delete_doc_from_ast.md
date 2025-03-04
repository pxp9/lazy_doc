Returns the updated AST after removing the specified function definition from the given module.

## Parameters

- ast - the original abstract syntax tree (AST) of the module.
- module_ast - the AST representation of the target module.
- name_func - the name of the function to be deleted from the AST.

## Description
Traverses the AST to locate and remove a specified function definition from a given module's AST.