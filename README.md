# Palimpsest

**A completely unnecessary and arguably irresponsible way to store files in the Windows Event Log.**
## Overview

Traditionally, event logs exist to record system activity, security events, and the occasional existential crisis of Windows Update. I created **Palimpsest** to ask the ever important question: _What if I could store my entire movie collection in the Windows Event Log?_

This module allows you to:

- **Import** a file by embedding its contents across multiple structured log entries.
- **Export** the file by carefully reassembling it from those same log entries.

Why? Because logs are _everywhere_, designed to retain data, and—let’s be honest—rarely scrutinized until something catches fire. If Windows insists on hoarding logs, why not make them _useful_? Whether you're testing blue team detection, exploring Windows internals, or just really committed to the idea of archiving your entire movie collection inside structured event data, **Palimpsest** will push those limits.

Is this practical? Depends on who you ask. 

Is it ridiculous? Absolutely. 

Is it beautiful? Also yes.

Use wisely. Or creatively, at least.

---

## Installation

Copy `Palimpsest.psm1` to a directory of your choice and import it into a PowerShell session:

```powershell
Import-Module .\Palimpsest.psm1
```

---

## Usage

### Importing a File into Windows Event Logs

```powershell
Invoke-Palimpsest -Path C:\path\to\file.txt -Import
```

This will:

- Slice the file into 32KB chunks (the event log entry size limit).
- Store the chunks as structured entries in a dedicated custom log. The actual raw data is stored in the `lpRawData` field.
- Export the resulting `.evtx` file to the current directory and clean up any newly created event sources from Windows.

### Extracting a File from Windows Event Logs

```powershell
Invoke-Palimpsest -Path C:\path\to\exported.evtx -Export
```

This will:

- Read the event log entries and extract the stored file contents.
- Reconstruct the original file from the stored 32KB chunks.
- Write it back to disk in its original form.

---

## Artifacts & Detection

- **Event Log Activity**
    - Palimpsest will create new event log sources that appear and disappear rapidly.
    - Performs large volumes of `Write-EventLog` operations in a short timeframe.
- **Log Content**
    - Palimpsest uses Event ID `1337` for all generated events.
    - Generated Event Sources follow the format of `Palimpsest-*` with a unique eight digit GUID trailing each source.
    - High volume of large event entries. 
	    - Standard event logs rarely contain large binary data entries. 
	    - Multiple large events written in sequence may indicate abuse of the event logs.
- **Artifacts**
    - Windows does not release the log files in `C:\Windows\System32\winevt\Logs` until the Windows Event Log service is restarted. Forensic artifacts may be left in this directory if not cleaned up manually.
