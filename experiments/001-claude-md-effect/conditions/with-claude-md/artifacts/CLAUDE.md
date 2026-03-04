# CLAUDE.md

## Commands

- Package manager: `pnpm` (NOT npm/yarn)
- Run specific rule tests: `npx vitest run packages/eslint-plugin/tests/rules/<rule-name>.test.ts`
- Typecheck eslint-plugin: `npx tsc --noEmit -p packages/eslint-plugin/tsconfig.json`
- Do NOT run full test suite (`pnpm test` triggers full CI including e2e)

## Architecture gotchas

- AST is hybrid TSESTree, not raw ESTree. Node shapes are defined in `packages/ast-spec` — do not guess structure, verify against type definitions
- Type checker access inside rules: `ESLintUtils.getParserServices(context)` then `services.getTypeAtLocation(node)` — never access tsc directly
- `getConstrainedTypeAtLocation()` from `@typescript-eslint/type-utils` resolves generic constraints — use it for narrowed types
- Monorepo: eslint-plugin depends on parser, type-utils, typescript-estree. Changes to upstream packages require rebuild before plugin tests pass

## Rule development

- Scaffold rules with `ESLintUtils.RuleCreator` — never export raw `{ create, meta }` objects
- Import `RuleTester` from `@typescript-eslint/rule-tester`, NOT from `eslint` core
- Type-checked rules use `createRuleTesterWithTypes()` from test helpers
- Test format: explicit `valid: [...]` and `invalid: [...]` arrays. Invalid cases need `errors: [{ messageId: '...' }]`
- Do NOT generate test cases dynamically (no `.map()`, no loops) — `@typescript-eslint/internal/no-dynamic-tests` rule will fail CI

## Boundaries

### Always

- Run the specific test file after changes, not the full suite
- Run typecheck before considering done
- Follow existing patterns in the file you modify

### Never

- Never modify test infrastructure, fixtures, or `ast-spec` definitions
- Never run `pnpm install` or install any tools
