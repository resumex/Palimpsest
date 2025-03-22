function Invoke-Palimpsest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,  # File path to read and log
        [switch]$Import,
        [switch]$Export
    )

    # Validate file existence
    if (-not (Test-Path $Path)) {
        Write-Error "File not found: $Path"
        return
    }

if ($Import) {

$LogName = Split-Path $Path -Leaf  # Use the filename as the event log name
$RandomUID = ([guid]::NewGuid().ToString() -replace "-","").Substring(0,8)
$LogSource = "Palimpsest-$RandomUID"
$EventID = "1337"
$ExportLocation = Split-Path -Path $Path -Parent

# Define the chunk size to read from the file (31 KB). 
# The maximum size of an event entry is 32 KB.
# https://msdn.microsoft.com/EN-US/library/windows/desktop/aa363679.aspx
$PartSizeBytes = 32kb  
# if you read this Microsoft 
# why won't you let me stuff a 4GB ISO 
# into a single event entry?
# are you scared of such power?
# of such
# beauty?

# Open the file for reading
$reader = [IO.File]::OpenRead($Path)

# Create a byte buffer to store chunks of file data
$buffer = New-Object -TypeName Byte[] -ArgumentList $PartSizeBytes
$moreData = $true  # Control flag for reading the file

# Ensure that the event log exists, and create it if necessary
if (-not (Get-WinEvent -ListLog $LogName -ErrorAction SilentlyContinue)) {
    Write-Host "Creating Log File..." -ForegroundColor Yellow
    New-EventLog -LogName $LogName -Source $LogSource -ErrorAction SilentlyContinue
}
else {
    # Check if the source already exists in the event log
    $existingSources = (Get-EventLog -LogName $LogName -ErrorAction SilentlyContinue).Source
    if (-not ($existingSources -contains $LogSource)) {
        New-EventLog -LogName $LogName -Source $LogSource -ErrorAction SilentlyContinue
    }
}

# configure target event log settings
Write-Host "Configuring Target Event Log..." -ForegroundColor Yellow
$targetLog = Get-WinEvent -ListLog $LogName
$targetLog.MaximumSizeInBytes = 25gb # Tried making this work by setting the max size to 1-2Gb bigger than the target file. Windows didn't like it. Did this instead.
$targetLog.SaveChanges()

# Read from the file and log its data as event log entries
$counter = 0
$totalChunks = [math]::Ceiling((Get-Item $Path).Length / $PartSizeBytes)
while ($moreData) {

        # Read a chunk of the file into the buffer
        $bytesRead = $reader.Read($buffer, 0, $buffer.Length)
        [Byte[]] $output = $buffer

        # If we reach the end of the file, adjust the buffer size accordingly
        if ($bytesRead -ne $buffer.Length) {
            $moreData = $false
            $output = New-Object -TypeName Byte[] -ArgumentList $bytesRead
            [Array]::Copy($buffer, $output, $bytesRead)
        }

        # Write an event log entry with the file data embedded in RawData
        Write-EventLog -LogName $LogName -Source $LogSource -EventId $EventID -EntryType "Information" -Category 0 -Message $LogName -RawData $output

        # cute lil counter :3
        $counter++
        Write-Host "`rProcessing Event: $counter / $totalChunks" -ForegroundColor Green -NoNewline
}
Write-Host "`nProcessing complete!                  " -ForegroundColor Green # Clears the last output
$reader.Close()

#Export EVTX and remove the event log from event viewer
Write-Host "Exporting EVTX File..." -ForegroundColor Yellow
$eventSession = New-Object System.Diagnostics.Eventing.Reader.EventLogSession
$eventSession.ExportLog("$LogName", "LogName", "*", "$ExportLocation\$Logname.evtx")
Write-Host "EVTX file exported to " -ForegroundColor Yellow -NoNewline
Write-host "$ExportLocation\$Logname.evtx" -ForegroundColor Red
Remove-EventLog -Source $LogSource
Remove-EventLog $LogName
Write-Host "Log removed from Event Viewer." -ForegroundColor Yellow
Write-Host "Manual cleanup of larger input files may be necessary at " -ForegroundColor Yellow -NoNewline
Write-Host "C:\Windows\System32\winevt\Logs " -ForegroundColor Red
# TO DO: Remove the file from C:\Windows\System32\winevt\Logs
# The Event Log process doesn't release the file until after the task is restarted
}


if ($Export) {

$Directory = Split-Path -Path $Path -Parent  # Grab the folder of the input file
$FileName = (Get-WinEvent -Path $Path | Select-Object -First 1).LogName # Grab the filename from the LogName field
$EventCount = (Get-WinEvent -Path $Path).count
$OutputFilePath = "$Directory\$FileName"
$FileStream = [System.IO.File]::OpenWrite($OutputFilePath)
$counter = 0
Get-WinEvent -Path $Path |
    Where-Object { $_.ProviderName -like "Palimpsest-*" } |
    Sort-Object -Property @{Expression = "RecordId"; Ascending = $true } |
    ForEach-Object {
        $data = $_.Properties[1].Value
        $FileStream.Write($data, 0, $data.Length)
        $counter++
        Write-Host "`rExtracting Chunk: $counter / $EventCount" -ForegroundColor Green -NoNewline
    }
    Write-Host "`nExtraction complete!                  " -ForegroundColor Green # Clears the last output
    Write-Host "File Exported to "  -ForegroundColor Yellow -NoNewline
    Write-Host "$OutputFilePath" -ForegroundColor Red
    $FileStream.Close()
}
}