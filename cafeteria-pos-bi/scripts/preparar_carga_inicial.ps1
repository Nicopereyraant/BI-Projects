param(
  [string]$RawDir = (Join-Path $PSScriptRoot '..\..\data\raw'),
  [string]$OutDir = (Join-Path $PSScriptRoot '..\data\prepared')
)

$ErrorActionPreference = 'Stop'
$raw = (Resolve-Path -LiteralPath $RawDir).Path
[void][System.IO.Directory]::CreateDirectory($OutDir)
$out = (Resolve-Path -LiteralPath $OutDir).Path
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Convert-FechaHora([string]$value) {
  if ($value -notmatch '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$') {
    throw "fecha_hora invalida: $value"
  }
  return ($value.Replace(' ', 'T') + '-03:00')
}

function Escape-Csv([object]$value) {
  $s = [string]$value
  if ($s.Contains(',') -or $s.Contains('"') -or $s.Contains([char]13) -or $s.Contains([char]10)) {
    return '"' + $s.Replace('"', '""') + '"'
  }
  return $s
}

function Write-CsvRow($writer, [object[]]$values) {
  $encoded = foreach ($value in $values) { Escape-Csv $value }
  $writer.WriteLine(($encoded -join ','))
}

foreach ($name in @('sucursales.csv', 'productos.csv')) {
  Copy-Item -LiteralPath (Join-Path $raw $name) -Destination (Join-Path $out $name) -Force
}

$salesCount = 0
$writer = New-Object System.IO.StreamWriter((Join-Path $out 'ventas.csv'), $false, $utf8)
try {
  $writer.WriteLine('venta_id,fecha_hora,sucursal_id,total_venta,medio_pago,canal')
  Import-Csv -LiteralPath (Join-Path $raw 'ventas.csv') -Encoding UTF8 | ForEach-Object {
    Write-CsvRow $writer @($_.venta_id, (Convert-FechaHora $_.fecha_hora),
      $_.sucursal_id, $_.total_venta, $_.medio_pago, $_.canal)
    $salesCount++
  }
} finally { $writer.Dispose() }

$lineCount = 0
$lineNumbers = @{}
$writer = New-Object System.IO.StreamWriter((Join-Path $out 'detalle_ventas.csv'), $false, $utf8)
try {
  $writer.WriteLine('venta_id,linea_id,fecha_hora,sucursal_id,producto_id,cantidad,precio_unitario,subtotal,medio_pago,canal')
  Import-Csv -LiteralPath (Join-Path $raw 'detalle_ventas.csv') -Encoding UTF8 | ForEach-Object {
    $id = [string]$_.venta_id
    if (-not $lineNumbers.ContainsKey($id)) { $lineNumbers[$id] = 0 }
    $lineNumbers[$id]++
    Write-CsvRow $writer @($id, $lineNumbers[$id], (Convert-FechaHora $_.fecha_hora),
      $_.sucursal_id, $_.producto_id, $_.cantidad, $_.precio_unitario,
      $_.subtotal, $_.medio_pago, $_.canal)
    $lineCount++
  }
} finally { $writer.Dispose() }

Write-Output "Preparados $salesCount tickets y $lineCount lineas en $out"
