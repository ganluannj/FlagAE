#########################################################################################################
#########################################################################################################

#' @name Hiermodel
#'
#' @title Three stages Bayesian Hierarchical Model
#'
#' @description  Functions here are to take the orginized data (output from
#'   \code{preprocess2}) and apply the three stages Bayesian Hierarchical Model.
#'   See details for model description and difference between each function.
#'
#' @param aedata output from function \code{\link{preprocess2}}
#' @param n_burn integer, number of interations without saving posterior samples
#' @param n_iter integer, number of interations saving posterior samples with every \code{thin}th iteration
#' @param thin integer, samples are saved for every \code{thin}th iteration
#' @param n_adapt integer, number of adaptations
#' @param n_chain number of MCMC chains
#' @param inits a list, with length equal to n_chain, each element of \code{inits} is
#' also a list contains initials for each chain; it needs to provide initials for the following
#' variables: mu.gamma.0, tau.gamma.0, mu.theta.0, tau.theta.0, alpha.pi, beta.pi
#' @param hierraw output from function \code{link{Hier_history}}
#'
#'
#' @details \strong{Model}: \cr Here the 3-stage hierarchical bayesian model was
#'   used to model the probability of AEs. It is model 1b (Bayesian Logistic
#'   Regression Model with Mixture Prior on Log-OR) in H. Amy Xia , Haijun Ma &
#'   Bradley P. Carlin (2011) Bayesian Hierarchical Modeling for Detecting
#'   Safety Signals in Clinical Trials, Journal of Biopharmaceutical Statistics,
#'   21:5, 1006-1029, DOI: 10.1080/10543406.2010.520181) \cr
#'   \strong{\code{Hier_history}}: \cr
#'   This function takes formatted Binomial data and
#'   output Gibbs sample of the defined parametes. The output is a dataframe
#'   with each column represent one parameter and each row is the output from
#'   one sampling/one iteration. Diff, OR, gamma, and theta are the parameters recorded.\cr
#'   \emph{Diff}: is the difference of incidence
#'   of AE between treatment and control group (treatment - control) \cr
#'   \emph{OR}: is the odds ratio for the incidence of AE between treatment and
#'   control group (treatment over control): t(1-c)/c(1-t), where t,c are the incidences of one AE for treatment
#'   and control group, respectively.\cr
#'   \emph{gamma}: logit(incidence of AE in control group) = gamma \cr
#'   \emph{theta}: logit(incidence of AE in treatment group) = gamma + theta; and OR = exp(theta) \cr
#'   The result for Diff, OR, gamma, and theta are ordered by j and then by b.
#'   For example the result is like Diff.1.1, Diff.2.1, Diff.3.1, Diff.4.1 Diff.1.2, Diff.2.2,
#'   Diff.3.2 and so on \cr
#'   \strong{\code{sum_Hier}}:\cr
#'   This function takes the output from \code{Hier_history} and return the summary
#'   statistics for each parameter recorded by \code{Hier_history}. The summary function is applied on each column. \cr
#'   \strong{\code{Hier}}:\cr
#'   This function takes the same input as \code{Hier_history} and calculate the summary statistics
#'   for output from \code{Hier_history}.
#'   It outputs the summary statistics for each AE, combining with raw data. \cr
#'   \strong{\code{Hiergetpi}}: \cr
#'   This function calculates pit (incidence of AE in treatment group) and
#'   pic (incidence of AE in control group) from the output of \code{Hier_history}
#    The output is used for Loss function
#'
#'
#'
#' @return
#' \strong{\code{Hier_history}}\cr
#' It returns a dataframe with each column represent one parameter
#' and each row is the output from one sampling/one iteraction (like the output of \code{\link[R2jags]{coda.samples}}) \cr
#' \strong{\code{sum_Hier}} \cr
#' It returns the summary statistics for each parameter recorded by \code{Hier_history}. \cr
#' \strong{\code{Hier}} \cr
#' It returns the summary statistics for each AE, combining with raw data.
#' The summary statistics including:
#' summary statistics for incidence rate difference (mean, 2.5\% and 97.5\% percentile);
#' summary statistics for odds ratio (mean, 2.5\% and 97.5\% percentile).
#' The other columns include SoC, PT, Nt, Nc, AEt, and AEc.
#' \strong{\code{Hiergetpi}}: \cr
#' This function calculates pit (incidence of AE in treatment group) and
#' pic (incidence of AE in control group) from the output of \code{Hier_history}.\cr
#'
#' @examples
#' \dontrun{
#' data(ADAE)
#' data(ADSL)
#' AEdata<-preprocess2(adsl=ADSL, adae=ADAE, TreatCol="TREATMENT", drug="xyz")
#' INITS1<-list(mu.gamma.0=0.1, tau.gamma.0=0.1, mu.theta.0=0.1, tau.theta.0=0.1, alpha.pi=2, beta.pi=2)
#' INITS2<-list(mu.gamma.0=1, tau.gamma.0=1, mu.theta.0=1, tau.theta.0=1, alpha.pi=10, beta.pi=10)
#' INITS <- list(INITS1,INITS2)
#' HIERRAW<-Hier_history(aedata=AEdata, inits=INITS, n_burn=1000, n_iter=1000, thin=20, n_adapt=1000, n_chain=2)
#' HIERRAW2<-Hier_history(aedata=AEdata, inits=INITS1, n_burn=1000, n_iter=1000, thin=20, n_adapt=1000, n_chain=1)
#' HIERMODEL<-Hier(aedata=AEdata, inits=INITS, n_burn=1000, n_iter=1000, thin=20, n_adapt=1000, n_chain=2)
#' HIERPI<-Hiergetpi(aedata=AEdata, hierraw=HIERRAW)
#' }
#'
#' @seealso
#' \code{\link{preprocess2}}
#'
#' @references H. Amy Xia , Haijun Ma & Bradley P. Carlin (2011) Bayesian
#'   Hierarchical Modeling for Detecting Safety Signals in Clinical Trials,
#'   Journal of Biopharmaceutical Statistics, 21:5, 1006-1029, DOI:
#'   10.1080/10543406.2010.520181)
#'
#' @export

