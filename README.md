# A Study on Architectural Smells Prediction - Replication Project
This project is a replication of the research described in the 2019 paper ["A Study on Architectural Smells Prediction"](https://www.doi.org/10.1109/SEAA.2019.00057) by Arcelli Fontana et al.

<img src="docs/kau.png" width="100" style="float: right;">

The work was carried out by Noah Bühlmann, Roland Widmer and Hugo Baptista and supervised by Sebastian Herold at the University of Karlstad in Karlstad, Sweden.

## Report
Our work is described and summarized in a report with additional background information about architectural smells. The report is available here:

[docs/report.pdf](docs/report.pdf)

## Replication package
This repository is essentially a replication package to our project that should allow anyone to replicate the steps that we have carried out.

### Additional data
Our results, the data that is produced in intermediate steps and additional required tools for the whole process are available for download here:

https://osf.io/p2jft/?view_only=761191a4e20e42d58d370d46f42faad4

### JDKs
In order to compile Jabref you will need several different versions of the Java Development Kit. They are available from the OpenJDK archive:

https://jdk.java.net/archive/

### Instructions

#### Installation
1. Clone this GitHub repository to your local machine
2. Make sure your local machine satisfies the following prerequisites:
   - [R version 4.0.5](https://cran.r-project.org/bin/windows/base/old/4.0.5) installed
   - Newest version of [R Studio](https://www.rstudio.com/products/rstudio/download/) installed
   - Cross-platform [PowerShell 7](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.2) installed
   - [Git](https://git-scm.com/downloads) installed
3. From the link mentioned under [additional data](#additional-data) download the auxillary material. In particular make sure that you:
   - unzip the file `Arcan-1.3.5.zip` to a directory `Arcan-1.3.5` in the root of the clone of this git repository
   - at least create the following empty directories in the root of the clone of this git repository:
      - `cache/jabref`
      - `data/jabref`
      - `commits`
4. From the link mentioned under [JDKs](#jdks) download the GA version of every major Java release between Java 9 and Java 17.
   - Place the unzipped folders with the naming scheme (jdk-*) in a directory `java` in the root of the clone of this git repository.
   - You should then have the following files in place:
      - `java/jdk-17/bin/javac.exe`
      - ...
      - `java/jdk-9/bin/javac.exe`

You now have all the necessary installation completed, to replicate our steps.

#### Data collection
The first step is the data collection. To execute it you can run the PowerShell script `buildScript-jabref.ps1`. It will clone [Jabref](https://www.github.com/jabref/jabref) from Github and iteratively build every commit in its commit history starting from the newest commit. After every successful build it will run the Arcan tool on the compiled class files to calculate the necessary metrics and save them to csv files in the `commits` directory.

You might need check the settings section in the PowerShell code. Especially if you want to split up the collection or resume it later you should adjust the following settings:

```{powershell}
# Commits for sequential mode (startIndex 0 = startCommit)
$startCommit = "main" # parameter for git checkout, can be refspec or commitId
$startIndex = 0
$endIndex = 100 # this determines how many builds will be performed
```

Our results of the data collection stage are available in the file `commits.zip` from the link mentioned under [additional data](#additional-data).
#### Data merging
After you have collected data from a sufficient amount of commits we have to merge the individual csv files into a single csv, that contains the data for all commits. To do this simply run run the PowerShell script `mergeScript-jabref.ps1`. This will write its output to the directory `data/jabref/`

Our results of the data merging stage are available in the files in the directory `data/jabref/` from the link mentioned under [additional data](#additional-data).
#### Pre-processing
Before we can run the actual machine learning a few pre-processing steps have to be carried out. The details of those steps are described in our [report](#report). In order to run the pre-processing open R Studio and knit the RMarkdown file `preprocessing-jabref.Rmd`. This will take as input the data located in `data/jabref/` and produce output in `cache/jabref/`.

Our results of the pre-processing stage are available in the files in the directory `cache/jabref/` and in the HTML file `preprocessing-jabref.html` from the link mentioned under [additional data](#additional-data).

#### Machine learning
Finally we can run the actual machine learning. The details are again described in our [report](#report). In order to run the machine learning open R Studio and knit the RMarkdown file `machineLearning-jabref.Rmd`. This will take as input the data located in `cache/jabref/` and produce an HTML file and csv files in the root directory.

Our final results are also available from the link mentioned under [additional data](#additional-data).
