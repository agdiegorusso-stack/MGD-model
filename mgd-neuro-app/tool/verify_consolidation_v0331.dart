import 'dart:convert';
import '../test/support/consolidation_checks_v0331.dart';

void main() => print(
    const JsonEncoder.withIndent('  ').convert(runConsolidationChecks331()));
