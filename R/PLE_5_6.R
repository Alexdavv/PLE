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
library(parallel)

# Data extraction ----

# TODO: Insert your connection details here
connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = "redshift",
                                                                connectionString='jdbc:redshift://rwes-e360-analytics.cqn81xkeuvfy.us-east-1.redshift.amazonaws.com/prod_pmtx',
                                                                user = "usr_adavydov",
                                                                #port = 5439,
                                                                password = "Thursday18")
cdmDatabaseSchema <- "full_201803_omop_v5"
vocabularyDatabaseSchema <- "full_201803_omop_v5"
exposureDatabaseSchema <- "full_201803_omop_v5_rstudy"
outcomeDatabaseSchema <- "full_201803_omop_v5_rstudy"
exposureTable <- "cohort"
outcomeTable <- "cohort"
cdmVersion <- "5" 
outputFolder <- "~/PLE/5_6/pharmetrix201803/hyst_lap_-0Days_1-1/1no_trim_cov_procedures+1"
setwd(outputFolder)
maxCores <- 64
targetCohortId <- 3200
comparatorCohortId <- 3190
outcomeCohortId1 <- 999
outcomeCohortId2 <- 321
outcomeCohortId3 <- 468
outcomeCohortId4 <- 476
outcomeCohortId5 <- 478
outcomeCohortId6 <- 479
outcomeCohortId7 <- 480
outcomeCohortId8 <- 489
outcomeCohortId9 <- 490

outcomeList <- c(outcomeCohortId1, outcomeCohortId2, outcomeCohortId3, outcomeCohortId4, outcomeCohortId5,
                 outcomeCohortId6, outcomeCohortId7, outcomeCohortId8, outcomeCohortId9)

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

