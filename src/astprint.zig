const std = @import("std");
const ast = @import("ast.zig");
const printImpl = std.debug.print;

pub fn print(root: *const ast.Root) void {
    var p = Printer{};
    p.printRoot(root);
}

const Printer = struct {
    depth: u32 = 0,

    pub fn printRoot(self: *Printer, root: *const ast.Root) void {
        self.pad();
        printImpl("RootNode\n", .{});
        self.depth += 1;
        self.pad();
        printImpl("Functions:\n", .{});

        var it = root.fn_table.iterator();
        while (it.next()) |fn_node| {
            const fn_decl = fn_node.value_ptr;
            self.printFnDeclaration(fn_decl);
        }
        self.pad();
        printImpl("Statements:\n", .{});
        for (root.statements) |*stmnt| {
            self.printStatement(stmnt);
        }
        self.depth -= 1;
    }

    pub fn printBareword(self: *Printer, node: *const ast.Bareword) void {
        self.pad();
        printImpl("BarewordNode: {s}\n", .{node.token.value});
    }

    pub fn printIdentifier(self: *Printer, node: *const ast.Identifier) void {
        self.pad();
        printImpl("IdentifierNode: {s}\n", .{node.token.value});
    }

    pub fn printStringLiteral(self: *Printer, node: *const ast.StringLiteral) void {
        self.pad();
        printImpl("StringLiteralNode: {s}\n", .{node.token.value});
    }

    pub fn printBoolLiteral(self: *Printer, node: *const ast.BoolLiteral) void {
        self.pad();
        printImpl("BoolLiteralNode: {}\n", .{node.value});
    }

    pub fn printIntegerLiteral(self: *Printer, node: *const ast.IntegerLiteral) void {
        self.pad();
        printImpl("IntegerLiteralNode: {}\n", .{node.value});
    }

    pub fn printArrayLiteral(self: *Printer, node: *const ast.ArrayLiteral) void {
        self.pad();
        printImpl("ArrayLiteralNode:\n", .{});
        self.depth += 1;
        for (node.values) |*value| {
            self.printExpr(value);
        }
        self.depth -= 1;
    }

    pub fn printStructLiteral(self: *Printer, node: *const ast.StructLiteral) void {
        self.pad();
        printImpl("StructLiteralNode:\n", .{});
        self.depth += 1;
        for (node.names) |name, idx| {
            self.pad();
            const value = node.values[idx];
            printImpl("Key: {s}\n", .{name});
            self.pad();
            printImpl("Value:\n", .{});
            self.depth += 1;
            self.printExpr(value);
            self.depth -= 1;
        }
        self.depth -= 1;
    }

    pub fn printVarDeclaration(self: *Printer, node: *const ast.VarDeclaration) void {
        self.pad();
        printImpl("VarDeclarationNode: {s}\n", .{node.decl});
        if (node.expr) |*expr| {
            self.depth += 1;
            self.printExpr(expr);
            self.depth -= 1;
        }
    }

    pub fn printFnDeclaration(self: *Printer, node: *const ast.FnDeclaration) void {
        self.pad();
        printImpl("FnDeclarationNode: {s}\n", .{node.token.value});
        self.depth += 1;
        self.pad();
        printImpl("Args:\n", .{});
        self.depth += 1;
        for (node.args) |*arg| {
            self.pad();
            printImpl("{s}\n", .{arg.value});
        }
        self.depth -= 1;
        self.printScope(&node.scope);
        self.depth -= 1;
    }

    pub fn printReturn(self: *Printer, node: *const ast.Return) void {
        self.pad();
        printImpl("ReturnNode:\n", .{});
        self.depth += 1;
        if (node.expr) |expr| {
            self.printExpr(expr);
        }
        self.depth -= 1;
    }

    pub fn printVariable(self: *Printer, node: *const ast.Variable) void {
        self.pad();
        printImpl("VariableNode: {s}\n", .{node.name});
    }

    pub fn printScope(self: *Printer, node: *const ast.Scope) void {
        self.pad();
        printImpl("ScopeNode:\n", .{});
        self.depth += 1;
        for (node.statements) |*stmnt| {
            self.printStatement(stmnt);
        }
        self.depth -= 1;
    }

    pub fn printBranch(self: *Printer, node: *const ast.Branch) void {
        self.pad();
        printImpl("BranchNode:\n", .{});
        self.depth += 1;
        if (node.condition) |*condition| {
            self.printExpr(condition);
        } else {
            self.pad();
            printImpl("no condition\n", .{});
        }
        self.depth += 1;
        self.printScope(&node.scope);
        self.depth -= 2;

        if (node.next) |next| {
            self.pad();
            printImpl("branch chain\n", .{});
            self.printBranch(next);
        }
    }

    pub fn printLoop(self: *Printer, node: *const ast.Loop) void {
        switch (node.*) {
            .while_loop => |*while_loop| {
                self.printWhileLoop(while_loop);
            },
            .for_in_loop => |*for_in_loop| {
                self.printForInLoop(for_in_loop);
            },
        }
    }

    pub fn printWhileLoop(self: *Printer, node: *const ast.Loop.WhileLoop) void {
        self.pad();
        printImpl("WhileLoopNode:\n", .{});
        self.depth += 1;
        self.printExpr(&node.condition);
        self.depth += 1;
        self.printScope(&node.scope);
        self.depth -= 2;
    }

    pub fn printForInLoop(self: *Printer, node: *const ast.Loop.ForInLoop) void {
        self.pad();
        printImpl("ForInLoopNode:\n", .{});
        self.depth += 1;
        self.printIdentifier(&node.iterator);
        self.printExpr(&node.iterable);
        self.depth += 1;
        self.printScope(&node.scope);
        self.depth -= 2;
    }

    pub fn printAssignment(self: *Printer, node: *const ast.Assignment) void {
        self.pad();
        printImpl("AssignmentNode:\n", .{});
        self.depth += 1;
        self.printVariable(&node.variable);
        self.printExpr(&node.expr);
        self.depth -= 1;
    }

    pub fn printBinaryOperator(self: *Printer, node: *const ast.BinaryOperator) void {
        self.pad();
        printImpl("BinaryOperatorNode: {s}\n", .{node.token.value});
        self.depth += 1;
        self.printExpr(node.lhs.?);
        self.printExpr(node.rhs.?);
        self.depth -= 1;
    }

    pub fn printUnaryOperator(self: *Printer, node: *const ast.UnaryOperator) void {
        self.pad();
        printImpl("UnaryOperatorNode: {s}\n", .{node.token.value});
        self.depth += 1;
        self.printExpr(node.expr);
        self.depth -= 1;
    }

    pub fn printFunctionCall(self: *Printer, node: *const ast.FunctionCall) void {
        self.pad();
        printImpl("FunctionCallNode: {s}\n", .{node.token.value});
        self.depth += 1;
        for (node.args) |*arg| {
            self.printExpr(arg);
        }
        self.depth -= 1;
    }

    pub fn printExpr(self: *Printer, node: *const ast.Expr) void {
        switch (node.*) {
            .bareword => |*bareword| {
                self.printBareword(bareword);
            },
            .identifier => |*identifier| {
                self.printIdentifier(identifier);
            },
            .string_literal => |*string_literal| {
                self.printStringLiteral(string_literal);
            },
            .boolean_literal => |*boolean_literal| {
                self.printBoolLiteral(boolean_literal);
            },
            .integer_literal => |*integer_literal| {
                self.printIntegerLiteral(integer_literal);
            },
            .array_literal => |*array_literal| {
                self.printArrayLiteral(array_literal);
            },
            .struct_literal => |*struct_literal| {
                self.printStructLiteral(struct_literal);
            },
            .variable => |*variable| {
                self.printVariable(variable);
            },
            .binary_operator => |*binary_operator| {
                self.printBinaryOperator(binary_operator);
            },
            .unary_operator => |*unary_operator| {
                self.printUnaryOperator(unary_operator);
            },
            .call => |*call| {
                self.printFunctionCall(call);
            },
        }
    }

    pub fn printStatement(self: *Printer, node: *const ast.Statement) void {
        switch (node.*) {
            .var_decl => |*var_decl| {
                self.printVarDeclaration(var_decl);
            },
            .fn_decl => |*fn_decl| {
                self.printFnDeclaration(fn_decl);
            },
            .ret => |*ret| {
                self.printReturn(ret);
            },
            .scope => |*scope| {
                self.printScope(scope);
            },
            .branch => |*branch| {
                self.printBranch(branch);
            },
            .loop => |*loop| {
                self.printLoop(loop);
            },
            .assignment => |*assignment| {
                self.printAssignment(assignment);
            },
            .expr => |*expr| {
                self.printExpr(expr);
            },
        }
    }

    fn pad(self: *Printer) void {
        var i: u32 = 0;
        while (i < self.depth) : (i += 1) {
            printImpl("    ", .{});
        }
    }
};
