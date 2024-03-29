#' Draw discrete variables including binary, binomial count, poisson count,
#' ordered, and categorical
#'
#' Drawing discrete data based on probabilities or latent traits is a common
#' task that can be cumbersome. Each function in our discrete drawing set creates
#' a different type of discrete data: \code{draw_binary} creates binary 0/1 data,
#' \code{draw_binomial} creates binomial data (repeated trial binary data),
#' \code{draw_categorical} creates categorical data, \code{draw_ordered}
#' transforms latent data into observed ordered categories, \code{draw_count}
#' creates count data (poisson-distributed).
#'
#' For variables with intra-cluster correlations, see
#' \code{\link{draw_binary_icc}} and \code{\link{draw_normal_icc}}
#'
#' @param prob A number or vector of numbers representing the probability for
#' binary or binomial outcomes; or a number, vector, or matrix of numbers
#' representing probabilities for categorical outcomes. If you supply a link
#' function, these underlying probabilities will be transformed.
#' @param trials for \code{draw_binomial}, the number of trials for each observation
#' @param mean for \code{draw_count}, the mean number of count units for each observation
#' @param x for \code{draw_ordered}, the latent data for each
#' observation.
#' @param type The number of buckets to split data into. For a median split,
#' enter 2; for terciles, enter 3; for quartiles, enter 4; for quintiles, 5;
#' for deciles, 10.
#' @param breaks vector of breaks to cut a latent outcome into ordered
#' categories with \code{draw_ordered}
#' @param break_labels vector of labels for the breaks to cut a latent outcome
#' into ordered categories with \code{draw_ordered}. (Optional)
#' @param category_labels vector of labels for the categories produced by
#' \code{draw_categorical}. If provided, must be equal to the number of categories
#' provided in the \code{prob} argument.
#' @param N number of units to draw. Defaults to the length of the vector of
#' probabilities or latent data you provided.
#' @param link link function between the latent variable and the probability of
#' a positive outcome, e.g. "logit", "probit", or "identity". For the "identity"
#' link, the latent variable must be a probability.
#' @param latent If the user provides a link argument other than identity, they
#' should provide the variable \code{latent} rather than \code{prob} or \code{mean}
#' @param strict Logical indicating whether values outside the provided breaks should be coded as NA. Defaults to \code{FALSE}, in which case effectively additional breaks are added between -Inf and the lowest break and between the highest break and Inf.
#' @param quantile_y A vector of quantiles; if provided, rather than drawing
#' stochastically from the distribution of interest, data will be drawn at
#' exactly those quantiles.
#' @return A vector of data in accordance with the specification; generally
#' numeric but for some functions, including \code{draw_ordered} and
#' \code{draw_categorical}, may be factor if labels are provided.
#' @name draw_discrete
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
#'    binary = draw_binary(latent = x, link = "probit"))
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
#' @importFrom stats pnorm rnorm rpois rbinom na.omit qbinom qpois
#' @export
#'
draw_binomial <- function(prob = link(latent),
                          trials = 1, N = length(prob),
                          latent = NULL,
                          link = "identity",
                          quantile_y = NULL) {

  # Handle link function - try matching normal way, and fallback
  # to manual logic for probit/logit
  link <- tryCatch(match.fun(link), error = handle_link_functions(link))

  # Error handle probabilities and apply link function.
  if (mode(prob) != "numeric") {
    stop("Probabilities provided in the `prob` argument must be numeric.")
  }

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

  # Prob and trials must be single numbers if quantile_y is provided
  if(!is.null(quantile_y) && (length(prob) > 1 || length(trials) > 1)) {
    stop(
      "When generating a correlated binary or binomial random variable, the ",
      "`prob` and `trials` arguments must be single numbers and not a ",
      "function of other variables."
    )
  }

  if(is.null(quantile_y)) {
    return(rbinom(N, trials, prob))
  } else {
    return(qbinom(quantile_y, trials, prob))
  }
}

