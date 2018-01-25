#' Draw discrete variables including binary, binomial count, poisson count,
#' ordered, and categorical
#'
#' Drawing discrete data based on probabilities or latent traits is a common
#' task that can be cumbersome. Each function in our discrete drawing set creates
#' a different type of discrete data: \code{draw_binary} creates binary 0/1 data,
#' \code{draw_binomial} creates binomial data (repeated trial binary data),
#' \code{draw_categorical} creates categorical data, \code{draw_ordered}
#' transforms latent data into observed ordered categories, \code{draw_count}
#' creates count data (poisson-distributed). \code{draw_likert} is an alias to
#' \code{draw_ordered} that pre-specifies break labels and offers default breaks
#' appropriate for a likert survey question.
#'
#' For variables with intra-cluster correlations, see
#' \code{\link{draw_binary_icc}} and \code{\link{draw_normal_icc}}
#'
#' @param prob A number or vector of numbers representing the probability for
#' binary or binomial outcomes; or a number, vector, or matrix of numbers
#' representing probabilities for categorical outcomes. If you supply a link
#' function, these underlying probabilities will be transformed.
#' @param trials for `draw_binomial`, the number of trials for each observation
#' @param mean for `draw_count`, the mean number of count units for each observation
#' @param x for `draw_ordered` or `draw_likert`, the latent data for each
#' observation.
#' @param breaks vector of breaks to cut a latent outcome into ordered
#' categories with `draw_ordered` or `draw_likert`
#' @param break_labels vector of labels for the breaks to cut a latent outcome
#' into ordered categories with `draw_ordered`.
#' @param type Type of Likert scale data for `draw_likert`. Valid options are 4,
#' 5, and 7. Type corresponds to the number of categories in the Likert scale.
#' @param N number of units to draw. Defaults to the length of the vector of
#' probabilities or latent data you provided.
#' @param link link function between the latent variable and the probability of
#' a postiive outcome, e.g. "logit", "probit", or "identity". For the "identity"
#' link, the latent variable must be a probability.
#'
#' @examples
#'
#' # Drawing binary values (success or failure, treatment assignment)
#' fabricate(N = 3,
#'    p = c(0, .5, 1),
#'    binary = draw_binary(prob = p))
#'
#' # Drawing binary values with probit link (transforming continuous data
#' # into a probability range).
#' fabricate(N = 3,
#'    x = 10 * rnorm(N),
#'    binary = draw_binary(prob = x, link = "probit"))
#'
#' # Repeated trials: `draw_binomial`
#' fabricate(N = 3,
#'    p = c(0, .5, 1),
#'    binomial = draw_binomial(prob = p, trials = 10))
#'
#' # Ordered data: transforming latent data into observed, ordinal data.
#' # useful for survey responses.
#' fabricate(N = 3,
#'    x = 5 * rnorm(N),
#'    ordered = draw_ordered(x = x,
#'                           breaks = c(-Inf, -1, 1, Inf)))
#'
#' # Providing break labels for latent data.
#' fabricate(N = 3,
#'    x = 5 * rnorm(N),
#'    ordered = draw_ordered(x = x,
#'                           breaks = c(-Inf, -1, 1, Inf),
#'                           break_labels = c("Not at all concerned",
#'                                            "Somewhat concerned",
#'                                            "Very concerned")))
#'
#' # Likert data: often used for survey data
#' fabricate(N = 10,
#'           support_free_college = draw_likert(x = rnorm(N),
#'                                              type = 5))
#'
#' # Count data: useful for rates of occurrences over time.
#' fabricate(N = 5,
#'    x = c(0, 5, 25, 50, 100),
#'    theft_rate = draw_count(mean=x))
#'
#' # Categorical data: useful for demographic data.
#' fabricate(N = 6, p1 = runif(N), p2 = runif(N), p3 = runif(N),
#'           cat = draw_categorical(cbind(p1, p2, p3)))
#'
#' @importFrom stats pnorm rnorm rpois rbinom na.omit
#'
#' @export
#'
draw_binomial <- function(prob, trials=1, N = length(prob), link = "identity") {
  # Error handle probabilities and apply link function.
  if (mode(prob) != "numeric") {
    stop("Probabilities provided in the `prob` argument must be numeric.")
  }

  if (link == "identity") {
    if (!all(na.omit(0 <= prob & prob <= 1))) {
      stop(
        "The identity link requires probability values between 0 and 1,",
        "inclusive."
      )
    } else if (any(is.na(prob))) {
      warning("At least one specified probability (`prob`) was NA.")
    }
    if (N %% length(prob)) {
      stop(
        "`N` is not an even multiple of the length of the number of
        probabilities, `prob`."
      )
    }
  } else if (link == "logit") {
    prob <- 1 / (1 + exp(-prob))
  } else if (link == "probit") {
    prob <- pnorm(prob)
  } else {
    stop(
      "Only 'identity', 'logit', 'and 'probit' are valid link functions for ",
      "`draw_binomial()` and `draw_binary()`."
    )
  }

  # Error handle trials
  if (is.vector(trials) && length(trials) > 1) {
    if (N %% length(trials) != 0) {
      stop(
        "`N` is not an even multiple of the length of the number of
        trials, `trials`."
      )
    }
    if (!is.integer(trials) && is.numeric(trials) && any(trials %% 1 != 0)) {
      stop(
        "All numbers of trials should be integer numbers."
      )
    }
  }
  if (!is.null(dim(trials))) {
    stop(
      "Number of trials must be an integer or vector, not higher-dimensional."
    )
  }
  if (is.null(trials) || any(is.na(trials))) {
    stop(
      "Number of trials must be specified, not null or NA."
    )
  }
  if (!is.integer(trials) && is.numeric(trials) && any(trials %% 1 != 0)) {
    stop(
      "Number of trials must be an integer."
    )
  }
  if (any(trials <= 0)) {
    stop(
      "Number of trials must be a positive integer."
    )
  }

  return(rbinom(N, trials, prob))
}

