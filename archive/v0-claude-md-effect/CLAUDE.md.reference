# CLAUDE.md

## Commands

- Package manager: `pnpm` (NOT npm/yarn) - lockfile is pnpm-lock.yaml
- Dependencies are pre-installed. Do NOT run `pnpm install`
- Do NOT install Node.js or any global tools - everything is already configured
- Run specific rule tests: `npx vitest run packages/eslint-plugin/tests/rules/<rule-name>.test.ts`
- Typecheck eslint-plugin: `npx tsc --noEmit -p packages/eslint-plugin/tsconfig.json`
- Run all eslint-plugin tests (slow, avoid): `npx vitest run packages/eslint-plugin/tests/`

## ESLint rule development

- Rules: `packages/eslint-plugin/src/rules/<rule-name>.ts`
- Tests: `packages/eslint-plugin/tests/rules/<rule-name>.test.ts`
- Rule helpers: `packages/eslint-plugin/src/util/`
- Type utilities: `packages/type-utils/src/`
- Test utility: use `RuleTester` from `@typescript-eslint/rule-tester` with `getFixturesRootDir()`
- Type-checked rules use `createRuleTesterWithTypes()` from test helpers
- Test format: `valid: [...]` and `invalid: [...]` arrays. Invalid cases need `errors: [{ messageId: '...' }]`

## Architecture gotchas

- Monorepo: eslint-plugin depends on parser, type-utils, utils, typescript-estree
- AST types from `@typescript-eslint/typescript-estree` - not raw ESTree
- Type checker access: `getParserServices(context)` inside rules, then `services.getTypeAtLocation(node)` or `services.program.getTypeChecker()`
- `getConstrainedTypeAtLocation()` from `@typescript-eslint/type-utils` resolves generic constraints
- Some rules use `isTypeFlagSet()`, `isTypeAnyType()`, `isTypeUnknownType()` from type-utils

## Boundaries

### Always

- Run the specific test file after changes (not the full suite)
- Run typecheck before considering done
- Follow existing patterns in the file you modify

### Never

- Never run full test suite (`pnpm test` runs CI including e2e)
- Never modify test infrastructure or fixtures
- Never run `pnpm install` or `npm install`
- Never install Node.js or any runtime
