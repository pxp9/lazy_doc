## Parameters

- ast - the abstract syntax tree to be transformed.
- module_ast - the specific module's abstract syntax tree that is being targeted for documentation.
- ast_doc - the documentation string to be inserted into the module.

## Description
Inserts documentation into the specified module's AST, either as a new block or by prepending it to an existing block.

## Returns
The modified abstract syntax tree with the documentation inserted into the desired module.