Hier_history<- function(aedata, inits, n_burn, n_iter, thin, n_adapt, n_chain) {

  # This function takes formatted Binomial data and output
  # Gibbs sample of the defined parameters
  # the output is a dataframe with each column represent one parameter
  # each row is the output from one sampling/one iteration
  # the result for Diff, OR, gamma, and theta are ordered by j and then by b
  # for example the result is like Diff.1.1, Diff.2.1, Diff.3.1, Diff.4.1
  # Diff.1.2, Diff.2.2, Diff.3.2 and so on
  # aedata is the output from function preprocess2
  # each row of the aedata corresponds to one AE
  # it contains the following columns:
  # Nc: number of total patients in control group
  # Nt: number of total patients in treatment group
  # b: SOC # of the AE
  # j: PT # of the AE
  # AEt: number of patients with AE in treatment group
  # AEc: number of patients with AE in control group
  ##################################################
  # n_burn, n_iter, thin, n_adapt, n_chain are for MCMC
  # n_burn: number of interations without saving posterior samples
  # n_iter: number of interations saving posterior samples with every nth iteration
  # n here is given by thin
  # n_adapt: number of adaptations
  # n_chain: number of MCMC chains
  # inits is a list with length equal to n_chain
  # each element of inits is one set of inits for each chain

  #############################################
  ## M1b: Binomial model with mixture prior ###
  #############################################

  # create the model

  model.binom<-"model{
    for (i in 1:Nae) {
      X[i] ~ dbin(c[b[i], j[i]], Nc)
      Y[i] ~ dbin(t[b[i], j[i]], Nt)

      logit(c[b[i], j[i]]) <- gamma[b[i], j[i]]
      logit(t[b[i], j[i]]) <- gamma[b[i], j[i]] + theta[b[i], j[i]]

      gamma[b[i], j[i]] ~ dnorm(mu.gamma[b[i]], tau.gamma[b[i]])
      p0[i] ~ dbern(pi[b[i]] ) # prob of point mass
      theta1[b[i], j[i]] ~ dnorm(mu.theta[b[i]], tau.theta[b[i]])

      # theta=0 w.p. pi[i] and theta=theta1 w.p. 1-pi[i]

      theta[b[i], j[i]] <- (1- p0[i]) * theta1[b[i], j[i]]

      OR[b[i],j[i]] <- exp(theta[b[i],j[i]] )
      # ORpv2[b[i], j[i]] <- step(OR[b[i],j[i]] - 2 )  # OR >= 2

      # ORpv2[b[i], j[i]] <- step(OR[b[i],j[i]] -1.2 ) # OR >= 1.2

      # ORpv[b[i], j[i]] <- 1- step(-OR[b[i],j[i]]) # OR >1

      # RD[b[i], j[i]] <- t[b[i], j[i]] - c[b[i], j[i]]
      # RDpv[b[i], j[i]] <- 1 - step(c[b[i], j[i]] - t[b[i], j[i]])
      # RD>0
      # RDpv2[b[i], j[i]] <- step(t[b[i], j[i]] - c[b[i], j[i]]- 0.02) # RD>=2%
      # RDpv5[b[i], j[i]] <- step(t[b[i], j[i]] - c[b[i], j[i]]- 0.05) # RD>=5%

      D[i] <- X[i]*log(c[b[i], j[i]]) + (Nc-X[i])*log(1-c[b[i], j[i]]) + Y[i]*log(t[b[i], j[i]]) + (Nt-Y[i])*log(1-t[b[i],j[i]])

      #below function is added by Jun
      Diff[b[i], j[i]] <- t[b[i], j[i]] - c[b[i], j[i]]
    }

    Dbar <- -2* sum(D[]) # -2logL without normalizing constant
    # SOC level parameters

    for(k in 1:B){
      pi[k] ~ dbeta(alpha.pi, beta.pi)
      mu.gamma[k] ~ dnorm(mu.gamma.0, tau.gamma.0)
      tau.gamma[k] ~ dgamma(3,1)
      mu.theta[k] ~ dnorm(mu.theta.0, tau.theta.0)
      tau.theta[k] ~ dgamma(3,1)
    }

    # hyperpriors for gamma?s;
    mu.gamma.0 ~ dnorm(0, 0.1)
    tau.gamma.0 ~ dgamma(3,1)

    # hyperpriors for theta?s;
    mu.theta.0 ~ dnorm(0, 0.1)
    tau.theta.0 ~ dgamma(3,1)

    # hyperpriors for pi?s;
    alpha.pi ~ dexp(0.1)I(1,)
    beta.pi ~ dexp(0.1)I(1,)
  }"


  param<-c("OR", "Diff", "gamma", "theta")

  data <- list(Nae = nrow(aedata), Nc = aedata$Nc[1], Nt = aedata$Nt[1], B = max(aedata$b),
               b = aedata$b, j = aedata$j, Y = aedata$AEt, X = aedata$AEc)


  # we use parallel computing for n_chain>1
  if (n_chain>1){
    #setup parallel backend to use multiple processors
    library(foreach)
    library(doParallel)
    cores<-detectCores()
    cl<-makeCluster(cores[1]-1)
    registerDoParallel(cl)

    param.est<-list()
    param.est<-foreach(m=1:n_chain) %dopar% {
      library(mcmcplots)
      library(rjags)
      library(R2jags)
      temp.fit <- jags.model(textConnection(model.binom),data=data,inits=inits[m],n.chains=1, n.adapt=n_adapt,quiet=TRUE)
      update(temp.fit, n.iter=n_burn)

      # summary of posterior samples
      temp.param.samples <- coda.samples(temp.fit,param,n.iter=n_iter,thin=thin)
      temp.param.est <- data.frame(as.matrix(temp.param.samples))
      param.est[[m]]<-temp.param.est
    }
    stopCluster(cl)

    ## combine the result from seperate chains together
    Final.est<-param.est[[1]]
    for (m in 2:n_chain){
      Final.est<-rbind(Final.est, param.est[[m]])
    }
  }

  else {
    library(mcmcplots)
    library(rjags)
    library(R2jags)
    temp.fit <- jags.model(textConnection(model.binom),data=data,inits=inits,n.chains=1, n.adapt=n_adapt,quiet=TRUE)
    update(temp.fit, n.iter=n_burn)

    # summary of posterior samples
    temp.param.samples <- coda.samples(temp.fit,param,n.iter=n_iter,thin=thin)
    temp.param.est <- data.frame(as.matrix(temp.param.samples))
    Final.est<-temp.param.est
  }

  return(Final.est)
}


