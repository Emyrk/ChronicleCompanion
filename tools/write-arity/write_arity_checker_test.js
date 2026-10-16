const assert = require("assert");
const path = require("path");
const { spawnSync } = require("child_process");

const root = path.resolve(__dirname, "../..");
const checker = path.join(__dirname, "check_write_arity.js");

function run(fixture) {
  return spawnSync(process.execPath, [checker, path.join(root, "tests", "lint", fixture)], {
    cwd: root,
    encoding: "utf8",
  });
}

const valid = run("write_arity_valid.lua");
assert.strictEqual(valid.status, 0, valid.stderr);

const invalid = run("write_arity_invalid.lua");
assert.strictEqual(invalid.status, 1, "invalid calls should fail the checker");
assert.match(invalid.stderr, /Write2 call has 4 explicit arguments; expected 3/);
assert.match(invalid.stderr, /Write2 call has 2 explicit arguments; expected 3/);
assert.match(invalid.stderr, /Write2 call uses a dynamic vararg count/);
assert.strictEqual((invalid.stderr.match(/error:/g) || []).length, 4, invalid.stderr);

const badDeclaration = run("write_arity_bad_declaration.lua");
assert.strictEqual(badDeclaration.status, 1, "invalid declarations should fail the checker");
assert.match(badDeclaration.stderr, /Write3 declaration must not be variadic/);

console.log("write arity checker tests passed");
