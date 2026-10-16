#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
/c/lazarus/lazbuild.exe MolMDReader.lpi 2>&1 | grep -E "(Error|Fatal):" && exit 1
/c/lazarus/lazbuild.exe tests/MolMDReaderTests.lpi 2>&1 | grep -E "(Error|Fatal):" && exit 1
tests/MolMDReaderTests.exe --all --format=plain
