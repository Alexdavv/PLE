# Study: ----
# Essure hysteroscopic vs laparoscopic and pregnancy algorithm outcome

# CohortMethod Installation & Load ----


# Uncomment to install CohortMethod
# install.packages("devtools")
# library(devtools)
# devtools::install_github("ohdsi/SqlRender")
# devtools::install_github("ohdsi/DatabaseConnector")
# devtools::install_github("ohdsi/OhdsiRTools")
# devtools::install_github("ohdsi/FeatureExtraction", ref = "v2.0.2")
# devtools::install_github("ohdsi/CohortMethod", ref = "v2.5.0")
# devtools::install_github("ohdsi/EmpiricalCalibration")

# Load the Cohort Method library
library(CohortMethod) 
library(SqlRender)
library(EmpiricalCalibration)

# Data extraction ----

# TODO: Insert your connection details here
connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = "redshift",
                                                                connectionString='jdbc:redshift://rwes-e360-prod-openclaims.cqn81xkeuvfy.us-east-1.redshift.amazonaws.com/prod_openclaims',
                                                                user = "usr_adavydov",
                                                                #port = 5439,
                                                                password = "Thursday18")
cdmDatabaseSchema <- "full_201807_omop_v5"
vocabularyDatabaseSchema <- "full_201807_omop_v5"
exposureDatabaseSchema <- "full_201807_omop_v5_rstudy"
outcomeDatabaseSchema <- "full_201807_omop_v5_rstudy"
exposureTable <- "cohort"
outcomeTable <- "cohort"
cdmVersion <- "5" 
outputFolder <- "/home/adavydov/PLE/5_1/open_claims/3200_3190_999/60m"
maxCores <- 1

targetCohortId <- 3200
comparatorCohortId <- 3190
comparatorCohortId2 <- 3180
outcomeCohortId <- 999
outcomeList <- c(outcomeCohortId)

# Default Prior & Control settings ----
defaultPrior <- Cyclops::createPrior("laplace", 
                                     exclude = c(0),
                                     useCrossValidation = TRUE)

defaultControl <- Cyclops::createControl(cvType = "auto",
                                         startingVariance = 0.01,
                                         noiseLevel = "quiet",
                                         tolerance  = 2e-07,
                                         cvRepetitions = 10,
                                         threads = 1)

# PLEASE NOTE ----
# If you want to use your code in a distributed network study
# you will need to create a temporary cohort table with common cohort IDs.
# The code below ASSUMES you are only running in your local network 
# where common cohort IDs have already been assigned in the cohort table.

