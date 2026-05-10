$content = Get-Content "lib/screens/punishment_lines_screen.dart" -Raw

$oldBlock = @"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Lignes a utiliser :',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  Row(
                    children: [
                      IconButton(
                        onPressed: linesToUse > 1 ? () => setState(() => linesToUse--) : null,
                        icon: const Icon(Icons.remove_circle_rounded, color: Colors.redAccent),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                            color: Colors.greenAccent.withAlpha(30),
                            borderRadius: BorderRadius.circular(10)),
                        child: Text('`$linesToUse',
                            style: const TextStyle(color: Colors.white,
                                fontWeight: FontWeight.bold, fontSize: 18)),
                      ),
                      IconButton(
                        onPressed: linesToUse < (selectedImmunity?.availableLines ?? 0) &&
                                linesToUse < remaining
                            ? () => setState(() => linesToUse++)
                            : null,
                        icon: const Icon(Icons.add_circle_rounded, color: Colors.greenAccent),
                      ),
                    ],
                  ),
                ],
              ),
"@

$newBlock = @"
              Row(
                children: [
                  const Text('Lignes a utiliser :',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.greenAccent)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.greenAccent, width: 2)),
                        filled: true,
                        fillColor: Colors.greenAccent.withAlpha(30),
                      ),
                      onChanged: (val) {
                        final n = int.tryParse(val) ?? 1;
                        final maxVal = selectedImmunity?.availableLines ?? 1;
                        final maxLine = maxVal < remaining ? maxVal : remaining;
                        setState(() => linesToUse = n.clamp(1, maxLine));
                      },
                    ),
                  ),
                ],
              ),
"@

$content = $content.Replace($oldBlock, $newBlock)
Set-Content "lib/screens/punishment_lines_screen.dart" -Value $content -Encoding UTF8 -NoNewline
Write-Host "DONE: $((Get-Content 'lib/screens/punishment_lines_screen.dart' | Measure-Object -Line).Lines) lignes" -ForegroundColor Green
