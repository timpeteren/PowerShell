## Base64 encode and decode

# Encode string
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("MjUyNjM2NmItNjFiZi00OTE0LThjZGQtYzcyNTE3MWIzYTIz"))
# Result = 108524473277112853904

# Decode string
[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("108524473277112853904"))
# Result = NmRjZmFlMzMtMjBmMy00NGNjLTg0NzYtMzlmMGZhNzQ2ZTU0