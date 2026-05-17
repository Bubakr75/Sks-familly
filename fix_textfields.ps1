# Script de remplacement TextField -> TvTextField
$files = @(
  'child_dashboard_screen.dart',
  'chores_screen.dart',
  'gemini_chat_screen.dart',
  'goals_screen.dart',
  'notes_screen.dart',
  'balance_screen.dart',
  'punishment_lines_screen.dart',
  'tribunal_screen.dart',
  'trade_screen.dart',
  'badges_screen.dart',
  'immunity_lines_screen.dart',
  'settings_screen.dart',
  'add_points_screen.dart',
  'dashboard_screen.dart',
  'family_screen.dart'
)

# Fichiers qui n'ont pas encore l'import
$needImport = @(
  'child_dashboard_screen.dart',
  'chores_screen.dart',
  'gemini_chat_screen.dart',
  'goals_screen.dart',
  'notes_screen.dart'
)

foreach ($file in $files) {
  $path = "lib\screens\$file"
  if (!(Test-Path $path)) { Write-Host "SKIP: $path introuvable"; continue }
  
  $content = Get-Content $path -Raw -Encoding UTF8
  
  # Ajouter l'import si necessaire
  if ($file -in $needImport) {
    if ($content -notmatch "tv_focus_wrapper") {
      $content = $content -replace "(import 'package:flutter/material\.dart';)", "`$1`nimport '../widgets/tv_focus_wrapper.dart';"
      Write-Host "IMPORT ajoute: $file"
    }
  }
  
  # Remplacer TextField( par TvTextField( sauf les imports et les classes
  # On remplace uniquement les lignes qui commencent par des espaces + TextField(
  $content = $content -replace '(\s+)TextField\(', '$1TvTextField('
  # Aussi child: TextField(
  $content = $content -replace 'child:\s*TextField\(', 'child: TvTextField('
  
  Set-Content -Path $path -Value $content -Encoding UTF8 -NoNewline
  Write-Host "OK: $file"
}

Write-Host "`nTermine! Verification..."
$remaining = Select-String -Path "lib\screens\*.dart" -Pattern "^\s*TextField\(|child:\s*TextField\(" | Select-Object Filename, LineNumber
if ($remaining) {
  Write-Host "TextField restants:"
  $remaining | Format-Table
} else {
  Write-Host "Aucun TextField restant - tout est converti!"
}
