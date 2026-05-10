$lines = Get-Content "lib/screens/punishment_lines_screen.dart"
$before = $lines[0..540]
$newBlock = @(
"              ConstrainedBox(",
"                constraints: const BoxConstraints(maxHeight: 250),",
"                child: SingleChildScrollView(",
"                  child: Column(",
"                    mainAxisSize: MainAxisSize.min,",
"                    children: [",
"                      ...immunities.map((i) => GestureDetector(",
"                        onTap: () => setState(() => selectedImmunity = i),",
"                        child: AnimatedContainer(",
"                          duration: const Duration(milliseconds: 200),",
"                          margin: const EdgeInsets.only(bottom: 8),",
"                          padding: const EdgeInsets.all(12),",
"                          decoration: BoxDecoration(",
"                            color: selectedImmunity?.id == i.id",
"                                ? Colors.greenAccent.withAlpha(30)",
"                                : Colors.white10,",
"                            borderRadius: BorderRadius.circular(12),",
"                            border: Border.all(",
"                                color: selectedImmunity?.id == i.id",
"                                    ? Colors.greenAccent",
"                                    : Colors.transparent),",
"                          ),",
"                          child: Row(",
"                            children: [",
"                              const Icon(Icons.shield_rounded, color: Colors.greenAccent, size: 18),",
"                              const SizedBox(width: 8),",
"                              Expanded(child: Text(i.reason,",
"                                  style: const TextStyle(color: Colors.white, fontSize: 13))),",
"                              Text(" + '"' + '${i.availableLines} dispo' + '"' + ",",
"                                  style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),",
"                            ],",
"                          ),",
"                        ),",
"                      )),",
"                    ],",
"                  ),",
"                ),",
"              ),"
)
$after = $lines[569..($lines.Count-1)]
$result = $before + $newBlock + $after
Set-Content "lib/screens/punishment_lines_screen.dart" -Value $result -Encoding UTF8
Write-Host "DONE: $((Get-Content 'lib/screens/punishment_lines_screen.dart' | Measure-Object -Line).Lines) lignes" -ForegroundColor Green
