# ============================================
#  YankunFrame — Envoyer des photos vers l'iMac
#  Usage : .\send_to_imac.ps1 photo1.jpg photo2.png ...
# ============================================
param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Files
)

$REMOTE = "yank@imac-de-yank.local"
$DEST   = "/users/yank_imac/Desktop/YankunFrame/photos/"

if (-not $Files -or $Files.Count -eq 0) {
    Write-Host "Aucun fichier fourni." -ForegroundColor Yellow
    Write-Host "Usage : .\send_to_imac.ps1 photo1.jpg photo2.png ..."
    Write-Host "Tu peux aussi glisser-deposer des fichiers dans le terminal apres avoir tape la commande."
    exit 1
}

Write-Host "Envoi de $($Files.Count) fichier(s) vers ${REMOTE}:${DEST} ..." -ForegroundColor Cyan
Write-Host ""

$success = 0
$fail = 0

for ($i = 0; $i -lt $Files.Count; $i++) {
    $file = $Files[$i]
    $name = Split-Path $file -Leaf
    $num  = $i + 1
    Write-Host "[$num/$($Files.Count)] $name" -NoNewline
    scp $file "${REMOTE}:${DEST}"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  OK" -ForegroundColor Green
        $success++
    } else {
        Write-Host "  ERREUR" -ForegroundColor Red
        $fail++
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Termine ! $success OK, $fail erreur(s)."
Write-Host "Pense a rafraichir la page du cadre photo."
Write-Host "==========================================" -ForegroundColor Cyan