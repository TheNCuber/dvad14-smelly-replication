# A Study on Architectural Smells Prediction - Replication Project
This project is a replication of the research described in the 2019 paper ["A Study on Architectural Smells Prediction"](https://www.doi.org/10.1109/SEAA.2019.00057) by Arcelli Fontana et al.

The work is carried out by Noah Bühlmann, Roland Widmer and Hugo Baptista and supervised by Sebastian Herold at the University of Karlstad in Karlstad, Sweden.

## Table of contents
- [Initial remarks by Sebastian](#initial-remarks-by-sebastian)
- [Troubleshooting remarks by Roland](#troubleshooting-remarks-by-roland)
- [Troubleshooting remarks by Noah](#troubleshooting-remarks-by-noah)

## Initial remarks by Sebastian
- replication package provided by authors is not bug free
- one architectural smell mentioned in the paper - Implicit Cross Package Dependency (ICPD) - is not supported by the ARCAN tool for architectural smells detection
- if the machine learning models crash, the number of commits should be constrained (e.g. to the last ten per month)
- during the preprocessing phase features without variance are removed, it should therefor be checked that the dataset is not empty after preprocessing

## Troubleshooting remarks by Roland
### Install DMwR

Package is outdated and only available in the archives.

1. Install dependencies of DMwR:

   ```R
    install.packages('abind')
    install.packages('zoo')
    install.packages('xts')
    install.packages('quantmod')
    install.packages('ROCR')
   ```

2. Go to https://cran.r-project.org/package=DMwR and download the tar.gz file. You can install it using the package tab in RStudio

### Install randomForest

Package not available for specific R version.

1. Go to https://cran.r-project.org/src/contrib/Archive/randomForest/ and download the tar.gz file. Install it using the package tab in RStudio.

### Package compilation fails: 'make' not found

1. Install RTools: https://cran.r-project.org/bin/windows/Rtools/rtools40.html

2. Follow the instructions to add Rtools on the PATH.

3. Restart R / RStudio

4. Test it with `Sys.which("make")` (should return `## "C:\\rtools40\\usr\\bin\\make.exe"`)

### NB model fails

1. comment out all occurrences of the Naive Bayes model
2. don't forget to remove the NB confusion matrices as well

## Troubleshooting remarks by Noah

### Setup
1. Use R version 4.0.5 and newest version of R studio for windows

### replication_package/r-mrkdwn-arcan-evolution-jgit.Rmd
1. Fix duplicated chunk labels
2. Insert following bug fix twice (see corresponding commit):

    ```R
    setDT(VariableName)
    is.data.table(VariableName)
    ```
