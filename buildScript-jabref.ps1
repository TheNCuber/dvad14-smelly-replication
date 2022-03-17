# Data collection / build script for replication project
# DVAD14 Karlstads Universitet
# Noah Bühlmann
#
# PowerShell 7 or higher is required to run this script!

### Helper functions ###
function New-CompatibilityObject {
    param ([string]$javaVersion, [string]$gradleVersion, [string] $path)

    $myObject = [PSCustomObject]@{
        Java        = [version]::new($javaVersion)
        FirstGradle = [version]::new($gradleVersion)
        JDKPath     = $path
    }
    return $myObject
}

function New-BuildObject {
    param ([string]$commitId, [string]$dateTime)

    $myObject = [PSCustomObject]@{
        CommitId = $commitId
        DateTime = $dateTime
    }
    return $myObject
}

### Begin of Settings ###

# Commits for sequential mode (startIndex 0 = startCommit)
$startCommit = "main" # parameter for git checkout, can be refspec or commitId
$startIndex = 0
$endIndex = 100 # this determines how many builds will be performed

# Paths
$projectPath = $PSScriptRoot
$buildOutputPath = Join-Path $projectPath "jabref\build\classes\java"
$disposableArtifactsPaths = @(  (Join-Path $projectPath "jabref\src\main\generated"),
                                (Join-Path $projectPath "jabref\src\main\gen"),
                                (Join-Path $projectPath "jabref\build"))
$arcanJarPath = Join-Path $projectPath "Arcan-1.3.5\Arcan-1.3.5-SNAPSHOT.jar"
$normalJavaPath = Join-Path $projectPath "java\jdk-17" # main JDK version to be used to execute Arcan
$metricsPath = Join-Path $projectPath "commits"

# What CSV files by Arcan should be deleted to save space (not used for study or copied with modifications to new files)
$unusedCSV = @( "classCyclesShapeTable.csv","classCyclicDependencyMatrix.csv","classCyclicDependencyTable.csv",
                "packageCyclesShapeTable.csv","packageCyclicDependencyMatrix.csv","packageCyclicDependencyTable.csv",
                "CM.csv","PM.csv","HL.csv","UD.csv","mas.csv","pkHL.csv","UD30.csv")

# Array of commit ids for manual mode (only use when you know what you are doing)
# $manualCommits = @()
# $startIndex = 0
# $endIndex = $manualCommits.Count

# Set compatibilities between Java and Gradle and specify paths to all the installed JDKs
$compatibilityMatrix = @()
$compatibilityMatrix += New-CompatibilityObject -javaVersion "17.0" -gradleVersion "7.3" -path (Join-Path $projectPath "java\jdk-17")
$compatibilityMatrix += New-CompatibilityObject -javaVersion "16.0" -gradleVersion "7.0" -path (Join-Path $projectPath "java\jdk-16")
$compatibilityMatrix += New-CompatibilityObject -javaVersion "15.0" -gradleVersion "6.7" -path (Join-Path $projectPath "java\jdk-15")
$compatibilityMatrix += New-CompatibilityObject -javaVersion "14.0" -gradleVersion "6.3" -path (Join-Path $projectPath "java\jdk-14")
$compatibilityMatrix += New-CompatibilityObject -javaVersion "13.0" -gradleVersion "6.0" -path (Join-Path $projectPath "java\jdk-13")
$compatibilityMatrix += New-CompatibilityObject -javaVersion "12.0" -gradleVersion "5.4" -path (Join-Path $projectPath "java\jdk-12")
$compatibilityMatrix += New-CompatibilityObject -javaVersion "11.0" -gradleVersion "5.0" -path (Join-Path $projectPath "java\jdk-11")
$compatibilityMatrix += New-CompatibilityObject -javaVersion "10.0" -gradleVersion "4.7" -path (Join-Path $projectPath "java\jdk-10")
$compatibilityMatrix += New-CompatibilityObject -javaVersion "9.0" -gradleVersion "4.3" -path (Join-Path $projectPath "java\jdk-9")
$compatibilityMatrix += New-CompatibilityObject -javaVersion "8.0" -gradleVersion "2.0" -path (Join-Path $projectPath "java\jdk-8")

### End of Settings ###

# Check if Jabref is already cloned
Set-Location $projectPath
if(!(Test-Path "jabref")) {
    git clone "https://www.github.com/jabref/jabref.git"
}
Set-Location (Join-Path $projectPath "jabref")

