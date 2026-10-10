$ErrorActionPreference = 'Stop'

if (-not (Test-Path '.env')) {
    throw 'Copia .env.example a .env y configura las credenciales antes de ejecutar la verificación.'
}

$environment = @{}
Get-Content '.env' | ForEach-Object {
    if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$' -and $Matches[1] -notmatch '^\s*#') {
        $environment[$Matches[1]] = $Matches[2].Trim('"').Trim("'")
    }
}

if (-not $environment.ADMIN_USERNAME -or -not $environment.ADMIN_PASSWORD) {
    throw 'ADMIN_USERNAME y ADMIN_PASSWORD deben estar definidos en .env.'
}

function Invoke-ApiInContainer {
    param(
        [Parameter(Mandatory = $true)][string] $Method,
        [Parameter(Mandatory = $true)][string] $Url,
        [string] $Token,
        [AllowNull()][object] $Body
    )

    $curl = "curl -fsS -X $Method"
    if ($Token) {
        $curl += " -H 'Authorization: Bearer $Token'"
    }

    if ($null -ne $Body) {
        $json = $Body | ConvertTo-Json -Compress -Depth 6
        $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json))
        $command = "printf '%s' '$encoded' | base64 -d | $curl -H 'Content-Type: application/json' --data-binary @- '$Url'"
    }
    else {
        $command = "$curl '$Url'"
    }

    $response = docker compose exec -T api sh -lc $command
    if ($LASTEXITCODE -ne 0) {
        throw "Falló la solicitud HTTP $Method $Url dentro del contenedor api."
    }

    return ($response | ConvertFrom-Json)
}

$login = Invoke-ApiInContainer -Method 'POST' -Url 'http://localhost/api/v1/auth/login' -Body @{
    username = $environment.ADMIN_USERNAME
    password = $environment.ADMIN_PASSWORD
}
if ($login.role -ne 'admin') {
    throw "El login devolvió rol '$($login.role)' en vez de admin."
}

$categories = Invoke-ApiInContainer -Method 'GET' -Url 'http://localhost/api/v1/categories' -Token $login.access_token
if ($categories -isnot [array]) {
    $categories = $categories.items
}
if (-not $categories.Count) {
    throw 'La API no devolvió categorías.'
}

$suffix = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$book = Invoke-ApiInContainer -Method 'POST' -Url 'http://localhost/api/v1/books' -Token $login.access_token -Body @{
    title = "Compose E2E $suffix"
    author = 'Integration Test'
    isbn = '978{0:D10}' -f ($suffix % 10000000000)
    category_id = $categories[0].id
    total_copies = 1
}
$member = Invoke-ApiInContainer -Method 'POST' -Url 'http://localhost/api/v1/members' -Token $login.access_token -Body @{
    full_name = "Compose E2E $suffix"
    document_number = "E2E-$suffix"
}
$loan = Invoke-ApiInContainer -Method 'POST' -Url 'http://localhost/api/v1/loans' -Token $login.access_token -Body @{
    member_id = $member.id
    items = @(@{ book_id = $book.id })
}
$item = $loan.items[0]
$returned = Invoke-ApiInContainer -Method 'POST' -Url "http://localhost/api/v1/loans/$($loan.id)/items/$($item.id)/return" -Token $login.access_token

$today = [DateTime]::UtcNow.ToString('yyyy-MM-dd')
$report = Invoke-ApiInContainer -Method 'GET' -Url "http://localhost/api/v1/reports/most-borrowed?from=2000-01-01&to=$today" -Token $login.access_token
if (-not $returned.returned_at -or -not $report.rows.Count) {
    throw 'La devolución o el reporte no devolvió los datos esperados.'
}

[PSCustomObject]@{
    login_role = $login.role
    loan_id = $loan.id
    returned_at = $returned.returned_at
    report_rows = $report.rows.Count
} | Format-List
