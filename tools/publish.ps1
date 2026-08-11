# 发布入口（跨 DST mod 项目可复用）
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('patch', 'minor', 'major')]
    [string]$Bump,

    [switch]$SkipChecks,

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# 项目根目录 = 当前工作目录（在哪个项目下执行就发布哪个项目）
$projectRoot = Resolve-Path (Get-Location)
if (-not (Test-Path (Join-Path $projectRoot 'modinfo.lua'))) {
    Write-Error "当前目录未找到 modinfo.lua，请在 DST mod 项目根目录执行此脚本。"
    Write-Error "当前目录: $projectRoot"
    exit 1
}

$sharedModule = Join-Path $env:USERPROFILE 'projects/DST-ArknightsItemPackage/tools/publish/publish.psm1'
if (-not (Test-Path $sharedModule)) {
    Write-Error "未找到共享发布模块: $sharedModule"
    exit 1
}

Import-Module $sharedModule -Force
Publish-Mod -ProjectRoot $projectRoot -Bump $Bump -SkipChecks:$SkipChecks -DryRun:$DryRun
