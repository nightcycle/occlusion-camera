#!/usr/bin/env bash
sh scripts/test/download.sh
# sh scripts/test/unit-test.sh
luau-lsp analyze --sourcemap="sourcemap.json" --ignore="Packages/**" --ignore="src/Server/NPC/Animate.server.lua" --ignore="**/Packages/**" --ignore="*.spec.luau" --ignore="out/**" --flag:LuauTypeInferIterationLimit=0 --definitions=types/benchmark.d.lua --flag:LuauCheckRecursionLimit=0 --flag:LuauTypeInferRecursionLimit=0 --flag:LuauTarjanChildLimit=0 --flag:LuauTypeInferTypePackLoopLimit=0 --flag:LuauVisitRecursionLimit=0 --definitions=types/globalTypes.d.lua --flag:LuauParseDeclareClassIndexer=true src
selene src
