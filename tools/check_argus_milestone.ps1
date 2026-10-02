[CmdletBinding()]
param(
    [string]$RpcUrl = 'https://rpc.mainnet.arc.io',
    [string]$Token = '0x4060e632bBb7D731d50fA8Fc58C82D93154085c1',
    [string]$ExpectedPoolId = '0xf962e883fd2ab4b21e1248a7ea62835f3ae31f6103351f74dfada89d43c63c36',
    [string]$ExpectedHook = '0xa0f36d2fb95f6c31f8fce28904d6b3ec335760cc',
    [string]$ExpectedPortal = '0xeed7559b8a6abf64427dc41cb5cc6400109c5d93',
    [string]$StateView = '0xF3334192D15450CdD385c8B70e03f9A6bD9E673b',
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

function Invoke-ArcRpc {
    param(
        [Parameter(Mandatory)] [string]$Method,
        [AllowEmptyCollection()] [object[]]$Params = @()
    )

    $body = @{
        jsonrpc = '2.0'
        id      = 1
        method  = $Method
        params  = $Params
    } | ConvertTo-Json -Depth 8 -Compress

    $response = Invoke-RestMethod -Method Post -Uri $RpcUrl -ContentType 'application/json' -Body $body
    if ($null -ne $response.error) {
        throw "RPC $Method failed: $($response.error.message)"
    }
    return [string]$response.result
}

function Invoke-EthCall {
    param(
        [Parameter(Mandatory)] [string]$To,
        [Parameter(Mandatory)] [string]$Data
    )

    return Invoke-ArcRpc -Method 'eth_call' -Params @(@{ to = $To; data = $Data }, 'latest')
}

function Split-AbiWords {
    param([Parameter(Mandatory)] [string]$Hex)

    $body = $Hex -replace '^0x', ''
    if (($body.Length % 64) -ne 0) {
        throw "ABI result length is not divisible by 32 bytes: $($body.Length) hex characters"
    }

    $words = @()
    for ($offset = 0; $offset -lt $body.Length; $offset += 64) {
        $words += $body.Substring($offset, 64)
    }
    return $words
}

function Convert-WordToInt24 {
    param([Parameter(Mandatory)] [string]$Word)

    $value = [Convert]::ToInt32($Word.Substring(58, 6), 16)
    if ($value -ge 0x800000) {
        $value -= 0x1000000
    }
    return $value
}

function Convert-WordToAddress {
    param([Parameter(Mandatory)] [string]$Word)
    return ('0x' + $Word.Substring(24, 40)).ToLowerInvariant()
}

function Convert-WordToBool {
    param([Parameter(Mandatory)] [string]$Word)
    return ($Word -notmatch '^0+$')
}

function Normalize-Hex {
    param([Parameter(Mandatory)] [string]$Value)
    return $Value.ToLowerInvariant()
}

$selectors = @{
    launches  = '0x1f2d8550'
    bonded    = '0xe88dc357'
    bondBound = '0x0c6eb359'
    bondTick  = '0x645acda3'
    poolId    = '0x3e0dc34e'
    portal    = '0x6425666b'
    token     = '0xfc0c546a'
    getSlot0  = '0xc815641c'
}

$tokenBody = ($Token -replace '^0x', '').ToLowerInvariant()
if ($tokenBody.Length -ne 40) {
    throw 'Token must be a 20-byte EVM address.'
}

$chainIdHex = Invoke-ArcRpc -Method 'eth_chainId' -Params @()
$hookPoolId = Invoke-EthCall -To $ExpectedHook -Data $selectors.poolId
$hookPortalWord = @(Split-AbiWords (Invoke-EthCall -To $ExpectedHook -Data $selectors.portal))[0]
$hookTokenWord = @(Split-AbiWords (Invoke-EthCall -To $ExpectedHook -Data $selectors.token))[0]
$bondedWord = @(Split-AbiWords (Invoke-EthCall -To $ExpectedHook -Data $selectors.bonded))[0]
$bondBoundWord = @(Split-AbiWords (Invoke-EthCall -To $ExpectedHook -Data $selectors.bondBound))[0]
$bondTickWord = @(Split-AbiWords (Invoke-EthCall -To $ExpectedHook -Data $selectors.bondTick))[0]

$actualPortal = Convert-WordToAddress $hookPortalWord
$actualToken = Convert-WordToAddress $hookTokenWord
$bonded = Convert-WordToBool $bondedWord
$bondBound = Convert-WordToBool $bondBoundWord
$bondTick = Convert-WordToInt24 $bondTickWord

$launchData = $selectors.launches + ('0' * 24) + $tokenBody
$launchWords = @(Split-AbiWords (Invoke-EthCall -To $actualPortal -Data $launchData))
if ($launchWords.Count -lt 6) {
    throw "Portal launch record is too short: $($launchWords.Count) words"
}

$recordHook = Convert-WordToAddress $launchWords[0]
$tickStart = Convert-WordToInt24 $launchWords[4]
$recordBondTick = Convert-WordToInt24 $launchWords[5]

$poolIdBody = ($hookPoolId -replace '^0x', '').ToLowerInvariant()
$slot0Words = @(Split-AbiWords (Invoke-EthCall -To $StateView -Data ($selectors.getSlot0 + $poolIdBody)))
if ($slot0Words.Count -lt 2) {
    throw "StateView slot0 result is too short: $($slot0Words.Count) words"
}
$currentTick = Convert-WordToInt24 $slot0Words[1]

$span = $bondTick - $tickStart
if ($span -eq 0) {
    throw 'Bonding span is zero.'
}
$rawProgressPct = (($currentTick - $tickStart) / [double]$span) * 100.0
$displayProgressPct = [Math]::Min(100.0, [Math]::Max(0.0, $rawProgressPct))

$checks = [ordered]@{
    chain_id_is_5042           = ($chainIdHex -eq '0x13b2')
    token_matches_hook         = ((Normalize-Hex $actualToken) -eq (Normalize-Hex $Token))
    portal_matches_expected    = ((Normalize-Hex $actualPortal) -eq (Normalize-Hex $ExpectedPortal))
    pool_id_matches_expected   = ((Normalize-Hex $hookPoolId) -eq (Normalize-Hex $ExpectedPoolId))
    record_hook_matches        = ((Normalize-Hex $recordHook) -eq (Normalize-Hex $ExpectedHook))
    record_bond_tick_matches   = ($recordBondTick -eq $bondTick)
}

$failedChecks = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })
if ($failedChecks.Count -gt 0) {
    throw "Invariant check failed: $($failedChecks -join ', ')"
}

$result = [ordered]@{
    observed_at             = (Get-Date).ToString('o')
    read_only               = $true
    rpc                     = $RpcUrl
    chain_id_hex            = $chainIdHex
    token                   = $Token
    portal                  = $actualPortal
    hook                    = $ExpectedHook
    pool_id                 = $hookPoolId
    bonded                  = $bonded
    bond_bound              = $bondBound
    tick_start              = $tickStart
    current_tick            = $currentTick
    tick_bond               = $bondTick
    raw_progress_pct        = $rawProgressPct
    display_progress_pct    = $displayProgressPct
    reached_100_percent     = $bonded -or ($displayProgressPct -ge 100.0)
    checks                  = $checks
    portal_record_word_count = $launchWords.Count
    mutations               = @()
}

$json = $result | ConvertTo-Json -Depth 8
if ($OutputPath) {
    $parent = Split-Path -Parent $OutputPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent | Out-Null
    }
    Set-Content -LiteralPath $OutputPath -Value $json -Encoding utf8
}
$json
