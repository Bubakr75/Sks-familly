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

# Premier bloc : lignes 581-608 (index 580-607)
$before1 = $lines[0..579]
$after1 = $lines[608..($lines.Count-1)]
$lines = $before1 + $newWidget + $after1

# Recalculer position du second bloc apres remplacement
# Original ligne 709, maintenant decalee
$diff = $newWidget.Count - 28
$idx2 = 708 + $diff
$before2 = $lines[0..($idx2-1)]
$after2 = $lines[($idx2+28)..($lines.Count-1)]
$lines = $before2 + $newWidget + $after2

Set-Content "lib/screens/punishment_lines_screen.dart" -Value $lines -Encoding UTF8
Write-Host "DONE: $((Get-Content 'lib/screens/punishment_lines_screen.dart' | Measure-Object -Line).Lines) lignes" -ForegroundColor Green
