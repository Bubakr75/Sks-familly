$lines = Get-Content "lib/screens/punishment_lines_screen.dart"
$newWidget = @(
"              Row(",
"                children: [",
"                  const Text('Lignes a utiliser :',",
"                      style: TextStyle(color: Colors.white70, fontSize: 13)),",
"                  const SizedBox(width: 12),",
"                  SizedBox(",
"                    width: 80,",
"                    child: TextField(",
"                      keyboardType: TextInputType.number,",
"                      textAlign: TextAlign.center,",
"                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),",
"                      decoration: InputDecoration(",
"                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),",
"                        enabledBorder: OutlineInputBorder(",
"                          borderRadius: BorderRadius.circular(10),",
"                          borderSide: const BorderSide(color: Colors.greenAccent)),",
"                        focusedBorder: OutlineInputBorder(",
"                          borderRadius: BorderRadius.circular(10),",
"                          borderSide: const BorderSide(color: Colors.greenAccent, width: 2)),",
"                        filled: true,",
"                        fillColor: Colors.greenAccent.withAlpha(30),",
"                      ),",
"                      onChanged: (val) {",
"                        final n = int.tryParse(val) ?? 1;",
"                        final maxVal = selectedImmunity?.availableLines ?? 1;",
"                        final maxLine = maxVal < remaining ? maxVal : remaining;",
"                        setState(() => linesToUse = n.clamp(1, maxLine));",
"                      },",
"                    ),",
"                  ),",
"                ],",
"              ),"
)
$before = $lines[0..579]
$after = $lines[611..($lines.Count-1)]
$result = $before + $newWidget + $after
Set-Content "lib/screens/punishment_lines_screen.dart" -Value $result -Encoding UTF8
Write-Host "DONE bloc1: $($result.Count) lignes" -ForegroundColor Green
