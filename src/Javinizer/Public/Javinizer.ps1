function Javinizer {

    <#
    .SYNOPSIS
        A command-line based tool to scrape and sort your local Japanese Adult Video (JAV) files

    .DESCRIPTION
        Javinizer is used to pull data from online data sources such as JAVLibrary, DMM, and R18 to aggregate data into a CMS (Plex,Emby,Jellyfin) parseable format.

    .PARAMETER Find
        The find parameter will output a list-formatted data output from the data sources specified using a movie ID, file path, or URL.

    .PARAMETER Aggregated
        The aggregated parameter will create an aggregated list-formatted data output from the data sources specified as well as metadata priorities in your settings.ini file.

    .PARAMETER Path
        The path parameter sets the file or directory path that Javinizer will search and sort files in.

    .PARAMETER DestinationPath
        The destinationpath parameter sets the directory path that Javinizer will send sorted files to.

    .PARAMETER Url
        The url parameter allows you to set direct URLs to JAVLibrary, DMM, and R18 data sources to scrape a video from in direct URLs comma-separated-format (url1,url2,url3).

    .PARAMETER Apply
        The apply parameter allows you to automatically begin your sort using settings specified in your settings.ini file.

    .PARAMETER Multi
        The multi parameter will perform your sort using multiple concurrent threads with a throttle limit of (1-5) set in your settings.ini file.

    .PARAMETER Help
        The help parameter will open a help dialogue in your console for Javinizer usage.

    .PARAMETER OpenSettings
        The opensettings parameter will open your settings.ini file for you to edit.

    .PARAMETER R18
        The r18 parameter allows you to set your data source of R18 to true.

    .PARAMETER Dmm
        The dmm parameter allows you to set your data source of DMM to true.

    .PARAMETER Javlibrary
        The javlibrary parameter allows you to set your data source of JAVLibrary to true.

    .PARAMETER Force
        The force parameter will attempt to force any new sorted files to be overwritten if it already exists.

    .PARAMETER ScriptRoot
        The scriptroot parameter sets the default Javinizer module directory. This should not be touched.


    .EXAMPLE
        PS> Javinizer -OpenSettings

        Description
        -----------
        Opens your Javinizer settings.ini file in the root module directory.

    .EXAMPLE
        PS> Javinizer -Path C:\Downloads\Unsorted -Multi

        Description
        -----------
        Performs a multi-threaded sort on C:\Downloads\Unsorted with settings specified in your settings.ini file.

    .EXAMPLE
        PS> Javinizer -Apply -Multi

        Description
        -----------
        Performs a multi-threaded sort on your directories with settings specified in your settings.ini file.

    .EXAMPLE
        PS> Javinizer -Path C:\Downloads -DestinationPath C:\Downloads\Sorted

        Description
        -----------
        Performs a single-threaded sort on your specified Path with other settings specified in your settings.ini file.

    .EXAMPLE
        PS> Javinizer -Path 'C:\Downloads\Jav\snis-620.mp4' -DestinationPath C:\Downloads\JAV\Sorted\' -Url 'http://www.javlibrary.com/en/?v=javlilljyy,https://www.r18.com/videos/vod/movies/detail/-/id=snis00620/?i3_ref=search&i3_ord=1,https://www.dmm.co.jp/digital/videoa/-/detail/=/cid=snis00620/?i3_ref=search&i3_ord=4'

        Description
        -----------
        Performs a single-threaded sort on your specified file using direct URLs to match the file.

    .EXAMPLE
        PS> Javinizer -Find SNIS-420

        Description
        -----------
        Performs a console search of SNIS-420 for all data sources specified in your settings.ini file

    .EXAMPLE
        PS> Javinizer -Find SNIS-420 -R18 -DMM -Aggregated

        Description
        -----------
        Performs a console search of SNIS-420 for R18 and DMM and aggregates output to your settings specified in your settings.inifile.

    .EXAMPLE
        PS> Javinizer -Find 'https://www.r18.com/videos/vod/movies/detail/-/id=pred00200/?dmmref=video.movies.new&i3_ref=list&i3_ord=2'

        Description
        -----------
        Performs a console search of PRED-200 using a direct url.
    #>

    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param (
        [Parameter(ParameterSetName = 'Info', Mandatory = $true, Position = 0)]
        [Alias('f')]
        [string]$Find,
        [Parameter(ParameterSetNAme = 'Info', Mandatory = $false)]
        [switch]$Aggregated,
        [Parameter(ParameterSetName = 'Path', Mandatory = $false, Position = 0)]
        [Alias('p')]
        [system.io.fileinfo]$Path,
        [Parameter(ParameterSetName = 'Path', Mandatory = $false, Position = 1)]
        [Alias('d')]
        [system.io.fileinfo]$DestinationPath,
        [Parameter(ParameterSetName = 'Path', Mandatory = $false)]
        [Alias('u')]
        [string]$Url,
        [Parameter(ParameterSetName = 'Path', Mandatory = $false)]
        [Alias('a')]
        [switch]$Apply,
        [Parameter(ParameterSetName = 'Path', Mandatory = $false)]
        [Alias('m')]
        [switch]$Multi,
        [Parameter(ParameterSetName = 'Path', Mandatory = $false)]
        [switch]$Force,
        [Parameter(ParameterSetName = 'Help')]
        [Alias('h')]
        [switch]$Help,
        [Parameter(ParameterSetName = 'Settings')]
        [switch]$OpenSettings,
        [Parameter(ParameterSetName = 'Path', Mandatory = $false)]
        [Parameter(ParameterSetName = 'Info', Mandatory = $false, Position = 0)]
        [switch]$R18,
        [Parameter(ParameterSetName = 'Path', Mandatory = $false)]
        [Parameter(ParameterSetName = 'Info', Mandatory = $false, Position = 0)]
        [switch]$Dmm,
        [Parameter(ParameterSetName = 'Path', Mandatory = $false)]
        [Parameter(ParameterSetName = 'Info', Mandatory = $false, Position = 0)]
        [switch]$Javlibrary,
        [string]$ScriptRoot = (Get-Item $PSScriptRoot).Parent
    )

    begin {
        $urlLocation = @()
        $urlList = @()
        $index = 1

        try {
            $settingsPath = Join-Path -Path $ScriptRoot -ChildPath 'settings.ini'
            Write-Verbose "Settings path: $ScriptRoot"
            $settings = Import-IniSettings -Path $settingsPath
        } catch {
            throw "[$($MyInvocation.MyCommand.Name)] Unable to load settings from path: $settingsPath"
        }

        if (($settings.Other.'verbose-shell-output' -eq 'True') -or ($PSBoundParameters.ContainsKey('Verbose'))) { $VerbosePreference = 'Continue' } else { $VerbosePreference = 'SilentlyContinue' }
        if ($settings.Other.'debug-shell-output' -eq 'True' -or ($DebugPreference -eq 'Continue')) { $DebugPreference = 'Continue' } elseif ($settings.Other.'debug-shell-output' -eq 'False') { $DebugPreference = 'SilentlyContinue' } else { $DebugPreference = 'SilentlyContinue' }
        $ProgressPreference = 'SilentlyContinue'
        Write-Host "[$($MyInvocation.MyCommand.Name)] Function started"
        Write-Debug "[$($MyInvocation.MyCommand.Name)] Parameter set: [$($PSCmdlet.ParameterSetName)]"
        Write-Debug "[$($MyInvocation.MyCommand.Name)] Bound parameters: [$($PSBoundParameters.Keys)]"
        $settings.Main.GetEnumerator() | Sort-Object Key | Out-String | Write-Debug
        $settings.General.GetEnumerator() | Sort-Object Key | Out-String | Write-Debug
        $settings.Metadata.GetEnumerator() | Sort-Object Key | Out-String | Write-Debug
        $settings.Locations.GetEnumerator() | Sort-Object Key | Out-String | Write-Debug
        $settings.'Emby/Jellyfin'.GetEnumerator() | Sort-Object Key | Out-String | Write-Debug
        $settings.Other.GetEnumerator() | Sort-Object Key | Out-String | Write-Debug

        if (-not ($PSBoundParameters.ContainsKey('r18')) -and `
            (-not ($PSBoundParameters.ContainsKey('dmm')) -and `
                (-not ($PSBoundParameters.ContainsKey('javlibrary')) -and `
                    (-not ($PSBoundParameters.ContainsKey('7mmtv')))))) {
            if ($settings.Main.'scrape-r18' -eq 'true') { $R18 = $true }
            if ($settings.Main.'scrape-dmm' -eq 'true') { $Dmm = $true }
            if ($settings.Main.'scrape-javlibrary' -eq 'true') { $Javlibrary = $true }
            #if ($settings.Main.'scrape-7mmtv' -eq 'true') { $7mmtv = $true }
        }
    }

    process {
        Write-Debug "[$($MyInvocation.MyCommand.Name)] R18 toggle: [$R18]; Dmm toggle: [$Dmm]; Javlibrary toggle: [$javlibrary]"
        switch ($PsCmdlet.ParameterSetName) {
            'Info' {
                $dataObject = Get-FindDataObject -Find $Find -Settings $settings -Aggregated:$Aggregated -Dmm:$Dmm -R18:$R18 -Javlibrary:$Javlibrary
                Write-Output $dataObject
            }

            'Settings' {
                if ([System.Environment]::OSVersion.Platform -eq 'Win32NT') {
                    Invoke-Item -Path (Join-Path $ScriptRoot -ChildPath 'settings.ini')
                } elseif ([System.Environment]::OSVersion.Platform -eq 'Unix') {
                    nano (Join-Path $ScriptRoot -ChildPath 'settings.ini')
                }
            }

            'Help' {
                help Javinizer
            }

            'Path' {
                if (-not ($PSBoundParameters.ContainsKey('Path'))) {
                    if (-not ($Apply.IsPresent)) {
                        Write-Warning "[$($MyInvocation.MyCommand.Name)] Neither [Path] nor [Apply] parameters are specified; Exiting..."
                        return
                    }
                    $Path = ($settings.Locations.'input-path') -replace '"', ''
                    $DestinationPath = ($settings.Locations.'output-path') -replace '"', ''
                }

                if (-not ($PSBoundParameters.ContainsKey('DestinationPath')) -and (-not ($Apply.IsPresent))) {
                    $DestinationPath = $Path
                }

                try {
                    $getPath = Get-Item $Path -ErrorAction Stop
                } catch {
                    Write-Warning "[$($MyInvocation.MyCommand.Name)] Path: [$Path] does not exist; Exiting..."
                    return
                }

                try {
                    $getDestinationPath = Get-Item $DestinationPath -ErrorAction 'SilentlyContinue'
                } catch [System.Management.Automation.SessionStateException] {
                    Write-Warning "[$($MyInvocation.MyCommand.Name)] Destination Path: [$DestinationPath] does not exist; Attempting to create the directory..."
                    New-Item -ItemType Directory -Path $DestinationPath -Confirm | Out-Null
                    $getDestinationPath = Get-Item $DestinationPath -ErrorAction Stop
                } catch {
                    throw $_
                }

                try {
                    #Write-Verbose "[$($MyInvocation.MyCommand.Name)] Attempting to read file(s) from path: [$($getPath.FullName)]"
                    $fileDetails = Convert-JavTitle -Path $getPath.FullName
                } catch {
                    Write-Warning "[$($MyInvocation.MyCommand.Name)] Path: [$Path] does not contain any video files or does not exist; Exiting..."
                    return
                }
                #Write-Debug "[$($MyInvocation.MyCommand.Name)] Converted file details: [$($fileDetails)]"

                # Match a single file and perform actions on it
                if ((Test-Path -Path $getPath.FullName -PathType Leaf) -and (Test-Path -Path $getDestinationPath.FullName -PathType Container)) {
                    Write-Verbose "[$($MyInvocation.MyCommand.Name)] Detected path: [$($getPath.FullName)] as single item"
                    Write-Host "[$($MyInvocation.MyCommand.Name)] ($index of $($fileDetails.Count)) Sorting [$($fileDetails.OriginalFileName)]"
                    if ($PSBoundParameters.ContainsKey('Url')) {
                        if ($Url -match ',') {
                            $urlList = $Url -split ','
                            $urlLocation = Test-UrlLocation -Url $urlList
                        } else {
                            $urlLocation = Test-UrlLocation -Url $Url
                        }
                        $dataObject = Get-AggregatedDataObject -UrlLocation $urlLocation -Settings $settings -ErrorAction 'SilentlyContinue'
                        Set-JavMovie -DataObject $dataObject -Settings $settings -Path $getPath.FullName -DestinationPath $getDestinationPath.FullName -ScriptRoot $ScriptRoot
                    } else {
                        $dataObject = Get-AggregatedDataObject -FileDetails $fileDetails -Settings $settings -R18:$R18 -Dmm:$Dmm -Javlibrary:$Javlibrary -ErrorAction 'SilentlyContinue' -ScriptRoot $ScriptRoot
                        Set-JavMovie -DataObject $dataObject -Settings $settings -Path $getPath.FullName -DestinationPath $getDestinationPath.FullName -ScriptRoot $ScriptRoot
                    }
                    # Match a directory/multiple files and perform actions on them
                } elseif (((Test-Path -Path $getPath.FullName -PathType Container) -and (Test-Path -Path $getDestinationPath.FullName -PathType Container)) -or $Apply.IsPresent) {
                    Write-Verbose "[$($MyInvocation.MyCommand.Name)] Detected path: [$($getPath.FullName)] as directory and destinationpath: [$($getDestinationPath.FullName)] as directory"
                    Write-Host "[$($MyInvocation.MyCommand.Name)] Performing directory sort on: [$($getDestinationPath.FullName)]"

                    if ($Multi.IsPresent) {
                        $throttleCount = $Settings.General.'multi-sort-throttle-limit'
                        try {
                            if ($Javlibrary) {
                                New-CloudflareSession -ScriptRoot $ScriptRoot
                            }
                            Start-MultiSort -Path $getPath.FullName -Throttle $throttleCount -DestinationPath $DestinationPath
                        } catch {
                            Write-Warning "[$($MyInvocation.MyCommand.Name)] There was an error starting multi sort for path: [$($getPath.FullName)] with destinationpath: [$DestinationPath] and threads: [$throttleCount]"
                        } finally {
                            # Stop all running jobs if script is stopped by user input
                            Write-Verbose "[$($MyInvocation.MyCommand.Name)] Sort has completed or has been stopped prematurely; Stopping all running jobs..."
                            Get-RSJob | Stop-RSJob
                        }
                    } else {
                        foreach ($video in $fileDetails) {
                            Write-Host "[$($MyInvocation.MyCommand.Name)] ($index of $($fileDetails.Count)) Sorting [$($video.OriginalFileName)]"
                            if ($video.PartNumber -le '1' -or $Multi.IsPresent) {
                                # Get data object for part 1 of a multipart video
                                $dataObject = Get-AggregatedDataObject -FileDetails $video -Settings $settings -R18:$R18 -Dmm:$Dmm -Javlibrary:$Javlibrary -ScriptRoot $ScriptRoot -ErrorAction 'SilentlyContinue'
                                $script:savedDataObject = $dataObject
                                Set-JavMovie -DataObject $dataObject -Settings $settings -Path $video.OriginalFullName -DestinationPath $getDestinationPath.FullName -Force:$Force -ScriptRoot $ScriptRoot
                            } elseif ($video.PartNumber -ge '2') {
                                # Use the saved data object for the following parts
                                $savedDataObject.PartNumber = $video.PartNumber
                                $fileDirName = Get-NewFileDirName -DataObject $savedDataObject
                                $savedDataObject.FileName = $fileDirName.FileName
                                $savedDataObject.OriginalFileName = $fileDirName.OriginalFileName
                                $savedDataObject.FolderName = $fileDirName.FolderName
                                $savedDataObject.DisplayName = $fileDirName.DisplayName
                                Set-JavMovie -DataObject $savedDataObject -Settings $settings -Path $video.OriginalFullName -DestinationPath $getDestinationPath.FullName -Force:$Force -ScriptRoot $ScriptRoot
                            }
                            $index++
                        }
                    }
                } else {
                    throw "[$($MyInvocation.MyCommand.Name)] Specified Path: [$Path] and/or DestinationPath: [$DestinationPath] did not match allowed types"
                }
            }
        }
    }

    end {
        Write-Host "[$($MyInvocation.MyCommand.Name)] Function ended"
    }
}