# Get all ESSURE Covariates to exclude
sql <- paste("select distinct I.concept_id FROM
( 
  select concept_id from @vocabulary_database_schema.CONCEPT where concept_id in 

(4228197,2774801,4073283,4073284,4075014,43530800,2110228,4036943,4140385,2110242,2722199,2110243,4100097,4339218,2805354,2781149,40658177, 2101014)and invalid_reason is null
UNION  select c.concept_id
  from @vocabulary_database_schema.CONCEPT c
  join @vocabulary_database_schema.CONCEPT_ANCESTOR ca on c.concept_id = ca.descendant_concept_id
  and ca.ancestor_concept_id in 

(4228197,2774801,4073283,4073284,4075014,43530800,2110228,4036943,4140385,2110242,2722199,2110243,4100097,4339218,2805354,2781149,40658177, 2101014)
  and c.invalid_reason is null

) I
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


# Get all Essure negative control Concept IDs for empirical calibration ----
negativeControlConcepts <- c(4243973,4294382,4189286,4142645,4080549,78619,73241,433577,372448,201606,257315,374919,257628,141932,380706,139099,443454,435783,439264,378427,443943,442068,444130,4115367,4193704)



# Create drug comparator and outcome arguments by combining target + comparitor + outcome + negative controls ----
dcos <- CohortMethod::createTargetComparatorOutcomes(targetId = targetCohortId,
                                                   comparatorId = comparatorCohortId,
                                                   excludedCovariateConceptIds = excludedConcepts,
                                                   includedCovariateConceptIds = includedConcepts,
                                                   outcomeIds = c(outcomeList, negativeControlConcepts))


targetComparatorOutcomesList <- list(dcos)



# Define which types of covariates must be constructed ----
covariateSettings1 <- FeatureExtraction::createCovariateSettings(useDemographicsGender = FALSE,
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
                                                                 useConditionOccurrencePrimaryInpatientAnyTimePrior = FALSE,
                                                                 useConditionOccurrencePrimaryInpatientLongTerm = FALSE,
                                                                 useConditionOccurrencePrimaryInpatientMediumTerm = FALSE,
                                                                 useConditionOccurrencePrimaryInpatientShortTerm = FALSE,
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

covariateSettings7 <- FeatureExtraction::createCovariateSettings(useDemographicsGender = FALSE,
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
                                                                 useConditionOccurrencePrimaryInpatientAnyTimePrior = FALSE,
                                                                 useConditionOccurrencePrimaryInpatientLongTerm = FALSE,
                                                                 useConditionOccurrencePrimaryInpatientMediumTerm = FALSE,
                                                                 useConditionOccurrencePrimaryInpatientShortTerm = FALSE,
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
                                                                 endDays = -7,
                                                                 includedCovariateConceptIds = includedConcepts, 
                                                                 addDescendantsToInclude = FALSE,
                                                                 excludedCovariateConceptIds = excludedConcepts, 
                                                                 addDescendantsToExclude = FALSE,
                                                                 includedCovariateIds = c())


getDbCmDataArgs1 <- CohortMethod::createGetDbCohortMethodDataArgs(washoutPeriod = 30,
                                                                  firstExposureOnly = FALSE,
                                                                  removeDuplicateSubjects = TRUE,
                                                                  studyStartDate = "20120501",
                                                                  studyEndDate = "",
                                                                  excludeDrugsFromCovariates = FALSE,
                                                                  covariateSettings = covariateSettings1)

getDbCmDataArgs7 <- CohortMethod::createGetDbCohortMethodDataArgs(washoutPeriod = 30,
                                                                  firstExposureOnly = FALSE,
                                                                  removeDuplicateSubjects = TRUE,
                                                                  studyStartDate = "20120501",
                                                                  studyEndDate = "",
                                                                  excludeDrugsFromCovariates = FALSE,
                                                                  covariateSettings = covariateSettings7)

createStudyPopArgs1 <- CohortMethod::createCreateStudyPopulationArgs(removeSubjectsWithPriorOutcome = FALSE,
                                                                     firstExposureOnly = FALSE,
                                                                     washoutPeriod = 30,
                                                                     removeDuplicateSubjects = TRUE,
                                                                     minDaysAtRisk = 0,
                                                                     riskWindowStart = 0,
                                                                     addExposureDaysToStart = FALSE,
                                                                     riskWindowEnd = 90,
                                                                     addExposureDaysToEnd = FALSE)

createStudyPopArgs2 <- CohortMethod::createCreateStudyPopulationArgs(removeSubjectsWithPriorOutcome = FALSE,
                                                                     firstExposureOnly = FALSE,
                                                                     washoutPeriod = 30,
                                                                     removeDuplicateSubjects = TRUE,
                                                                     minDaysAtRisk = 0,
                                                                     riskWindowStart = 0,
                                                                     addExposureDaysToStart = FALSE,
                                                                     riskWindowEnd = 180,
                                                                     addExposureDaysToEnd = FALSE)

createStudyPopArgs3 <- CohortMethod::createCreateStudyPopulationArgs(removeSubjectsWithPriorOutcome = FALSE,
                                                                     firstExposureOnly = FALSE,
                                                                     washoutPeriod = 30,
                                                                     removeDuplicateSubjects = TRUE,
                                                                     minDaysAtRisk = 0,
                                                                     riskWindowStart = 0,
                                                                     addExposureDaysToStart = FALSE,
                                                                     riskWindowEnd = 360,
                                                                     addExposureDaysToEnd = FALSE)

createStudyPopArgs4 <- CohortMethod::createCreateStudyPopulationArgs(removeSubjectsWithPriorOutcome = FALSE,
                                                                     firstExposureOnly = FALSE,
                                                                     washoutPeriod = 30,
                                                                     removeDuplicateSubjects = TRUE,
                                                                     minDaysAtRisk = 0,
                                                                     riskWindowStart = 0,
                                                                     addExposureDaysToStart = FALSE,
                                                                     riskWindowEnd = 720,
                                                                     addExposureDaysToEnd = FALSE)

createStudyPopArgs5 <- CohortMethod::createCreateStudyPopulationArgs(removeSubjectsWithPriorOutcome = FALSE,
                                                                     firstExposureOnly = FALSE,
                                                                     washoutPeriod = 30,
                                                                     removeDuplicateSubjects = TRUE,
                                                                     minDaysAtRisk = 0,
                                                                     riskWindowStart = 0,
                                                                     addExposureDaysToStart = FALSE,
                                                                     riskWindowEnd = 1080,
                                                                     addExposureDaysToEnd = FALSE)

createStudyPopArgs6 <- CohortMethod::createCreateStudyPopulationArgs(removeSubjectsWithPriorOutcome = FALSE,
                                                                     firstExposureOnly = FALSE,
                                                                     washoutPeriod = 30,
                                                                     removeDuplicateSubjects = TRUE,
                                                                     minDaysAtRisk = 0,
                                                                     riskWindowStart = 0,
                                                                     addExposureDaysToStart = FALSE,
                                                                     riskWindowEnd = 1440,
                                                                     addExposureDaysToEnd = FALSE)

createStudyPopArgs7 <- CohortMethod::createCreateStudyPopulationArgs(removeSubjectsWithPriorOutcome = FALSE,
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
#matchOnPsArgs2 <- CohortMethod::createMatchOnPsArgs(caliper = 0.25, caliperScale = "standardized", maxRatio = 2)
#matchOnPsAndCovariatesArgs1 <- CohortMethod::createMatchOnPsAndCovariatesArgs(caliper = 0.25, caliperScale = "standardized", maxRatio = 1, includedConcepts)
#matchOnPsAndCovariatesArgs2 <- CohortMethod::createMatchOnPsAndCovariatesArgs(caliper = 0.25, caliperScale = "standardized", maxRatio = 2, includedConcepts)


stratifyByPsArgs1 <- CohortMethod::createStratifyByPsArgs() # Using only defaults

cmAnalysis1 <- CohortMethod::createCmAnalysis(analysisId = 1,
                                              description = "Essure hysteroscopic vs laparoscopic and pregnancy algorithm outcome",
                                              getDbCohortMethodDataArgs = getDbCmDataArgs1,
                                              createStudyPopArgs = createStudyPopArgs1,
                                              createPs = TRUE,
                                              createPsArgs = createPsArgs1,
                                              trimByPs = FALSE,
                                              trimByPsArgs = trimByPsArgs1,
                                              trimByPsToEquipoise = FALSE,
                                              trimByPsToEquipoiseArgs = trimByPsToEquipoiseArgs1,
                                              matchOnPs = TRUE,
                                              matchOnPsArgs = matchOnPsArgs1,
                                              stratifyByPs = FALSE,
                                              stratifyByPsArgs = stratifyByPsArgs1,
                                              #computeCovariateBalance = TRUE,
                                              fitOutcomeModel = TRUE,
                                              fitOutcomeModelArgs = fitOutcomeModelArgs1,
                                              matchOnPsAndCovariates = FALSE,
                                              stratifyByPsAndCovariates = FALSE)

cmAnalysis2 <- CohortMethod::createCmAnalysis(analysisId = 2,
                                              description = "Essure hysteroscopic vs laparoscopic and pregnancy algorithm outcome",
                                              getDbCohortMethodDataArgs = getDbCmDataArgs1,
                                              createStudyPopArgs = createStudyPopArgs2,
                                              createPs = TRUE,
                                              createPsArgs = createPsArgs1,
                                              trimByPs = FALSE,
                                              trimByPsArgs = trimByPsArgs1,
                                              trimByPsToEquipoise = FALSE,
                                              trimByPsToEquipoiseArgs = trimByPsToEquipoiseArgs1,
                                              matchOnPs = TRUE,
                                              matchOnPsArgs = matchOnPsArgs1,
                                              stratifyByPs = FALSE,
                                              stratifyByPsArgs = stratifyByPsArgs1,
                                              #computeCovariateBalance = TRUE,
                                              fitOutcomeModel = TRUE,
                                              fitOutcomeModelArgs = fitOutcomeModelArgs1,
                                              matchOnPsAndCovariates = FALSE,
                                              stratifyByPsAndCovariates = FALSE)

cmAnalysis3 <- CohortMethod::createCmAnalysis(analysisId = 3,
                                              description = "Essure hysteroscopic vs laparoscopic and pregnancy algorithm outcome",
                                              getDbCohortMethodDataArgs = getDbCmDataArgs1,
                                              createStudyPopArgs = createStudyPopArgs3,
                                              createPs = TRUE,
                                              createPsArgs = createPsArgs1,
                                              trimByPs = FALSE,
                                              trimByPsArgs = trimByPsArgs1,
                                              trimByPsToEquipoise = FALSE,
                                              trimByPsToEquipoiseArgs = trimByPsToEquipoiseArgs1,
                                              matchOnPs = TRUE,
                                              matchOnPsArgs = matchOnPsArgs1,
                                              stratifyByPs = FALSE,
                                              stratifyByPsArgs = stratifyByPsArgs1,
                                              #computeCovariateBalance = TRUE,
                                              fitOutcomeModel = TRUE,
                                              fitOutcomeModelArgs = fitOutcomeModelArgs1,
                                              matchOnPsAndCovariates = FALSE,
                                              stratifyByPsAndCovariates = FALSE)

cmAnalysis4 <- CohortMethod::createCmAnalysis(analysisId = 4,
                                              description = "Essure hysteroscopic vs laparoscopic and pregnancy algorithm outcome",
                                              getDbCohortMethodDataArgs = getDbCmDataArgs1,
                                              createStudyPopArgs = createStudyPopArgs4,
                                              createPs = TRUE,
                                              createPsArgs = createPsArgs1,
                                              trimByPs = FALSE,
                                              trimByPsArgs = trimByPsArgs1,
                                              trimByPsToEquipoise = FALSE,
                                              trimByPsToEquipoiseArgs = trimByPsToEquipoiseArgs1,
                                              matchOnPs = TRUE,
                                              matchOnPsArgs = matchOnPsArgs1,
                                              stratifyByPs = FALSE,
                                              stratifyByPsArgs = stratifyByPsArgs1,
                                              #computeCovariateBalance = TRUE,
                                              fitOutcomeModel = TRUE,
                                              fitOutcomeModelArgs = fitOutcomeModelArgs1,
                                              matchOnPsAndCovariates = FALSE,
                                              stratifyByPsAndCovariates = FALSE)

cmAnalysis5 <- CohortMethod::createCmAnalysis(analysisId = 5,
                                              description = "Essure hysteroscopic vs laparoscopic and pregnancy algorithm outcome",
                                              getDbCohortMethodDataArgs = getDbCmDataArgs1,
                                              createStudyPopArgs = createStudyPopArgs5,
                                              createPs = TRUE,
                                              createPsArgs = createPsArgs1,
                                              trimByPs = FALSE,
                                              trimByPsArgs = trimByPsArgs1,
                                              trimByPsToEquipoise = FALSE,
                                              trimByPsToEquipoiseArgs = trimByPsToEquipoiseArgs1,
                                              matchOnPs = TRUE,
                                              matchOnPsArgs = matchOnPsArgs1,
                                              stratifyByPs = FALSE,
                                              stratifyByPsArgs = stratifyByPsArgs1,
                                              #computeCovariateBalance = TRUE,
                                              fitOutcomeModel = TRUE,
                                              fitOutcomeModelArgs = fitOutcomeModelArgs1,
                                              matchOnPsAndCovariates = FALSE,
                                              stratifyByPsAndCovariates = FALSE)

cmAnalysis6 <- CohortMethod::createCmAnalysis(analysisId = 6,
                                              description = "Essure hysteroscopic vs laparoscopic and pregnancy algorithm outcome",
                                              getDbCohortMethodDataArgs = getDbCmDataArgs1,
                                              createStudyPopArgs = createStudyPopArgs6,
                                              createPs = TRUE,
                                              createPsArgs = createPsArgs1,
                                              trimByPs = FALSE,
                                              trimByPsArgs = trimByPsArgs1,
                                              trimByPsToEquipoise = FALSE,
                                              trimByPsToEquipoiseArgs = trimByPsToEquipoiseArgs1,
                                              matchOnPs = TRUE,
                                              matchOnPsArgs = matchOnPsArgs1,
                                              stratifyByPs = FALSE,
                                              stratifyByPsArgs = stratifyByPsArgs1,
                                              #computeCovariateBalance = TRUE,
                                              fitOutcomeModel = TRUE,
                                              fitOutcomeModelArgs = fitOutcomeModelArgs1,
                                              matchOnPsAndCovariates = FALSE,
                                              stratifyByPsAndCovariates = FALSE)

cmAnalysis7 <- CohortMethod::createCmAnalysis(analysisId = 7,
                                              description = "Essure hysteroscopic vs laparoscopic and pregnancy algorithm outcome",
                                              getDbCohortMethodDataArgs = getDbCmDataArgs1,
                                              createStudyPopArgs = createStudyPopArgs7,
                                              createPs = TRUE,
                                              createPsArgs = createPsArgs1,
                                              trimByPs = FALSE,
                                              trimByPsArgs = trimByPsArgs1,
                                              trimByPsToEquipoise = FALSE,
                                              trimByPsToEquipoiseArgs = trimByPsToEquipoiseArgs1,
                                              matchOnPs = TRUE,
                                              matchOnPsArgs = matchOnPsArgs1,
                                              stratifyByPs = FALSE,
                                              stratifyByPsArgs = stratifyByPsArgs1,
                                              #computeCovariateBalance = TRUE,
                                              fitOutcomeModel = TRUE,
                                              fitOutcomeModelArgs = fitOutcomeModelArgs1,
                                              matchOnPsAndCovariates = FALSE,
                                              stratifyByPsAndCovariates = FALSE)

cmAnalysis8 <- CohortMethod::createCmAnalysis(analysisId = 8,
                                              description = "Essure hysteroscopic vs laparoscopic and pregnancy algorithm outcome",
                                              getDbCohortMethodDataArgs = getDbCmDataArgs1,
                                              createStudyPopArgs = createStudyPopArgs1,
                                              createPs = TRUE,
                                              createPsArgs = createPsArgs1,
                                              trimByPs = TRUE,
                                              trimByPsArgs = trimByPsArgs1,
                                              trimByPsToEquipoise = FALSE,
                                              trimByPsToEquipoiseArgs = trimByPsToEquipoiseArgs1,
                                              matchOnPs = TRUE,
                                              matchOnPsArgs = matchOnPsArgs2,
                                              stratifyByPs = FALSE,
                                              stratifyByPsArgs = stratifyByPsArgs1,
                                              computeCovariateBalance = TRUE,
                                              fitOutcomeModel = TRUE,
                                              fitOutcomeModelArgs = fitOutcomeModelArgs1)

cmAnalysis9 <- CohortMethod::createCmAnalysis(analysisId = 9,
                                              description = "Essure hysteroscopic vs laparoscopic and pregnancy algorithm outcome",
                                              getDbCohortMethodDataArgs = getDbCmDataArgs1,
                                              createStudyPopArgs = createStudyPopArgs2,
                                              createPs = TRUE,
                                              createPsArgs = createPsArgs1,
                                              trimByPs = TRUE,
                                              trimByPsArgs = trimByPsArgs1,
                                              trimByPsToEquipoise = FALSE,
                                              trimByPsToEquipoiseArgs = trimByPsToEquipoiseArgs1,
                                              matchOnPs = TRUE,
                                              matchOnPsArgs = matchOnPsArgs2,
                                              stratifyByPs = FALSE,
                                              stratifyByPsArgs = stratifyByPsArgs1,
                                              computeCovariateBalance = TRUE,
                                              fitOutcomeModel = TRUE,
                                              fitOutcomeModelArgs = fitOutcomeModelArgs1)

cmAnalysis10 <- CohortMethod::createCmAnalysis(analysisId = 10,
                                               description = "Essure hysteroscopic vs laparoscopic and pregnancy algorithm outcome",
                                               getDbCohortMethodDataArgs = getDbCmDataArgs1,
                                               createStudyPopArgs = createStudyPopArgs3,
                                               createPs = TRUE,
                                               createPsArgs = createPsArgs1,
                                               trimByPs = TRUE,
                                               trimByPsArgs = trimByPsArgs1,
                                               trimByPsToEquipoise = FALSE,
                                               trimByPsToEquipoiseArgs = trimByPsToEquipoiseArgs1,
                                               matchOnPs = TRUE,
                                               matchOnPsArgs = matchOnPsArgs2,
                                               stratifyByPs = FALSE,
                                               stratifyByPsArgs = stratifyByPsArgs1,
                                               computeCovariateBalance = TRUE,
                                               fitOutcomeModel = TRUE,
                                               fitOutcomeModelArgs = fitOutcomeModelArgs1)

cmAnalysis11 <- CohortMethod::createCmAnalysis(analysisId = 11,
                                               description = "Essure hysteroscopic vs laparoscopic and pregnancy algorithm outcome",
                                               getDbCohortMethodDataArgs = getDbCmDataArgs1,
                                               createStudyPopArgs = createStudyPopArgs4,
                                               createPs = TRUE,
                                               createPsArgs = createPsArgs1,
                                               trimByPs = TRUE,
                                               trimByPsArgs = trimByPsArgs1,
                                               trimByPsToEquipoise = FALSE,
                                               trimByPsToEquipoiseArgs = trimByPsToEquipoiseArgs1,
                                               matchOnPs = TRUE,
                                               matchOnPsArgs = matchOnPsArgs2,
                                               stratifyByPs = FALSE,
                                               stratifyByPsArgs = stratifyByPsArgs1,
                                               computeCovariateBalance = TRUE,
                                               fitOutcomeModel = TRUE,
                                               fitOutcomeModelArgs = fitOutcomeModelArgs1)

cmAnalysis12 <- CohortMethod::createCmAnalysis(analysisId = 12,
                                               description = "Essure hysteroscopic vs laparoscopic and pregnancy algorithm outcome",
                                               getDbCohortMethodDataArgs = getDbCmDataArgs1,
                                               createStudyPopArgs = createStudyPopArgs5,
                                               createPs = TRUE,
                                               createPsArgs = createPsArgs1,
                                               trimByPs = TRUE,
                                               trimByPsArgs = trimByPsArgs1,
                                               trimByPsToEquipoise = FALSE,
                                               trimByPsToEquipoiseArgs = trimByPsToEquipoiseArgs1,
                                               matchOnPs = TRUE,
                                               matchOnPsArgs = matchOnPsArgs2,
                                               stratifyByPs = FALSE,
                                               stratifyByPsArgs = stratifyByPsArgs1,
                                               computeCovariateBalance = TRUE,
                                               fitOutcomeModel = TRUE,
                                               fitOutcomeModelArgs = fitOutcomeModelArgs1)

cmAnalysis13 <- CohortMethod::createCmAnalysis(analysisId = 13,
                                               description = "Essure hysteroscopic vs laparoscopic and pregnancy algorithm outcome",
                                               getDbCohortMethodDataArgs = getDbCmDataArgs1,
                                               createStudyPopArgs = createStudyPopArgs6,
                                               createPs = TRUE,
                                               createPsArgs = createPsArgs1,
                                               trimByPs = TRUE,
                                               trimByPsArgs = trimByPsArgs1,
                                               trimByPsToEquipoise = FALSE,
                                               trimByPsToEquipoiseArgs = trimByPsToEquipoiseArgs1,
                                               matchOnPs = TRUE,
                                               matchOnPsArgs = matchOnPsArgs2,
                                               stratifyByPs = FALSE,
                                               stratifyByPsArgs = stratifyByPsArgs1,
                                               computeCovariateBalance = TRUE,
                                               fitOutcomeModel = TRUE,
                                               fitOutcomeModelArgs = fitOutcomeModelArgs1)

cmAnalysis14 <- CohortMethod::createCmAnalysis(analysisId = 14,
                                               description = "Essure hysteroscopic vs laparoscopic and pregnancy algorithm outcome",
                                               getDbCohortMethodDataArgs = getDbCmDataArgs1,
                                               createStudyPopArgs = createStudyPopArgs7,
                                               createPs = TRUE,
                                               createPsArgs = createPsArgs1,
                                               trimByPs = TRUE,
                                               trimByPsArgs = trimByPsArgs1,
                                               trimByPsToEquipoise = FALSE,
                                               trimByPsToEquipoiseArgs = trimByPsToEquipoiseArgs1,
                                               matchOnPs = TRUE,
                                               matchOnPsArgs = matchOnPsArgs2,
                                               stratifyByPs = FALSE,
                                               stratifyByPsArgs = stratifyByPsArgs1,
                                               computeCovariateBalance = TRUE,
                                               fitOutcomeModel = TRUE,
                                               fitOutcomeModelArgs = fitOutcomeModelArgs1)


cmAnalysis15 <- CohortMethod::createCmAnalysis(analysisId = 15,
                                               description = "Essure hysteroscopic vs laparoscopic and pregnancy algorithm outcome",
                                               getDbCohortMethodDataArgs = getDbCmDataArgs7,
                                               createStudyPopArgs = createStudyPopArgs1,
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

cmAnalysis16 <- CohortMethod::createCmAnalysis(analysisId = 16,
                                               description = "Essure hysteroscopic vs laparoscopic and pregnancy algorithm outcome",
                                               getDbCohortMethodDataArgs = getDbCmDataArgs7,
                                               createStudyPopArgs = createStudyPopArgs2,
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

cmAnalysis17 <- CohortMethod::createCmAnalysis(analysisId = 17,
                                               description = "Essure hysteroscopic vs laparoscopic and pregnancy algorithm outcome",
                                               getDbCohortMethodDataArgs = getDbCmDataArgs7,
                                               createStudyPopArgs = createStudyPopArgs3,
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

cmAnalysis18 <- CohortMethod::createCmAnalysis(analysisId = 18,
                                               description = "Essure hysteroscopic vs laparoscopic and pregnancy algorithm outcome",
                                               getDbCohortMethodDataArgs = getDbCmDataArgs7,
                                               createStudyPopArgs = createStudyPopArgs4,
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

cmAnalysis19 <- CohortMethod::createCmAnalysis(analysisId = 19,
                                               description = "Essure hysteroscopic vs laparoscopic and pregnancy algorithm outcome",
                                               getDbCohortMethodDataArgs = getDbCmDataArgs7,
                                               createStudyPopArgs = createStudyPopArgs5,
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

cmAnalysis20 <- CohortMethod::createCmAnalysis(analysisId = 20,
                                               description = "Essure hysteroscopic vs laparoscopic and pregnancy algorithm outcome",
                                               getDbCohortMethodDataArgs = getDbCmDataArgs7,
                                               createStudyPopArgs = createStudyPopArgs6,
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

cmAnalysis21 <- CohortMethod::createCmAnalysis(analysisId = 21,
                                               description = "Essure hysteroscopic vs laparoscopic and pregnancy algorithm outcome",
                                               getDbCohortMethodDataArgs = getDbCmDataArgs7,
                                               createStudyPopArgs = createStudyPopArgs7,
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

cmAnalysis22 <- CohortMethod::createCmAnalysis(analysisId = 22,
                                               description = "Essure hysteroscopic vs laparoscopic and pregnancy algorithm outcome",
                                               getDbCohortMethodDataArgs = getDbCmDataArgs7,
                                               createStudyPopArgs = createStudyPopArgs1,
                                               createPs = TRUE,
                                               createPsArgs = createPsArgs1,
                                               trimByPs = TRUE,
                                               trimByPsArgs = trimByPsArgs1,
                                               trimByPsToEquipoise = FALSE,
                                               trimByPsToEquipoiseArgs = trimByPsToEquipoiseArgs1,
                                               matchOnPs = TRUE,
                                               matchOnPsArgs = matchOnPsArgs2,
                                               stratifyByPs = FALSE,
                                               stratifyByPsArgs = stratifyByPsArgs1,
                                               computeCovariateBalance = TRUE,
                                               fitOutcomeModel = TRUE,
                                               fitOutcomeModelArgs = fitOutcomeModelArgs1)

cmAnalysis23 <- CohortMethod::createCmAnalysis(analysisId = 23,
                                               description = "Essure hysteroscopic vs laparoscopic and pregnancy algorithm outcome",
                                               getDbCohortMethodDataArgs = getDbCmDataArgs7,
                                               createStudyPopArgs = createStudyPopArgs2,
                                               createPs = TRUE,
                                               createPsArgs = createPsArgs1,
                                               trimByPs = TRUE,
                                               trimByPsArgs = trimByPsArgs1,
                                               trimByPsToEquipoise = FALSE,
                                               trimByPsToEquipoiseArgs = trimByPsToEquipoiseArgs1,
                                               matchOnPs = TRUE,
                                               matchOnPsArgs = matchOnPsArgs2,
                                               stratifyByPs = FALSE,
                                               stratifyByPsArgs = stratifyByPsArgs1,
                                               computeCovariateBalance = TRUE,
                                               fitOutcomeModel = TRUE,
                                               fitOutcomeModelArgs = fitOutcomeModelArgs1)

cmAnalysis24 <- CohortMethod::createCmAnalysis(analysisId = 24,
                                               description = "Essure hysteroscopic vs laparoscopic and pregnancy algorithm outcome",
                                               getDbCohortMethodDataArgs = getDbCmDataArgs7,
                                               createStudyPopArgs = createStudyPopArgs3,
                                               createPs = TRUE,
                                               createPsArgs = createPsArgs1,
                                               trimByPs = TRUE,
                                               trimByPsArgs = trimByPsArgs1,
                                               trimByPsToEquipoise = FALSE,
                                               trimByPsToEquipoiseArgs = trimByPsToEquipoiseArgs1,
                                               matchOnPs = TRUE,
                                               matchOnPsArgs = matchOnPsArgs2,
                                               stratifyByPs = FALSE,
                                               stratifyByPsArgs = stratifyByPsArgs1,
                                               computeCovariateBalance = TRUE,
                                               fitOutcomeModel = TRUE,
                                               fitOutcomeModelArgs = fitOutcomeModelArgs1)

cmAnalysis25 <- CohortMethod::createCmAnalysis(analysisId = 25,
                                               description = "Essure hysteroscopic vs laparoscopic and pregnancy algorithm outcome",
                                               getDbCohortMethodDataArgs = getDbCmDataArgs7,
                                               createStudyPopArgs = createStudyPopArgs4,
                                               createPs = TRUE,
                                               createPsArgs = createPsArgs1,
                                               trimByPs = TRUE,
                                               trimByPsArgs = trimByPsArgs1,
                                               trimByPsToEquipoise = FALSE,
                                               trimByPsToEquipoiseArgs = trimByPsToEquipoiseArgs1,
                                               matchOnPs = TRUE,
                                               matchOnPsArgs = matchOnPsArgs2,
                                               stratifyByPs = FALSE,
                                               stratifyByPsArgs = stratifyByPsArgs1,
                                               computeCovariateBalance = TRUE,
                                               fitOutcomeModel = TRUE,
                                               fitOutcomeModelArgs = fitOutcomeModelArgs1)

cmAnalysis26 <- CohortMethod::createCmAnalysis(analysisId = 26,
                                               description = "Essure hysteroscopic vs laparoscopic and pregnancy algorithm outcome",
                                               getDbCohortMethodDataArgs = getDbCmDataArgs7,
                                               createStudyPopArgs = createStudyPopArgs5,
                                               createPs = TRUE,
                                               createPsArgs = createPsArgs1,
                                               trimByPs = TRUE,
                                               trimByPsArgs = trimByPsArgs1,
                                               trimByPsToEquipoise = FALSE,
                                               trimByPsToEquipoiseArgs = trimByPsToEquipoiseArgs1,
                                               matchOnPs = TRUE,
                                               matchOnPsArgs = matchOnPsArgs2,
                                               stratifyByPs = FALSE,
                                               stratifyByPsArgs = stratifyByPsArgs1,
                                               computeCovariateBalance = TRUE,
                                               fitOutcomeModel = TRUE,
                                               fitOutcomeModelArgs = fitOutcomeModelArgs1)

cmAnalysis27 <- CohortMethod::createCmAnalysis(analysisId = 27,
                                               description = "Essure hysteroscopic vs laparoscopic and pregnancy algorithm outcome",
                                               getDbCohortMethodDataArgs = getDbCmDataArgs7,
                                               createStudyPopArgs = createStudyPopArgs6,
                                               createPs = TRUE,
                                               createPsArgs = createPsArgs1,
                                               trimByPs = TRUE,
                                               trimByPsArgs = trimByPsArgs1,
                                               trimByPsToEquipoise = FALSE,
                                               trimByPsToEquipoiseArgs = trimByPsToEquipoiseArgs1,
                                               matchOnPs = TRUE,
                                               matchOnPsArgs = matchOnPsArgs2,
                                               stratifyByPs = FALSE,
                                               stratifyByPsArgs = stratifyByPsArgs1,
                                               computeCovariateBalance = TRUE,
                                               fitOutcomeModel = TRUE,
                                               fitOutcomeModelArgs = fitOutcomeModelArgs1)

cmAnalysis28 <- CohortMethod::createCmAnalysis(analysisId = 28,
                                               description = "Essure hysteroscopic vs laparoscopic and pregnancy algorithm outcome",
                                               getDbCohortMethodDataArgs = getDbCmDataArgs7,
                                               createStudyPopArgs = createStudyPopArgs7,
                                               createPs = TRUE,
                                               createPsArgs = createPsArgs1,
                                               trimByPs = TRUE,
                                               trimByPsArgs = trimByPsArgs1,
                                               trimByPsToEquipoise = FALSE,
                                               trimByPsToEquipoiseArgs = trimByPsToEquipoiseArgs1,
                                               matchOnPs = TRUE,
                                               matchOnPsArgs = matchOnPsArgs2,
                                               stratifyByPs = FALSE,
                                               stratifyByPsArgs = stratifyByPsArgs1,
                                               computeCovariateBalance = TRUE,
                                               fitOutcomeModel = TRUE,
                                               fitOutcomeModelArgs = fitOutcomeModelArgs1)

# 1:1 ratio, -1 endDAys
cmAnalysisList1 <- list(cmAnalysis1, cmAnalysis2, cmAnalysis3, cmAnalysis4, cmAnalysis5, cmAnalysis6, cmAnalysis7)

# 1:2 ratio, -1 endDAys
cmAnalysisList2 <- list(cmAnalysis8, cmAnalysis9, cmAnalysis10, cmAnalysis11, cmAnalysis12, cmAnalysis13, cmAnalysis14)

# 1:1 ratio, -7 endDAys
cmAnalysisList3 <- list(cmAnalysis15, cmAnalysis16, cmAnalysis17, cmAnalysis18, cmAnalysis19, cmAnalysis20, cmAnalysis21)

# 1:2 ratio, -7 endDAys
cmAnalysisList4 <- list(cmAnalysis22, cmAnalysis23, cmAnalysis24, cmAnalysis25, cmAnalysis26, cmAnalysis27, cmAnalysis28)


# Run the analysis ----
result <- CohortMethod::runCmAnalyses(connectionDetails = connectionDetails,
                                      cdmDatabaseSchema = cdmDatabaseSchema,
                                      exposureDatabaseSchema = exposureDatabaseSchema,
                                      exposureTable = exposureTable,
                                      outcomeDatabaseSchema = outcomeDatabaseSchema,
                                      outcomeTable = outcomeTable,
                                      cdmVersion = cdmVersion,
                                      outputFolder = outputFolder,
                                      cmAnalysisList = cmAnalysisList1,
                                      targetComparatorOutcomesList = targetComparatorOutcomesList,
                                      getDbCohortMethodDataThreads = 1,
                                      createPsThreads = 1,
                                      psCvThreads = max(16, maxCores),
                                      #computeCovarBalThreads = max(3, maxCores),
                                      createStudyPopThreads = max(3, maxCores),
                                      trimMatchStratifyThreads = max(10, maxCores),
                                      prefilterCovariatesThreads = maxCores,
                                      fitOutcomeModelThreads = max(1, round(maxCores/4)),
                                      outcomeCvThreads = min(4, maxCores),
                                      refitPsForEveryOutcome = FALSE,
                                      refitPsForEveryStudyPopulation = FALSE,
                                      prefilterCovariates = FALSE,
                                      compressCohortMethodData = FALSE)


write.csv (result, file = "0result.csv")



#cohortMethodData1 <- CohortMethod::getDbCohortMethodData(connectionDetails = connectionDetails,
#                                                        cdmDatabaseSchema = cdmDatabaseSchema,
#                                                        targetId = targetCohortId,
#                                                        comparatorId = comparatorCohortId,
#                                                        outcomeIds = c(outcomeList, negativeControlConcepts),
#                                                        studyStartDate = "20120501",
#                                                        studyEndDate = "",
#                                                        exposureDatabaseSchema = exposureDatabaseSchema,
#                                                        exposureTable = exposureTable,
#                                                        outcomeDatabaseSchema = outcomeDatabaseSchema,
#                                                        outcomeTable = outcomeTable,
#                                                        cdmVersion = cdmVersion,
#                                                        firstExposureOnly = FALSE,
#                                                        removeDuplicateSubjects = TRUE,
#                                                        restrictToCommonPeriod = FALSE,
#                                                        washoutPeriod = 30,
#                                                        maxCohortSize = 0,
#                                                        covariateSettings = covariateSettings1)
                                                
                                                
                                     
                                                      
                                                        
                                                        
                                                        
                                                        

## Summarize the results
analysisSummary <- CohortMethod::summarizeAnalyses(result, outputFolder)
#head(analysisSummary)
write.csv (analysisSummary, file = "0analysisSummary.csv")

# Perform Empirical Calibration ----
newSummary <- data.frame()
# Calibrate p-values:
for (targetComparatorOutcome in targetComparatorOutcomesList) {
  for (analysisId in unique(analysisSummary$analysisId)) {
    subset <- analysisSummary[analysisSummary$analysisId == analysisId &
                                analysisSummary$targetId == targetComparatorOutcome$targetId &
                                analysisSummary$comparatorId == targetComparatorOutcome$comparatorId, ]
    
    negControlSubset <- subset[analysisSummary$outcomeId %in% negativeControlConcepts, ]
    negControlSubset <- negControlSubset[!is.na(negControlSubset$logRr) & negControlSubset$logRr != 0, ]
    
    hoiSubset <- subset[!(analysisSummary$outcomeId %in% negativeControlConcepts), ]
    hoiSubset <- hoiSubset[!is.na(hoiSubset$logRr) & hoiSubset$logRr != 0, ]
    
    if (nrow(negControlSubset) > 10) {
      null <- EmpiricalCalibration::fitMcmcNull(negControlSubset$logRr, negControlSubset$seLogRr)
      
      # View the empirical calibration plot with only negative controls
      #EmpiricalCalibration::plotCalibrationEffect(negControlSubset$logRr,
      #                                            negControlSubset$seLogRr,showCis = TRUE)
      
      # Save the empirical calibration plot with only negative controls
      plotName <- paste("calEffectNoHois_a",analysisId, "_t", targetComparatorOutcome$targetId, "_c", targetComparatorOutcome$comparatorId, ".png", sep = "")
      EmpiricalCalibration::plotCalibrationEffect(negControlSubset$logRr,
                                                  negControlSubset$seLogRr,
                                                  fileName = file.path(outputFolder, plotName),showCis = TRUE)
      
      # View the empirical calibration plot with  negative controls and HOIs plotted
      #EmpiricalCalibration::plotCalibrationEffect(negControlSubset$logRr,
      #                                            negControlSubset$seLogRr,
      #                                            hoiSubset$logRr, 
      #                                            hoiSubset$seLogRr,showCis = TRUE)
      
      # Save the empirical calibration plot with  negative controls and HOIs plotted
      plotName <- paste("calEffect_a",analysisId, "_t", targetComparatorOutcome$targetId, "_c", targetComparatorOutcome$comparatorId, ".png", sep = "")
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



write.csv (newSummary, file = "0newSummary.csv")






# Results ----
for (targetComparatorOutcome in targetComparatorOutcomesList) {
  for (analysisId in unique(analysisSummary$analysisId)) {
    currentAnalysisSubset <- analysisSummary[analysisSummary$analysisId == analysisId &
                                               analysisSummary$targetId == targetComparatorOutcome$targetId &
                                               analysisSummary$comparatorId == targetComparatorOutcome$comparatorId &
                                               analysisSummary$outcomeId %in% outcomeList, ]
    
    for(currentOutcomeId in unique(currentAnalysisSubset$outcomeId)) {
      outputImageSuffix <- paste0("_a",analysisId, "_t", targetComparatorOutcome$targetId, "_c", targetComparatorOutcome$comparatorId, "_o", currentOutcomeId, ".png")
      
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
      
      fileName <- paste0("0studyPop", outputImageSuffix, ".csv");
      write.csv (studyPop, file = fileName)
      
      
      #getAttritionTable(studyPop)
      #getAttritionTable_studyPop <- getAttritionTable(studyPop)
      #fileName <- paste0("0getAttritionTable_studyPop", outputImageSuffix, ".csv");
      #write.csv (getAttritionTable_studyPop, file = fileName)
      
      
      Mdrr_studyPop <- computeMdrr (population = studyPop,
                                    modelType = "cox",
                                    alpha = 0.05,
                                    power = 0.8,
                                    twoSided = TRUE)
      fileName <- paste0("0Mdrr_cox_studyPop", outputImageSuffix, ".csv");
      write.csv (Mdrr_studyPop, file = fileName)
      
      # View the attrition diagram
      #drawAttritionDiagram(studyPop, 
      #                     treatmentLabel = "Target", 
      #                     comparatorLabel = "Comparator")
      
      # Save the attrition diagram ----
      #plotName <- paste0("attritionDiagram", outputImageSuffix);
      #drawAttritionDiagram(studyPop, 
      #                     treatmentLabel = "Target", 
      #                     comparatorLabel = "Comparator", 
      #                     fileName = file.path(outputFolder, plotName))
      
      
      psFile <- result$psFile[result$target == currentAnalysisSubset$targetId &
                                result$comparatorId == currentAnalysisSubset$comparatorId &
                                result$outcomeId == currentOutcomeId &
                                result$analysisId == analysisId]
      
      ps <- readRDS(psFile)
      
      fileName <- paste0("0ps", outputImageSuffix, ".csv");
      write.csv (ps, file = fileName)
      
      
      #getAttritionTable_ps <- getAttritionTable(ps)
      #fileName <- paste0("0getAttritionTable_ps", outputImageSuffix, ".csv");
      #write.csv (getAttritionTable_ps, file = fileName)
      
      
      #fileName <- paste0("0Mdrr_cox_ps", outputImageSuffix, ".csv");
      #Mdrr_ps <- computeMdrr (population = ps,
      #                        modelType = "cox",
      #                        alpha = 0.05,
      #                        power = 0.8,
      #                        twoSided = TRUE)
      #write.csv (Mdrr_ps, file = fileName)
      
      # Compute the area under the receiver-operator curve (AUC) for the propensity score model ----
      #CohortMethod::computePsAuc(ps)
      
      #psAuc <- CohortMethod::computePsAuc(ps)
      #fileName <- paste0("0psAuc", outputImageSuffix, ".csv");
      #write.csv (psAuc, file = fileName)
      
      # Plot the propensity score distribution ----
      #CohortMethod::plotPs(ps, 
      #                     scale = "preference")
      
      # Save the propensity score distribution ----
      #plotName <- paste0("propensityScorePlot", outputImageSuffix);
      #CohortMethod::plotPs(ps, 
      #                     scale = "preference",
      #                     fileName = file.path(outputFolder, plotName))
      
      
      # Inspect the propensity model ----
      propensityModel <- CohortMethod::getPsModel(ps, cohortMethodData)
      #head(propensityModel)
      
      
      strataFile <- result$strataFile[result$target == currentAnalysisSubset$targetId &
                                        result$comparatorId == currentAnalysisSubset$comparatorId &
                                        result$outcomeId == currentOutcomeId &
                                        result$analysisId == analysisId]
      strataPop <- readRDS(strataFile)
      
      fileName <- paste0("0strataPop", outputImageSuffix, ".csv");
      write.csv (strataPop, file = fileName)
      
      
      
      Mdrr_strataPop <- computeMdrr (population = strataPop,
                                     modelType = "cox",
                                     alpha = 0.05,
                                     power = 0.8,
                                     twoSided = TRUE)
      fileName <- paste0("0Mdrr_cox_strataPop", outputImageSuffix, ".csv");
      write.csv (Mdrr_strataPop, file = fileName)
      
      
      
      
      #strataPopAuc <- CohortMethod::computePsAuc(strataPop)
      #fileName <- paste0("0strataPopAuc", outputImageSuffix, ".csv");
      #write.csv (strataPopAuc, file = fileName)
      
      
      # View PS With Population Trimmed By Percentile ----
      #CohortMethod::plotPs(strataPop, 
      #                     ps, 
      #                     scale = "preference")
      
      # Save PS With Population Trimmed By Percentile ----
      #plotName <- paste0("propensityScorePlotStrata", outputImageSuffix);
      #CohortMethod::plotPs(strataPop, 
      #                     ps, 
      #                     scale = "preference",
      #                     fileName = file.path(outputFolder, plotName))
      
      
      # Get the attrition table and diagram for the strata pop ----
      #CohortMethod::getAttritionTable
      #getAttritionTable_strataPop <- getAttritionTable(strataPop)
      #fileName <- paste0("0getAttritionTable_strataPop", outputImageSuffix, ".csv");
      #write.csv (getAttritionTable_strataPop, file = fileName)
      
      # View the attrition diagram for the strata pop ----
      #CohortMethod::drawAttritionDiagram(strataPop)
      
      # Save the attrition diagram for the strata pop ----
      #plotName <- paste0("attritionDiagramStrata", outputImageSuffix);
      #CohortMethod::drawAttritionDiagram(strataPop,
      #                                   fileName = file.path(outputFolder, plotName))
      
      
      # Plot the covariate balance ----
      #balanceFile <- result$covariateBalanceFile[result$target == currentAnalysisSubset$targetId &
      #                                             result$comparatorId == currentAnalysisSubset$comparatorId &
      #                                             result$outcomeId == currentOutcomeId &
      #                                             result$analysisId == analysisId]
      #balance <- readRDS(balanceFile)
      

      # View the covariate balance scatter plot ----
      #CohortMethod::plotCovariateBalanceScatterPlot(balance)
      
      # Save the covariate balance scatter plot ----
      #plotName <- paste0("covBalScatter", outputImageSuffix);
      #CohortMethod::plotCovariateBalanceScatterPlot(balance,
      #                                              fileName = file.path(outputFolder, plotName))
      
      # View the plot of top variables ----
      #CohortMethod::plotCovariateBalanceOfTopVariables(balance)
      
      # Save the plot of top variables ----
      #plotName <- paste0("covBalTop", outputImageSuffix);
      #CohortMethod::plotCovariateBalanceOfTopVariables(balance,
      #                                                 fileName = file.path(outputFolder, plotName))
      
      
      
      plotName <- paste0("Kaplan-MeierPlot_studyPop", outputImageSuffix);
      plotKaplanMeier(studyPop,
                      includeZero = FALSE,
                      fileName = file.path(outputFolder, plotName))
      
      
      plotName <- paste0("Kaplan-MeierPlot_strataPop", outputImageSuffix);
      plotKaplanMeier(strataPop,
                      includeZero = FALSE,
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
    plotName <- paste0("Follow−up_distribution_studyPop_a", analysisId, ".png");
    plotFollowUpDistribution(population = studyPop,
                             fileName = file.path(outputFolder, plotName))
    
    
    plotName <- paste0("Follow−up_distribution_strataPop_a", analysisId, ".png");
    plotFollowUpDistribution(population = strataPop,
                             fileName = file.path(outputFolder, plotName))
    
    
  }
  
  
}


balance <- CohortMethod::computeCovariateBalance (population = strataPop,
                                                  cohortMethodData = cohortMethodData)

CmTable1_balance <- createCmTable1(balance)
write.csv (CmTable1_balance, file = "0CmTable1_balance.csv")


#fileName <- paste0("0balance", outputImageSuffix, ".csv");
#write.csv (balance, file = fileName)



FollowUpDistribution_study <- getFollowUpDistribution(studyPop)
write.csv (FollowUpDistribution_study, file = "0FollowUpDistribution_study.csv")

FollowUpDistribution_strata <- getFollowUpDistribution(strataPop)
write.csv (FollowUpDistribution_strata, file = "0FollowUpDistribution_strata.csv")



#Checked that the same
write.csv (balance, file = "0balance.csv")

#Checked that the same
write.csv (propensityModel, file = "0propensityModel.csv")


getAttritionTable_studyPop <- getAttritionTable(studyPop)
write.csv (getAttritionTable_studyPop, file = "0getAttritionTable_studyPop.csv")

#getAttritionTable_ps <- getAttritionTable(ps)
#write.csv (getAttritionTable_ps, file = "0getAttritionTable_ps.csv")

getAttritionTable_strataPop <- getAttritionTable(strataPop)
write.csv (getAttritionTable_strataPop, file = "0getAttritionTable_strataPop.csv")


#Mdrr_studyPop <- computeMdrr (population = studyPop,
#                              modelType = "cox",
#                              alpha = 0.05,
#                              power = 0.8,
#                              twoSided = TRUE)
#write.csv (Mdrr_studyPop, file = "0Mdrr_cox_studyPop.csv")


#Mdrr_ps <- computeMdrr (population = ps,
#                        modelType = "cox",
#                        alpha = 0.05,
#                        power = 0.8,
#                        twoSided = TRUE)
#write.csv (Mdrr_ps, file = "0Mdrr_cox_ps.csv")

#Mdrr_strataPop <- computeMdrr (population = strataPop,
#                               modelType = "cox",
#                               alpha = 0.05,
#                               power = 0.8,
#                               twoSided = TRUE)
#write.csv (Mdrr_strataPop, file = "0Mdrr_cox_strataPop.csv")

psAuc <- CohortMethod::computePsAuc(ps)
write.csv (psAuc, file = "0psAuc.csv")


strataPopAuc <- CohortMethod::computePsAuc(strataPop)
write.csv (strataPopAuc, file = "0strataPopAuc.csv")


# Save the attrition diagram ----
plotName <- "attritionDiagram.png";
drawAttritionDiagram(studyPop, 
                     targetLabel = "Target", 
                     comparatorLabel = "Comparator", 
                     fileName = file.path(outputFolder, plotName))






# Save the propensity score distribution ----
plotName <- "propensityScorePlot_preference.png";
CohortMethod::plotPs(ps, 
                     scale = "preference",
                     showCountsLabel = TRUE,
                     showAucLabel = TRUE,
                     showEquiposeLabel = TRUE,
                     fileName = file.path(outputFolder, plotName),
                     type = 'density')


plotName <- "propensityScorePlot_propensity.png";
CohortMethod::plotPs(ps, 
                     scale = "propensity",
                     showCountsLabel = TRUE,
                     showAucLabel = TRUE,
                     showEquiposeLabel = TRUE,
                     fileName = file.path(outputFolder, plotName),
                     type = 'density')


# Save the propensity score distribution ----
plotName <- "propensityScorePlot_preference_hist.png";
CohortMethod::plotPs(ps, 
                     scale = "preference",
                     showCountsLabel = TRUE,
                     showAucLabel = TRUE,
                     showEquiposeLabel = TRUE,
                     fileName = file.path(outputFolder, plotName),
                     type = 'histogram')


plotName <- "propensityScorePlot_propensity_hist.png";
CohortMethod::plotPs(ps, 
                     scale = "propensity",
                     showCountsLabel = TRUE,
                     showAucLabel = TRUE,
                     showEquiposeLabel = TRUE,
                     fileName = file.path(outputFolder, plotName),
                     type = 'histogram')









# Save PS With Population Trimmed By Percentile ----
plotName <- "propensityScorePlotStrata_preference.png";
CohortMethod::plotPs(strataPop, 
                     ps, 
                     scale = "preference",
                     fileName = file.path(outputFolder, plotName),
                     showCountsLabel = TRUE,
                     showAucLabel = TRUE,
                     showEquiposeLabel = TRUE,
                     type = 'density')

# Save PS With Population Trimmed By Percentile ----
plotName <- "propensityScorePlotStrata_propensity.png";
CohortMethod::plotPs(strataPop, 
                     ps, 
                     scale = "propensity",
                     fileName = file.path(outputFolder, plotName),
                     showCountsLabel = TRUE,
                     showAucLabel = TRUE,
                     showEquiposeLabel = TRUE,
                     type = 'density')

# Save PS With Population Trimmed By Percentile ----
plotName <- "propensityScorePlotStrata_preference_hyst.png";
CohortMethod::plotPs(strataPop, 
                     ps, 
                     scale = "preference",
                     fileName = file.path(outputFolder, plotName),
                     showCountsLabel = TRUE,
                     showAucLabel = TRUE,
                     showEquiposeLabel = TRUE,
                     type = 'histogram')

# Save PS With Population Trimmed By Percentile ----
plotName <- "propensityScorePlotStrata_propensity_hyst.png";
CohortMethod::plotPs(strataPop, 
                     ps, 
                     scale = "propensity",
                     fileName = file.path(outputFolder, plotName),
                     showCountsLabel = TRUE,
                     showAucLabel = TRUE,
                     showEquiposeLabel = TRUE,
                     type = 'histogram')


# Save the attrition diagram for the strata pop ----
plotName <- "attritionDiagramStrata.png";
CohortMethod::drawAttritionDiagram(strataPop,
                                   fileName = file.path(outputFolder, plotName))


# Save the covariate balance scatter plot ----
plotName <- "covBalScatter.png";
CohortMethod::plotCovariateBalanceScatterPlot(balance,
                                              showCovariateCountLabel = TRUE,
                                              showMaxLabel = TRUE,
                                              fileName = file.path(outputFolder, plotName))

# Save the plot of top variables ----
plotName <- "covBalTop.png";
CohortMethod::plotCovariateBalanceOfTopVariables(balance,
                                                 fileName = file.path(outputFolder, plotName))


summary(cohortMethodData)

summary(outcomeModel)
