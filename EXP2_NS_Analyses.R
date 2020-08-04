## EVDP 2019 elisa.plas.18@ucl.ac.uk
## 18/06/19: EVDP added dummy-coded coherence (-0.5: weak, 0: med, 0.5: str.)

# Behavioural regression models for Fleming, van der Putten & Daw
# Adapted from Steve Fleming 2016 stephen.fleming@ucl.ac.uk 

rm(list=ls())
require(R.matlab) 
require(lme4)
require(car)
require(optimx)

bigData = NULL
demoData = NULL

nat = c('PKU', 'UCL')
j=1
for (d in 1:2) {
  if (d == 1) {
    dataset = "PKU"
    dataDir = "~/Dropbox/PKU_collaboration/Github/DATA/EXP2/PKU_data/PKU_data/"
    filePrefix = "fMRI_pilotData_sub_"
    suffix = "_2"
    subjects = c(403, seq(404,418), seq(420,432), seq(434,435), seq(437,443), seq(445,459))
  } else if ( d == 2) {
    dataset = "UCL"
    dataDir = "~/Dropbox/PKU_collaboration/Github/DATA/EXP2/UCL_data/UCL_data/"
    filePrefix = "fMRI_pilotData_sub_"
    suffix = "_2"
    subjects =c(seq(25,76), 79) 
  }
  # Extract out data from mat files
  for (s in 1:length(subjects)){
    
    ## EXTRACT DATA FILE
    setwd(dataDir)
    DATA = readMat(paste(filePrefix,subjects[s],suffix,'.mat',sep=""))
    
    dat = DATA$locDATA
    
    precoh = NULL
    postcoh = NULL
    RT = NULL
    conf = NULL
    confRT = NULL
    response = NULL
    dir = NULL
    
    precoh = dat[,,1]$dots.coherence[1,]
    postcoh = dat[,,1]$post.coherence[1,]
    coh = sort(unique(precoh))
    
    precoh_cat = ifelse(precoh %in% coh[1], -0.5,
                        ifelse(precoh %in% coh[2], 0, 0.5))
    postcoh_cat = ifelse(postcoh %in% coh[1], -0.5,
                         ifelse(postcoh %in% coh[2], 0, 0.5))
    
    RT = dat[,,1]$reaction.time.button[1,]
    conf = dat[,,1]$mouse.response[1,]
    confRT = dat[,,1]$reaction.time.mouse[1,]
    response = dat[,,1]$button.response[1,] - 1
    response[response == 0] = -1
    dir = dat[,,1]$dots.direction[1,]/360
    dir[dir == 0.5] = -1
    accuracy = response == dir
    accuracy[accuracy == 0] <- -1
    condition = dat[,,1]$condition[1,]

    logRT = scale(log(RT))
    logConfRT = scale(log(confRT))
    subj = rep(j, length(accuracy))
    country = rep(d, length(accuracy))
    subData1 = data.frame("country"=country, "subj"=subj, "dir"=dir, "precoh"=precoh, "postcoh"=postcoh, "precoh_cat"=precoh_cat, "postcoh_cat"=postcoh_cat,"conf"=conf, "logConfRT"=logConfRT, "response"=response, "dir"=dir, "logRT"=logRT, "accuracy"=accuracy, "condition" = condition)
    
    #add to larger file 
    bigData = rbind(bigData, subData1)
    
    j=j+1 # total subject counter
  }
  setwd(paste(dataDir,nat[d], '_betas', sep = ""))
  demoData1<- read.csv(paste(nat[d], '_subject_log.csv',sep=""), header = T, sep = ",", na.strings = "EMPTY")
  demoData = rbind(demoData, demoData1)
}

# Factors
bigData$subj <- factor(bigData$subj)
bigData$country <- factor(bigData$country, levels = c(1,2), labels = c("PKU","UCL"))

## distinguish between social/nonsocial trials
bigData_social <- bigData[bigData$condition == 1, ]
bigData_nonsocial <- bigData[bigData$condition == 0, ]

## distinguish between error/correct trials
bigData_err <- bigData_nonsocial[bigData_nonsocial$accuracy == -1, ]
bigData_corr <- bigData_nonsocial[bigData_nonsocial$accuracy == 1, ]

## distinguish between PKU/UCL trials
bigData_PKU <- bigData_nonsocial[bigData_nonsocial$country == "PKU",]
bigData_UCL <- bigData_nonsocial[bigData_nonsocial$country == "UCL",]

## distinguish between both PKU/UCL trials and correct/error trials on non-social condition
bigData_PKU_correct <- bigData_nonsocial[bigData_nonsocial$country == "PKU" & bigData_nonsocial$accuracy == 1,]
bigData_UCL_correct <- bigData_nonsocial[bigData_nonsocial$country == "UCL" & bigData_nonsocial$accuracy == 1,]
bigData_PKU_incorrect <- bigData_nonsocial[bigData_nonsocial$country == "PKU" & bigData_nonsocial$accuracy == -1,]
bigData_UCL_incorrect <- bigData_nonsocial[bigData_nonsocial$country == "UCL" & bigData_nonsocial$accuracy == -1,]

## distinguish between PKU/UCL dataset
PKU = c(demoData[1:length(subjects),])
UCL = c(demoData[length(subjects)+1:nrow(demoData),])

mean(PKU$BCIS, na.rm = T)
mean(UCL$BCIS, na.rm = T)
t.test(PKU$BCIS, UCL$BCIS, var.equal = T)

