''
'' uar.bas -- direct archive management ex (use with care!)
''

DefInt a-z
'$include: '..\inc\dos.bi'
'$include: '..\inc\arch.bi'

Declare Sub ExitError (msg As String)
Declare Sub Usage ()

'':::   
    Dim u as UAR, f AS UARDIR
    Dim archive as String, filename as String

    If ( Len( Command$ ) = 0 ) Then Usage

    sp = Instr( Command$, Chr$( 32 ) )
    If ( sp = 0 ) Then Usage
    archive = Left$( Command$, sp-1 ) + "::" 
    filename = Right$( Command$, Len( Command$ ) - sp )

    '' open archive
    If ( not uarOpen( u, archive, F4RW ) ) Then
        ExitError "archive not found"
    End If
    
    '' try finding the file
    If ( not uarFileFind( u, f, filename ) ) Then
        uarClose u
        ExitError "file not found"
    End If
        
    '' extract the file to a temp one
    If ( not uarFileExtract( u, f, "temp.tmp" ) ) Then
        uarClose u
        ExitError "extracting"
    End If
    
    '' delete the file from the archive
    If ( not uarFileDel( u, f ) ) Then
        Kill "temp.tmp"
        uarClose u
        ExitError "deleting"
    End If

    '' add it back to the archive
    If ( not uarFileAdd( u, "temp.tmp", filename ) ) Then
        Kill "temp.tmp"
        uarClose u
        ExitError "deleting"
    End If
    
    '' delete temp file
    Kill "temp.tmp"
    
    '' close archive
    uarClose u
    
    End

'':::
Sub ExitError (msg As String)
    Print "ERROR! "; msg
    End
End Sub
    
'':::
Sub Usage
    Print "Usage: uar archive filename (all with extensions)"
    End
End Sub
