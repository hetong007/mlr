#' Predict new data with an R learner.
#'
#' Mainly for internal use. Predict new data with a fitted model.
#' You have to implement this method if you want to add another learner to this package.
#'
#' You implementation must adhere to the following:
#' The model must be fitted on the subset of \code{.task} given by \code{.subset}. All parameters
#' in \code{...} must be passed to the underlying training function.
#'
#' @param .learner [\code{\link{RLearner}}]\cr
#'   Wrapped learner.
#' @param .model [\code{\link{WrappedModel}}]\cr
#'   Model produced by training.
#' @param .newdata [\code{data.frame}]\cr
#'   New data to predict. Does not include target column.
#' @param ... [any]\cr
#'   Additional parameters, which need to be passed to the underlying predict function.
#' @return For classification: Either a factor for type \dQuote{response} or a matrix for
#'   type \dQuote{prob}. In the latter case the columns must be named with the class labels.
#'   For regressions: Either a numeric for type \dQuote{response} or a matrix with two columns
#'   for type \dQuote{se}. In the latter case first column is the estimated response (mean value)
#'   and the second column the estimated standard errors.
#' @export
predictLearner = function(.learner, .model, .newdata, ...) {
  lmod = getLearnerModel(.model)
  if (inherits(lmod, "NoFeaturesModel")) {
    predict_nofeatures(.model, .newdata)
  } else {
    assertDataFrame(.newdata, min.rows = 1L, min.cols = 1L)
    UseMethod("predictLearner")
  }
}

predictLearner2 = function(.learner, .model, .newdata, ...) {
  # if we have that option enabled, set factor levels to complete levels from task
  if (.learner$fix.factors.prediction) {
    fls = .model$factor.levels
    ns = names(fls)
    # only take objects in .newdata
    ns = intersect(colnames(.newdata), ns)
    fls = fls[ns]
    if (length(ns) > 0L)
      .newdata[ns] = mapply(factor, x = .newdata[ns],
         levels = fls, SIMPLIFY = FALSE)
  }
  p = predictLearner(.learner, .model, .newdata, ...)
  p = checkPredictLearnerOutput(.learner, .model, p)
  return(p)
}

checkPredictLearnerOutput = function(learner, model, p) {
  cl = class(p)[1L]
  if (learner$type == "classif") {
    levs = model$task.desc$class.levels
    if (learner$predict.type == "response") {
      # the levels of the predicted classes might not be complete....
      # be sure to add the levels at the end, otherwise data gets changed!!!
      if (!is.factor(p))
        stopf("predictLearner for %s has returned a class %s instead of a factor!", learner$id, cl)
      levs2 = levels(p)
      if (length(levs2) != length(levs) || any(levs != levs2))
        p = factor(p, levels = levs)
    } else if (learner$predict.type == "prob") {
      if (!is.matrix(p))
        stopf("predictLearner for %s has returned a class %s instead of a matrix!", learner$id, cl)
      cns = colnames(p)
      if (is.null(cns) || length(cns) == 0L)
        stopf("predictLearner for %s has returned not the class levels as column names, but no column names at all!",
          learner$id)
      if (!setequal(cns, levs))
        stopf("predictLearner for %s has returned not the class levels as column names: %s",
          learner$id, collapse(colnames(p)))
    }
  } else if (learner$type == "regr") {
    if (learner$predict.type == "response") {
      if (cl != "numeric")
        stopf("predictLearner for %s has returned a class %s instead of a numeric!", learner$id, cl)
     } else if (learner$predict.type == "se") {
      if (!is.matrix(p))
        stopf("predictLearner for %s has returned a class %s instead of a matrix!", learner$id, cl)
      if (ncol(p) != 2L)
        stopf("predictLearner for %s has not returned a numeric matrix with 2 columns!", learner$id)
    }
  } else if (learner$type == "surv") {
    if (learner$predict.type == "prob")
      stop("Survival does not support prediction of probabilites yet.")
    if (!is.numeric(p))
      stopf("predictLearner for %s has returned a class %s instead of a numeric!", learner$id, cl)
  } else if (learner$type == "cluster")  {
    if (learner$predict.type == "response") {
      if (cl != "integer")
        stopf("predictLearner for %s has returned a class %s instead of an integer!", learner$id, cl)
     } else if (learner$predict.type == "prob") {
      if (!is.matrix(p))
        stopf("predictLearner for %s has returned a class %s instead of a matrix!", learner$id, cl)
    }
  } else if (learner$type == "multilabel")  {
    if (learner$predict.type == "response") {
      if (!(is.matrix(p) && typeof(p) == "logical"))
        stopf("predictLearner for %s has returned a class %s instead of a logical matrix!", learner$id, cl)
     } else if (learner$predict.type == "prob") {
      if (!(is.matrix(p) && typeof(p) == "double"))
        stopf("predictLearner for %s has returned a class %s instead of a numerical matrix!", learner$id, cl)
    }
  }
  return(p)
}