# Sanity check of JDKs
foreach($compatibilityEntry in $compatibilityMatrix) {
    if(!(Test-Path $compatibilityEntry.JDKPath)) {
        Write-Error "JDK is not found in $($compatibilityEntry.JDKPath)"
        exit
    }
}

# Sequential mode (default)
git checkout $startCommit
# Manual mode
# git checkout $manualCommits[0]

$succededBuilds = @()
$failedBuilds = @()

for ($i = $startIndex; $i -lt $endIndex; $i++) {
    $totalBuilds = $endIndex-$startIndex
    Write-Host -Object "BUILD $($i+1) of $totalBuilds" -ForegroundColor DarkBlue -BackgroundColor White
    if($i -gt $startIndex) {
        # Sequential mode (default)
        git checkout HEAD~1
        # Manual mode
        # git checkout $manualCommits[$i]
    }

    # Using suitable Java JDK
    $configLine = (Get-Content -Path ".\gradle\wrapper\gradle-wrapper.properties" | Select-String -Pattern "distributionUrl").Line
    $gradleVersion = [Version]::new(($configLine | Select-String -Pattern "(?<=-)\d+.\d+(\.(\d+))*(?=-)").Matches[0])
    Write-Host "Gradle Version is: $gradleVersion"
    foreach($compatibilityEntry in $compatibilityMatrix) {
        if($gradleVersion -ge $compatibilityEntry.FirstGradle) {
            Write-Host "We can use Java $($compatibilityEntry.Java)"
            $Env:java_home = $compatibilityEntry.JDKPath
            break
        }
    }

    # Saving commitId and commit_time
    $commitTime = git show -s --format=%cd --date=format:'%Y-%m-%dT%H:%M:%S' HEAD
    $commitId = git rev-parse HEAD

    # Bugfix 1
    if($commitTime -le "2021-06-15T13:43:41") {
        Write-Host "Applying Bugfix 1" -ForegroundColor Yellow
        (Get-Content -Path "build.gradle" -Raw).replace("de.undercouch:citeproc-java:3.0.0-SNAPSHOT", "de.undercouch:citeproc-java:3.0.0-alpha.1") |
        Set-Content -Path "build.gradle"
    }

    # Bugfix 2
    if($commitTime -le "2021-03-10T21:32:18") {
        Write-Host "Applying Bugfix 2" -ForegroundColor Yellow
        (Get-Content -Path ".\src\main\java\org\jabref\logic\citationstyle\CSLAdapter.java" -Raw).replace("new DefaultAbbreviationProvider(), null, newStyle, `"en-US`");", "new DefaultAbbreviationProvider(), newStyle, `"en-US`");") |
        Set-Content -Path ".\src\main\java\org\jabref\logic\citationstyle\CSLAdapter.java"
    }
    
    # Bugfix 3
    if(($commitTime -le "2020-07-17T17:23:34") -and ($commitTime -ge "2020-05-15T09:27:24")) {
        Write-Host "Applying Bugfix 3" -ForegroundColor Yellow
        git cherry-pick 87e824237585e3a33a58c356607cc8a56ffeac54
        $appliedBugfix3 = $True
    } else {
        $appliedBugfix3 = $False
    }

    # Bugfix 4
    if(($commitTime -le "2019-11-18T06:33:27") -and ($commitTime -ge "2019-11-16T12:42:07")) {
        Write-Host "Applying Bugfix 4" -ForegroundColor Yellow
        (Get-Content -Path "build.gradle" -Raw).replace("io.github.java-diff-utils:java-diff-utils:4.5-SNAPSHOT", "io.github.java-diff-utils:java-diff-utils:4.5") |
        Set-Content -Path "build.gradle"
    }

    # Bugfix 5
    if(($commitTime -le "2019-10-12T11:33:41")) {
        Write-Host "Applying Bugfix 5" -ForegroundColor Yellow
        git add build.gradle
        git commit -m "bugfix"
        git cherry-pick 515551793a75ded6859a904e2bd11108ae1034e2
        $appliedBugfix5 = $True
    } else {
        $appliedBugfix5 = $False
    }

    # Compile project
    Write-Host "Starting gradle" -ForegroundColor Blue
    & .\gradlew compileJava
    Write-Host "Finished gradle" -ForegroundColor Blue
    if($LASTEXITCODE -eq 0) {
        Write-Host "Build of $commitId succeeded" -ForegroundColor Green
        $succededBuilds += New-BuildObject -commitId $commitId -dateTime $commitTime

        # Running Arcan
        $Env:java_home = $normalJavaPath
        $metricsFolder = (Join-Path $metricsPath $commitId)
        & java -jar $arcanJarPath -p $buildOutputPath -out $metricsFolder  -all
        Start-Sleep -Seconds 1

        # Add commitId and dateTime to csv's and remove unused csv rows for cyclic dependencies
        Import-Csv -LiteralPath (Join-Path -Path $metricsFolder -ChildPath "CM.csv") | 
        Select-Object @{Name='version';Expression={$commitId}},@{Name='commit_time';Expression={$commitTime}},* |
        Export-Csv -Path (Join-Path -Path $metricsFolder -ChildPath "CM2.csv") -NoTypeInformation -UseQuotes AsNeeded

        Import-Csv -LiteralPath (Join-Path -Path $metricsFolder -ChildPath "PM.csv") | 
        Select-Object @{Name='version';Expression={$commitId}},@{Name='commit_time';Expression={$commitTime}},* |
        Export-Csv -Path (Join-Path -Path $metricsFolder -ChildPath "PM2.csv") -NoTypeInformation -UseQuotes AsNeeded

        Import-Csv -LiteralPath (Join-Path -Path $metricsFolder -ChildPath "HL.csv") | 
        Select-Object @{Name='version';Expression={$commitId}},@{Name='commit_time';Expression={$commitTime}},* |
        Export-Csv -Path (Join-Path -Path $metricsFolder -ChildPath "HL2.csv") -NoTypeInformation -UseQuotes AsNeeded

        Import-Csv -LiteralPath (Join-Path -Path $metricsFolder -ChildPath "UD.csv") | 
        Select-Object @{Name='version';Expression={$commitId}},@{Name='commit_time';Expression={$commitTime}},* |
        Export-Csv -Path (Join-Path -Path $metricsFolder -ChildPath "UD2.csv") -NoTypeInformation -UseQuotes AsNeeded

        Import-Csv -LiteralPath (Join-Path -Path $metricsFolder -ChildPath "classCyclesShapeTable.csv") | 
        Select-Object @{Name='version';Expression={$commitId}},@{Name='commit_time';Expression={$commitTime}},IdCycle,CycleType,ElementList |
        Export-Csv -Path (Join-Path -Path $metricsFolder -ChildPath "classCL.csv") -NoTypeInformation -UseQuotes AsNeeded

        Import-Csv -LiteralPath (Join-Path -Path $metricsFolder -ChildPath "packageCyclesShapeTable.csv") | 
        Select-Object @{Name='version';Expression={$commitId}},@{Name='commit_time';Expression={$commitTime}},IdCycle,CycleType,ElementList |
        Export-Csv -Path (Join-Path -Path $metricsFolder -ChildPath "packageCL.csv") -NoTypeInformation -UseQuotes AsNeeded

        # Remove unused csv files
        $unusedCSV | ForEach-Object {
            Remove-Item -LiteralPath (Join-Path $metricsFolder $_) -Force
        }

        # Renaming
        @("CM2.csv","PM2.csv","HL2.csv","UD2.csv") | Foreach-Object {
            Rename-Item -Path (Join-Path $metricsFolder $_) -NewName ($_.substring(0,2) + ".csv")
        }
    }
    else {
        Write-Host "Build of $commitId failed" -ForegroundColor Red
        $failedBuilds += New-BuildObject -commitId $commitId -dateTime $commitTime
    }

    # Remove build output
    Remove-Item -Recurse -Force $buildOutputPath

    # Remove disposable artifacts
    $disposableArtifactsPaths | ForEach-Object {
        if(Test-Path -Path $_) {
            Remove-Item -Recurse -Force $_
        }
    }

    # Undo temporary commits
    if($appliedBugfix3) {
        git reset --hard HEAD^
    }
    if($appliedBugfix5) {
        git reset --hard HEAD^
        git reset --hard HEAD^
    }

    git reset --hard
}

# Print summary
Write-Host "---- SUMMARY ----"
$totalCommits = $succededBuilds.Count + $failedBuilds.Count
$successRate = [math]::Round($succededBuilds.Count / $totalCommits * 100,2)
Write-Host "Attempted to build and analyse $totalCommits commits."
Write-Host "$($succededBuilds.Count) / $totalCommits ($successRate%) succeded"
if ($failedBuilds.Count -gt 0) {
    Write-Host "List of failed commits:"
    $failedBuilds | ForEach-Object{
        Write-Host "$($_.DateTime) - $($_.CommitId)"
    }
}