#########################################################################################################
#########################################################################################################

#' @rdname Hiermodel
#' @export
sum_Hier <- function(hierraw){
  # this functin will take the output from Hier_history as input
  # and return the summary statistics for each parameter
  # the summary function is applyed on each column
  xbar <- mean(hierraw)
  xsd  <- sd(hierraw)
  x2.5 <- quantile(hierraw,0.025)
  x25  <- quantile(hierraw,0.25)
  xmdn <- quantile(hierraw,0.5)
  x75  <- quantile(hierraw,0.75)
  x97.5<- quantile(hierraw,0.975)
  out <- c(xbar,xsd,x2.5,x25,xmdn,x75,x97.5)
  return(out)
}


#########################################################################################################
#########################################################################################################

#' @rdname Hiermodel
#' @export
Hier<- function(aedata, inits, n_burn, n_iter, thin, n_adapt, n_chain){
  # this function take the same input as Hier_history
  # this function will get the summary statistics for output from Hier_history
  # it will give the summary statistics for each AE and combine with raw data
  # the summary statistics including:
  # summary statistics for incidence rate difference (mean, 2.5% and 97.5% percentile)
  # summary statistics for odds ratio (mean, 2.5% and 97.5% percentile)
  # the other columns including:
  # SoC, PT, Nt, Nc, AEt, AEc

  oest<-Hier_history(aedata, inits, n_burn, n_iter, thin, n_adapt, n_chain)

  # Get the mean, standard devision, quantile of 2.5%, 25%, 50%, 75%, and 97.5% for the parameters interested
  # get the summary for parameter Dbar, Diff, and OR
  oest_Diff<-oest[, grepl("Diff", names(oest))]
  oest_OR<-oest[, grepl("OR", names(oest))]
  oest_DiffOR<-cbind(oest_Diff, oest_OR)

  param.sum <- sapply(oest_DiffOR,sum_Hier)
  summary <- as.data.frame(t(param.sum))

  # Associate the parameters with SOC and PT names
  # sort aedata by j, since parameters in summary are sorted by j and then by b.
  AEDECOD <- aedata[order(aedata$j, aedata$b),]
  SoC <- rep(as.character(AEDECOD$AEBODSYS),2)
  PT <- rep(as.character(AEDECOD$AEDECOD),2)
  Sub <- c(rep('Diff',nrow(aedata)),rep('OR',nrow(aedata)))
  col.name <- c("Mean","SD","2.5%","25%","50%","75%","97.5%")
  colnames(summary) <- col.name
  summary <- cbind(Sub,SoC,PT,summary)

  # Summary statistics for parameter Diff
  summary.diff <- summary[summary$Sub=='Diff',c('SoC','PT','Mean','2.5%','97.5%')]
  colnames(summary.diff)[3:5] <- c('Diff_mean','Diff_2.5%','Diff_97.5%')

  # Summary statistics for parameter OR
  summary.OR <- summary[summary$Sub=='OR',c('SoC','PT','Mean','2.5%','97.5%')]
  colnames(summary.OR)[3:5] <- c('OR_mean','OR_2.5%','OR_97.5%')

  # merge summary statistics with raw data
  out <- merge(summary.diff,summary.OR,by=c('SoC','PT')) # this merge function also sort the resulting dataframe by Soc and PT
  # get the raw data from aedata
  Raw<-aedata
  names(Raw)[1:2]<-c("SoC", "PT")
  out<-merge(Raw, out, by=c("SoC", "PT"))
  Hier.plot <- out[order(out$SoC),]
  Hier.plot$Method = 'Bayesian Hierarchical Model'
  return (Hier.plot)
}

