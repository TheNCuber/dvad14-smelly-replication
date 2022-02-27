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

# Set compatibilities between Java and Gradle and specify paths to all the installed JDKs
$compatibilityMatrix = @()
$compatibilityMatrix += New-CompatibilityObject -javaVersion "17.0" -gradleVersion "7.3" -path "C:\Program Files\Java\jdk-17.0.2"
$compatibilityMatrix += New-CompatibilityObject -javaVersion "16.0" -gradleVersion "7.0" -path "C:\Users\noahb\.jdks\jdk-16"
$compatibilityMatrix += New-CompatibilityObject -javaVersion "15.0" -gradleVersion "6.7" -path "C:\Users\noahb\.jdks\jdk-15"
$compatibilityMatrix += New-CompatibilityObject -javaVersion "14.0" -gradleVersion "6.3" -path "C:\Users\noahb\.jdks\jdk-14"
$compatibilityMatrix += New-CompatibilityObject -javaVersion "13.0" -gradleVersion "6.0" -path "C:\Users\noahb\.jdks\jdk-13"
$compatibilityMatrix += New-CompatibilityObject -javaVersion "12.0" -gradleVersion "5.4" -path "C:\Users\noahb\.jdks\jdk-12"
$compatibilityMatrix += New-CompatibilityObject -javaVersion "11.0" -gradleVersion "5.0" -path "C:\Users\noahb\.jdks\jdk-11"
$compatibilityMatrix += New-CompatibilityObject -javaVersion "10.0" -gradleVersion "4.7" -path "C:\Users\noahb\.jdks\jdk-10"
$compatibilityMatrix += New-CompatibilityObject -javaVersion "9.0" -gradleVersion "4.3" -path "C:\Users\noahb\.jdks\jdk-9.0.4"
$compatibilityMatrix += New-CompatibilityObject -javaVersion "8.0" -gradleVersion "2.0" -path "C:\Users\noahb\.jdks\jdk-8"

# Commits for automatic mode (startIndex 0 = startCommit)
$startCommit = "main" # parameter for git checkout, can be refspec or commitId
$startIndex = 0
$endIndex = 100

$projectPath = "C:\Users\noahb\Desktop\jabref"
$buildOutputPath = "C:\Users\noahb\Desktop\jabref\build\classes\java"
$arcanJarPath = "C:\Users\noahb\Desktop\dvad14-smelly-replication\Arcan-1.3.5\Arcan-1.3.5-SNAPSHOT\Arcan-1.3.5-SNAPSHOT.jar"
$metricsPath = "C:\Users\noahb\Desktop\dvad14-smelly-replication\data"

# Main Java version
$normalJavaPath = "C:\Program Files\Java\jdk-17.0.2"

# What CSV files by Arcan should be deleted to save space (not used for study or copied with modifications to new files)
$unusedCSV = @( "classCyclesShapeTable.csv","classCyclicDependencyMatrix.csv","classCyclicDependencyTable.csv",
                "packageCyclesShapeTable.csv","packageCyclicDependencyMatrix.csv","packageCyclicDependencyTable.csv",
                "CM.csv","PM.csv","HL.csv","UD.csv","mas.csv","pkHL.csv","UD30.csv")

# Array of commit ids for manual mode (only use when you know what you are doing)
# $manualCommits = @()
# $startIndex = 0
# $endIndex = $manualCommits.Count

### End of Settings ###

Set-Location $projectPath

# Sequential mode (default)
git checkout $startCommit
# Manual mode
# #git checkout $manualCommits[0]

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
        (Get-Content -Path "build.gradle" -Raw) -replace "de.undercouch:citeproc-java:3.0.0-SNAPSHOT", "de.undercouch:citeproc-java:3.0.0-alpha.1" |
        Set-Content -Path "build.gradle"
    }

    # Compile project
    Write-Host "Starting gradle"
    #& .\gradlew build -x test
    & .\gradlew compileJava
    Write-Host "Finished gradle"
    if($LASTEXITCODE -eq 0) {
        Write-Host "Build of $commitId succeeded"
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
        Write-Host "Build of $commitId failed"
        $failedBuilds += New-BuildObject -commitId $commitId -dateTime $commitTime
    }
    Remove-Item -Recurse -Force $buildOutputPath
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