#' @rdname draw_discrete
#' @export
draw_categorical <- function(prob = link(latent), N = NULL,
                             latent = NULL,
                             link = "identity",
                             category_labels = NULL) {

  # Handle link function - try matching normal way, and fallback
  # to manual logic for probit/logit
  link <- tryCatch(match.fun(link), error = handle_link_functions(link))

  if (!identical(link, identity)) {
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
    } else {
      stop(
        "For a categorical (multinomial) distribution, a matrix of ",
        "probabilities must be provided"
      )
    }
  }
  if (any(prob < 0)) {
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

  if(!is.null(category_labels) && length(category_labels) != ncol(prob)) {
    stop("If provided, the number of category labels (",
         length(category_labels),
         ") must equal the number of categories. (", ncol(prob), ")")
  }

  m <- ncol(prob)
  rcateg <- function(p)
    sample(1:m, 1, prob = p)

  draws <- apply(prob, 1, rcateg)

  if(!is.null(category_labels)) {
    return(factor(draws, levels = 1:m, labels = category_labels))
  } else {
    return(draws)
  }
}

#' @rdname draw_discrete
#' @export
draw_ordered <- function(x = link(latent),
                         breaks = c(-1, 0, 1),
                         break_labels = NULL,
                         N = length(x),
                         latent = NULL,
                         strict = FALSE,
                         link = "identity") {

  # Handle link function - try matching normal way, and fallback
  # to manual logic for probit/logit
  link <- tryCatch(match.fun(link), error = handle_link_functions(link))

  if (!identical(link, identity)) {
    stop("`draw_ordered` only allows the \"identity\" link.")
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

  add_to_value <- !strict & !any(is.infinite(breaks) & sign(breaks))

  # Make sure break labels are concordant with breaks.
  if (!is.null(break_labels) &&
    (is.vector(break_labels) &&
      !is.logical(break_labels) &&
      all(!is.na(break_labels)) &&
      length(break_labels) != length(breaks) + ifelse(add_to_value, 1, -1))) {
    stop(
      "Break labels should be of length one more than breaks. ",
      "Currently you have ", length(break_labels), " bucket labels and ",
      length(breaks) - 1, " buckets of data."
    )
  }

  # Output

  if (!is.null(break_labels)) {
    ret <- factor(
      findInterval(x, breaks) + add_to_value,
      levels = 1:length(break_labels),
      labels = break_labels,
      ordered = TRUE
    )
  } else {
    ret <- findInterval(x, breaks) + add_to_value
  }
  if(strict == TRUE){
    ret[x > breaks[length(breaks)] | x < breaks[1]] <- NA
  }
  return(ret)
}

#' @rdname draw_discrete
#' @export
draw_count <- function(mean=link(latent),
                       N = length(mean),
                       latent = NULL,
                       link = "identity",
                       quantile_y = NULL) {

  # Handle link function - try matching normal way, and fallback
  # to manual logic for probit/logit
  link <- tryCatch(match.fun(link), error = handle_link_functions(link))

  if (!identical(link, identity)) {
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

  # Prob and trials must be single numbers if quantile_y is provided
  if(!is.null(quantile_y) && length(mean) > 1) {
    stop(
      "When generating a correlated count variable, the `mean` argument must ",
      "be a single number and not a function of other variables."
    )
  }

  if(is.null(quantile_y)) {
    return(rpois(N, lambda = mean))
  } else {
    return(qpois(quantile_y, lambda = mean))
  }

}

#' @rdname draw_discrete
#' @export
draw_binary <- function(prob = link(latent), N = length(prob),
                        link = "identity",
                        latent = NULL,
                        quantile_y = NULL) {

  # Handle link function - try matching normal way, and fallback
  # to manual logic for probit/logit
  link <- tryCatch(match.fun(link), error = handle_link_functions(link))

  draw_binomial(
    prob = prob,
    N = N,
    link = link,
    trials = 1,
    latent = latent,
    quantile_y = quantile_y
  )
}

#' Recode a latent variable into a Likert response variable
#'
#' @param x a numeric variable considered to be "latent"
#'
#' @param min the minimum value of the latent variable
#' @param max the maximum value of the latent variable
#' @param bins the number of Likert scale values. The latent variable will be cut into equally sized bins as in seq(min, max, length.out = bins + 1)
#' @param breaks A vector of breaks. This option is useful for settings in which equally-sized breaks are inappropriate
#' @param labels An optional vector of labels. If labels are provided, the resulting output will be a factor.
#'
#' @export
#'
#' @examples
#'
#' x <- 1:100
#'
#' draw_likert(x, min = 0, max = 100, bins = 7)
#' draw_likert(x, breaks = c(-1, 10, 100))
#'
#'
draw_likert <- function(x,
                        min = NULL,
                        max = NULL,
                        bins = NULL,
                        breaks = NULL,
                        labels = NULL) {
  if (is.null(breaks) &&
      (is.null(min) & is.null(max) & is.null(bins))) {
    stop(
      "You must provide either `breaks` or `min`, `max`, and `bins` to a `draw_likert()` ",
      "call."
    )
  }

  if (is.null(breaks)) {
    breaks <- seq(min, max, length.out = bins + 1)
  }

  x_ret <- cut(x, breaks)
  x_ret <- as.numeric(x_ret)

  if(!is.null(labels)){
    x_ret <- factor(x_ret, levels = unique(x_ret), labels = labels)
  }

  x_ret
}





#' @rdname draw_discrete
#' @importFrom stats runif
#' @export
draw_quantile <- function(type, N) {

  if(!is_scalar_integerish(N) || N <= 0) {
    stop("`N` must be provided to `draw_quantile()` and must be a single positive number.")
  }

  if(!is_scalar_integerish(type) || type <= 1 || type >= N) {
    stop("`type` must be a single number between 2 and N-1.")
  }

  latent_data <- runif(n = N, min = 0, max = 1)
  split_quantile(latent_data, type = type)
}

#' Split data into quantile buckets (e.g. terciles, quartiles, quantiles,
#' deciles).
#'
#' Survey data is often presented in aggregated, depersonalized form, which
#' can involve binning underlying data into quantile buckets; for example,
#' rather than reporting underlying income, a survey might report income by
#' decile. \code{split_quantile} can automatically produce this split using any
#' data \code{x} and any number of splits `type.
#'
#' @param x A vector of any type that can be ordered -- i.e. numeric or factor
#' where factor levels are ordered.
#' @param type The number of buckets to split data into. For a median split,
#' enter 2; for terciles, enter 3; for quartiles, enter 4; for quintiles, 5;
#' for deciles, 10.
#'
#' @examples
#'
#' # Divide this arbitrary data set in 3.
#' data_input <- rnorm(n = 100)
#' split_quantile(x = data_input, type = 3)
#'
#' @importFrom stats quantile
#' @export
split_quantile <- function(x = NULL,
                           type = NULL) {
  if(length(x) < 2) {
    stop("The `x` argument provided to quantile split must be non-null and ",
         "length at least 2.")
  }
  if(!is.numeric(type)) {
    stop("The `type` argument provided to quantile split must be non-null and ",
         "numeric.")
  }

  cut(x, breaks = quantile(x, probs = seq(0, 1, length.out = type + 1)),
      labels = 1:type,
      include.lowest = TRUE)
}

#' @importFrom stats plogis pnorm
handle_link_functions <- function(link){
  function(cond) switch(link,
                        probit=pnorm,
                        logit=plogis,
                        stop("You must provide a link function in order to",
                             "use `draw_*` functions. Valid link functions ",
                             "include `identity`, `probit`, and `logit`"))
}
