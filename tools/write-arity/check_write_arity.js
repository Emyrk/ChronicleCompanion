#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const luaparse = require("luaparse");

const WRITE_NAME = /^Write(\d+)$/;
const SKIPPED_DIRECTORIES = new Set([".git", "node_modules"]);

function collectLuaFiles(inputs) {
  const files = [];

  function visit(input) {
    const stat = fs.statSync(input);
    if (stat.isDirectory()) {
      for (const entry of fs.readdirSync(input).sort()) {
        if (!SKIPPED_DIRECTORIES.has(entry)) {
          visit(path.join(input, entry));
        }
      }
    } else if (input.endsWith(".lua")) {
      files.push(input);
    }
  }

  for (const input of inputs) {
    visit(input);
  }
  return files;
}

function memberWriteArity(node) {
  if (!node || node.type !== "MemberExpression" || !node.identifier) {
    return null;
  }
  const match = WRITE_NAME.exec(node.identifier.name);
  if (!match) {
    return null;
  }
  const arity = Number(match[1]);
  return arity >= 0 && arity <= 12 ? arity : null;
}

function isChronicleLogBase(node) {
  return node && node.type === "Identifier" && node.name === "ChronicleLog";
}

function isChronicleLogReceiver(node) {
  return node && node.type === "Identifier" && (node.name === "ChronicleLog" || node.name === "self");
}

function callArgumentCount(node) {
  if (Array.isArray(node.arguments)) {
    return node.arguments.length;
  }
  if (node.argument) {
    return 1;
  }
  return 0;
}

function walk(node, visitor) {
  if (!node || typeof node !== "object") {
    return;
  }
  if (typeof node.type === "string") {
    visitor(node);
  }
  for (const key of Object.keys(node)) {
    if (key === "loc" || key === "comments") {
      continue;
    }
    const value = node[key];
    if (Array.isArray(value)) {
      for (const child of value) {
        walk(child, visitor);
      }
    } else {
      walk(value, visitor);
    }
  }
}

function location(node) {
  const start = node.loc && node.loc.start;
  return start ? `${start.line}:${start.column + 1}` : "1:1";
}

function checkFile(file) {
  const source = fs.readFileSync(file, "utf8");
  let tree;
  try {
    tree = luaparse.parse(source, {
      comments: false,
      locations: true,
      luaVersion: "5.1",
    });
  } catch (error) {
    const line = error.line || 1;
    const column = (error.index != null ? error.index : 0) + 1;
    return [`${file}:${line}:${column}: error: Lua parse failed: ${error.message}`];
  }

  const errors = [];
  walk(tree, (node) => {
    if (node.type === "FunctionDeclaration") {
      const arity = memberWriteArity(node.identifier);
      if (arity === null || !isChronicleLogBase(node.identifier.base)) {
        return;
      }
      const vararg = node.parameters.some((parameter) => parameter.type === "VarargLiteral");
      if (vararg) {
        errors.push(
          `${file}:${location(node.identifier)}: error: ${node.identifier.identifier.name} declaration must not be variadic`,
        );
        return;
      }
      const implicitSelf = node.identifier.indexer === ":";
      const expected = arity + (implicitSelf ? 1 : 2);
      const actual = node.parameters.length;
      if (actual !== expected) {
        errors.push(
          `${file}:${location(node.identifier)}: error: ${node.identifier.identifier.name} declaration has ${actual} explicit parameters; expected ${expected}`,
        );
      }
      return;
    }

    if (node.type !== "CallExpression" && node.type !== "TableCallExpression" && node.type !== "StringCallExpression") {
      return;
    }
    const arity = memberWriteArity(node.base);
    if (arity === null || !isChronicleLogReceiver(node.base.base)) {
      return;
    }
    if (Array.isArray(node.arguments) && node.arguments.some((argument) => argument.type === "VarargLiteral")) {
      errors.push(
        `${file}:${location(node.base.identifier)}: error: ${node.base.identifier.name} call uses a dynamic vararg count`,
      );
      return;
    }
    const implicitSelf = node.base.indexer === ":";
    const expected = arity + (implicitSelf ? 1 : 2);
    const actual = callArgumentCount(node);
    if (actual !== expected) {
      errors.push(
        `${file}:${location(node.base.identifier)}: error: ${node.base.identifier.name} call has ${actual} explicit arguments; expected ${expected} (${arity} payload fields)`,
      );
    }
  });
  return errors;
}

function main(argv) {
  if (argv.length === 0) {
    console.error("usage: node tools/check_write_arity.js <file-or-directory> [...]");
    return 2;
  }

  const errors = [];
  for (const file of collectLuaFiles(argv)) {
    errors.push(...checkFile(file));
  }
  for (const error of errors) {
    console.error(error);
  }
  return errors.length === 0 ? 0 : 1;
}

process.exitCode = main(process.argv.slice(2));