#' @rdname draw_binomial
#' @export
draw_categorical <- function(prob, N=NULL, link = "identity") {
  if (link != "identity") {
    stop("Categorical data does not accept link functions.")
  }

  if (is.null(dim(prob))) {
    if (is.vector(prob) && is.numeric(prob) && length(prob) > 1) {
      if (is.null(N)) {
        stop(
          "If `prob` is a vector of category probabilities, you must provide ",
          "an explicit `N` argument."
        )
      }
      prob <- matrix(rep(prob, N), byrow = TRUE, ncol = length(prob), nrow = N)
      warning(
        "For a categorical (multinomial) distribution, a matrix of ",
        "probabilities should be provided. The data below is generated by ",
        "interpreting the vector of category probabilities you provided as ",
        "identical for each observation."
      )
    } else {
      stop(
        "For a categorical (multinomial) distribution, a matrix of ",
        "probabilities must be provided"
      )
    }
  }
  if (!all(apply(prob, 1, min) > 0)) {
    stop(
      "For a categorical (multinomial) distribution, the elements of `prob` ",
      "should be positive and sum to a positive number."
    )
  }

  if (is.null(N)) {
    N <- nrow(prob)
  }

  if (!(nrow(prob) %in% c(1, N))) {
    stop("The number of probabilities provided should be equal to `N` or 1.")
  }

  m <- ncol(prob)
  rcateg <- function(p)
    sample(1:m, 1, prob = p)

  return(apply(prob, 1, rcateg))
}

