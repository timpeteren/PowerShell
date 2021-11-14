$ProgressPreference = 'SilentlyContinue'

$url = "http://pages.cs.wisc.edu/~ballard/bofh/bofhserver.pl?$(Get-Random)"
$page = Invoke-WebRequest -Uri $url -UseBasicParsing
$pattern = '(?s)<br><font\ size\ =\ "\+2">(.{1,})</font'
if ($page.Content -match $pattern)
{
  $matches[1].Trim() -replace '\n', '' -replace '\r', ''
}