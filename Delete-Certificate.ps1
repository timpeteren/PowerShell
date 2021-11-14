function delete-Certificate {

    Param ([String]$certToDeleteThumbprint, `

        [String]$certRootStoreIn = "LocalMachine", `

        [string]$certStoreIn)

        Remove-Item Cert:\$certRootStoreIn\$certStoreIn\CA\$certToDeleteThumbprint
}