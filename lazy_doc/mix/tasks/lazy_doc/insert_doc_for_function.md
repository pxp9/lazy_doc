Returns the updated AST after inserting the documentation for the specified function.

## Parameters

- ast - the abstract syntax tree of the module.
- name_func - the name of the function for which documentation is being added.
- ast_doc - the documentation to be inserted into the function.
- module_ast - the abstract syntax tree representation of the module.

## Description
Traverses the AST and inserts documentation for the specified function within the specified module.