$lines = Get-Content "lib/screens/punishment_lines_screen.dart"
$newWidget = @(
"                  Row(",
"                    children: [",
"                      const Text('Lignes a utiliser :',",
"                          style: TextStyle(color: Colors.white70, fontSize: 13)),",
"                      const SizedBox(width: 12),",
"                      SizedBox(",
"                        width: 80,",
"                        child: TextField(",
"                          keyboardType: TextInputType.number,",
"                          textAlign: TextAlign.center,",
"                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),",
"                          decoration: InputDecoration(",
"                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),",
"                            enabledBorder: OutlineInputBorder(",
"                              borderRadius: BorderRadius.circular(10),",
"                              borderSide: const BorderSide(color: Colors.greenAccent)),",
"                            focusedBorder: OutlineInputBorder(",
"                              borderRadius: BorderRadius.circular(10),",
"                              borderSide: const BorderSide(color: Colors.greenAccent, width: 2)),",
"                            filled: true,",
"                            fillColor: Colors.greenAccent.withAlpha(30),",
"                          ),",
"                          controller: TextEditingController(text: linesToUse.toString()),",
"                          onChanged: (val) {",
"                            final n = int.tryParse(val) ?? 1;",
"                            final max = (selectedImmunity?.availableLines ?? 1) < remaining",
"                                ? (selectedImmunity?.availableLines ?? 1)",
"                                : remaining;",
"                            setState(() => linesToUse = n.clamp(1, max));",
"                          },",
"                        ),",
"                      ),",
"                    ],",
"                  ),"
)

# Remplacer le premier bloc (ligne 583, index 582)
$i1start = 582
$i1end = 608
$before1 = $lines[0..($i1start-1)]
$after1 = $lines[$i1end..($lines.Count-1)]
$lines = $before1 + $newWidget + $after1

# Recalculer le second bloc apres insertion
$lines2 = $lines
for ($i = 0; $i -lt $lines2.Count; $i++) {
    if ($lines2[$i] -match "Lignes a utiliser" -and $i -gt 590) {
        $i2start = $i - 1
        $i2end = $i2start + 27
        $before2 = $lines2[0..($i2start-1)]
        $after2 = $lines2[$i2end..($lines2.Count-1)]
        $lines2 = $before2 + $newWidget + $after2
        break
    }
}

Set-Content "lib/screens/punishment_lines_screen.dart" -Value $lines2 -Encoding UTF8
Write-Host "DONE: $((Get-Content 'lib/screens/punishment_lines_screen.dart' | Measure-Object -Line).Lines) lignes" -ForegroundColor Green