mean(PKU$BCIS_SR, na.rm = T)
mean(UCL$BCIS_SR, na.rm = T)
t.test(PKU$BCIS_SR, UCL$BCIS_SR, var.equal = T)

mean(PKU$BCIS_SC, na.rm = T)
mean(UCL$BCIS_SC, na.rm = T)
t.test(PKU$BCIS_SC, UCL$BCIS_SC, var.equal = T)

mean(PKU$hol_tot, na.rm = T)
mean(UCL$hol_tot, na.rm = T)
t.test(PKU$hol_tot, UCL$hol_tot, var.equal = T)

## SECOND-ORDER PERFORMANCE
confModel_wcountry = lmer(conf ~ country*(accuracy + precoh_cat + postcoh_cat + precoh_cat:postcoh_cat + precoh_cat:accuracy + postcoh_cat:accuracy + precoh_cat:postcoh_cat:accuracy + logRT) + (1 + accuracy + precoh_cat + postcoh_cat + precoh_cat:postcoh_cat + precoh_cat:accuracy + postcoh_cat:accuracy + precoh_cat:postcoh_cat:accuracy + logRT|subj), data=bigData_nonsocial
                          , control = lmerControl(optimizer = "optimx", calc.derivs = FALSE, optCtrl = list(method = "bobyqa", starttests = FALSE, kkt = FALSE, REML = FALSE)))

fix <- fixef(confModel_wcountry)
print(summary(confModel_wcountry))
print(Anova(confModel_wcountry, type = 3))
coef(summary(confModel_wcountry)) #get the contrast statistics
fix.se <- sqrt(diag(vcov(confModel_wcountry)))

## Get the beta coefficients per country (Fig 1D plotted)
# error, PKU
error_coef_PKU = lmer(conf ~ precoh_cat*postcoh_cat + logRT + (1 +  precoh_cat*postcoh_cat + logRT|subj), data=bigData_PKU_incorrect
                      , control = lmerControl(optimizer = "optimx", calc.derivs = FALSE, optCtrl = list(method = "bobyqa", starttests = FALSE, kkt = FALSE)))
fix <- fixef(error_coef_PKU)
fix.se <- sqrt(diag(vcov(error_coef_PKU)))
betas <- c(fix, fix.se)
setwd('~/Dropbox/PKU_collaboration/Github/DATA/EXP2/PKU_data/PKU_data/PKU_betas/')
write.csv(betas, file = paste('regression_betas_EXP2_NS_err_PKU.csv'))

# correct, PKU 
corr_coef_PKU = lmer(conf ~ precoh_cat*postcoh_cat + logRT + (1 +  precoh_cat*postcoh_cat + logRT|subj), data=bigData_PKU_correct
                     , control = lmerControl(optimizer = "optimx", calc.derivs = FALSE, optCtrl = list(method = "bobyqa", starttests = FALSE, kkt = FALSE)))
fix <- fixef(corr_coef_PKU)
fix.se <- sqrt(diag(vcov(corr_coef_PKU)))
betas <- c(fix, fix.se)
write.csv(betas, file = paste('regression_betas_EXP2_NS_corr_PKU.csv'))

# error, UCL
error_coef_UCL = lmer(conf ~ precoh_cat*postcoh_cat + logRT + (1 +  precoh_cat*postcoh_cat + logRT|subj), data=bigData_UCL_incorrect
                      , control = lmerControl(optimizer = "optimx", calc.derivs = FALSE, optCtrl = list(method = "bobyqa", starttests = FALSE, kkt = FALSE)))
fix <- fixef(error_coef_UCL)
fix.se <- sqrt(diag(vcov(error_coef_UCL)))
betas <- c(fix, fix.se)
setwd('~/Dropbox/PKU_collaboration/Github/DATA/EXP2/UCL_data/UCL_data/UCL_betas/')
write.csv(betas, file = paste('regression_betas_EXP2_NS_err_UCL.csv'))

# correct, UCL
corr_coef_UCL = lmer(conf ~ precoh_cat*postcoh_cat + logRT + (1 +  precoh_cat*postcoh_cat + logRT|subj), data=bigData_UCL_correct
                     , control = lmerControl(optimizer = "optimx", calc.derivs = FALSE, optCtrl = list(method = "bobyqa", starttests = FALSE, kkt = FALSE)))
fix <- fixef(corr_coef_UCL)
fix.se <- sqrt(diag(vcov(corr_coef_UCL)))
betas <- c(fix, fix.se)
write.csv(betas, file = paste('regression_betas_EXP2_NS_corr_UCL.csv'))

## Country interaction on error trials (Fig 3A 2x stars)
confModel_error = lmer(conf ~ country * (precoh_cat*postcoh_cat + logRT) + (1 +  precoh_cat*postcoh_cat + logRT|subj), data=bigData_err
                       , control = lmerControl(optimizer = "optimx", calc.derivs = FALSE, optCtrl = list(method = "bobyqa", starttests = FALSE, kkt = FALSE)))
print(summary(confModel_error))
print(Anova(confModel_error, type =3))

## Country interaction on correct trials (Fig 3A 'n.s.')
confModel_correct = lmer(conf ~ country * (precoh_cat*postcoh_cat + logRT) + (1 +  precoh_cat*postcoh_cat + logRT|subj), data=bigData_corr
                         , control = lmerControl(optimizer = "optimx", calc.derivs = FALSE, optCtrl = list(method = "bobyqa", starttests = FALSE, kkt = FALSE)))
print(summary(confModel_correct))
print(Anova(confModel_correct, type =3))
