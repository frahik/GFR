#' Multi-trait Multi-Environment
#'
#' @param data data
#' @param ETA eta
#' @param nIter number of iterations
#' @param burnIn number of burning
#' @param thin number of thinning
#' @param CrossValidation cv object
#' @param set_seed seed for a reproducible research
#' @param digits number of digits of accuracy in the results
#' @param ... for BFR function
#'
#' @return Something cool
#' @export
#'
#' @importFrom IBCF.MTME getMatrixForm
#' @examples
#' ETA=list(Env=list(X=Z.E,model="BRR"),Gen = list(X = Z.G, model = 'BRR'), EnvGen=list(X=Z.EG,model="BRR"))
#' CrossValidation <- BMTME::CV.RandomPart(pheno, NPartitions = 10, PTesting = 0.2, set_seed = 123)
MTME <- function(data = NULL, ETA = NULL, nIter = 2500, burnIn = 500, thin = 5, progressBar = TRUE, CrossValidation = NULL, set_seed = NULL, digits = 4, ...){
  matrixData <- getMatrixForm(data, onlyTrait = T) ## Get matrix format data
  Y <- matrixData[, -c(1L,2L)] # get pheno data
  newY <- Y # to include covariance data
  nCV <- length(CrossValidation$CrossValidation_list) #Number of cross-validations
  Yhat_post <- matrix(NA, ncol = nCV, nrow = nrow(Y)) # save predictions
  nTraits <- dim(Y)[2L]
  results <- data.frame() # save cross-validation results
  pb <- progress::progress_bar$new(format = ':what  [:bar]; Time elapsed: :elapsed - ETA: :eta',
                                   total = 2L*(nCV*nTraits), clear = FALSE, show_after = 0)

  for (t in seq_len(nTraits)) {
    y2 <- Y[, t] #Loop each trait
    for (actual_CV in seq_len(nCV)) {
      if (progressBar) {
        pb$tick(tokens = list(what = paste0('Estimating covariance of trait ', colnames(Y)[t], ' in CV ', actual_CV, ' out of ', nCV)))
      }
      y1 <- y2
      indices <- CrossValidation$CrossValidation_list[[actual_CV]]
      Pos_ts <- which(indices == 1L)
      y1[-Pos_ts] <- NA
      fm <- BGLR(y = y1, ETA = ETA, nIter = nIter, burnIn = burnIn, thin = thin, verbose = F, ...)
      Yhat_post[, progressBar] <- fm$predictions #fm$predictions
    }
    cleanDat(noConfirm = T)
    ypred_ave <- apply(Yhat_post, 1L, mean)
    newY[, nTraits + t] <- ypred_ave
  }

  XPV <- scale(newY[, (1L+nTraits):(2L*nTraits)])

  for (t in seq_len(nTraits)) {
    y2 <- Y[, t]
    for (actual_CV in seq_len(nCV)) {
      if (progressBar) {
        pb$tick(tokens = list(what = paste0('Fitting Cross-Validation of trait ', colnames(Y)[t], ' in CV ', actual_CV, ' out of ', nCV)))
      }
      y1 <- y2
      positionTST <- CrossValidation$CrossValidation_list[[actual_CV]]
      y1[positionTST] <- NA
      ETA1 <- ETA
      ETA1$Cov_PreVal <- list(X = XPV, model = "BRR")
      fm1 <- BGLR(y = y1, ETA = ETA1, nIter = nIter, burnIn = burnIn, thin = thin, verbose = F, ...)

      results <- rbind(results, data.frame(Position = positionTST,
                                           Environment = matrixData$Env[positionTST],
                                           Trait = colnames(Y)[t],
                                           Partition = actual_CV,
                                           Observed = round(y2[positionTST], digits), #$response, digits),
                                           Predicted = round(fm1$predictions[positionTST], digits)))
    }
  }
  out <- list(results = results,
              covariance = Yhat_post)
  class(out) <- 'MTMECV'
  return(out)
}