#' @rdname draw_binomial
#' @export
draw_ordered <- function(x, breaks = c(-1, 0, 1), break_labels = NULL,
                         N = length(x), link = "identity") {
  # Link function
  if (link == "probit") {
    x <- x + rnorm(N)
  } else if (link != "identity") {
    stop("`draw_ordered()` only accepts 'identity' and 'probit' link functions.")
  }

  # Error handling breaks
  if (is.null(breaks) || any(is.na(breaks))) {
    stop("You must specify numeric breaks for ordered data.")
  }
  if (!is.numeric(breaks)) {
    stop("All breaks specified for ordered data must be numeric.")
  }
  if (is.matrix(breaks) || is.data.frame(breaks)) {
    stop("Numeric breaks must be a vector.")
  }
  if (is.unsorted(breaks)) {
    stop("Numeric breaks must be in ascending order.")
  }

  # Check N/x
  if (N %% length(x) != 0) {
    stop("`N` must be an even multiple of the length of `x`.")
  }

  # Pre-pend -Inf
  if (any(breaks[1] > x)) {
    breaks <- c(-Inf, breaks)
  }
  # Post-pend Inf
  if (any(breaks[length(breaks)] < x)) {
    breaks <- c(breaks, Inf)
  }

  # Make sure break labels are concordant with breaks.
  if (!is.null(break_labels) &&
    (is.vector(break_labels) &&
      !is.logical(break_labels) &&
      all(!is.na(break_labels)) &&
      length(break_labels) != length(breaks) - 1)) {
    stop(
      "Break labels should be of length one less than breaks. ",
      "Currently you have ", length(break_labels), " bucket labels and ",
      length(breaks) - 1, " buckets of data."
    )
  }

  # Output
  if (!is.null(break_labels)) {
    return(factor(
      break_labels[findInterval(x, breaks)],
      levels = break_labels
    ))
  } else {
    return(factor(findInterval(x, breaks)))
  }
}

#' @rdname draw_binomial
#' @export
draw_count <- function(mean, N = length(mean), link = "identity") {
  if (link != "identity") {
    stop("Count data does not accept link functions.")
  }

  if (any(mean < 0)) {
    stop(
      "All provided count values must be non-negative."
    )
  }

  if (N %% length(mean) != 0) {
    stop("`N` must be an even multiple of the length of mean.")
  }

  return(rpois(N, lambda = mean))
}

#' @rdname draw_binomial
#' @export
draw_binary <- function(prob, N = length(prob), link = "identity") {
  return(draw_binomial(
    prob,
    N = N,
    link = link,
    trials = 1
  ))
}

#' @rdname draw_binomial
#' @export
draw_likert <- function(x,
                        type = 7,
                        breaks = NULL,
                        N = length(x),
                        link = "identity") {
  if (is.null(breaks) && is.null(type)) {
    stop("You must provide either `breaks` or `type` to a `draw_likert()` call.")
  }

  if (is.null(breaks)) {
    if (type == 7) {
      breaks <- c(-Inf, -2.5, -1.5, -0.5, 0.5, 1.5, 2.5, Inf)
    } else if (type == 5) {
      breaks <- c(-Inf, -1.5, -0.5, 0.5, 1.5, Inf)
    } else if (type == 4) {
      breaks <- c(-Inf, -1, 0, 1, Inf)
    } else {
      stop("Valid `type` arguments for a `draw_likert()` call are 4, 5, and 7.")
    }
  }

  if (length(breaks) == 8) {
    break_labels <- c(
      "Strongly Disagree",
      "Disagree",
      "Lean Disagree",
      "Don't Know / Neutral",
      "Lean Agree",
      "Agree",
      "Strong Agree"
    )
  } else if (length(breaks) == 6) {
    break_labels <- c(
      "Strongly Disagree",
      "Disagree",
      "Don't Know / Neutral",
      "Agree",
      "Strongly Agree"
    )
  } else if (length(breaks) == 5) {
    break_labels <- c(
      "Strongly Disagree",
      "Disagree",
      "Agree",
      "Strongly Agree"
    )
  } else {
    stop(
      "If you provide `draw_likert()` with a `breaks` argument, `breaks` must ",
      "be either 5, 6, or 8 elements long for 4, 5, or 7 category Likert data."
    )
  }

  return(draw_ordered(
    x = x,
    breaks = breaks,
    N = N,
    link = link,
    break_labels = break_labels
  ))
}