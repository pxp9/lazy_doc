Returns the modified AST with the documentation for the specified module inserted.

## Parameters

- ast - the abstract syntax tree representing the original code.
- module_ast - the abstract syntax tree of the module where documentation is to be inserted.
- ast_doc - the documentation to be inserted into the module's AST.

## Description
Modifies the module's AST to include documentation by traversing the original AST.