# Get all ESSURE covariates to exclude hyst + lap Concept IDs for exclusion ----
sql <- paste("select distinct I.concept_id FROM
             ( 
             select concept_id from @vocabulary_database_schema.CONCEPT where concept_id in (2100997,2101014,2101597,2101590,4228197,2110199,2774801,4073283,4073284,4075014,2211565,43530800,2110228,2110760,4036943,4140385,2110242,2110243,4100097,4339218,4335020,4163273,4030568,40658177,2110200)and invalid_reason is null
             UNION  select c.concept_id
             from @vocabulary_database_schema.CONCEPT c
             join @vocabulary_database_schema.CONCEPT_ANCESTOR ca on c.concept_id = ca.descendant_concept_id
             and ca.ancestor_concept_id in (2100997,2101014,2101597,2101590,4228197,2110199,2774801,4073283,4073284,4075014,2211565,43530800,2110228,2110760,4036943,4140385,2110242,2110243,4100097,4339218,4335020,4163273,4030568,40658177,2110200)
             and c.invalid_reason is null
             
             ) I
             LEFT JOIN
             (
             select concept_id from @vocabulary_database_schema.CONCEPT where concept_id in (2103796)and invalid_reason is null
             
             ) E ON I.concept_id = E.concept_id
             WHERE E.concept_id is null
             ")
sql <- SqlRender::renderSql(sql, cdm_database_schema = cdmDatabaseSchema, vocabulary_database_schema = vocabularyDatabaseSchema)$sql
sql <- SqlRender::translateSql(sql, targetDialect = connectionDetails$dbms)$sql
connection <- DatabaseConnector::connect(connectionDetails)
excludedConcepts <- DatabaseConnector::querySql(connection, sql)
excludedConcepts <- excludedConcepts$CONCEPT_ID
DatabaseConnector::disconnect(connection)

# Get all  Concept IDs for inclusion ----

includedConcepts <- c()


# Get all  Concept IDs for exclusion in the outcome model ----

omExcludedConcepts <- c()

# Get all  Concept IDs for inclusion exclusion in the outcome model ----

omIncludedConcepts <- c()


# Get all  Concept IDs for empirical calibration ----

negativeControlConcepts <- c()


# Create drug comparator and outcome arguments by combining target + comparitor + outcome + negative controls ----
comparatorIds = list(laparo = comparatorCohortId,
                     iud = comparatorCohortId2)

dcos <- CohortMethod::createDrugComparatorOutcomes(targetId = targetCohortId,
                                                   comparatorId = comparatorIds,
                                                   excludedCovariateConceptIds = excludedConcepts,
                                                   includedCovariateConceptIds = includedConcepts,
                                                   outcomeIds = c(outcomeList, negativeControlConcepts))

drugComparatorOutcomesList <- list(dcos)



# Define which types of covariates must be constructed ----
covariateSettings <- FeatureExtraction::createCovariateSettings(useDemographicsGender = FALSE,
                                                                useDemographicsAge = FALSE, 
                                                                useDemographicsAgeGroup = TRUE,
                                                                useDemographicsRace = TRUE,
                                                                useDemographicsEthnicity = TRUE,
                                                                useDemographicsIndexYear = TRUE,
                                                                useDemographicsIndexMonth = FALSE,
                                                                useDemographicsPriorObservationTime = FALSE,
                                                                useDemographicsPostObservationTime = FALSE,
                                                                useDemographicsTimeInCohort = FALSE,
                                                                useDemographicsIndexYearMonth = FALSE,
                                                                useConditionOccurrenceAnyTimePrior = FALSE,
                                                                useConditionOccurrenceLongTerm = FALSE,
                                                                useConditionOccurrenceMediumTerm = FALSE,
                                                                useConditionOccurrenceShortTerm = FALSE,
                                                                useConditionOccurrenceInpatientAnyTimePrior = FALSE,
                                                                useConditionOccurrenceInpatientLongTerm = FALSE,
                                                                useConditionOccurrenceInpatientMediumTerm = FALSE,
                                                                useConditionOccurrenceInpatientShortTerm = FALSE,
                                                                useConditionEraAnyTimePrior = TRUE,
                                                                useConditionEraLongTerm = FALSE,
                                                                useConditionEraMediumTerm = FALSE,
                                                                useConditionEraShortTerm = FALSE,
                                                                useConditionEraOverlapping = FALSE,
                                                                useConditionEraStartLongTerm = FALSE,
                                                                useConditionEraStartMediumTerm = FALSE,
                                                                useConditionEraStartShortTerm = FALSE,
                                                                useConditionGroupEraAnyTimePrior = FALSE,
                                                                useConditionGroupEraLongTerm = FALSE,
                                                                useConditionGroupEraMediumTerm = FALSE,
                                                                useConditionGroupEraShortTerm = FALSE,
                                                                useConditionGroupEraOverlapping = FALSE,
                                                                useConditionGroupEraStartLongTerm = FALSE,
                                                                useConditionGroupEraStartMediumTerm = FALSE,
                                                                useConditionGroupEraStartShortTerm = FALSE,
                                                                useDrugExposureAnyTimePrior = FALSE,
                                                                useDrugExposureLongTerm = TRUE,
                                                                useDrugExposureMediumTerm = FALSE,
                                                                useDrugExposureShortTerm = FALSE, 
                                                                useDrugEraAnyTimePrior = FALSE,
                                                                useDrugEraLongTerm = FALSE,
                                                                useDrugEraMediumTerm = FALSE,
                                                                useDrugEraShortTerm = FALSE,
                                                                useDrugEraOverlapping = FALSE, 
                                                                useDrugEraStartLongTerm = FALSE, 
                                                                useDrugEraStartMediumTerm = FALSE,
                                                                useDrugEraStartShortTerm = FALSE,
                                                                useDrugGroupEraAnyTimePrior = FALSE,
                                                                useDrugGroupEraLongTerm = FALSE,
                                                                useDrugGroupEraMediumTerm = FALSE,
                                                                useDrugGroupEraShortTerm = FALSE,
                                                                useDrugGroupEraOverlapping = FALSE,
                                                                useDrugGroupEraStartLongTerm = FALSE,
                                                                useDrugGroupEraStartMediumTerm = FALSE,
                                                                useDrugGroupEraStartShortTerm = FALSE,
                                                                useProcedureOccurrenceAnyTimePrior = FALSE,
                                                                useProcedureOccurrenceLongTerm = TRUE,
                                                                useProcedureOccurrenceMediumTerm = FALSE,
                                                                useProcedureOccurrenceShortTerm = FALSE,
                                                                useDeviceExposureAnyTimePrior = FALSE,
                                                                useDeviceExposureLongTerm = FALSE,
                                                                useDeviceExposureMediumTerm = FALSE,
                                                                useDeviceExposureShortTerm = FALSE,
                                                                useMeasurementAnyTimePrior = FALSE,
                                                                useMeasurementLongTerm = TRUE, 
                                                                useMeasurementMediumTerm = FALSE,
                                                                useMeasurementShortTerm = FALSE,
                                                                useMeasurementValueAnyTimePrior = FALSE,
                                                                useMeasurementValueLongTerm = FALSE,
                                                                useMeasurementValueMediumTerm = FALSE,
                                                                useMeasurementValueShortTerm = FALSE,
                                                                useMeasurementRangeGroupAnyTimePrior = FALSE,
                                                                useMeasurementRangeGroupLongTerm = FALSE,
                                                                useMeasurementRangeGroupMediumTerm = FALSE,
                                                                useMeasurementRangeGroupShortTerm = FALSE,
                                                                useObservationAnyTimePrior = FALSE,
                                                                useObservationLongTerm = FALSE, 
                                                                useObservationMediumTerm = FALSE,
                                                                useObservationShortTerm = FALSE,
                                                                useCharlsonIndex = FALSE,
                                                                useDcsi = FALSE, 
                                                                useChads2 = FALSE,
                                                                useChads2Vasc = FALSE,
                                                                useDistinctConditionCountLongTerm = FALSE,
                                                                useDistinctConditionCountMediumTerm = FALSE,
                                                                useDistinctConditionCountShortTerm = FALSE,
                                                                useDistinctIngredientCountLongTerm = FALSE,
                                                                useDistinctIngredientCountMediumTerm = FALSE,
                                                                useDistinctIngredientCountShortTerm = FALSE,
                                                                useDistinctProcedureCountLongTerm = FALSE,
                                                                useDistinctProcedureCountMediumTerm = FALSE,
                                                                useDistinctProcedureCountShortTerm = FALSE,
                                                                useDistinctMeasurementCountLongTerm = FALSE,
                                                                useDistinctMeasurementCountMediumTerm = FALSE,
                                                                useDistinctMeasurementCountShortTerm = FALSE,
                                                                useVisitCountLongTerm = FALSE,
                                                                useVisitCountMediumTerm = FALSE,
                                                                useVisitCountShortTerm = FALSE,
                                                                longTermStartDays = -365,
                                                                mediumTermStartDays = -180, 
                                                                shortTermStartDays = -30, 
                                                                endDays = 0,
                                                                includedCovariateConceptIds = includedConcepts, 
                                                                addDescendantsToInclude = FALSE,
                                                                excludedCovariateConceptIds = excludedConcepts, 
                                                                addDescendantsToExclude = FALSE,
                                                                includedCovariateIds = c())																				 


getDbCmDataArgs <- CohortMethod::createGetDbCohortMethodDataArgs(washoutPeriod = 30,
                                                                 firstExposureOnly = FALSE,
                                                                 removeDuplicateSubjects = TRUE,
                                                                 studyStartDate = "",
                                                                 studyEndDate = "",
                                                                 excludeDrugsFromCovariates = FALSE,
                                                                 covariateSettings = covariateSettings)

createStudyPopArgs <- CohortMethod::createCreateStudyPopulationArgs(removeSubjectsWithPriorOutcome = FALSE,
                                                                    firstExposureOnly = FALSE,
                                                                    washoutPeriod = 30,
                                                                    removeDuplicateSubjects = TRUE,
                                                                    minDaysAtRisk = 0,
                                                                    riskWindowStart = 0,
                                                                    addExposureDaysToStart = FALSE,
                                                                    riskWindowEnd = 1800,
                                                                    addExposureDaysToEnd = FALSE)


fitOutcomeModelArgs1 <- CohortMethod::createFitOutcomeModelArgs(useCovariates = FALSE,
                                                                modelType = "logistic",
                                                                stratified = TRUE,
                                                                includeCovariateIds = omIncludedConcepts, 
                                                                excludeCovariateIds = omExcludedConcepts,
                                                                prior = defaultPrior, 
                                                                control = defaultControl)

createPsArgs1 <- CohortMethod::createCreatePsArgs(control = defaultControl) # Using only defaults
trimByPsArgs1 <- CohortMethod::createTrimByPsArgs(trimFraction = 0.05) 
trimByPsToEquipoiseArgs1 <- CohortMethod::createTrimByPsToEquipoiseArgs() # Using only defaults 
matchOnPsArgs1 <- CohortMethod::createMatchOnPsArgs(caliper = 0.25, caliperScale = "standardized", maxRatio = 1) 
stratifyByPsArgs1 <- CohortMethod::createStratifyByPsArgs() # Using only defaults 

cmAnalysis1 <- CohortMethod::createCmAnalysis(analysisId = 1,
                                              description = "Essure hysteroscopic vs laparoscopic on pregnancy outcome",
                                              comparatorType = "laparo",
                                              getDbCohortMethodDataArgs = getDbCmDataArgs,
                                              createStudyPopArgs = createStudyPopArgs,
                                              createPs = TRUE,
                                              createPsArgs = createPsArgs1,
                                              trimByPs = TRUE,
                                              trimByPsArgs = trimByPsArgs1,
                                              trimByPsToEquipoise = FALSE,
                                              trimByPsToEquipoiseArgs = trimByPsToEquipoiseArgs1,
                                              matchOnPs = TRUE,
                                              matchOnPsArgs = matchOnPsArgs1,
                                              stratifyByPs = FALSE,
                                              stratifyByPsArgs = stratifyByPsArgs1,
                                              computeCovariateBalance = TRUE,
                                              fitOutcomeModel = TRUE,
                                              fitOutcomeModelArgs = fitOutcomeModelArgs1)

cmAnalysis2 <- CohortMethod::createCmAnalysis(analysisId = 2,
                                              description = "Essure hysteroscopic vs IUD on pregnancy outcome",
                                              comparatorType = "iud",
                                              getDbCohortMethodDataArgs = getDbCmDataArgs,
                                              createStudyPopArgs = createStudyPopArgs,
                                              createPs = TRUE,
                                              createPsArgs = createPsArgs1,
                                              trimByPs = TRUE,
                                              trimByPsArgs = trimByPsArgs1,
                                              trimByPsToEquipoise = FALSE,
                                              trimByPsToEquipoiseArgs = trimByPsToEquipoiseArgs1,
                                              matchOnPs = TRUE,
                                              matchOnPsArgs = matchOnPsArgs1,
                                              stratifyByPs = FALSE,
                                              stratifyByPsArgs = stratifyByPsArgs1,
                                              computeCovariateBalance = TRUE,
                                              fitOutcomeModel = TRUE,
                                              fitOutcomeModelArgs = fitOutcomeModelArgs1)
cmAnalysisList <- list(cmAnalysis1, cmAnalysis2)

# Run the analysis ----
result <- CohortMethod::runCmAnalyses(connectionDetails = connectionDetails,
                                      cdmDatabaseSchema = cdmDatabaseSchema,
                                      exposureDatabaseSchema = exposureDatabaseSchema,
                                      exposureTable = exposureTable,
                                      outcomeDatabaseSchema = outcomeDatabaseSchema,
                                      outcomeTable = outcomeTable,
                                      cdmVersion = cdmVersion,
                                      outputFolder = outputFolder,
                                      cmAnalysisList = cmAnalysisList,
                                      drugComparatorOutcomesList = drugComparatorOutcomesList,
                                      getDbCohortMethodDataThreads = 1,
                                      createPsThreads = 1,
                                      psCvThreads = min(16, maxCores),
                                      computeCovarBalThreads = min(3, maxCores),
                                      createStudyPopThreads = min(3, maxCores),
                                      trimMatchStratifyThreads = min(10, maxCores),
                                      fitOutcomeModelThreads = max(1, round(maxCores/4)),
                                      outcomeCvThreads = min(4, maxCores),
                                      refitPsForEveryOutcome = FALSE)

## Summarize the results
analysisSummary <- CohortMethod::summarizeAnalyses(result)
head(analysisSummary)

# Perform Empirical Calibration ----
newSummary <- data.frame()
# Calibrate p-values:
for (drugComparatorOutcome in drugComparatorOutcomesList) {
  for (analysisId in unique(analysisSummary$analysisId)) {
    subset <- analysisSummary[analysisSummary$analysisId == analysisId &
                                analysisSummary$targetId == drugComparatorOutcome$targetId &
                                analysisSummary$comparatorId == drugComparatorOutcome$comparatorId, ]
    
    negControlSubset <- subset[analysisSummary$outcomeId %in% negativeControlConcepts, ]
    negControlSubset <- negControlSubset[!is.na(negControlSubset$logRr) & negControlSubset$logRr != 0, ]
    
    hoiSubset <- subset[!(analysisSummary$outcomeId %in% negativeControlConcepts), ]
    hoiSubset <- hoiSubset[!is.na(hoiSubset$logRr) & hoiSubset$logRr != 0, ]
    
    if (nrow(negControlSubset) > 10) {
      null <- EmpiricalCalibration::fitMcmcNull(negControlSubset$logRr, negControlSubset$seLogRr)
      
      # View the empirical calibration plot with only negative controls
      EmpiricalCalibration::plotCalibrationEffect(negControlSubset$logRr,
                                                  negControlSubset$seLogRr,showCis = TRUE)
      
      # Save the empirical calibration plot with only negative controls
      plotName <- paste("calEffectNoHois_a",analysisId, "_t", drugComparatorOutcome$targetId, "_c", drugComparatorOutcome$comparatorId, ".png", sep = "")
      EmpiricalCalibration::plotCalibrationEffect(negControlSubset$logRr,
                                                  negControlSubset$seLogRr,
                                                  fileName = file.path(outputFolder, plotName),showCis = TRUE)
      
      # View the empirical calibration plot with  negative controls and HOIs plotted
      EmpiricalCalibration::plotCalibrationEffect(negControlSubset$logRr,
                                                  negControlSubset$seLogRr,
                                                  hoiSubset$logRr, 
                                                  hoiSubset$seLogRr,showCis = TRUE)
      
      # Save the empirical calibration plot with  negative controls and HOIs plotted
      plotName <- paste("calEffect_a",analysisId, "_t", drugComparatorOutcome$targetId, "_c", drugComparatorOutcome$comparatorId, ".png", sep = "")
      EmpiricalCalibration::plotCalibrationEffect(negControlSubset$logRr,
                                                  negControlSubset$seLogRr,
                                                  hoiSubset$logRr, 
                                                  hoiSubset$seLogRr,
                                                  fileName = file.path(outputFolder, plotName),showCis = TRUE)
      
      calibratedP <- calibrateP(null, subset$logRr, subset$seLogRr)
      subset$calibratedP <- calibratedP$p
      subset$calibratedP_lb95ci <- calibratedP$lb95ci
      subset$calibratedP_ub95ci <- calibratedP$ub95ci
      mcmc <- attr(null, "mcmc")
      subset$null_mean <- mean(mcmc$chain[, 1])
      subset$null_sd <- 1/sqrt(mean(mcmc$chain[, 2]))
    } else {
      subset$calibratedP <- NA
      subset$calibratedP_lb95ci <- NA
      subset$calibratedP_ub95ci <- NA
      subset$null_mean <- NA
      subset$null_sd <- NA
    }
    newSummary <- rbind(newSummary, subset)
  }
}

# Results ----
for (drugComparatorOutcome in drugComparatorOutcomesList) {
  for (analysisId in unique(analysisSummary$analysisId)) {
    currentAnalysisSubset <- analysisSummary[analysisSummary$analysisId == analysisId &
                                               analysisSummary$targetId == drugComparatorOutcome$targetId &
                                               analysisSummary$comparatorId == drugComparatorOutcome$comparatorId &
                                               analysisSummary$outcomeId %in% outcomeList, ]
    
    for(currentOutcomeId in unique(currentAnalysisSubset$outcomeId)) {
      outputImageSuffix <- paste0("_a",analysisId, "_t", drugComparatorOutcome$targetId, "_c", drugComparatorOutcome$comparatorId, "_o", currentOutcomeId, ".png")
      
      cohortMethodFile <- result$cohortMethodDataFolder[result$target == currentAnalysisSubset$targetId &
                                                          result$comparatorId == currentAnalysisSubset$comparatorId &
                                                          result$outcomeId == currentOutcomeId &
                                                          result$analysisId == analysisId]
      
      cohortMethodData <- loadCohortMethodData(cohortMethodFile)
      
      studyPopFile <- result$studyPopFile[result$target == currentAnalysisSubset$targetId &
                                            result$comparatorId == currentAnalysisSubset$comparatorId &
                                            result$outcomeId == currentOutcomeId &
                                            result$analysisId == analysisId]
      
      # Return the attrition table for the study population ----
      studyPop <- readRDS(studyPopFile)
      getAttritionTable(studyPop)
      
      # View the attrition diagram
      drawAttritionDiagram(studyPop, 
                           treatmentLabel = "Target", 
                           comparatorLabel = "Comparator")
      
      # Save the attrition diagram ----
      plotName <- paste0("attritionDiagram", outputImageSuffix);
      drawAttritionDiagram(studyPop, 
                           treatmentLabel = "Target", 
                           comparatorLabel = "Comparator", 
                           fileName = file.path(outputFolder, plotName))
      
      
      psFile <- result$psFile[result$target == currentAnalysisSubset$targetId &
                                result$comparatorId == currentAnalysisSubset$comparatorId &
                                result$outcomeId == currentOutcomeId &
                                result$analysisId == analysisId]
      
      ps <- readRDS(psFile)
      
      # Compute the area under the receiver-operator curve (AUC) for the propensity score model ----
      CohortMethod::computePsAuc(ps)
      
      # Plot the propensity score distribution ----
      CohortMethod::plotPs(ps, 
                           scale = "preference")
      
      # Save the propensity score distribution ----
      plotName <- paste0("propensityScorePlot", outputImageSuffix);
      CohortMethod::plotPs(ps, 
                           scale = "preference",
                           fileName = file.path(outputFolder, plotName))
      
      
      # Inspect the propensity model ----
      propensityModel <- CohortMethod::getPsModel(ps, cohortMethodData)
      head(propensityModel)
      
      
      strataFile <- result$strataFile[result$target == currentAnalysisSubset$targetId &
                                        result$comparatorId == currentAnalysisSubset$comparatorId &
                                        result$outcomeId == currentOutcomeId &
                                        result$analysisId == analysisId]
      strataPop <- readRDS(strataFile)
      
      # View PS With Population Trimmed By Percentile ----
      CohortMethod::plotPs(strataPop, 
                           ps, 
                           scale = "preference")
      
      # Save PS With Population Trimmed By Percentile ----
      plotName <- paste0("propensityScorePlotStrata", outputImageSuffix);
      CohortMethod::plotPs(strataPop, 
                           ps, 
                           scale = "preference",
                           fileName = file.path(outputFolder, plotName))
      
      
      # Get the attrition table and diagram for the strata pop ----
      CohortMethod::getAttritionTable(strataPop)
      
      # View the attrition diagram for the strata pop ----
      CohortMethod::drawAttritionDiagram(strataPop)
      
      # Save the attrition diagram for the strata pop ----
      plotName <- paste0("attritionDiagramStrata", outputImageSuffix);
      CohortMethod::drawAttritionDiagram(strataPop,
                                         fileName = file.path(outputFolder, plotName))
      
      
      # Plot the covariate balance ----
      balanceFile <- result$covariateBalanceFile[result$target == currentAnalysisSubset$targetId &
                                                   result$comparatorId == currentAnalysisSubset$comparatorId &
                                                   result$outcomeId == currentOutcomeId &
                                                   result$analysisId == analysisId]
      balance <- readRDS(balanceFile)
      
      # View the covariate balance scatter plot ----
      CohortMethod::plotCovariateBalanceScatterPlot(balance)
      
      # Save the covariate balance scatter plot ----
      plotName <- paste0("covBalScatter", outputImageSuffix);
      CohortMethod::plotCovariateBalanceScatterPlot(balance,
                                                    fileName = file.path(outputFolder, plotName))
      
      # View the plot of top variables ----
      CohortMethod::plotCovariateBalanceOfTopVariables(balance)
      
      # Save the plot of top variables ----
      plotName <- paste0("covBalTop", outputImageSuffix);
      CohortMethod::plotCovariateBalanceOfTopVariables(balance,
                                                       fileName = file.path(outputFolder, plotName))
      
      
      # Outcome Model ----
      
      outcomeFile <- result$outcomeModelFile[result$target == currentAnalysisSubset$targetId &
                                               result$comparatorId == currentAnalysisSubset$comparatorId &
                                               result$outcomeId == currentOutcomeId &
                                               result$analysisId == analysisId]
      outcomeModel <- readRDS(outcomeFile)
      
      # Calibrated results -----
      outcomeSummary <- newSummary[newSummary$targetId == currentAnalysisSubset$targetId & 
                                     newSummary$comparatorId == currentAnalysisSubset$comparatorId & 
                                     newSummary$outcomeId == currentOutcomeId & 
                                     newSummary$analysisId == analysisId, ]  
      
      outcomeSummaryOutput <- data.frame(outcomeSummary$rr, 
                                         outcomeSummary$ci95lb, 
                                         outcomeSummary$ci95ub, 
                                         outcomeSummary$logRr, 
                                         outcomeSummary$seLogRr,
                                         outcomeSummary$p,
                                         outcomeSummary$calibratedP, 
                                         outcomeSummary$calibratedP_lb95ci,
                                         outcomeSummary$calibratedP_ub95ci,
                                         outcomeSummary$null_mean,
                                         outcomeSummary$null_sd)
      
      colnames(outcomeSummaryOutput) <- c("Estimate", 
                                          "lower .95", 
                                          "upper .95", 
                                          "logRr", 
                                          "seLogRr", 
                                          "p", 
                                          "cal p",  
                                          "cal p - lower .95",  
                                          "cal p - upper .95", 
                                          "null mean",  
                                          "null sd")
      
      rownames(outcomeSummaryOutput) <- "treatment"
      
      # View the outcome model -----
      outcomeModelOutput <- capture.output(outcomeModel)
      outcomeModelOutput <- head(outcomeModelOutput,n=length(outcomeModelOutput)-2)
      outcomeSummaryOutput <- capture.output(printCoefmat(outcomeSummaryOutput))
      outcomeModelOutput <- c(outcomeModelOutput, outcomeSummaryOutput)
      writeLines(outcomeModelOutput)
      
    }
  }
}
