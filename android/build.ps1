param(
    [string]$SdkRoot = "",
    [string]$JavaHome = ""
)

$ErrorActionPreference = "Stop"
$project = Split-Path -Parent $MyInvocation.MyCommand.Path

if ([string]::IsNullOrWhiteSpace($SdkRoot)) {
    $SdkRoot = $env:ANDROID_SDK_ROOT
}
if ([string]::IsNullOrWhiteSpace($SdkRoot)) {
    $localSdk = [System.IO.Path]::GetFullPath((Join-Path $project "..\android-toolchain\sdk"))
    if (Test-Path -LiteralPath $localSdk) { $SdkRoot = $localSdk }
}
if ([string]::IsNullOrWhiteSpace($JavaHome)) {
    $JavaHome = $env:JAVA_HOME
}
if ([string]::IsNullOrWhiteSpace($JavaHome)) {
    $bundledJava = "C:\Program Files\Android\openjdk\jdk-21.0.8"
    if (Test-Path -LiteralPath $bundledJava) { $JavaHome = $bundledJava }
}
if ([string]::IsNullOrWhiteSpace($SdkRoot)) {
    throw "Set ANDROID_SDK_ROOT or pass -SdkRoot."
}
if ([string]::IsNullOrWhiteSpace($JavaHome)) {
    throw "Set JAVA_HOME or pass -JavaHome."
}

$env:JAVA_HOME = $JavaHome
$env:PATH = (Join-Path $JavaHome "bin") + ";" + $env:PATH

$build = Join-Path $project "build"
$classes = Join-Path $build "classes"
$dex = Join-Path $build "dex"
$assets = Join-Path $project "assets"
$sharedShopLog = [System.IO.Path]::GetFullPath((Join-Path $project "..\shared\shoplog.html"))
$signing = Join-Path $project "signing"
$keystore = Join-Path $signing "shoplog-release.jks"
$properties = Join-Path $signing "keystore.properties"
$tools = Join-Path $SdkRoot "build-tools\36.0.0"
$androidJar = Join-Path $SdkRoot "platforms\android-36\android.jar"

foreach ($required in @(
    $androidJar,
    (Join-Path $tools "aapt2.exe"),
    (Join-Path $tools "d8.bat"),
    (Join-Path $tools "zipalign.exe"),
    (Join-Path $tools "apksigner.bat"),
    (Join-Path $JavaHome "bin\javac.exe"),
    (Join-Path $JavaHome "bin\jar.exe"),
    (Join-Path $JavaHome "bin\keytool.exe")
)) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Missing build dependency: $required" }
}

if (-not (Test-Path -LiteralPath (Join-Path $assets "shoplog.html"))) {
    throw "Missing bundled ShopLog HTML: $assets\shoplog.html"
}

New-Item -ItemType Directory -Path $build,$classes,$dex,$signing -Force | Out-Null
if (Test-Path -LiteralPath $sharedShopLog) {
    Copy-Item -LiteralPath $sharedShopLog -Destination (Join-Path $assets "shoplog.html") -Force
}

if (-not (Test-Path -LiteralPath $properties)) {
    $password = [guid]::NewGuid().ToString("N")
    Set-Content -LiteralPath $properties -Value @(
        "storePassword=$password",
        "keyPassword=$password",
        "keyAlias=shoplog"
    ) -Encoding UTF8
}

$signingValues = @{}
Get-Content -LiteralPath $properties | ForEach-Object {
    if ($_ -match "^([^=]+)=(.*)$") { $signingValues[$matches[1]] = $matches[2] }
}

if (-not (Test-Path -LiteralPath $keystore)) {
    & (Join-Path $JavaHome "bin\keytool.exe") -genkeypair -v `
        -keystore $keystore `
        -storepass $signingValues.storePassword `
        -keypass $signingValues.keyPassword `
        -alias $signingValues.keyAlias `
        -keyalg RSA `
        -keysize 2048 `
        -validity 10000 `
        -dname "CN=ShopLog, O=Texas Swiss, C=US"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$compiledResources = Join-Path $build "compiled-res.zip"
$unsignedApk = Join-Path $build "ShopLog-unsigned.apk"
$alignedApk = Join-Path $build "ShopLog-aligned.apk"
$releaseApk = Join-Path $build "ShopLog-Android.apk"

& (Join-Path $tools "aapt2.exe") compile --dir (Join-Path $project "res") -o $compiledResources
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& (Join-Path $tools "aapt2.exe") link `
    -I $androidJar `
    --manifest (Join-Path $project "AndroidManifest.xml") `
    --java $build `
    --min-sdk-version 26 `
    --target-sdk-version 36 `
    --version-code 3 `
    --version-name "1.2" `
    -A $assets `
    $compiledResources `
    -o $unsignedApk
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$javaSources = Get-ChildItem -LiteralPath (Join-Path $project "src") -Filter *.java -Recurse |
    Select-Object -ExpandProperty FullName
$generatedSources = Get-ChildItem -LiteralPath $build -Filter R.java -Recurse |
    Select-Object -ExpandProperty FullName

$javacArguments = @(
    "-encoding", "UTF-8",
    "-source", "17",
    "-target", "17",
    "-classpath", $androidJar,
    "-d", $classes
) + $javaSources + $generatedSources
& (Join-Path $JavaHome "bin\javac.exe") $javacArguments
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$classesJar = Join-Path $build "classes.jar"
& (Join-Path $JavaHome "bin\jar.exe") --create --file $classesJar -C $classes .
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& (Join-Path $tools "d8.bat") `
    --lib $androidJar `
    --min-api 26 `
    --output $dex `
    $classesJar
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& (Join-Path $JavaHome "bin\jar.exe") --update --file $unsignedApk -C $dex classes.dex
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& (Join-Path $tools "zipalign.exe") -f -p 4 $unsignedApk $alignedApk
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& (Join-Path $tools "apksigner.bat") sign `
    --ks $keystore `
    --ks-key-alias $signingValues.keyAlias `
    --ks-pass "pass:$($signingValues.storePassword)" `
    --key-pass "pass:$($signingValues.keyPassword)" `
    --out $releaseApk `
    $alignedApk
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& (Join-Path $tools "apksigner.bat") verify --verbose --print-certs $releaseApk
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Get-Item -LiteralPath $releaseApk
