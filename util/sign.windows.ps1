
if ($env:SIGNING_ACCOUNT) {
    choco install dotnet-8.0-runtime --no-progress
    nuget install Microsoft.Windows.SDK.BuildTools -Version 10.0.22621.3233 -x
    nuget install Microsoft.Trusted.Signing.Client -Version 1.0.95 -x

    (Get-Content .\util\config.windows.json.in) -replace "SIGNING_ACCOUNT", $env:SIGNING_ACCOUNT | Out-File -encoding ASCII .\util\config.windows.json

    .\Microsoft.Windows.SDK.BuildTools\bin\10.0.22621.0\x86\signtool.exe sign /v /debug /fd SHA256 /tr "http://timestamp.acs.microsoft.com" /td SHA256 /dlib .\Microsoft.Trusted.Signing.Client\bin\x86\Azure.CodeSigning.Dlib.dll /dmdf .\util\config.windows.json .\target\release\rbx-studio-mcp.exe
}
copy target\release\rbx-studio-mcp.exe output\