#########################################################################################################
#########################################################################################################

#' @rdname Hiermodel
#' @export
Hiergetpi<-function(aedata, hierraw){
  # this function is to get the pit and pic from the output of Hier_history
  # the output is used for Loss function
  # aedata is the output of preprocess2
  # hierraw is the output of Hier_history
  # it will output a list with two elements, pit and pic
  # pit contains the columns of SoC, PT for each AE and also the incidence rate
  # for AE in treatment group for each iteraction
  # pic contains the columns of SoC, PT for each AE and also the incidence rate
  # for AE in control group for each iteraction

  # first get \gamma_{bj} and \theta_{bj}
  sim.gamma <- sim.theta <- matrix(0,nrow(aedata),nrow(hierraw))

  for (i in 1:nrow(aedata)){
    ind1 <- aedata$b[i]; ind2 <- aedata$j[i]
    sim.gamma[i,] <- as.numeric(as.character(hierraw[[paste0('gamma.',ind1,'.',ind2,'.')]]))
    sim.theta[i,] <- as.numeric(as.character(hierraw[[paste0('theta.',ind1,'.',ind2,'.')]]))
  }

  # create pit and pic
  # pic=exp(sim.gamma)/(1+exp(sim.gamma))
  # pit=exp(sim.gamma+sim.theta)/(1+exp(sim.gamma+sim.theta))
  pic0<-exp(sim.gamma)/(1+exp(sim.gamma))
  pit0<-exp(sim.theta+sim.gamma)/(1+exp(sim.theta+sim.gamma))

  # combine SoC and PT together with incidence rate
  pit<-cbind(as.character(aedata$AEBODSYS), as.character(aedata$AEDECOD), pit0)
  pic<-cbind(as.character(aedata$AEBODSYS), as.character(aedata$AEDECOD), pic0)
  # convert to data frame
  pit<-as.data.frame(pit)
  pic<-as.data.frame(pic)

  # rename of first two columns of pit and pic
  names(pit)[1:2]<-c("SoC", "PT")
  names(pic)[1:2]<-c("SoC", "PT")

  List<-list(pit=pit, pic=pic)
  return (List)
}

